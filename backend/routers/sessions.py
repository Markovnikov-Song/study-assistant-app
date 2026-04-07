from typing import List, Optional, Any
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from deps import get_current_user
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
