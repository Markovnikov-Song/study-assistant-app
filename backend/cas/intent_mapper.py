"""
IntentMapper — LLM 意图映射 + RuleMapper 关键词降级。

优先用 LLM 把用户输入映射到 action_id + params，
超时/不可用/返回非法结果时自动降级为 RuleMapper。
"""
from __future__ import annotations

import asyncio
import json
import logging
import re
from typing import Any

from .models import IntentMapResult

logger = logging.getLogger(__name__)

# ── RuleMapper 关键词表 ───────────────────────────────────────────────────────

_RULES: list[tuple[str, list[str]]] = [
    ("make_quiz",                 ["出题", "出几道", "考考我", "练习题", "测试题", "做题"]),
    ("make_plan",                 ["学习计划", "复习计划", "备考", "计划", "安排学习", "规划"]),
    ("open_calendar",             ["日历", "打开日历", "查看日历", "学习日历"]),
    ("add_calendar_event",        ["加到日历", "添加到日历", "记到日历", "日历提醒", "安排"]),
    ("recommend_mistake_practice",["错题", "复盘", "薄弱", "针对练习", "错误"]),
    ("open_notebook",             ["笔记", "笔记本", "打开笔记"]),
    ("explain_concept",           ["解释", "什么是", "讲解", "说明", "介绍一下"]),
    ("solve_problem",             ["解题", "解答", "帮我做", "这道题", "解这道"]),
    ("open_course_space",         ["讲义", "课程", "大纲", "思维导图", "图书馆", "打开课程"]),
]


class RuleMapper:
    """基于关键词的本地规则映射，不依赖 LLM，降级时使用。"""

    def map(self, text: str) -> IntentMapResult:
        lower = text.lower()
        for action_id, keywords in _RULES:
            if any(kw in lower for kw in keywords):
                return IntentMapResult(
                    action_id=action_id,
                    params={},
                    confidence=0.5,
                    degraded=True,
                )
        return IntentMapResult(
            action_id="unknown_intent",
            params={},
            confidence=0.5,
            degraded=True,
        )


class IntentMapper:
    """
    LLM 意图映射，失败时自动降级为 RuleMapper。
    超时（>3s）、LLM 不可用、返回非法 JSON、action_id 不在注册表中，
    均静默降级，不向调用方传播异常。
    """

    _rule_mapper = RuleMapper()

    async def map(
        self,
        text: str,
        session_id: str | None = None,
        timeout_seconds: float = 3.0,
    ) -> IntentMapResult:
        """
        将用户输入映射到 action_id + params。
        任何路径均不抛出异常。
        """
        try:
            result = await asyncio.wait_for(
                self._llm_map(text, session_id),
                timeout=timeout_seconds,
            )
            return result
        except asyncio.TimeoutError:
            logger.warning("IntentMapper: LLM 超时（>%.1fs），降级为 RuleMapper", timeout_seconds)
            return self._rule_mapper.map(text)
        except Exception as exc:
            logger.warning("IntentMapper: LLM 映射失败（%s），降级为 RuleMapper", exc)
            return self._rule_mapper.map(text)

    async def _llm_map(self, text: str, session_id: str | None) -> IntentMapResult:
        """调用 LLM 进行意图映射（在线程池中执行同步 LLM 调用）。"""
        from cas.action_registry import get_action_registry
        from services.llm_service import LLMService
        from backend_config import get_config

        registry = get_action_registry()
        summaries = registry.summaries()

        prompt = f"""你是一个意图识别助手。根据用户输入，从以下 Action 列表中选择最匹配的一个，并提取参数。

可用 Action 列表：
{summaries}

用户输入：{text}

请以 JSON 格式返回，结构如下（只返回 JSON，不要 markdown 代码块）：
{{
  "action_id": "action的id",
  "params": {{}},
  "confidence": 0.9
}}

要求：
1. action_id 必须是上面列表中的某一个
2. params 中只包含能从用户输入中提取到的参数，无法提取的参数不要填
3. confidence 在 0.0-1.0 之间
4. 如果无法匹配任何 Action，使用 unknown_intent"""

        loop = asyncio.get_event_loop()
        raw = await loop.run_in_executor(
            None,
            lambda: LLMService().chat(
                [{"role": "user", "content": prompt}],
                max_tokens=get_config().LLM_SKILL_RECOMMEND_MAX_TOKENS,
            ),
        )

        # 解析 JSON
        raw = raw.strip()
        if raw.startswith("```"):
            lines = raw.splitlines()
            raw = "\n".join(lines[1:-1] if lines[-1].strip() == "```" else lines[1:])

        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            logger.warning("IntentMapper: LLM 返回非法 JSON，降级为 RuleMapper")
            return self._rule_mapper.map(text)

        action_id = data.get("action_id", "unknown_intent")
        # 验证 action_id 存在于注册表
        if not registry.get_action(action_id):
            logger.warning("IntentMapper: LLM 返回不存在的 action_id '%s'，使用 unknown_intent", action_id)
            action_id = "unknown_intent"

        confidence = float(data.get("confidence", 0.8))
        confidence = max(0.0, min(1.0, confidence))

        return IntentMapResult(
            action_id=action_id,
            params=data.get("params") or {},
            confidence=confidence,
            degraded=False,
        )
