"""
library.py — 学校/图书馆路由模块
挂载在 /api/library
"""
from __future__ import annotations

import re
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, field_validator
from sqlalchemy import text

from database import (
    ConversationHistory,
    ConversationSession,
    MindmapNodeState,
    NodeLecture,
    Subject,
    get_session as db_session,
)
from deps import get_current_user

router = APIRouter()


# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------


class SubjectProgressOut(BaseModel):
    id: int
    name: str
    category: Optional[str]
    is_pinned: int
    session_count: int
    total_nodes: int
    lit_nodes: int
    last_visited_at: Optional[str]


class SessionSummaryOut(BaseModel):
    id: int
    title: Optional[str]
    created_at: str
    total_nodes: int
    lit_nodes: int
    is_pinned: bool
    sort_order: int


class SessionMetaIn(BaseModel):
    is_pinned: Optional[bool] = None
    sort_order: Optional[int] = None


class SessionMetaOut(BaseModel):
    id: int
    is_pinned: bool
    sort_order: int


class TitleIn(BaseModel):
    title: str

    @field_validator("title")
    @classmethod
    def validate_title(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("标题不能为空")
        if len(v) > 64:
            raise ValueError("标题不能超过 64 个字符")
        return v


class NodeStateItem(BaseModel):
    node_id: str
    is_lit: bool


class NodeStatesIn(BaseModel):
    states: list[NodeStateItem]


class LectureContentIn(BaseModel):
    content: dict[str, Any]


class ContentIn(BaseModel):
    content: str


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _parse_node_count(markdown: str) -> int:
    """统计 Markdown 中 # 开头的节点行数。"""
    return sum(1 for line in markdown.splitlines() if re.match(r"^#{1,4}\s+\S", line))


def _get_mindmap_content(db, session_id: int) -> Optional[str]:
    """从 conversation_history 取该会话最新 assistant 记录的 content。"""
    record = (
        db.query(ConversationHistory)
        .filter_by(session_id=session_id, role="assistant")
        .order_by(ConversationHistory.created_at.desc())
        .first()
    )
    return record.content if record else None


def _assert_session_owner(db, session_id: int, user_id: int) -> ConversationSession:
    sess = db.query(ConversationSession).filter_by(id=session_id, user_id=user_id).first()
    if not sess:
        raise HTTPException(404, "大纲不存在")
    return sess


# ---------------------------------------------------------------------------
# 学科列表
# ---------------------------------------------------------------------------


@router.get("/subjects", response_model=list[SubjectProgressOut])
def get_subjects(user=Depends(get_current_user)):
    with db_session() as db:
        subjects = (
            db.query(Subject)
            .filter_by(user_id=user["id"], is_archived=0)
            .order_by(Subject.is_pinned.desc(), Subject.created_at.desc())
            .all()
        )
        result = []
        for subj in subjects:
            sessions = (
                db.query(ConversationSession)
                .filter_by(user_id=user["id"], subject_id=subj.id, session_type="mindmap")
                .all()
            )
            total_nodes = 0
            lit_nodes = 0
            last_visited_at = None
            for sess in sessions:
                content = _get_mindmap_content(db, sess.id)
                if content:
                    total_nodes += _parse_node_count(content)
                # count lit nodes
                lit = (
                    db.query(MindmapNodeState)
                    .filter_by(user_id=user["id"], session_id=sess.id, is_lit=1)
                    .count()
                )
                lit_nodes += lit
                if last_visited_at is None or sess.created_at > last_visited_at:
                    last_visited_at = sess.created_at

            result.append(
                SubjectProgressOut(
                    id=subj.id,
                    name=subj.name,
                    category=subj.category,
                    is_pinned=subj.is_pinned,
                    session_count=len(sessions),
                    total_nodes=total_nodes,
                    lit_nodes=lit_nodes,
                    last_visited_at=last_visited_at.isoformat() if last_visited_at else None,
                )
            )
        return result


# ---------------------------------------------------------------------------
# 学科下的大纲列表
# ---------------------------------------------------------------------------


@router.get("/subjects/{subject_id}/sessions", response_model=list[SessionSummaryOut])
def get_sessions(subject_id: int, user=Depends(get_current_user)):
    with db_session() as db:
        sessions = (
            db.query(ConversationSession)
            .filter_by(user_id=user["id"], subject_id=subject_id, session_type="mindmap")
            .order_by(
                ConversationSession.is_pinned.desc(),
                ConversationSession.sort_order.asc(),
                ConversationSession.created_at.desc(),
            )
            .all()
        )
        result = []
        for sess in sessions:
            content = _get_mindmap_content(db, sess.id)
            total = _parse_node_count(content) if content else 0
            lit = (
                db.query(MindmapNodeState)
                .filter_by(user_id=user["id"], session_id=sess.id, is_lit=1)
                .count()
            )
            result.append(
                SessionSummaryOut(
                    id=sess.id,
                    title=sess.title,
                    created_at=sess.created_at.isoformat(),
                    total_nodes=total,
                    lit_nodes=lit,
                    is_pinned=bool(getattr(sess, "is_pinned", 0)),
                    sort_order=getattr(sess, "sort_order", 0),
                )
            )
        return result


# ---------------------------------------------------------------------------
# 更新大纲元数据（置顶 / 排序）
# ---------------------------------------------------------------------------


@router.patch("/sessions/{session_id}/meta", response_model=SessionMetaOut)
def update_session_meta(session_id: int, body: SessionMetaIn, user=Depends(get_current_user)):
    with db_session() as db:
        sess = _assert_session_owner(db, session_id, user["id"])
        if body.is_pinned is not None:
            sess.is_pinned = 1 if body.is_pinned else 0
        if body.sort_order is not None:
            sess.sort_order = body.sort_order
        db.flush()
        return SessionMetaOut(
            id=sess.id,
            is_pinned=bool(sess.is_pinned),
            sort_order=sess.sort_order,
        )


# ---------------------------------------------------------------------------
# 重命名大纲
# ---------------------------------------------------------------------------


@router.patch("/sessions/{session_id}/title")
def rename_session(session_id: int, body: TitleIn, user=Depends(get_current_user)):
    with db_session() as db:
        sess = _assert_session_owner(db, session_id, user["id"])
        sess.title = body.title
    return {"ok": True}


# ---------------------------------------------------------------------------
# 删除大纲（级联删除讲义和点亮状态）
# ---------------------------------------------------------------------------


@router.delete("/sessions/{session_id}")
def delete_session(session_id: int, user=Depends(get_current_user)):
    with db_session() as db:
        sess = _assert_session_owner(db, session_id, user["id"])
        # cascade via FK ON DELETE CASCADE handles node_states and lectures
        db.delete(sess)
    return {"ok": True}


# ---------------------------------------------------------------------------
# 节点树（解析 Markdown 返回节点树 JSON）
# ---------------------------------------------------------------------------


def _build_node_tree(markdown: str) -> list[dict]:
    """将 Markdown 标题解析为节点树列表（扁平，含 parent_id）。"""
    nodes: list[dict] = []
    ancestor_stack: list[dict] = []  # stack of (depth, node)
    sibling_counter: dict[str, int] = {}  # key -> count

    for line in markdown.splitlines():
        m = re.match(r"^(#{1,4})\s+(.*)", line)
        if not m:
            continue
        depth = len(m.group(1))
        text = m.group(2).strip()
        if not text:
            continue

        # pop stack to find parent
        while ancestor_stack and ancestor_stack[-1]["depth"] >= depth:
            ancestor_stack.pop()

        parent = ancestor_stack[-1] if ancestor_stack else None
        parent_id = parent["node_id"] if parent else None

        # build ancestor path for node_id
        if parent:
            ancestor_path = parent["node_id"].split("_", 1)[1] if "_" in parent["node_id"] else parent["node_id"]
            base_key = f"L{depth}_{ancestor_path}_{text}"
        else:
            base_key = f"L{depth}_{text}"

        count = sibling_counter.get(base_key, 0) + 1
        sibling_counter[base_key] = count
        node_id = base_key if count == 1 else f"{base_key}_{count}"

        node = {
            "node_id": node_id,
            "text": text,
            "depth": depth,
            "parent_id": parent_id,
            "is_user_created": False,
            "children": [],
        }
        nodes.append(node)
        ancestor_stack.append({"depth": depth, "node_id": node_id})

    return nodes


@router.get("/sessions/{session_id}/nodes")
def get_nodes(session_id: int, user=Depends(get_current_user)):
    with db_session() as db:
        _assert_session_owner(db, session_id, user["id"])
        content = _get_mindmap_content(db, session_id)
        if not content:
            return {"nodes": []}
        return {"nodes": _build_node_tree(content)}


# ---------------------------------------------------------------------------
# 更新大纲 Markdown 内容
# ---------------------------------------------------------------------------


@router.patch("/sessions/{session_id}/content")
def update_content(session_id: int, body: ContentIn, user=Depends(get_current_user)):
    with db_session() as db:
        _assert_session_owner(db, session_id, user["id"])
        record = (
            db.query(ConversationHistory)
            .filter_by(session_id=session_id, role="assistant")
            .order_by(ConversationHistory.created_at.desc())
            .first()
        )
        if record:
            record.content = body.content
        else:
            db.add(ConversationHistory(session_id=session_id, role="assistant", content=body.content))
    return {"ok": True}


# ---------------------------------------------------------------------------
# 节点点亮状态
# ---------------------------------------------------------------------------


@router.get("/sessions/{session_id}/node-states")
def get_node_states(session_id: int, user=Depends(get_current_user)):
    with db_session() as db:
        _assert_session_owner(db, session_id, user["id"])
        rows = (
            db.query(MindmapNodeState)
            .filter_by(user_id=user["id"], session_id=session_id)
            .all()
        )
        return {row.node_id: bool(row.is_lit) for row in rows}


@router.post("/sessions/{session_id}/node-states")
def upsert_node_states(session_id: int, body: NodeStatesIn, user=Depends(get_current_user)):
    with db_session() as db:
        _assert_session_owner(db, session_id, user["id"])
        for item in body.states:
            existing = (
                db.query(MindmapNodeState)
                .filter_by(user_id=user["id"], session_id=session_id, node_id=item.node_id)
                .first()
            )
            if existing:
                existing.is_lit = 1 if item.is_lit else 0
            else:
                db.add(
                    MindmapNodeState(
                        user_id=user["id"],
                        session_id=session_id,
                        node_id=item.node_id,
                        is_lit=1 if item.is_lit else 0,
                    )
                )
    return {"ok": True}


# ---------------------------------------------------------------------------
# 讲义 CRUD
# ---------------------------------------------------------------------------


@router.get("/lectures/{session_id}/{node_id:path}")
def get_lecture(session_id: int, node_id: str, user=Depends(get_current_user)):
    with db_session() as db:
        lecture = (
            db.query(NodeLecture)
            .filter_by(user_id=user["id"], session_id=session_id, node_id=node_id)
            .first()
        )
        if not lecture:
            raise HTTPException(404, "讲义不存在")
        return {
            "id": lecture.id,
            "node_id": lecture.node_id,
            "content": lecture.content,
            "resource_scope": lecture.resource_scope,
            "created_at": lecture.created_at.isoformat(),
            "updated_at": lecture.updated_at.isoformat(),
        }


class LectureCreateIn(BaseModel):
    session_id: int
    node_id: str
    content: Optional[dict[str, Any]] = None  # ignored; LLM generates content
    resource_scope: Optional[dict[str, Any]] = None


@router.post("/lectures")
def create_lecture(body: LectureCreateIn, user=Depends(get_current_user)):
    """生成节点讲义（一次性，兼容旧接口）。超时返回 504。"""
    import concurrent.futures
    from services.lecture_generator_service import LectureGeneratorService

    with db_session() as db:
        session = _assert_session_owner(db, body.session_id, user["id"])
        subject_id: int = session.subject_id or 0

    svc = LectureGeneratorService()

    def _generate():
        return svc.generate(
            session_id=body.session_id,
            node_id=body.node_id,
            user_id=user["id"],
            subject_id=subject_id,
        )

    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
            future = executor.submit(_generate)
            result = future.result(timeout=120)
        return {"id": result["id"], "ok": True}
    except concurrent.futures.TimeoutError:
        raise HTTPException(504, "讲义生成超时，请重试")
    except RuntimeError as e:
        raise HTTPException(502, f"AI 服务暂时不可用：{e}")
    except Exception as e:
        raise HTTPException(500, f"讲义生成失败：{e}")


@router.post("/lectures/stream")
def create_lecture_stream(body: LectureCreateIn, user=Depends(get_current_user)):
    """流式生成讲义，返回 SSE。每个 token 以 data: <token>\\n\\n 发送，结束发 data: [DONE]\\n\\n。"""
    import json as _json
    from fastapi.responses import StreamingResponse
    from services.lecture_generator_service import LectureGeneratorService

    with db_session() as db:
        session = _assert_session_owner(db, body.session_id, user["id"])
        subject_id: int = session.subject_id or 0

    svc = LectureGeneratorService()

    def event_generator():
        try:
            for token in svc.generate_stream(
                session_id=body.session_id,
                node_id=body.node_id,
                user_id=user["id"],
                subject_id=subject_id,
            ):
                yield f"data: {token}\n\n"
        except Exception as e:
            yield f"data: [ERROR]{e}\n\n"
        finally:
            yield "data: [DONE]\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


@router.patch("/lectures/{lecture_id}")
def patch_lecture(lecture_id: int, body: LectureContentIn, user=Depends(get_current_user)):
    with db_session() as db:
        lecture = db.query(NodeLecture).filter_by(id=lecture_id, user_id=user["id"]).first()
        if not lecture:
            raise HTTPException(404, "讲义不存在")
        lecture.content = body.content
    return {"ok": True}


@router.delete("/lectures/{session_id}/{node_id:path}")
def delete_lecture(session_id: int, node_id: str, user=Depends(get_current_user)):
    with db_session() as db:
        lecture = (
            db.query(NodeLecture)
            .filter_by(user_id=user["id"], session_id=session_id, node_id=node_id)
            .first()
        )
        if not lecture:
            raise HTTPException(404, "讲义不存在")
        db.delete(lecture)
    return {"ok": True}


@router.post("/lectures/{lecture_id}/export")
def export_lecture(lecture_id: int, format: str = "docx", user=Depends(get_current_user)):
    """导出讲义为 Word 文件（python-docx）。"""
    try:
        from docx import Document as DocxDocument
        from fastapi.responses import StreamingResponse
        import io
    except ImportError:
        raise HTTPException(500, "python-docx 未安装")

    with db_session() as db:
        lecture = db.query(NodeLecture).filter_by(id=lecture_id, user_id=user["id"]).first()
        if not lecture:
            raise HTTPException(404, "讲义不存在")
        content = lecture.content

    doc = DocxDocument()
    blocks = content.get("blocks", [])
    for block in blocks:
        btype = block.get("type", "paragraph")
        text = block.get("text", "")
        if btype == "heading":
            level = block.get("level", 2)
            doc.add_heading(text, level=level)
        elif btype == "code":
            p = doc.add_paragraph(text)
            p.style = "No Spacing"
        elif btype == "list":
            doc.add_paragraph(text, style="List Bullet")
        elif btype == "quote":
            doc.add_paragraph(f"> {text}")
        else:
            doc.add_paragraph(text)

    buf = io.BytesIO()
    doc.save(buf)
    buf.seek(0)
    from fastapi.responses import StreamingResponse
    return StreamingResponse(
        buf,
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        headers={"Content-Disposition": f"attachment; filename=lecture_{lecture_id}.docx"},
    )
