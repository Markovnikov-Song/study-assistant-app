"""
会话路由：列表 / 历史 / 删除 / 重命名
"""
from typing import List, Optional, Any
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from api.deps import get_current_user
from utils import (
    get_user_sessions, get_subject_sessions,
    get_session_history, delete_session, rename_session,
)

router = APIRouter()


class SessionOut(BaseModel):
    id: int
    subject_id: Optional[int]
    subject_name: Optional[str]
    title: Optional[str]
    session_type: str
    type_label: str
    created_at: str

    @classmethod
    def from_dict(cls, d: dict) -> "SessionOut":
        type_labels = {"qa": "💬 问答", "solve": "🔢 解题", "mindmap": "🗺 思维导图", "exam": "🤖 出题"}
        return cls(
            id=d["id"],
            subject_id=d.get("subject_id"),
            subject_name=d.get("subject_name"),
            title=d.get("title") or f"对话 #{d['id']}",
            session_type=d["session_type"],
            type_label=d.get("type_label") or type_labels.get(d["session_type"], d["session_type"]),
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
    def from_dict(cls, d: dict) -> "MessageOut":
        return cls(
            id=d["id"], session_id=d["session_id"],
            role=d["role"], content=d["content"],
            sources=d.get("sources"), scope_choice=d.get("scope_choice"),
            created_at=d["created_at"].isoformat(),
        )


@router.get("", response_model=List[SessionOut])
def list_all(user=Depends(get_current_user)):
    sessions = get_user_sessions(user["id"])
    return [SessionOut.from_dict(s) for s in sessions]


@router.get("/subject/{subject_id}", response_model=List[SessionOut])
def list_by_subject(subject_id: int, user=Depends(get_current_user)):
    sessions = get_subject_sessions(subject_id, user["id"])
    return [SessionOut.from_dict(s) for s in sessions]


@router.get("/{session_id}/history", response_model=List[MessageOut])
def history(session_id: int, user=Depends(get_current_user)):
    msgs = get_session_history(session_id, user["id"])
    return [MessageOut.from_dict(m) for m in msgs]


@router.delete("/{session_id}", status_code=204)
def delete(session_id: int, user=Depends(get_current_user)):
    result = delete_session(session_id, user["id"])
    if not result["success"]:
        raise HTTPException(400, result["error"])


@router.patch("/{session_id}/title")
def rename(session_id: int, body: dict, user=Depends(get_current_user)):
    title = body.get("title", "")
    result = rename_session(session_id, user["id"], title)
    if not result["success"]:
        raise HTTPException(400, result["error"])
    return result
