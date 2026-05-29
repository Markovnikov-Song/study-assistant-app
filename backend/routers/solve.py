"""
解题历史 REST API 路由。
挂载在 /api/solve

端点：
  GET    /api/solve/sessions              — 历史会话列表（含缩略图）
  GET    /api/solve/sessions/{session_id} — 会话详情（完整对话历史）
  DELETE /api/solve/sessions/{session_id} — 删除会话（级联删除历史消息）
"""
from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException

from database import ConversationHistory, ConversationSession, get_session
from deps import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/sessions")
def list_solve_sessions(user=Depends(get_current_user)):
    """
    GET /api/solve/sessions

    返回当前用户所有 session_type='solve' 的会话列表，按 created_at 降序。
    每条记录包含：id、title、created_at、thumbnail（首条用户消息第一张图片 Base64 前 200 字符）。
    """
    user_id = int(user["id"])
    with get_session() as db:
        sessions = (
            db.query(ConversationSession)
            .filter_by(user_id=user_id, session_type="solve")
            .order_by(ConversationSession.created_at.desc())
            .all()
        )
        result = []
        for s in sessions:
            # 取首条用户消息的第一张图片作为缩略图
            first_user_msg = (
                db.query(ConversationHistory)
                .filter_by(session_id=s.id, role="user")
                .order_by(ConversationHistory.created_at)
                .first()
            )
            thumbnail: str | None = None
            if first_user_msg and first_user_msg.sources:
                images = first_user_msg.sources.get("images", [])
                if images and isinstance(images, list) and len(images) > 0:
                    # 截取前 200 字符作为缩略图预览（避免传输完整 Base64）
                    thumbnail = str(images[0])[:200]

            result.append({
                "id": s.id,
                "title": s.title or "解题记录",
                "created_at": s.created_at.isoformat() if s.created_at else None,
                "thumbnail": thumbnail,
            })
    return result


@router.get("/sessions/{session_id}")
def get_solve_session(session_id: int, user=Depends(get_current_user)):
    """
    GET /api/solve/sessions/{session_id}

    返回指定会话的完整 conversation_history 记录列表。
    非本人会话返回 HTTP 403。
    每条记录包含：id、role、content、sources、created_at。
    """
    user_id = int(user["id"])
    with get_session() as db:
        session = (
            db.query(ConversationSession)
            .filter_by(id=session_id, user_id=user_id, session_type="solve")
            .first()
        )
        if not session:
            raise HTTPException(status_code=403, detail="无权访问该会话或会话不存在")

        history = (
            db.query(ConversationHistory)
            .filter_by(session_id=session_id)
            .order_by(ConversationHistory.created_at)
            .all()
        )
        return [
            {
                "id": h.id,
                "role": h.role,
                "content": h.content,
                "sources": h.sources,
                "created_at": h.created_at.isoformat() if h.created_at else None,
            }
            for h in history
        ]


@router.delete("/sessions/{session_id}")
def delete_solve_session(session_id: int, user=Depends(get_current_user)):
    """
    DELETE /api/solve/sessions/{session_id}

    删除指定会话及其所有关联的历史消息记录（级联删除）。
    非本人会话返回 HTTP 403。
    """
    user_id = int(user["id"])
    with get_session() as db:
        session = (
            db.query(ConversationSession)
            .filter_by(id=session_id, user_id=user_id, session_type="solve")
            .first()
        )
        if not session:
            raise HTTPException(status_code=403, detail="无权删除该会话或会话不存在")

        db.delete(session)  # 级联删除 conversation_history（数据库外键 ON DELETE CASCADE）
        logger.info("删除解题会话 session_id=%s user_id=%s", session_id, user_id)

    return {"success": True, "session_id": session_id}
