"""
笔记管理 API 端点

POST   /api/notes                                  - 批量创建笔记（收藏消息）
GET    /api/notes/{note_id}                        - 获取单条笔记详情
PATCH  /api/notes/{note_id}                        - 更新笔记（标题/正文）
DELETE /api/notes/{note_id}                        - 删除单条笔记
POST   /api/notes/{note_id}/generate-title         - AI 生成标题提纲
POST   /api/notes/{note_id}/import-to-rag          - 导入资料库

注意：GET /api/notebooks/{id}/notes 已移至 notebooks.py 以避免路由冲突。
"""
from __future__ import annotations

import json
import logging
from typing import Any, List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from database import Chunk, Document, Note, Notebook, get_session
from deps import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter()


# ---------------------------------------------------------------------------
# Pydantic 模型
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
            created_at=note.created_at.isoformat(),
            updated_at=note.updated_at.isoformat(),
        )


class NoteCreateItem(BaseModel):
    role: str
    original_content: str
    source_session_id: Optional[int] = None
    source_message_id: Optional[int] = None
    sources: Optional[Any] = None
    notebook_id: int
    subject_id: Optional[int] = None


class BatchCreateNotesIn(BaseModel):
    notes: List[NoteCreateItem]


class NoteUpdateIn(BaseModel):
    title: Optional[str] = Field(default=None, max_length=64)
    original_content: Optional[str] = None


class GenerateTitleOut(BaseModel):
    title: str
    outline: List[str]


class ImportToRagOut(BaseModel):
    doc_id: int
    message: str


class PolishNoteOut(BaseModel):
    polished_content: str


# ---------------------------------------------------------------------------
# 辅助
# ---------------------------------------------------------------------------

def _get_note_for_user(note_id: int, user_id: int, db) -> Note:
    note = db.query(Note).filter(Note.id == note_id).first()
    if not note:
        raise HTTPException(404, "笔记不存在")
    nb = db.query(Notebook).filter(
        Notebook.id == note.notebook_id,
        Notebook.user_id == user_id,
    ).first()
    if not nb:
        raise HTTPException(403, "无权限访问该笔记")
    return note


# ---------------------------------------------------------------------------
# POST /api/notes  批量创建（需求：5.1, 5.2, 5.5）
# ---------------------------------------------------------------------------

@router.post("/notes", status_code=201, response_model=List[NoteOut])
def batch_create_notes(body: BatchCreateNotesIn, user=Depends(get_current_user)):
    if not body.notes:
        raise HTTPException(400, "至少需要一条笔记")
    with get_session() as db:
        notebook_ids = {item.notebook_id for item in body.notes}
        for nb_id in notebook_ids:
            nb = db.query(Notebook).filter(
                Notebook.id == nb_id, Notebook.user_id == user["id"]
            ).first()
            if not nb:
                raise HTTPException(404, f"笔记本 {nb_id} 不存在或无权限")
        created = []
        for item in body.notes:
            note = Note(
                notebook_id=item.notebook_id,
                subject_id=item.subject_id,
                source_session_id=item.source_session_id,
                source_message_id=item.source_message_id,
                role=item.role,
                original_content=item.original_content,
                sources=item.sources,
            )
            db.add(note)
            db.flush()
            created.append(NoteOut.from_orm(note))
        return created


# ---------------------------------------------------------------------------
# GET / PATCH / DELETE /api/notes/{note_id}（需求：6.2, 6.3）
# ---------------------------------------------------------------------------

@router.get("/notes/{note_id}", response_model=NoteOut)
def get_note(note_id: int, user=Depends(get_current_user)):
    with get_session() as db:
        return NoteOut.from_orm(_get_note_for_user(note_id, user["id"], db))


@router.patch("/notes/{note_id}", response_model=NoteOut)
def update_note(note_id: int, body: NoteUpdateIn, user=Depends(get_current_user)):
    with get_session() as db:
        note = _get_note_for_user(note_id, user["id"], db)
        if body.title is not None:
            note.title = body.title
        if body.original_content is not None:
            note.original_content = body.original_content
        db.flush()
        return NoteOut.from_orm(note)


@router.delete("/notes/{note_id}", status_code=204)
def delete_note(note_id: int, user=Depends(get_current_user)):
    with get_session() as db:
        db.delete(_get_note_for_user(note_id, user["id"], db))


# ---------------------------------------------------------------------------
# POST /api/notes/{note_id}/generate-title（需求：6.1, 6.2, 6.4）
# ---------------------------------------------------------------------------

