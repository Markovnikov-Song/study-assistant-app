from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from deps import get_current_user
from services.rag_pipeline import RAGPipeline
from services.mindmap_service import MindMapService
from database import get_session as db_session, ConversationHistory

router = APIRouter()
_rag = RAGPipeline()
_mindmap = MindMapService()


class QueryIn(BaseModel):
    subject_id: int
    message: str
    session_id: Optional[int] = None
    mode: str = "strict"   # strict | broad | hybrid | solve


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
    doc_id: Optional[int] = None


class CustomMindMapIn(BaseModel):
    """用户自定义主题的思维导图，不依赖学科资料"""
    topic: str
    session_id: Optional[int] = None
    subject_id: Optional[int] = None


class MindMapOut(BaseModel):
    session_id: int
    content: str


@router.post("/query", response_model=QueryOut)
def query(body: QueryIn, user=Depends(get_current_user)):
    session_id = body.session_id
    if not session_id:
        session_type = "solve" if body.mode == "solve" else "qa"
        session_id = _rag.create_session(user_id=user["id"], subject_id=body.subject_id, session_type=session_type)

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

    with db_session() as db:
        msg = (db.query(ConversationHistory)
               .filter_by(session_id=session_id, role="assistant")
               .order_by(ConversationHistory.created_at.desc()).first())
        if not msg:
            raise HTTPException(500, "消息写入失败")
        sources = [SourceOut(filename=s.get("filename",""), chunk_index=s.get("chunk_index",0),
                             content=s.get("content",""), score=s.get("score",0.0))
                   for s in (msg.sources or [])]
        out_msg = MessageOut(id=msg.id, role=msg.role, content=msg.content,
                             sources=sources, created_at=msg.created_at.isoformat())

    return QueryOut(session_id=session_id, message=out_msg)


@router.get("/memory", summary="获取当前用户的学习记忆画像")
def get_memory(subject_id: Optional[int] = None, user=Depends(get_current_user)):
    """返回用户在指定学科（或全局）的学习画像。"""
    from services.memory_service import MemoryService
    memory = MemoryService().get_memory(user["id"], subject_id)
    return {"memory": memory}


@router.delete("/memory", summary="清除当前用户的学习记忆画像")
def clear_memory(subject_id: Optional[int] = None, user=Depends(get_current_user)):
    """清除用户在指定学科的记忆（subject_id=None 清除全局记忆）。"""
    from database import UserMemory, get_session as db_session_ctx
    with db_session_ctx() as db:
        q = db.query(UserMemory).filter_by(user_id=user["id"], subject_id=subject_id)
        q.delete()
    return {"ok": True}

def mindmap(body: MindMapIn, user=Depends(get_current_user)):
    session_id = body.session_id
    if not session_id:
        session_id = _rag.create_session(user_id=user["id"], subject_id=body.subject_id, session_type="mindmap")

    try:
        content = _mindmap.generate_from_subject(body.subject_id, body.doc_id)
    except Exception as e:
        raise HTTPException(500, str(e))

    with db_session() as db:
        db.add(ConversationHistory(session_id=session_id, role="user", content="生成思维导图"))
        db.add(ConversationHistory(session_id=session_id, role="assistant", content=content))

    return MindMapOut(session_id=session_id, content=content)


@router.post("/mindmap/custom", response_model=MindMapOut)
def custom_mindmap(body: CustomMindMapIn, user=Depends(get_current_user)):
    """根据用户输入的主题/文本自由生成思维导图，不依赖学科资料库。"""
    from services.llm_service import LLMService

    topic = body.topic.strip()
    if not topic:
        from fastapi import HTTPException
        raise HTTPException(400, "主题不能为空")

    prompt = (
        "你是一个专业的知识结构分析助手。请根据以下主题或内容，生成一份结构清晰的思维导图（markmap 格式）。\n\n"
        "输出要求：\n"
        "1. 使用 Markdown 标题语法（# ## ### ####）表示层级\n"
        "2. 第一行用 # 作为根节点，内容为主题名称\n"
        "3. 二级节点（##）对应主要分支\n"
        "4. 三级节点（###）对应核心概念\n"
        "5. 四级节点（####）对应具体细节，最多四级\n"
        "6. 每个节点简洁，不超过 15 个字\n"
        "7. 只输出 Markdown 内容，不要有任何代码块标记或说明文字\n\n"
        f"主题/内容：\n{topic}"
    )

    try:
        content = LLMService().chat([{"role": "user", "content": prompt}])
        content = content.strip()
        if content.startswith("```"):
            lines = content.splitlines()
            inner = lines[1:-1] if lines[-1].strip() == "```" else lines[1:]
            content = "\n".join(inner).strip()
    except Exception as e:
        from fastapi import HTTPException
        raise HTTPException(500, str(e))

    # 可选：保存到 session
    session_id = body.session_id
    if body.subject_id:
        if not session_id:
            session_id = _rag.create_session(
                user_id=user["id"], subject_id=body.subject_id, session_type="mindmap"
            )
        with db_session() as db:
            db.add(ConversationHistory(session_id=session_id, role="user", content=f"自建导图：{topic[:50]}"))
            db.add(ConversationHistory(session_id=session_id, role="assistant", content=content))

    return MindMapOut(session_id=session_id or 0, content=content)
