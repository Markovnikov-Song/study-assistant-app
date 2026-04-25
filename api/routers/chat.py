"""
对话路由：RAG 问答 / 解题 / 思维导图生成
"""
from typing import Optional, List, Any
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from api.deps import get_current_user
from services.rag_pipeline import RAGPipeline
from services.mindmap_service import MindMapService
from database import get_session as db_session, ConversationHistory, ConversationSession

router = APIRouter()
_rag = RAGPipeline()


class QueryIn(BaseModel):
    subject_id: int
    message: str
    session_id: Optional[int] = None
    # mode: strict | broad | solve
    mode: str = "strict"


class SourceOut(BaseModel):
    filename: str
    chunk_index: int
    content: str
    score: float


class MessageOut(BaseModel):
    id: int
    role: str
    content: str
    sources: Optional[List[SourceOut]]
    created_at: str


class QueryOut(BaseModel):
    session_id: int
    message: MessageOut
    needs_confirmation: bool = False


class MindMapIn(BaseModel):
    subject_id: int
    session_id: Optional[int] = None
    doc_id: Optional[int] = None  # None = 全部资料


class MindMapOut(BaseModel):
    session_id: int
    content: str  # Markdown markmap 格式


@router.post("/query", response_model=QueryOut)
def query(body: QueryIn, user=Depends(get_current_user)):
    # 懒创建会话
    session_id = body.session_id
    if not session_id:
        session_type = "solve" if body.mode == "solve" else "qa"
        session_id = _rag.create_session(
            user_id=user["id"],
            subject_id=body.subject_id,
            session_type=session_type,
        )

    result = _rag.query(
        question=body.message,
        subject_id=body.subject_id,
        session_id=session_id,
        mode=body.mode,
        user_id=user["id"],
    )

    if result.needs_confirmation:
        return QueryOut(
            session_id=session_id,
            message=MessageOut(id=0, role="assistant", content="", sources=None, created_at=""),
            needs_confirmation=True,
        )

    # 取刚写入的 assistant 消息
    with db_session() as db:
        msg = (
            db.query(ConversationHistory)
            .filter_by(session_id=session_id, role="assistant")
            .order_by(ConversationHistory.created_at.desc())
            .first()
        )
        if not msg:
            raise HTTPException(500, "消息写入失败")
        sources = [
            SourceOut(
                filename=s.get("filename", ""),
                chunk_index=s.get("chunk_index", 0),
                content=s.get("content", ""),
                score=s.get("score", 0.0),
            )
            for s in (msg.sources or [])
        ]
        out_msg = MessageOut(
            id=msg.id, role=msg.role, content=msg.content,
            sources=sources, created_at=msg.created_at.isoformat(),
        )

    return QueryOut(session_id=session_id, message=out_msg)


@router.post("/mindmap", response_model=MindMapOut)
def mindmap(body: MindMapIn, user=Depends(get_current_user)):
    session_id = body.session_id
    if not session_id:
        session_id = _rag.create_session(
            user_id=user["id"],
            subject_id=body.subject_id,
            session_type="mindmap",
        )

    try:
        mindmap_svc = MindMapService(user_id=user["id"])
        content = mindmap_svc.generate_from_subject(body.subject_id, body.doc_id)
    except Exception as e:
        raise HTTPException(500, str(e))

    with db_session() as db:
        db.add(ConversationHistory(session_id=session_id, role="user", content="生成思维导图"))
        db.add(ConversationHistory(session_id=session_id, role="assistant", content=content))

    return MindMapOut(session_id=session_id, content=content)
