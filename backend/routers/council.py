"""
council.py — Multi-Agent Council 路由
挂载在 /api/council

端点：
  POST /api/council/convene          — 召开议事会，返回 CouncilDecision
  POST /api/council/feedback         — 路由 FeedbackSignal 到对应 Agent
  POST /api/council/principal/strategy   — 校长制定战略
  POST /api/council/advisor/schedule     — 班主任排课
  POST /api/council/subject/execute      — 各科老师执行 Skill
  POST /api/council/companion/observe    — 同桌观察并生成反馈信号
"""
from __future__ import annotations

import json
import logging
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from deps import get_current_user

router = APIRouter()
logger = logging.getLogger(__name__)


# ── Pydantic 模型 ──────────────────────────────────────────────────────────────


class AgentOpinionOut(BaseModel):
    agent_id: str
    role: str
    content: str
    structured_data: dict[str, Any] = {}


class CouncilDecisionOut(BaseModel):
    summary: str
    opinions: list[AgentOpinionOut] = []
    action_items: dict[str, Any] = {}


class ConveneIn(BaseModel):
    topic: str
    agenda_type: str          # strategyReview | planScheduling | progressReview | skillCreation | emergencyAdjust
    context: dict[str, Any] = {}
    subject_id: Optional[int] = None


class FeedbackSignalIn(BaseModel):
    level: str                # fast | medium | slow
    subject_id: str
    message: str
    metrics: dict[str, Any] = {}


class StrategyIn(BaseModel):
    user_profile: str
    agenda: str
    other_opinions: str = ""
    deviation_threshold: int = -1  # -1 表示使用配置默认值


class ScheduleIn(BaseModel):
    current_plan: str
    subject_progress: str
    companion_feedback: str = ""


class SubjectExecuteIn(BaseModel):
    subject_name: str
    skill_name: str
    skill_id: str
    lesson_goal: str
    error_rate: str = "未知"
    weak_points: str = "暂无"
    session_id: Optional[str] = None
    subject_id: Optional[int] = None


class CompanionObserveIn(BaseModel):
    focus_minutes: int
    mistake_count: int
    emotion_keywords: str = ""
    declining_subjects: str = ""
    session_id: Optional[str] = None


# ── 议事会 ─────────────────────────────────────────────────────────────────────


@router.post("/convene", response_model=CouncilDecisionOut)
def convene(body: ConveneIn, user=Depends(get_current_user)):
    """
    召开议事会。根据 agenda_type 决定哪些 Agent 参与，合成 CouncilDecision。

    agenda_type 对应参与者：
    - strategyReview：校长主持，班主任列席
    - planScheduling：班主任主持，各科老师列席
    - progressReview：班主任主持，同桌汇报
    - skillCreation：校长主持，班主任列席
    - emergencyAdjust：同桌触发，班主任响应
    """
    from services.llm_service import LLMService

    agenda_type = body.agenda_type
    opinions: list[AgentOpinionOut] = []

    try:
        llm = LLMService()

        if agenda_type in ("strategyReview", "skillCreation"):
            # 校长主持
            principal_opinion = _call_principal(
                llm=llm,
                user_profile=f"用户 ID: {user['id']}",
                agenda=body.topic,
                other_opinions="",
                context=body.context,
            )
            opinions.append(principal_opinion)

            # 班主任列席
            advisor_opinion = _call_advisor(
                llm=llm,
                current_plan="待制定",
                subject_progress="待评估",
                companion_feedback="",
                context=body.context,
            )
            opinions.append(advisor_opinion)

        elif agenda_type in ("planScheduling", "progressReview"):
            # 班主任主持
            advisor_opinion = _call_advisor(
                llm=llm,
                current_plan=str(body.context.get("current_plan", "待制定")),
                subject_progress=str(body.context.get("subject_progress", "待评估")),
                companion_feedback=str(body.context.get("companion_feedback", "")),
                context=body.context,
            )
            opinions.append(advisor_opinion)

        elif agenda_type == "emergencyAdjust":
            # 同桌触发，班主任响应
            advisor_opinion = _call_advisor(
                llm=llm,
                current_plan=str(body.context.get("current_plan", "待制定")),
                subject_progress=str(body.context.get("subject_progress", "待评估")),
                companion_feedback=body.topic,
                context=body.context,
            )
            opinions.append(advisor_opinion)

        # 合成决策摘要
        summary = _synthesize_decision(llm, body.topic, opinions)

    except RuntimeError as e:
        # AI 不可用时返回骨架决策，不中断流程
        logger.warning("AgentCouncil convene AI 不可用，返回骨架决策: %s", e)
        summary = f"议题「{body.topic}」已记录，待 AI 服务恢复后处理。"

    return CouncilDecisionOut(
        summary=summary,
        opinions=opinions,
        action_items={"agenda_type": agenda_type, "topic": body.topic},
    )


