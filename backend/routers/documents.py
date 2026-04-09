import os
import threading
from typing import List, Optional
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from pydantic import BaseModel
from deps import get_current_user
from services.document_service import DocumentService

router = APIRouter()
_svc = DocumentService()
_ALLOWED = {".pdf", ".docx", ".pptx", ".txt", ".md"}


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
    if ext not in _ALLOWED:
        raise HTTPException(400, f"不支持的文件格式：{ext}，支持：{', '.join(_ALLOWED)}")
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
