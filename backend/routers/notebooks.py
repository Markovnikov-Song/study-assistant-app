"""
笔记本管理 API 端点
GET    /api/notebooks          - 获取当前用户笔记本列表（主列表，不含已归档）
POST   /api/notebooks          - 创建用户自定义本
PATCH  /api/notebooks/{id}     - 更新笔记本（名称/置顶/归档/排序）
DELETE /api/notebooks/{id}     - 删除用户自定义本（级联删除笔记）
"""
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from database import Note, Notebook, get_session
from deps import get_current_user

router = APIRouter()


# ---------------------------------------------------------------------------
# Pydantic 模型
# ---------------------------------------------------------------------------

class NotebookOut(BaseModel):
    id: int
    name: str
    is_system: bool
    is_pinned: bool
    is_archived: bool
    sort_order: int
    created_at: str

    @classmethod
    def from_orm(cls, nb: Notebook) -> "NotebookOut":
        return cls(
            id=nb.id,
            name=nb.name,
            is_system=bool(nb.is_system),
            is_pinned=bool(nb.is_pinned),
            is_archived=bool(nb.is_archived),
            sort_order=nb.sort_order,
            created_at=nb.created_at.isoformat(),
        )


class NotebookCreateIn(BaseModel):
    name: str = Field(min_length=1, max_length=64)


class NotebookUpdateIn(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=64)
    is_pinned: Optional[bool] = None
    is_archived: Optional[bool] = None
    sort_order: Optional[int] = None


# ---------------------------------------------------------------------------
# 端点
# ---------------------------------------------------------------------------

@router.get("", response_model=List[NotebookOut])
def list_notebooks(user=Depends(get_current_user)):
    """
    获取当前用户的笔记本主列表（仅返回未归档笔记本）。
    排序规则：is_system DESC, is_pinned DESC, sort_order ASC, created_at DESC
    需求：1.4, 2.7
    """
    with get_session() as db:
        notebooks = (
            db.query(Notebook)
            .filter(
                Notebook.user_id == user["id"],
                Notebook.is_archived == 0,
            )
            .order_by(
                Notebook.is_system.desc(),
                Notebook.is_pinned.desc(),
                Notebook.sort_order.asc(),
                Notebook.created_at.desc(),
            )
            .all()
        )
        return [NotebookOut.from_orm(nb) for nb in notebooks]


@router.post("", response_model=NotebookOut, status_code=201)
def create_notebook(body: NotebookCreateIn, user=Depends(get_current_user)):
    """
    创建用户自定义笔记本。
    - 名称非空且 ≤ 64 字符（由 Pydantic Field 校验，违反时自动返回 422）
    - 新建本 is_system = 0
    需求：2.1, 2.2
    """
    with get_session() as db:
        nb = Notebook(
            user_id=user["id"],
            name=body.name,
            is_system=0,
            is_pinned=0,
            is_archived=0,
            sort_order=0,
        )
        db.add(nb)
        db.flush()
        return NotebookOut.from_orm(nb)


@router.patch("/{notebook_id}", response_model=NotebookOut)
def update_notebook(
    notebook_id: int,
    body: NotebookUpdateIn,
    user=Depends(get_current_user),
):
    """
    更新笔记本属性，支持：name、is_pinned、is_archived、sort_order。
    需求：2.3, 2.4, 2.5
    """
    with get_session() as db:
        nb = (
            db.query(Notebook)
            .filter(Notebook.id == notebook_id, Notebook.user_id == user["id"])
            .first()
        )
        if not nb:
            raise HTTPException(404, "笔记本不存在")

        if body.name is not None:
            nb.name = body.name
        if body.is_pinned is not None:
            nb.is_pinned = 1 if body.is_pinned else 0
        if body.is_archived is not None:
            nb.is_archived = 1 if body.is_archived else 0
        if body.sort_order is not None:
            nb.sort_order = body.sort_order

        db.flush()
        return NotebookOut.from_orm(nb)


@router.delete("/{notebook_id}", status_code=204)
def delete_notebook(notebook_id: int, user=Depends(get_current_user)):
    """
    删除用户自定义笔记本（级联删除所有笔记，由数据库 ON DELETE CASCADE 保证）。
    系统预设本（is_system = 1）返回 403 Forbidden。
    需求：1.3, 2.6
    """
    with get_session() as db:
        nb = (
            db.query(Notebook)
            .filter(Notebook.id == notebook_id, Notebook.user_id == user["id"])
            .first()
        )
        if not nb:
            raise HTTPException(404, "笔记本不存在")

        db.delete(nb)


# ---------------------------------------------------------------------------
# GET /api/notebooks/{notebook_id}/notes  (moved here to avoid route conflict)
# ---------------------------------------------------------------------------

class NoteOut(BaseModel):
    id: int
    notebook_id: int
    subject_id: Optional[int]
    source_session_id: Optional[int]
    source_message_id: Optional[int]
    role: str
    original_content: str
    title: Optional[str]
    outline: Optional[List[str]]
    imported_to_doc_id: Optional[int]
    sources: Optional[Any]
    note_type: str
    mistake_status: Optional[str]
    mistake_details: Optional[Any]
    mastery_score: int = 0
    review_count: int = 0
    last_reviewed_at: Optional[str] = None
    mistake_category: Optional[str] = None
    mastery_history: Optional[List] = None
    created_at: str
    updated_at: str

    @classmethod
    def from_orm(cls, note: Note) -> "NoteOut":
        return cls(
            id=note.id,
            notebook_id=note.notebook_id,
            subject_id=note.subject_id,
            source_session_id=note.source_session_id,
            source_message_id=note.source_message_id,
            role=note.role,
            original_content=note.original_content,
            title=note.title,
            outline=note.outline,
            imported_to_doc_id=note.imported_to_doc_id,
            sources=note.sources,
            note_type=note.note_type,
            mistake_status=note.mistake_status,
            mistake_details=note.mistake_details,
            mastery_score=note.mastery_score,
            review_count=note.review_count,
            last_reviewed_at=note.last_reviewed_at.isoformat() if note.last_reviewed_at else None,
            mistake_category=note.mistake_category,
            mastery_history=note.mastery_history,
            created_at=note.created_at.isoformat(),
            updated_at=note.updated_at.isoformat(),
        )


class NoteSection(BaseModel):
    subject_id: Optional[int]
    notes: List[NoteOut]


class NotebookNotesOut(BaseModel):
    sections: List[NoteSection]


@router.get("/{notebook_id}/notes", response_model=NotebookNotesOut)
def get_notebook_notes(notebook_id: int, user=Depends(get_current_user)):
    """GET /api/notebooks/{notebook_id}/notes — 按 subject_id 分组返回笔记"""
    with get_session() as db:
        nb = db.query(Notebook).filter(
            Notebook.id == notebook_id,
            Notebook.user_id == user["id"],
        ).first()
        if not nb:
            raise HTTPException(404, "笔记本不存在")

        notes = (
            db.query(Note)
            .filter(Note.notebook_id == notebook_id)
            .order_by(Note.subject_id.asc().nullsfirst(), Note.created_at.desc())
            .all()
        )

        sections_map: Dict[Optional[int], List[NoteOut]] = {}
        order: List[Optional[int]] = []
        for note in notes:
            sid = note.subject_id
            if sid not in sections_map:
                sections_map[sid] = []
                order.append(sid)
            sections_map[sid].append(NoteOut.from_orm(note))

        if None in order and order[0] is not None:
            order.remove(None)
            order.insert(0, None)

        return NotebookNotesOut(sections=[
            NoteSection(subject_id=sid, notes=sections_map[sid]) for sid in order
        ])
