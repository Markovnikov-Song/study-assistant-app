from typing import List, Optional, Any
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from deps import get_current_user
from database import ConversationHistory, ConversationSession, Subject, get_session as db_session
from utils import (
    get_user_sessions, get_subject_sessions,
    get_session_history, delete_session, rename_session,
)

router = APIRouter()

_TYPE_LABELS = {"qa": "💬 问答", "solve": "🔢 解题", "mindmap": "🗺 思维导图", "exam": "🤖 出题"}

class SessionOut(BaseModel):
    id: int
    subject_id: Optional[int]
    subject_name: Optional[str]
    title: Optional[str]
    session_type: str
    type_label: str
    created_at: str

    @classmethod
    def from_dict(cls, d: dict):
        return cls(
            id=d["id"], subject_id=d.get("subject_id"),
            subject_name=d.get("subject_name"),
            title=d.get("title") or f"对话 #{d['id']}",
            session_type=d["session_type"],
            type_label=d.get("type_label") or _TYPE_LABELS.get(d["session_type"], d["session_type"]),
            created_at=d["created_at"].isoformat(),
        )

class MessageOut(BaseModel):
    id: int
    session_id: int
    role: str
    content: str
    sources: Optional[Any]
    scope_choice: Optional[str]
    created_at: str

    @classmethod
    def from_dict(cls, d: dict):
        return cls(
            id=d["id"], session_id=d["session_id"],
            role=d["role"], content=d["content"],
            sources=d.get("sources"), scope_choice=d.get("scope_choice"),
            created_at=d["created_at"].isoformat(),
        )

@router.get("", response_model=List[SessionOut])
def list_all(user=Depends(get_current_user)):
    return [SessionOut.from_dict(s) for s in get_user_sessions(user["id"])]

@router.get("/subject/{subject_id}", response_model=List[SessionOut])
def list_by_subject(subject_id: int, user=Depends(get_current_user)):
    return [SessionOut.from_dict(s) for s in get_subject_sessions(subject_id, user["id"])]

@router.get("/{session_id}/history", response_model=List[MessageOut])
def history(session_id: int, user=Depends(get_current_user)):
    return [MessageOut.from_dict(m) for m in get_session_history(session_id, user["id"])]

@router.delete("/{session_id}", status_code=204)
def delete(session_id: int, user=Depends(get_current_user)):
    r = delete_session(session_id, user["id"])
    if not r["success"]:
        raise HTTPException(400, r["error"])

@router.patch("/{session_id}/title")
def rename(session_id: int, body: dict, user=Depends(get_current_user)):
    r = rename_session(session_id, user["id"], body.get("title", ""))
    if not r["success"]:
        raise HTTPException(400, r["error"])
    return r


# ── 搜索 ──────────────────────────────────────────────────────────────────────

class SearchResultItem(BaseModel):
    message_id: int
    session_id: int
    session_title: Optional[str]
    session_type: str
    type_label: str
    subject_id: Optional[int]
    subject_name: Optional[str]
    role: str
    snippet: str        # 高亮片段，前后各保留 40 字符
    created_at: str


@router.get("/search", response_model=List[SearchResultItem])
def search_messages(
    q: str = Query(..., min_length=1, max_length=100),
    session_type: Optional[str] = Query(None, pattern="^(qa|solve|mindmap|exam)$"),
    limit: int = Query(30, le=100),
    user=Depends(get_current_user),
):
    """全文搜索用户的对话消息，返回匹配消息及所属 session 信息。"""
    if not q.strip():
        return []

    with db_session() as db:
        query = (
            db.query(
                ConversationHistory.id,
                ConversationHistory.session_id,
                ConversationHistory.role,
                ConversationHistory.content,
                ConversationHistory.created_at,
                ConversationSession.title,
                ConversationSession.session_type,
                ConversationSession.subject_id,
                Subject.name.label("subject_name"),
            )
            .join(ConversationSession, ConversationHistory.session_id == ConversationSession.id)
            .outerjoin(Subject, ConversationSession.subject_id == Subject.id)
            .filter(
                ConversationSession.user_id == user["id"],
                ConversationHistory.content.ilike(f"%{q}%"),
            )
        )
        if session_type:
            query = query.filter(ConversationSession.session_type == session_type)

        rows = query.order_by(ConversationHistory.created_at.desc()).limit(limit).all()

    results = []
    for row in rows:
        content: str = row.content
        idx = content.lower().find(q.lower())
        start = max(0, idx - 40)
        end = min(len(content), idx + len(q) + 40)
        snippet = ("…" if start > 0 else "") + content[start:end] + ("…" if end < len(content) else "")

        results.append(SearchResultItem(
            message_id=row.id,
            session_id=row.session_id,
            session_title=row.title or f"对话 #{row.session_id}",
            session_type=row.session_type,
            type_label=_TYPE_LABELS.get(row.session_type, row.session_type),
            subject_id=row.subject_id,
            subject_name=row.subject_name,
            role=row.role,
            snippet=snippet,
            created_at=row.created_at.isoformat(),
        ))
    return results
