# backend/skill_ecosystem/ai_model_adapter.py
"""
SkillParser 适配器：
  - AIModelAdapter：调用 LLMService 解析文本，失败时自动降级为 RuleBasedAdapter
  - RuleBasedAdapter：基于规则提取编号列表作为 PromptNode
支持运行时切换适配器（全局变量 _current_adapter）。
"""
from __future__ import annotations

import json
import re
import time
import uuid
from typing import Optional

from skill_ecosystem.models import ParseLog, PromptNodeSchema, SkillDraftSchema

# ── 全局适配器状态 ─────────────────────────────────────────────────────────────
# 可选值："ai" | "rule_based"
_current_adapter: str = "ai"


def get_current_adapter_name() -> str:
    """返回当前适配器名称。"""
    return _current_adapter


def set_current_adapter(name: str) -> None:
    """运行时切换适配器。name 必须为 'ai' 或 'rule_based'。"""
    global _current_adapter
    if name not in ("ai", "rule_based"):
        raise ValueError(f"未知适配器：{name}，可选值为 'ai' 或 'rule_based'")
    _current_adapter = name


def parse_text(text: str) -> SkillDraftSchema:
    """根据当前适配器配置解析文本，返回 SkillDraftSchema。"""
    if _current_adapter == "ai":
        return AIModelAdapter().parse(text)
    return RuleBasedAdapter().parse(text)


# ── AIModelAdapter ─────────────────────────────────────────────────────────────


class AIModelAdapter:
    """
    实现 SkillParser 接口，将 LLMService 封装为可插拔的解析适配器。
    AI 失败时自动降级为 RuleBasedAdapter。
    """

    PARSE_PROMPT_TEMPLATE = """你是一个学习方法结构化专家。请将以下学习经验文本解析为结构化的 Skill 定义。

要求：
1. 提取学习步骤，每个步骤生成一个 PromptNode
2. 识别适用学科标签
3. 生成简洁的名称和描述
4. 以 JSON 格式返回，结构见下方 Schema

输入文本：
{text}

返回 JSON Schema：
{{
  "name": "string",
  "description": "string",
  "tags": ["string"],
  "steps": [{{"id": "string", "prompt": "string", "input_mapping": {{}}}}]
}}

只返回 JSON，不要 markdown 代码块。"""

    def parse(self, text: str) -> SkillDraftSchema:
        """
        调用 LLMService 解析文本。
        失败时降级为 RuleBasedAdapter.parse(text)。
        记录：模型名称、耗时、输入字符数、输出节点数。
        """
        from services.llm_service import LLMService
        from backend_config import get_config

        try:
            from prompt_manager import PromptManager
            prompt = PromptManager().get("skill/parse.yaml", "parse", field="user", text=text)
        except Exception:
            prompt = self.PARSE_PROMPT_TEMPLATE.replace("{text}", text)
        model_name = "unknown"
        start = time.time()

        try:
            llm = LLMService()
            model_name = llm.get_model_for_scene("fast")
            raw = llm.chat(
                [{"role": "user", "content": prompt}],
                model=model_name,
                max_tokens=get_config().LLM_SKILL_PARSE_MAX_TOKENS,
            )

            # 去掉可能的 markdown 代码块包裹
            raw = raw.strip()
            if raw.startswith("```"):
                lines = raw.splitlines()
                raw = "\n".join(lines[1:-1] if lines[-1].strip() == "```" else lines[1:])

            data = json.loads(raw)
            steps_raw = data.get("steps") or []
            steps: list[PromptNodeSchema] = []
            for i, s in enumerate(steps_raw):
                steps.append(
                    PromptNodeSchema(
                        id=s.get("id") or f"node_{i}",
                        prompt=s.get("prompt", ""),
                        input_mapping=s.get("input_mapping") or {},
                    )
                )

            duration_ms = (time.time() - start) * 1000
            _record_log(
                ParseLog(
                    model_name=model_name,
                    duration_ms=duration_ms,
                    input_char_count=len(text),
                    output_node_count=len(steps),
                    success=True,
                )
            )

            return SkillDraftSchema(
                name=data.get("name"),
                description=data.get("description"),
                tags=list(data.get("tags") or []),
                steps=steps,
                source_text_length=len(text),
            )

        except Exception as exc:
            duration_ms = (time.time() - start) * 1000
            _record_log(
                ParseLog(
                    model_name=model_name,
                    duration_ms=duration_ms,
                    input_char_count=len(text),
                    output_node_count=0,
                    success=False,
                    error=str(exc),
                )
            )
            # 自动降级为规则解析
            return RuleBasedAdapter().parse(text)


