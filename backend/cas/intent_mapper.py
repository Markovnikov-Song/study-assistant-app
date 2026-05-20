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

# ── 多模态短路豁免词表 ────────────────────────────────────────────────────────
# 有图片时默认短路到 solve_problem，但若 supplement_text 包含以下词，
# 说明用户有其他明确意图（如"把这道题加到日历"），取消短路放行给 LLM Router。
_NON_SOLVE_KEYWORDS: list[str] = [
    "日历", "导图", "思维导图", "笔记", "计划", "出题", "错题", "讲义", "课程",
]

# ── RuleMapper 关键词表 ───────────────────────────────────────────────────────

_RULES: list[tuple[str, list[str]]] = [
    ("create_mini_app",           ["学习小程序", "学习软件", "学习app", "学习应用", "背单词小程序", "百词斩", "多邻国", "拼装", "积木", "mini app", "mini-app", "workshop"]),
    ("make_quiz",                 ["出题", "出几道", "考考我", "练习题", "测试题", "做题"]),
    ("make_plan",                 ["学习计划", "复习计划", "备考", "计划", "安排学习", "规划"]),
    ("open_calendar",             ["日历", "打开日历", "查看日历", "学习日历"]),
    ("add_calendar_event",        ["加到日历", "添加到日历", "记到日历", "日历提醒", "安排"]),
    ("recommend_mistake_practice",["错题", "复盘", "薄弱", "针对练习", "错误"]),
    ("open_notebook",             ["笔记", "笔记本", "打开笔记"]),
    ("open_course_space",         ["讲义", "课程", "大纲", "思维导图", "图书馆", "打开课程"]),
    ("start_feynman",             ["费曼", "费曼学习法", "用自己的话", "讲给我听", "讲解一下", "费曼技巧"]),
    ("explain_concept",           ["什么是", "解释一下", "解释", "概念", "含义", "什么意思", "原理"]),
]


