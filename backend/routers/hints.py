"""
提示词建议 API
GET  /api/hints/{subject_id}?type=qa|solve  — 读缓存，无缓存返回空列表
POST /api/hints/{subject_id}/refresh        — 后台异步用 LLM 刷新，立即返回 202
"""
import logging
from typing import List, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, Query
from pydantic import BaseModel

from database import ConversationHistory, ConversationSession, HintSuggestion, Subject, get_session
from deps import get_current_user
from backend_config import get_config

logger = logging.getLogger(__name__)
router = APIRouter()


class HintsOut(BaseModel):
    hints: List[str]
    stale: bool  # True = 缓存存在但可能过时，前端可触发刷新


@router.get("/{subject_id}", response_model=HintsOut)
def get_hints(
    subject_id: int,
    type: str = Query("qa", pattern="^(qa|solve)$"),
    user=Depends(get_current_user),
):
    with get_session() as db:
        row = (
            db.query(HintSuggestion)
            .filter_by(user_id=user["id"], subject_id=subject_id, hint_type=type)
            .first()
        )
        if row:
            return HintsOut(hints=row.hints or [], stale=False)
        return HintsOut(hints=[], stale=True)


@router.post("/{subject_id}/refresh", status_code=202)
def refresh_hints(
    subject_id: int,
    background_tasks: BackgroundTasks,
    type: str = Query("qa", pattern="^(qa|solve)$"),
    user=Depends(get_current_user),
):
    """立即返回 202，后台异步生成并缓存提示词。"""
    background_tasks.add_task(_generate_and_cache, user["id"], subject_id, type)
    return {"status": "refreshing"}


# ---------------------------------------------------------------------------
# 后台任务
# ---------------------------------------------------------------------------

def _generate_and_cache(user_id: int, subject_id: int, hint_type: str):
    try:
        hints = _call_llm(user_id, subject_id, hint_type)
        if not hints:
            return
        with get_session() as db:
            row = (
                db.query(HintSuggestion)
                .filter_by(user_id=user_id, subject_id=subject_id, hint_type=hint_type)
                .first()
            )
            if row:
                row.hints = hints
            else:
                db.add(HintSuggestion(
                    user_id=user_id,
                    subject_id=subject_id,
                    hint_type=hint_type,
                    hints=hints,
                ))
    except Exception as e:
        logger.warning("hint refresh failed: %s", e)


def _call_llm(user_id: int, subject_id: int, hint_type: str) -> Optional[List[str]]:
    from services.llm_service import LLMService

    # 拉取学科名
    with get_session() as db:
        subject = db.query(Subject).filter_by(id=subject_id).first()
        if not subject:
            return None
        subject_name = subject.name

        # 取最近 20 条用户消息作为上下文
        recent_msgs = (
            db.query(ConversationHistory.content)
            .join(ConversationSession, ConversationHistory.session_id == ConversationSession.id)
            .filter(
                ConversationSession.subject_id == subject_id,
                ConversationSession.user_id == user_id,
                ConversationHistory.role == "user",
                ConversationSession.session_type == hint_type,
            )
            .order_by(ConversationHistory.created_at.desc())
            .limit(20)
            .all()
        )
        history_text = "\n".join(f"- {r.content}" for r in recent_msgs) if recent_msgs else "（暂无历史记录）"

    if hint_type == "qa":
        task_desc = "问答（理解概念、总结知识点、解释原理）"
        example = f"帮我理解{subject_name}中的XXX概念"
    else:
        task_desc = "解题（计算、证明、分析题目）"
        example = f"求解这道{subject_name}题：XXX"

    try:
        from prompt_manager import PromptManager
        prompt = PromptManager().get(
            "hints/suggest.yaml", "suggest", field="user",
            subject_name=subject_name,
            task_desc=task_desc,
            history_text=history_text,
            example=example,
        )
    except Exception:
        prompt = f"""你是一个学习助手。用户正在学习「{subject_name}」，以下是他最近的{task_desc}历史提问：

{history_text}

请根据学科特点和历史提问，生成 3 条适合该用户的新提问建议，用于{task_desc}场景。
要求：
1. 每条建议简洁，15字以内
2. 贴合「{subject_name}」学科内容
3. 与历史提问不重复，但可以延伸
4. 直接输出 3 行，每行一条，不要编号、不要解释

示例格式（仅供参考，请替换为真实内容）：
{example}
"""

    result = LLMService().chat(
        [{"role": "user", "content": prompt}],
        max_tokens=get_config().LLM_HINTS_MAX_TOKENS,
        temperature=get_config().LLM_HINTS_TEMPERATURE,
    )

    lines = [l.strip() for l in result.strip().splitlines() if l.strip()]
    # 最多取 N 条，过滤掉太长的
    cfg = get_config()
    hints = [l for l in lines if len(l) <= cfg.HINTS_MAX_CHARS][:cfg.HINTS_COUNT]
    return hints if hints else None