# ── 反馈路由 ───────────────────────────────────────────────────────────────────


@router.post("/feedback")
def route_feedback(body: FeedbackSignalIn, user=Depends(get_current_user)):
    """
    路由 FeedbackSignal 到对应 Agent（甲状腺轴模型）。

    fast   → SubjectAgent（立即响应）
    medium → ClassAdvisorAgent（每天汇总）
    slow   → PrincipalAgent（每周评估）
    """
    from services.llm_service import LLMService

    level = body.level
    response_content = ""

    try:
        llm = LLMService()

        if level == "fast":
            # 快反馈：直接告诉当前科目老师
            response_content = _fast_feedback_to_subject(llm, body)
        elif level == "medium":
            # 中反馈：告诉班主任
            response_content = _medium_feedback_to_advisor(llm, body)
        elif level == "slow":
            # 慢反馈：告诉校长
            response_content = _slow_feedback_to_principal(llm, body)
        else:
            raise HTTPException(400, f"未知反馈级别：{level}")

    except RuntimeError as e:
        logger.warning("FeedbackSignal 路由 AI 不可用: %s", e)
        response_content = f"反馈已记录（{level} 级），待处理。"

    return {
        "level": level,
        "subject_id": body.subject_id,
        "routed_to": _feedback_target(level),
        "response": response_content,
    }


# ── 校长端点 ───────────────────────────────────────────────────────────────────


@router.post("/principal/strategy", response_model=CouncilDecisionOut)
def principal_strategy(body: StrategyIn, user=Depends(get_current_user)):
    """校长制定战略：分析用户目标，产出战略 Plan 草稿。"""
    from services.llm_service import LLMService

    try:
        llm = LLMService()
        opinion = _call_principal(
            llm=llm,
            user_profile=body.user_profile,
            agenda=body.agenda,
            other_opinions=body.other_opinions,
            context={"deviation_threshold": body.deviation_threshold},
        )
        return CouncilDecisionOut(
            summary=opinion.content[:200],
            opinions=[opinion],
            action_items=_parse_action_items(opinion.content),
        )
    except RuntimeError as e:
        raise HTTPException(502, f"AI 服务暂时不可用：{e}")


# ── 班主任端点 ─────────────────────────────────────────────────────────────────


@router.post("/advisor/schedule", response_model=CouncilDecisionOut)
def advisor_schedule(body: ScheduleIn, user=Depends(get_current_user)):
    """班主任排课：将战略目标转化为具体周/日计划。"""
    from services.llm_service import LLMService

    try:
        llm = LLMService()
        opinion = _call_advisor(
            llm=llm,
            current_plan=body.current_plan,
            subject_progress=body.subject_progress,
            companion_feedback=body.companion_feedback,
            context={},
        )
        return CouncilDecisionOut(
            summary=opinion.content[:200],
            opinions=[opinion],
            action_items=_parse_action_items(opinion.content),
        )
    except RuntimeError as e:
        raise HTTPException(502, f"AI 服务暂时不可用：{e}")


# ── 各科老师端点 ───────────────────────────────────────────────────────────────


