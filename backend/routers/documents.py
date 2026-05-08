import os
import threading
from typing import Any, List, Optional
from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from pydantic import BaseModel
from deps import get_current_user
from services.document_service import DocumentService
from backend_config import get_config

router = APIRouter()
_svc = DocumentService()

def _get_allowed() -> set[str]:
    return get_config().document_allowed_extensions_set


def _max_upload_bytes() -> int:
    return get_config().DOCUMENT_MAX_UPLOAD_MB * 1024 * 1024


def _ensure_subject(subject_id: int, user_id: int) -> None:
    from database import Subject, get_session

    with get_session() as db:
        subject = db.query(Subject).filter_by(id=subject_id, user_id=user_id).first()
        if subject is None:
            raise HTTPException(404, "学科不存在或无权访问")


class DocOut(BaseModel):
    id: int
    filename: str
    status: str
    processing_stage: str = "queued"
    progress: int = 0
    parser_backend: Optional[str] = None
    chunk_count: int = 0
    outline: Optional[dict[str, Any]] = None
    mindmap_ready: bool = False
    error: Optional[str]
    created_at: str

    @classmethod
    def from_dict(cls, d: dict):
        return cls(id=d["id"], filename=d["filename"], status=d["status"],
                   processing_stage=d.get("processing_stage") or "queued",
                   progress=int(d.get("progress") or 0),
                   parser_backend=d.get("parser_backend"),
                   chunk_count=int(d.get("chunk_count") or 0),
                   outline=d.get("outline"),
                   mindmap_ready=bool(d.get("mindmap_ready")),
                   error=d.get("error"), created_at=d["created_at"].isoformat())


class KnowledgeBaseOut(BaseModel):
    subject_id: int
    status: str
    document_count: int
    chunk_count: int
    outline: Optional[dict[str, Any]] = None
    mindmap_ready: bool
    updated_at: Optional[str] = None


@router.get("", response_model=List[DocOut])
def list_docs(subject_id: int, user=Depends(get_current_user)):
    _ensure_subject(subject_id, user["id"])
    return [DocOut.from_dict(d) for d in _svc.list_documents(subject_id=subject_id, user_id=user["id"])]


@router.get("/knowledge-base", response_model=KnowledgeBaseOut)
def knowledge_base(subject_id: int, user=Depends(get_current_user)):
    _ensure_subject(subject_id, user["id"])
    kb = _svc.get_knowledge_base_status(subject_id=subject_id, user_id=user["id"])
    updated_at = kb.get("updated_at")
    if hasattr(updated_at, "isoformat"):
        updated_at = updated_at.isoformat()
    return KnowledgeBaseOut(
        subject_id=kb["subject_id"],
        status=kb["status"],
        document_count=kb["document_count"],
        chunk_count=kb["chunk_count"],
        outline=kb.get("outline"),
        mindmap_ready=kb["mindmap_ready"],
        updated_at=updated_at,
    )


@router.post("", status_code=202)
async def upload(
    request: Request,
    file: UploadFile = File(...),
    subject_id: int = Form(...),
    user=Depends(get_current_user),
):
    _ensure_subject(subject_id, user["id"])
    ext = os.path.splitext(file.filename)[1].lower()
    allowed = _get_allowed()
    max_bytes = _max_upload_bytes()
    content_length = request.headers.get("content-length")
    if content_length and content_length.isdigit() and int(content_length) > max_bytes:
        max_mb = get_config().DOCUMENT_MAX_UPLOAD_MB
        raise HTTPException(413, f"文件太大，请上传不超过 {max_mb}MB 的资料")
    if ext not in allowed:
        raise HTTPException(400, f"不支持的文件格式：{ext}，支持：{', '.join(sorted(allowed))}")
    # 重复文件名检测
    existing = _svc.list_documents(subject_id=subject_id, user_id=user["id"])
    if any(d["filename"] == file.filename for d in existing):
        raise HTTPException(409, f"文件「{file.filename}」已存在，请先删除旧文件或重命名后上传")

    file_bytes = await file.read()
    if len(file_bytes) > max_bytes:
        max_mb = get_config().DOCUMENT_MAX_UPLOAD_MB
        raise HTTPException(413, f"文件太大，请上传不超过 {max_mb}MB 的资料")
    filename = file.filename

    # 先创建 pending 记录，立即返回 doc_id
    doc_id = _svc.create_pending(filename=filename, subject_id=subject_id, user_id=user["id"])

    # 后台线程异步处理
    def _process():
        _svc.process_existing(doc_id=doc_id, file_bytes=file_bytes,
                               filename=filename, subject_id=subject_id, user_id=user["id"])

    threading.Thread(target=_process, daemon=True).start()
    return {"doc_id": doc_id}


@router.delete("/{doc_id}", status_code=204)
def delete(doc_id: int, subject_id: int, user=Depends(get_current_user)):
    _ensure_subject(subject_id, user["id"])
    r = _svc.delete_document(doc_id=doc_id, subject_id=subject_id, user_id=user["id"])
    if not r["success"]:
        raise HTTPException(400, r["error"])


@router.post("/{doc_id}/reindex", status_code=202, summary="重新分块并向量化指定文档")
def reindex(doc_id: int, subject_id: int, user=Depends(get_current_user)):
    _ensure_subject(subject_id, user["id"])
    from database import Document, get_session as db_sess
    with db_sess() as db:
        doc = db.query(Document).filter_by(
            id=doc_id,
            user_id=user["id"],
            subject_id=subject_id,
        ).first()
        if not doc:
            raise HTTPException(404, "文档不存在")
    threading.Thread(target=_svc.reindex, args=(doc_id, subject_id), daemon=True).start()
    return {"doc_id": doc_id, "status": "reindexing"}


@router.post("/reindex-all", status_code=202, summary="重新索引某学科下所有文档")
def reindex_all(subject_id: int, user=Depends(get_current_user)):
    _ensure_subject(subject_id, user["id"])
    docs = _svc.list_documents(subject_id=subject_id, user_id=user["id"])
    triggered = [d["id"] for d in docs if d["status"] == "completed"]
    for doc_id in triggered:
        threading.Thread(target=_svc.reindex, args=(doc_id, subject_id), daemon=True).start()
    return {"triggered": triggered, "count": len(triggered)}