@router.post("/notes/{note_id}/generate-title", response_model=GenerateTitleOut)
def generate_title(note_id: int, user=Depends(get_current_user)):
    with get_session() as db:
        note = _get_note_for_user(note_id, user["id"], db)
        content = note.original_content
        if not content or not content.strip():
            raise HTTPException(400, "笔记内容为空，无法生成标题")

        prompt = f"""请根据以下笔记内容，生成一个不超过30字的标题和不超过5条提纲要点。

笔记内容：
{content}

请严格按照以下 JSON 格式返回，不要包含任何其他文字：
{{
  "title": "标题（不超过30字）",
  "outline": ["要点1", "要点2", "要点3"]
}}"""

        try:
            from services.llm_service import LLMService
            raw = LLMService().chat([{"role": "user", "content": prompt}])
        except Exception as e:
            raise HTTPException(500, f"AI 生成失败，请手动填写或稍后重试。（{e}）")

        try:
            text = raw.strip()
            if "```" in text:
                text = text[text.find("{"):text.rfind("}") + 1]
            result = json.loads(text)
            title = str(result.get("title", "")).strip()[:30]
            outline = [str(i).strip() for i in result.get("outline", [])[:5] if str(i).strip()]
        except Exception:
            raise HTTPException(500, "AI 生成失败，请手动填写或稍后重试。（响应格式错误）")

        if not title:
            raise HTTPException(500, "AI 生成失败，请手动填写或稍后重试。（标题为空）")

        note.title = title
        note.outline = outline
        db.flush()
        return GenerateTitleOut(title=title, outline=outline)


# ---------------------------------------------------------------------------
# POST /api/notes/{note_id}/import-to-rag（需求：7.1, 7.2, 7.4, 7.5, 7.6）
# ---------------------------------------------------------------------------

@router.post("/notes/{note_id}/import-to-rag", response_model=ImportToRagOut)
def import_to_rag(note_id: int, user=Depends(get_current_user)):
    with get_session() as db:
        note = _get_note_for_user(note_id, user["id"], db)
        content = (note.original_content or "").strip()
        if not content:
            raise HTTPException(400, "笔记内容为空，无法导入")

        subject_id = note.subject_id
        if not subject_id:
            raise HTTPException(400, "通用栏笔记无关联学科，无法导入资料库")

        title = note.title or content[:20]
        filename = f"笔记：{title}"
        full_text = f"{title}\n\n{content}" if note.title else content

        # 已导入时先删除旧 Document
        if note.imported_to_doc_id:
            old_doc = db.query(Document).filter(Document.id == note.imported_to_doc_id).first()
            if old_doc:
                try:
                    from services.document_service import DocumentService
                    DocumentService()._delete_vectors(note.imported_to_doc_id, subject_id)
                except Exception as e:
                    logger.warning("删除旧向量失败：%s", e)
                db.delete(old_doc)
                db.flush()

        new_doc = Document(subject_id=subject_id, user_id=user["id"], filename=filename, status="pending")
        db.add(new_doc)
        db.flush()
        new_doc_id = new_doc.id

        try:
            from services.document_service import DocumentService
            from services.embedding_service import EmbeddingService
            svc = DocumentService()
            new_doc.status = "processing"
            db.flush()
            chunks = svc.chunk_text(full_text)
            if chunks:
                vectors = EmbeddingService().embed_texts(chunks)
                svc._store_vectors(chunks, vectors, new_doc_id, subject_id, filename)
            for idx, chunk_content in enumerate(chunks):
                db.add(Chunk(document_id=new_doc_id, subject_id=subject_id, chunk_index=idx, content=chunk_content))
            new_doc.status = "completed"
        except Exception as e:
            logger.error("导入资料库失败：%s", e)
            db.delete(new_doc)
            db.flush()
            raise HTTPException(500, f"导入失败，请重试。（{e}）")

        note.imported_to_doc_id = new_doc_id
        db.flush()
        return ImportToRagOut(doc_id=new_doc_id, message="导入成功")


# ---------------------------------------------------------------------------
# POST /api/notes/{note_id}/polish  AI 润色
# ---------------------------------------------------------------------------

@router.post("/notes/{note_id}/polish", response_model=PolishNoteOut)
def polish_note(note_id: int, user=Depends(get_current_user)):
    with get_session() as db:
        note = _get_note_for_user(note_id, user["id"], db)
        content = (note.original_content or "").strip()
        if not content:
            raise HTTPException(400, "笔记内容为空，无法润色")

    prompt = f"""请对以下学习笔记进行润色和优化，要求：
1. 保持原意不变，不添加新内容
2. 改善语言表达，使其更清晰流畅
3. 修正语法错误和不通顺的句子
4. 保持 Markdown 格式（如有）
5. 直接输出润色后的内容，不要任何解释

原始笔记：
{content}"""

    try:
        from services.llm_service import LLMService
        result = LLMService().chat(
            [{"role": "user", "content": prompt}],
            max_tokens=2000,
            temperature=0.3,
        )
        return PolishNoteOut(polished_content=result.strip())
    except Exception as e:
        raise HTTPException(500, f"AI 润色失败，请稍后重试。（{e}）")