@router.post("/subject/execute")
def subject_execute(body: SubjectExecuteIn, user=Depends(get_current_user)):
    """各科老师执行 Skill：按 Skill 的 PromptChain 教学。"""
    from services.llm_service import LLMService
    from backend_config import get_config

    cfg = get_config()

    _SUBJECT_TEACHER_PROMPT = """你是{subject_name}老师，负责辅导学生学习{subject_name}。

【身份与风格】
专业、耐心、善于因材施教。你使用的教学方法是：{skill_name}。

【职责边界】
✓ 按照指定的 Skill（{skill_name}）执行教学
✓ 回答学生关于{subject_name}的问题
✓ 出题、批改、讲解错题
✓ 当同桌反馈学生状态异常时，调整当前课堂节奏
✗ 不跨学科教学
✗ 不修改整体学习计划（向班主任反映）

【当前学科状态】
错题率：{error_rate}
本节课目标：{lesson_goal}
学生薄弱点：{weak_points}"""

    try:
        from prompt_manager import PromptManager
        system_prompt = PromptManager().get(
            "council/agents.yaml", "subject_teacher",
            subject_name=body.subject_name,
            skill_name=body.skill_name,
            error_rate=body.error_rate,
            lesson_goal=body.lesson_goal,
            weak_points=body.weak_points,
        )
    except Exception:
        system_prompt = _SUBJECT_TEACHER_PROMPT.format(
            subject_name=body.subject_name,
            skill_name=body.skill_name,
            error_rate=body.error_rate,
            lesson_goal=body.lesson_goal,
            weak_points=body.weak_points,
        )

    try:
        llm = LLMService()
        model = llm.get_model_for_scene("heavy")
        content = llm.chat(
            [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": f"请开始今天的{body.subject_name}课，目标：{body.lesson_goal}"},
            ],
            model=model,
            max_tokens=cfg.LLM_COUNCIL_SUBJECT_TEACHER_MAX_TOKENS,
        )
        return {
            "subject_name": body.subject_name,
            "skill_name": body.skill_name,
            "content": content,
            "agent_role": "subject_teacher",
        }
    except RuntimeError as e:
        raise HTTPException(502, f"AI 服务暂时不可用：{e}")


# ── 同桌端点 ───────────────────────────────────────────────────────────────────


@router.post("/companion/observe")
def companion_observe(body: CompanionObserveIn, user=Depends(get_current_user)):
    """
    同桌观察学习状态，生成分级 FeedbackSignal。
    返回：用户可见的同桌消息 + 内部 FeedbackSignal 列表。
    """
    from services.llm_service import LLMService
    from backend_config import get_config

    cfg = get_config()

    _COMPANION_PROMPT = """你是用户的同桌，陪伴他一起学习。

【身份与风格】
轻松、真实、像朋友，但不失正经。你会关心他的状态，偶尔开个小玩笑，
但在他需要专注的时候不打扰。

【职责边界】
✓ 观察学习状态：错题率、专注时长、情绪词
✓ 快反馈（立即）：发现某题连续错3次，提醒当前老师换个讲法
✓ 中反馈（每天）：汇总今日情况，告诉班主任
✓ 慢反馈（每周）：整体趋势分析，告诉校长
✗ 不主动教学，不出题，不批改

【当前观察数据】
今日专注时长：{focus_minutes} 分钟
今日错题数：{mistake_count}
情绪关键词：{emotion_keywords}
连续掉分学科：{declining_subjects}

请用轻松的口吻给用户一句话反馈，同时以 JSON 格式输出 feedback_signals 列表：
{{"message": "...", "feedback_signals": [{{"level": "fast|medium|slow", "subject_id": "...", "message": "..."}}]}}"""

    try:
        from prompt_manager import PromptManager
        prompt = PromptManager().get(
            "council/agents.yaml", "companion", field="user",
            focus_minutes=body.focus_minutes,
            mistake_count=body.mistake_count,
            emotion_keywords=body.emotion_keywords or "无",
            declining_subjects=body.declining_subjects or "无",
        )
    except Exception:
        prompt = _COMPANION_PROMPT.format(
            focus_minutes=body.focus_minutes,
            mistake_count=body.mistake_count,
            emotion_keywords=body.emotion_keywords or "无",
            declining_subjects=body.declining_subjects or "无",
        )

    try:
        llm = LLMService()
        model = llm.get_model_for_scene("fast")
        raw = llm.chat([{"role": "user", "content": prompt}], model=model, max_tokens=cfg.LLM_COUNCIL_FEEDBACK_MAX_TOKENS)

        # 解析 JSON
        raw = raw.strip()
        if raw.startswith("```"):
            lines = raw.splitlines()
            raw = "\n".join(lines[1:-1] if lines[-1].strip() == "```" else lines[1:])
        data = json.loads(raw)

        return {
            "message": data.get("message", "今天辛苦了！"),
            "feedback_signals": data.get("feedback_signals", []),
            "agent_role": "companion",
        }
    except (RuntimeError, json.JSONDecodeError, ValueError) as e:
        logger.warning("同桌观察 AI 失败，返回默认消息: %s", e)
        # 硬编码兜底：AI 不可用时返回默认消息
        return {
            "message": _default_companion_message(body, cfg),
            "feedback_signals": _default_feedback_signals(body, cfg),
            "agent_role": "companion",
            "degraded": True,
        }


