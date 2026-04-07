import os
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
    result = _svc.upload_and_process(
        file_bytes=await file.read(), filename=file.filename,
        subject_id=subject_id, user_id=user["id"],
    )
    if not result["success"]:
        raise HTTPException(500, result["error"])
    return {"doc_id": result["doc_id"]}


@router.delete("/{doc_id}", status_code=204)
def delete(doc_id: int, subject_id: int, user=Depends(get_current_user)):
    r = _svc.delete_document(doc_id=doc_id, subject_id=subject_id, user_id=user["id"])
    if not r["success"]:
        raise HTTPException(400, r["error"])