# ── RuleBasedAdapter ───────────────────────────────────────────────────────────


class RuleBasedAdapter:
    """
    基于规则的降级解析器。
    提取编号列表（1. 2. 3. 或 一、二、三 或 - 列表项）作为 PromptNode。
    保证包含有效步骤结构的文本至少生成一个 PromptNode（属性 10）。
    """

    # 中文数字映射
    _CN_DIGITS = {
        "一": 1, "二": 2, "三": 3, "四": 4, "五": 5,
        "六": 6, "七": 7, "八": 8, "九": 9, "十": 10,
    }

    def parse(self, text: str) -> SkillDraftSchema:
        """提取编号列表作为 PromptNode，生成最小可用草稿。"""
        steps = self._extract_steps(text)

        return SkillDraftSchema(
            name=None,
            description=None,
            tags=[],
            steps=steps,
            source_text_length=len(text),
        )

    def _extract_steps(self, text: str) -> list[PromptNodeSchema]:
        """
        按优先级尝试三种提取策略：
        1. 阿拉伯数字编号列表（1. / 1、/ 1) / (1)）
        2. 中文数字编号列表（一、/ 二、）
        3. 破折号/星号列表项（- / * / • ）
        """
        steps: list[PromptNodeSchema] = []

        # 策略 1：阿拉伯数字编号
        arabic_pattern = re.compile(
            r"^\s*(?:\d+[\.、\)）]|\(\d+\))\s*(.+)$", re.MULTILINE
        )
        matches = arabic_pattern.findall(text)
        if matches:
            for i, content in enumerate(matches):
                steps.append(
                    PromptNodeSchema(
                        id=f"node_{i}",
                        prompt=content.strip(),
                        input_mapping={},
                    )
                )
            return steps

        # 策略 2：中文数字编号
        cn_pattern = re.compile(
            r"^\s*[一二三四五六七八九十][、。\.]\s*(.+)$", re.MULTILINE
        )
        matches = cn_pattern.findall(text)
        if matches:
            for i, content in enumerate(matches):
                steps.append(
                    PromptNodeSchema(
                        id=f"node_{i}",
                        prompt=content.strip(),
                        input_mapping={},
                    )
                )
            return steps

        # 策略 3：破折号/星号/圆点列表项
        bullet_pattern = re.compile(
            r"^\s*[-\*•]\s+(.+)$", re.MULTILINE
        )
        matches = bullet_pattern.findall(text)
        if matches:
            for i, content in enumerate(matches):
                steps.append(
                    PromptNodeSchema(
                        id=f"node_{i}",
                        prompt=content.strip(),
                        input_mapping={},
                    )
                )
            return steps

        # 兜底：将整段文本作为单个步骤（保证至少一个 PromptNode）
        stripped = text.strip()
        if stripped:
            steps.append(
                PromptNodeSchema(
                    id="node_0",
                    prompt=stripped,
                    input_mapping={},
                )
            )

        return steps


# ── 日志记录（内存，后续可接数据库）─────────────────────────────────────────────

_parse_logs: list[ParseLog] = []


def _record_log(log: ParseLog) -> None:
    _parse_logs.append(log)
    # 保留最近 1000 条
    if len(_parse_logs) > 1000:
        _parse_logs.pop(0)


def get_parse_logs() -> list[ParseLog]:
    """返回最近的解析日志（调试用）。"""
    return list(_parse_logs)