# ── 内部工具函数 ───────────────────────────────────────────────────────────────


def _call_principal(
    llm: Any,
    user_profile: str,
    agenda: str,
    other_opinions: str,
    context: dict,
) -> AgentOpinionOut:
    """调用校长 Agent，返回 AgentOpinion。"""
    from backend_config import get_config
    cfg = get_config()
    deviation_threshold = context.get("deviation_threshold", -1)
    if deviation_threshold == -1:
        deviation_threshold = cfg.COUNCIL_DEVIATION_THRESHOLD_PERCENT

    _PRINCIPAL_PROMPT = """你是一个学习系统的校长，负责制定长期学习目标和整体策略。

【身份与风格】
严肃、有远见、言简意赅。你不参与具体教学，只关注全局。

【职责边界】
✓ 分析用户学习目标是否合理
✓ 评估整体资源（时间、精力）是否匹配目标
✓ 当整体进度偏差超过 {deviation_threshold}% 时主动介入
✗ 不干涉具体学科的教学方法

【当前学生画像】
{user_profile}

【当前会议议题】
{agenda}

【其他与会者意见】
{other_opinions}

请以 JSON 格式输出：{{"summary": "...", "action_items": {{}}}}"""

    try:
        from prompt_manager import PromptManager
        prompt = PromptManager().get(
            "council/agents.yaml", "principal",
            deviation_threshold=deviation_threshold,
            user_profile=user_profile,
            agenda=agenda,
            other_opinions=other_opinions or "暂无",
        )
    except Exception:
        prompt = _PRINCIPAL_PROMPT.format(
            deviation_threshold=deviation_threshold,
            user_profile=user_profile,
            agenda=agenda,
            other_opinions=other_opinions or "暂无",
        )

    model = llm.get_model_for_scene("heavy")
    content = llm.chat(
        [{"role": "system", "content": "你是学习系统的校长。"}, {"role": "user", "content": prompt}],
        model=model,
        max_tokens=cfg.LLM_COUNCIL_PRINCIPAL_MAX_TOKENS,
    )
    return AgentOpinionOut(agent_id="principal", role="principal", content=content)


def _call_advisor(
    llm: Any,
    current_plan: str,
    subject_progress: str,
    companion_feedback: str,
    context: dict,
) -> AgentOpinionOut:
    """调用班主任 Agent，返回 AgentOpinion。"""
    from backend_config import get_config
    cfg = get_config()

    _ADVISOR_PROMPT = """你是学生的班主任，负责将战略目标转化为具体的学习计划。

【职责边界】
✓ 将长期目标拆解为周计划和日计划
✓ 协调各科老师的课时需求，解决时间冲突
✓ 每天汇总同桌的反馈，决定是否需要调整计划

【当前计划状态】
{current_plan}

【各科进度】
{subject_progress}

【同桌今日反馈】
{companion_feedback}

请以 JSON 格式输出调整后的计划建议：{{"summary": "...", "action_items": {{}}}}"""

    try:
        from prompt_manager import PromptManager
        prompt = PromptManager().get(
            "council/agents.yaml", "advisor",
            current_plan=current_plan,
            subject_progress=subject_progress,
            companion_feedback=companion_feedback or "暂无",
        )
    except Exception:
        prompt = _ADVISOR_PROMPT.format(
            current_plan=current_plan,
            subject_progress=subject_progress,
            companion_feedback=companion_feedback or "暂无",
        )

    model = llm.get_model_for_scene("heavy")
    content = llm.chat(
        [{"role": "system", "content": "你是学生的班主任。"}, {"role": "user", "content": prompt}],
        model=model,
        max_tokens=cfg.LLM_COUNCIL_ADVISOR_MAX_TOKENS,
    )
    return AgentOpinionOut(agent_id="class_advisor", role="class_advisor", content=content)


