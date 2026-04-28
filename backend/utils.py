"""
utils.py — 数据库操作工具函数（Subject 相关）
供 routers/subjects.py 调用。
"""
from __future__ import annotations

from database import Subject, get_session


def get_user_subjects(user_id: int, include_archived: bool = False) -> list[dict]:
    with get_session() as db:
        q = db.query(Subject).filter(Subject.user_id == user_id)
        if not include_archived:
            q = q.filter(Subject.is_archived == 0)
        subjects = q.order_by(Subject.is_pinned.desc(), Subject.sort_order, Subject.created_at).all()
        return [_to_dict(s) for s in subjects]


def get_subject(subject_id: int, user_id: int) -> dict | None:
    with get_session() as db:
        s = db.query(Subject).filter(
            Subject.id == subject_id, Subject.user_id == user_id
        ).first()
        return _to_dict(s) if s else None


def create_subject(user_id: int, name: str, category: str = "", description: str = "") -> dict:
    try:
        with get_session() as db:
            s = Subject(
                user_id=user_id,
                name=name,
                category=category or None,
                description=description or None,
            )
            db.add(s)
            db.flush()
            result = _to_dict(s)
        return {"success": True, "subject": result}
    except Exception as e:
        return {"success": False, "error": str(e)}


def update_subject(subject_id: int, user_id: int, name: str, category: str = "", description: str = "") -> dict:
    try:
        with get_session() as db:
            s = db.query(Subject).filter(
                Subject.id == subject_id, Subject.user_id == user_id
            ).first()
            if not s:
                return {"success": False, "error": "学科不存在"}
            s.name = name
            s.category = category or None
            s.description = description or None
        return {"success": True}
    except Exception as e:
        return {"success": False, "error": str(e)}


def delete_subject(subject_id: int, user_id: int) -> dict:
    try:
        with get_session() as db:
            s = db.query(Subject).filter(
                Subject.id == subject_id, Subject.user_id == user_id
            ).first()
            if not s:
                return {"success": False, "error": "学科不存在"}
            db.delete(s)
        return {"success": True}
    except Exception as e:
        return {"success": False, "error": str(e)}


def toggle_pin_subject(subject_id: int, user_id: int) -> dict:
    try:
        with get_session() as db:
            s = db.query(Subject).filter(
                Subject.id == subject_id, Subject.user_id == user_id
            ).first()
            if not s:
                return {"success": False, "error": "学科不存在"}
            s.is_pinned = 0 if s.is_pinned else 1
        return {"success": True}
    except Exception as e:
        return {"success": False, "error": str(e)}


def toggle_archive_subject(subject_id: int, user_id: int) -> dict:
    try:
        with get_session() as db:
            s = db.query(Subject).filter(
                Subject.id == subject_id, Subject.user_id == user_id
            ).first()
            if not s:
                return {"success": False, "error": "学科不存在"}
            s.is_archived = 0 if s.is_archived else 1
        return {"success": True}
    except Exception as e:
        return {"success": False, "error": str(e)}


def _to_dict(s: Subject) -> dict:
    return {
        "id": s.id,
        "name": s.name,
        "category": s.category,
        "description": s.description,
        "is_pinned": bool(s.is_pinned),
        "is_archived": bool(s.is_archived),
        "created_at": s.created_at,
    }


# ---------------------------------------------------------------------------
# Session 相关工具函数（供 routers/sessions.py 使用）
# ---------------------------------------------------------------------------

from database import ConversationSession, ConversationHistory


def get_user_sessions(user_id: int) -> list[dict]:
    """获取用户所有对话会话（含学科名称）。"""
    from database import Subject
    with get_session() as db:
        rows = (
            db.query(ConversationSession, Subject.name.label("subject_name"))
            .outerjoin(Subject, ConversationSession.subject_id == Subject.id)
            .filter(ConversationSession.user_id == user_id)
            .order_by(ConversationSession.created_at.desc())
            .all()
        )
        return [_session_to_dict(s, sname) for s, sname in rows]


def get_subject_sessions(subject_id: int, user_id: int) -> list[dict]:
    """获取某学科下的所有对话会话。subject_id=0 表示通用对话（subject_id IS NULL）。"""
    with get_session() as db:
        query = db.query(ConversationSession).filter(
            ConversationSession.user_id == user_id,
        )
        if subject_id == 0:
            # 通用对话：subject_id 在数据库里存的是 NULL
            query = query.filter(ConversationSession.subject_id.is_(None))
        else:
            query = query.filter(ConversationSession.subject_id == subject_id)
        rows = query.order_by(ConversationSession.created_at.desc()).all()
        return [_session_to_dict(s, None) for s in rows]


def get_session_history(session_id: int, user_id: int) -> list[dict]:
    """获取某会话的消息历史，验证归属权。"""
    with get_session() as db:
        session = db.query(ConversationSession).filter(
            ConversationSession.id == session_id,
            ConversationSession.user_id == user_id,
        ).first()
        if not session:
            return []
        messages = (
            db.query(ConversationHistory)
            .filter(ConversationHistory.session_id == session_id)
            .order_by(ConversationHistory.created_at)
            .all()
        )
        return [_message_to_dict(m) for m in messages]


def delete_session(session_id: int, user_id: int) -> dict:
    try:
        with get_session() as db:
            s = db.query(ConversationSession).filter(
                ConversationSession.id == session_id,
                ConversationSession.user_id == user_id,
            ).first()
            if not s:
                return {"success": False, "error": "会话不存在"}
            db.delete(s)
        return {"success": True}
    except Exception as e:
        return {"success": False, "error": str(e)}


def rename_session(session_id: int, user_id: int, title: str) -> dict:
    try:
        with get_session() as db:
            s = db.query(ConversationSession).filter(
                ConversationSession.id == session_id,
                ConversationSession.user_id == user_id,
            ).first()
            if not s:
                return {"success": False, "error": "会话不存在"}
            s.title = title
        return {"success": True}
    except Exception as e:
        return {"success": False, "error": str(e)}


def _session_to_dict(s: ConversationSession, subject_name: str | None) -> dict:
    _TYPE_LABELS = {"qa": "💬 问答", "solve": "🔢 解题", "mindmap": "🗺 思维导图", "exam": "🤖 出题"}
    return {
        "id": s.id,
        "subject_id": s.subject_id,
        "subject_name": subject_name,
        "title": s.title,
        "session_type": s.session_type,
        "type_label": _TYPE_LABELS.get(s.session_type, s.session_type),
        "created_at": s.created_at,
    }


def _message_to_dict(m: ConversationHistory) -> dict:
    return {
        "id": m.id,
        "session_id": m.session_id,
        "role": m.role,
        "content": m.content,
        "sources": m.sources,
        "scope_choice": m.scope_choice,
        "created_at": m.created_at,
    }