class RuleMapper:
    """基于关键词的本地规则映射，不依赖 LLM，降级时使用。"""

    def map(self, text: str, images: list[str] | None = None) -> IntentMapResult:
        # ── 多模态短路规则（优先级最高）────────────────────────────────────────
        # 有图片时，默认短路到 solve_problem（置信度 0.9）。
        # 豁免条件：supplement_text 包含其他明确系统动作词时，取消短路，
        # 继续走关键词规则，避免"把这道题加到日历"被误判为解题。
        if images:
            has_other_intent = any(kw in text for kw in _NON_SOLVE_KEYWORDS)
            if not has_other_intent:
                return IntentMapResult(
                    action_id="solve_problem",
                    params={"has_images": True},
                    confidence=0.9,
                    degraded=True,
                )
            # 有图片但含其他动作词 → 继续走关键词规则

        lower = text.lower()
        mini_app_keywords = [
            "\u5b66\u4e60\u5c0f\u7a0b\u5e8f",
            "\u5b66\u4e60\u8f6f\u4ef6",
            "\u5b66\u4e60app",
            "\u5b66\u4e60\u5e94\u7528",
            "\u80cc\u5355\u8bcd\u5c0f\u7a0b\u5e8f",
            "\u767e\u8bcd\u65a9",
            "\u591a\u90bb\u56fd",
            "\u62fc\u88c5",
            "\u79ef\u6728",
            "mini app",
            "mini-app",
            "workshop",
        ]
        if any(kw in lower for kw in mini_app_keywords):
            return IntentMapResult(
                action_id="create_mini_app",
                params={},
                confidence=0.7,
                degraded=True,
            )
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

    def extract_planning_params(self, text: str) -> dict:
        """从文本中提取学习规划参数"""
        from .models import PlanningParams
        import re
        from datetime import datetime, timedelta
        
        params = {
            'subject': None,
            'exam_date': None,
            'exam_scope': None,
            'daily_hours': 2.0,
            'target_score': None
        }
        
        # 提取学科（通过匹配已知学科）
        # 从文本中提取学科关键词
        subject_keywords = ['数学', '语文', '英语', '物理', '化学', '生物', '历史', '地理', '政治', '奥数']
        for subject in subject_keywords:
            if subject in text:
                params['subject'] = subject
                break
        
        # 提取日期（"下个月期末" → 具体日期）
        now = datetime.now()
        
        # 匹配"下周"
        if '下周' in text:
            params['exam_date'] = (now + timedelta(days=7)).strftime('%Y-%m-%d')
        # 匹配"下个月"
        elif '下个月' in text:
            if now.month == 12:
                params['exam_date'] = f"{now.year + 1}-01-15"
            else:
                params['exam_date'] = f"{now.year}-{now.month + 1:02d}-15"
        # 匹配"期末"
        elif '期末' in text:
            # 假设期末是6月15日或1月15日
            if now.month <= 6:
                params['exam_date'] = f"{now.year}-06-15"
            else:
                params['exam_date'] = f"{now.year + 1}-01-15"
        # 匹配"期中"
        elif '期中' in text:
            if now.month <= 4:
                params['exam_date'] = f"{now.year}-04-15"
            elif now.month <= 10:
                params['exam_date'] = f"{now.year}-10-15"
            else:
                params['exam_date'] = f"{now.year + 1}-04-15"
        # 匹配具体日期数字
        date_match = re.search(r'(\d{1,2})[月\-](\d{1,2})', text)
        if date_match:
            month = int(date_match.group(1))
            day = int(date_match.group(2))
            year = now.year if month >= now.month else now.year + 1
            params['exam_date'] = f"{year}-{month:02d}-{day:02d}"
        
        # 提取范围（"前五章"）
        scope_match = re.search(r'前(\d+)章', text)
        if scope_match:
            params['exam_scope'] = f"前{scope_match.group(1)}章"
        elif '全书' in text:
            params['exam_scope'] = '全书'
        elif '全部' in text:
            params['exam_scope'] = '全书'
        
        # 提取时长（"每天2小时"）
        hours_match = re.search(r'每天(\d+\.?\d*)小时', text)
        if hours_match:
            params['daily_hours'] = float(hours_match.group(1))
        
        # 提取目标分数
        score_match = re.search(r'(\d{2,3})分', text)
        if score_match:
            params['target_score'] = int(score_match.group(1))
        
        return params


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
        images: list[str] | None = None,
    ) -> IntentMapResult:
        """
        将用户输入映射到 action_id + params。
        任何路径均不抛出异常。
        """
        try:
            result = await asyncio.wait_for(
                self._llm_map(text, session_id, images=images),
                timeout=timeout_seconds,
            )
            return result
        except asyncio.TimeoutError:
            logger.warning("IntentMapper: LLM 超时（>%.1fs），降级为 RuleMapper", timeout_seconds)
            return self._rule_mapper.map(text, images=images)
        except Exception as exc:
            logger.warning("IntentMapper: LLM 映射失败（%s），降级为 RuleMapper", exc)
            return self._rule_mapper.map(text, images=images)

    async def _llm_map(self, text: str, session_id: str | None, images: list[str] | None = None) -> IntentMapResult:
        """调用 LLM 进行意图映射（在线程池中执行同步 LLM 调用）。"""
        # 有图片且无其他动作词时，直接短路，不消耗 LLM Token
        if images:
            has_other_intent = any(kw in text for kw in _NON_SOLVE_KEYWORDS)
            if not has_other_intent:
                return IntentMapResult(
                    action_id="solve_problem",
                    params={"has_images": True},
                    confidence=0.9,
                    degraded=False,
                )

        from cas.action_registry import get_action_registry
        from services.llm_service import LLMService
        from backend_config import get_config

        registry = get_action_registry()
        summaries = registry.summaries()

        prompt = f"""你是一个操作意图识别助手。根据用户输入，判断用户是否在发出"操作指令"，并从以下 Action 列表中选择最匹配的一个。

可用 Action 列表（均为工具/导航类操作）：
{summaries}

用户输入：{text}

【重要规则】
- 这些 Action 只对应明确的"操作指令"，例如：出题、加日历、打开某页面、生成计划等
- 如果用户是在"提问"、"求解释"、"问概念"、"问原理"、"让AI回答问题"，一律返回 unknown_intent
- 只有用户明确要求执行某个操作时，才映射到对应 Action

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
4. 如果无法匹配任何操作 Action，使用 unknown_intent"""

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
