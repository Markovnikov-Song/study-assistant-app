import os
import threading
from typing import List, Optional
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from pydantic import BaseModel
from deps import get_current_user
from services.document_service import DocumentService
from backend_config import get_config

router = APIRouter()
_svc = DocumentService()

def _get_allowed() -> set[str]:
    return get_config().document_allowed_extensions_set


class DocOut(BaseModel):
    id: int
    filename: str
    status: str
    error: Optional[str]
    created_at: str

    @classmethod
    def from_dict(cls, d: dict):
        return cls(id=d["id"], filename=d["filename"], status=d["status"],
                   error=d.get("error"), created_at=d["created_at"].isoformat())


@router.get("", response_model=List[DocOut])
def list_docs(subject_id: int, user=Depends(get_current_user)):
    return [DocOut.from_dict(d) for d in _svc.list_documents(subject_id=subject_id, user_id=user["id"])]


@router.post("", status_code=202)
async def upload(file: UploadFile = File(...), subject_id: int = Form(...), user=Depends(get_current_user)):
    ext = os.path.splitext(file.filename)[1].lower()
    allowed = _get_allowed()
    if ext not in allowed:
        raise HTTPException(400, f"不支持的文件格式：{ext}，支持：{', '.join(sorted(allowed))}")
    # 重复文件名检测
    existing = _svc.list_documents(subject_id=subject_id, user_id=user["id"])
    if any(d["filename"] == file.filename for d in existing):
        raise HTTPException(409, f"文件「{file.filename}」已存在，请先删除旧文件或重命名后上传")

    file_bytes = await file.read()
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
    r = _svc.delete_document(doc_id=doc_id, subject_id=subject_id, user_id=user["id"])
    if not r["success"]:
        raise HTTPException(400, r["error"])


@router.post("/{doc_id}/reindex", status_code=202, summary="重新分块并向量化指定文档")
def reindex(doc_id: int, subject_id: int, user=Depends(get_current_user)):
    from database import Document, get_session as db_sess
    with db_sess() as db:
        doc = db.query(Document).filter_by(id=doc_id, user_id=user["id"]).first()
        if not doc:
            raise HTTPException(404, "文档不存在")
    threading.Thread(target=_svc.reindex, args=(doc_id, subject_id), daemon=True).start()
    return {"doc_id": doc_id, "status": "reindexing"}


@router.post("/reindex-all", status_code=202, summary="重新索引某学科下所有文档")
def reindex_all(subject_id: int, user=Depends(get_current_user)):
    docs = _svc.list_documents(subject_id=subject_id, user_id=user["id"])
    triggered = [d["id"] for d in docs if d["status"] == "completed"]
    for doc_id in triggered:
        threading.Thread(target=_svc.reindex, args=(doc_id, subject_id), daemon=True).start()
    return {"triggered": triggered, "count": len(triggered)}