def _synthesize_decision(llm: Any, topic: str, opinions: list[AgentOpinionOut]) -> str:
    """合成多个 Agent 意见为最终决策摘要。"""
    from backend_config import get_config
    cfg = get_config()
    if not opinions:
        return f"议题「{topic}」已记录，暂无 Agent 意见。"

    opinions_text = "\n".join(
        f"[{op.role}]: {op.content[:300]}" for op in opinions
    )
    prompt = f"""以下是关于议题「{topic}」的各方意见：

{opinions_text}

请用 2-3 句话总结最终决策，重点是行动项。"""

    try:
        model = llm.get_model_for_scene("fast")
        return llm.chat([{"role": "user", "content": prompt}], model=model, max_tokens=cfg.LLM_COUNCIL_DECISION_MAX_TOKENS)
    except Exception:
        return opinions[0].content[:200] if opinions else f"议题「{topic}」已处理。"


def _fast_feedback_to_subject(llm: Any, signal: FeedbackSignalIn) -> str:
    from backend_config import get_config
    cfg = get_config()
    prompt = f"""作为{signal.subject_id}老师，收到同桌的快速反馈：{signal.message}
请用一句话说明你会如何立即调整教学方式。"""
    model = llm.get_model_for_scene("fast")
    return llm.chat([{"role": "user", "content": prompt}], model=model, max_tokens=cfg.LLM_COUNCIL_FEEDBACK_MAX_TOKENS)


def _medium_feedback_to_advisor(llm: Any, signal: FeedbackSignalIn) -> str:
    from backend_config import get_config
    cfg = get_config()
    prompt = f"""作为班主任，收到同桌的每日反馈：{signal.message}（学科：{signal.subject_id}）
请用一句话说明是否需要调整今日计划。"""
    model = llm.get_model_for_scene("fast")
    return llm.chat([{"role": "user", "content": prompt}], model=model, max_tokens=cfg.LLM_COUNCIL_FEEDBACK_MAX_TOKENS)


def _slow_feedback_to_principal(llm: Any, signal: FeedbackSignalIn) -> str:
    from backend_config import get_config
    cfg = get_config()
    prompt = f"""作为校长，收到同桌的每周反馈：{signal.message}（学科：{signal.subject_id}）
请用一句话说明是否需要调整整体战略。"""
    model = llm.get_model_for_scene("fast")
    return llm.chat([{"role": "user", "content": prompt}], model=model, max_tokens=cfg.LLM_COUNCIL_FEEDBACK_MAX_TOKENS)


def _feedback_target(level: str) -> str:
    return {"fast": "subject_teacher", "medium": "class_advisor", "slow": "principal"}.get(level, "unknown")


def _parse_action_items(content: str) -> dict:
    """尝试从 LLM 输出中解析 action_items，失败时返回空字典。"""
    try:
        content = content.strip()
        if content.startswith("```"):
            lines = content.splitlines()
            content = "\n".join(lines[1:-1] if lines[-1].strip() == "```" else lines[1:])
        data = json.loads(content)
        return data.get("action_items", {})
    except Exception:
        return {}


def _default_companion_message(body: CompanionObserveIn, cfg=None) -> str:
    """AI 不可用时的硬编码同桌消息。"""
    if cfg is None:
        from backend_config import get_config
        cfg = get_config()
    if body.mistake_count > cfg.COMPANION_MISTAKE_THRESHOLD:
        return f"今天错了 {body.mistake_count} 道题，要不要休息一下再继续？"
    if body.focus_minutes < cfg.COMPANION_FOCUS_MINUTES_CRITICAL:
        return "今天专注时间有点短，明天加油！"
    return f"今天专注了 {body.focus_minutes} 分钟，不错！"


def _default_feedback_signals(body: CompanionObserveIn, cfg=None) -> list[dict]:
    """AI 不可用时的硬编码反馈信号。"""
    if cfg is None:
        from backend_config import get_config
        cfg = get_config()
    signals = []
    if body.mistake_count > cfg.COMPANION_MISTAKE_THRESHOLD:
        signals.append({
            "level": "fast",
            "subject_id": "unknown",
            "message": f"错题数较多（{body.mistake_count}），建议调整讲解方式",
        })
    if body.focus_minutes < cfg.COMPANION_FOCUS_MINUTES_WARN:
        signals.append({
            "level": "medium",
            "subject_id": "unknown",
            "message": f"今日专注时间不足（{body.focus_minutes}分钟），建议班主任关注",
        })
    return signals
