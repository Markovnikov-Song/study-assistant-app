"""
资料文档路由：上传 / 列表 / 删除
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from pydantic import BaseModel

from api.deps import get_current_user
from services.document_service import DocumentService

router = APIRouter()
_svc = DocumentService()


class DocOut(BaseModel):
    id: int
    filename: str
    status: str
    error: Optional[str]
    created_at: str

    @classmethod
    def from_dict(cls, d: dict) -> "DocOut":
        return cls(
            id=d["id"], filename=d["filename"],
            status=d["status"], error=d.get("error"),
            created_at=d["created_at"].isoformat(),
        )


@router.get("", response_model=List[DocOut])
def list_docs(subject_id: int, user=Depends(get_current_user)):
    docs = _svc.list_documents(subject_id=subject_id, user_id=user["id"])
    return [DocOut.from_dict(d) for d in docs]


@router.post("", status_code=202)
async def upload(
    file: UploadFile = File(...),
    subject_id: int = Form(...),
    user=Depends(get_current_user),
):
    allowed = {".pdf", ".docx", ".pptx", ".txt", ".md"}
    import os
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in allowed:
        raise HTTPException(400, f"不支持的文件格式：{ext}")

    file_bytes = await file.read()
    result = _svc.upload_and_process(
        file_bytes=file_bytes,
        filename=file.filename,
        subject_id=subject_id,
        user_id=user["id"],
    )
    if not result["success"]:
        raise HTTPException(500, result["error"])
    return {"doc_id": result["doc_id"], "detail": "处理完成"}


@router.delete("/{doc_id}", status_code=204)
def delete(doc_id: int, subject_id: int, user=Depends(get_current_user)):
    result = _svc.delete_document(doc_id=doc_id, subject_id=subject_id, user_id=user["id"])
    if not result["success"]:
        raise HTTPException(400, result["error"])
