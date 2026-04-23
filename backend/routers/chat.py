import json
from typing import List, Literal, Optional
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from deps import get_current_user
from services.rag_pipeline import RAGPipeline, RAGStreamContext, RAGNeedsConfirmation
from services.mindmap_service import MindMapService
from database import get_session as db_session, ConversationHistory

router = APIRouter()
_rag = RAGPipeline()
_mindmap = MindMapService()


class QueryIn(BaseModel):
    subject_id: Optional[int] = None
    message: str
    session_id: Optional[int] = None
    mode: Literal["strict", "broad", "hybrid", "solve"] = "strict"


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
    subject_id = body.subject_id or None
    if not session_id:
        session_type = "solve" if body.mode == "solve" else "qa"
        session_id = _rag.create_session(user_id=user["id"], subject_id=subject_id, session_type=session_type)

    result = _rag.query(
        question=body.message,
        subject_id=subject_id,
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


@router.post("/query/stream")
def query_stream(body: QueryIn, user=Depends(get_current_user)):
    """
    流式问答，返回 SSE 格式。
    每个 token 以 `data: <token>\\n\\n` 格式发送。
    最后依次发送 sources 信息和 [DONE] 标记。
    """
    session_id = body.session_id
    if not session_id:
        session_type = "solve" if body.mode == "solve" else "qa"
        session_id = _rag.create_session(
            user_id=user["id"], subject_id=body.subject_id or None, session_type=session_type
        )

    def event_generator():
        ctx = RAGStreamContext()
        ctx.session_id = session_id
        try:
            gen = _rag.query_stream(
                question=body.message,
                subject_id=body.subject_id or None,
                session_id=session_id,
                mode=body.mode,
                user_id=user["id"],
                _ctx=ctx,
            )
            for token in gen:
                # SSE: escape newlines inside token so each frame stays on one logical line
                yield f"data: {token}\n\n"
        except RAGNeedsConfirmation:
            yield "data: [NEEDS_CONFIRMATION]\n\n"
            yield "data: [DONE]\n\n"
            return
        except Exception as e:
            yield f"data: [ERROR]{e}\n\n"
            yield "data: [DONE]\n\n"
            return

        # Send sources frame
        sources_payload = {
            "sources": [
                {
                    "filename": s.filename,
                    "chunk_index": s.chunk_index,
                    "content": s.content,
                    "score": s.score,
                }
                for s in ctx.sources
            ],
            "session_id": ctx.session_id,
        }
        yield f"data: [SOURCES]{json.dumps(sources_payload, ensure_ascii=False)}\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )


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

@router.post("/mindmap", response_model=MindMapOut)
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

    # 异步触发知识关联图生成（不阻塞响应）
    import threading
    def _async_generate_links():
        try:
            import json as _json, re as _re
            from services.llm_service import LLMService
            from database import MindmapKnowledgeLink, get_session as _db

            node_texts = []
            for line in content.splitlines():
                m = _re.match(r"^#{1,4}\s+(.*)", line)
                if m:
                    text = _re.sub(r"^[⭐⚠️🎯📌]\s*", "", m.group(1).strip()).strip()
                    if text:
                        node_texts.append(text)

            if len(node_texts) < 3:
                return

            prompt = (
                "你是一个知识图谱分析专家。请分析以下思维导图节点，找出 5-12 条最重要的跨节点关联。\n\n"
                f"节点列表：\n{chr(10).join(f'- {t}' for t in node_texts)}\n\n"
                "以 JSON 数组输出，每条包含 source_node_text、target_node_text、"
                "link_type（causal/dependency/contrast/evolution）、rationale（≤30字）。"
                "只输出 JSON，不要其他文字。"
            )
            raw = LLMService().chat(messages=[{"role": "user", "content": prompt}], max_tokens=1500)
            raw = raw.strip()
            if raw.startswith("```"):
                lines = raw.splitlines()
                raw = "\n".join(lines[1:-1] if lines[-1].strip() == "```" else lines[1:])
            items = _json.loads(raw)
            if not isinstance(items, list):
                return

            node_id_map = {}
            for line in content.splitlines():
                m = _re.match(r"^#{1,4}\s+(.*)", line)
                if m:
                    raw_text = m.group(1).strip()
                    clean = _re.sub(r"^[⭐⚠️🎯📌]\s*", "", raw_text).strip()
                    if clean:
                        node_id_map[clean] = raw_text

            valid_types = {"causal", "dependency", "contrast", "evolution"}
            with _db() as db:
                db.query(MindmapKnowledgeLink).filter_by(
                    user_id=user["id"], session_id=session_id
                ).delete()
                for item in items:
                    src = str(item.get("source_node_text", "")).strip()
                    dst = str(item.get("target_node_text", "")).strip()
                    lt = str(item.get("link_type", "")).strip()
                    rat = str(item.get("rationale", "")).strip()[:100]
                    if not src or not dst or lt not in valid_types or src == dst:
                        continue
                    db.add(MindmapKnowledgeLink(
                        user_id=user["id"], session_id=session_id,
                        source_node_id=node_id_map.get(src, src),
                        target_node_id=node_id_map.get(dst, dst),
                        source_node_text=src, target_node_text=dst,
                        link_type=lt, rationale=rat,
                    ))
        except Exception:
            pass  # 关联图生成失败不影响主流程

    threading.Thread(target=_async_generate_links, daemon=True).start()

    return MindMapOut(session_id=session_id, content=content)


@router.post("/mindmap/custom", response_model=MindMapOut)
def custom_mindmap(body: CustomMindMapIn, user=Depends(get_current_user)):
    """根据用户输入的主题/文本自由生成思维导图，不依赖学科资料库。"""
    from services.llm_service import LLMService

    topic = body.topic.strip()
    if not topic:
        from fastapi import HTTPException
        raise HTTPException(400, "主题不能为空")

    try:
        from prompt_manager import PromptManager
        base_prompt = PromptManager().get("mindmap/generate.yaml", "custom")
        prompt = base_prompt + f"\n\n主题/内容：\n{topic}"
    except Exception:
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
