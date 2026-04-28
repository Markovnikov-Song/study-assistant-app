import os
import threading
from typing import List, Optional
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from pydantic import BaseModel
from deps import get_current_user
from services.exam_service import ExamService
from database import get_session as db_session, PastExamQuestion
from backend_config import get_config

router = APIRouter()
_svc = ExamService()

def _get_allowed() -> set[str]:
    return get_config().past_exam_allowed_extensions_set


class ExamFileOut(BaseModel):
    id: int
    filename: str
    status: str
    question_count: int
    error: Optional[str]
    created_at: str

    @classmethod
    def from_dict(cls, d: dict):
        return cls(id=d["id"], filename=d["filename"], status=d["status"],
                   question_count=d.get("question_count", 0),
                   error=d.get("error"), created_at=d["created_at"].isoformat())


class QuestionOut(BaseModel):
    id: int
    question_number: Optional[str]
    content: str
    answer: Optional[str]


@router.get("", response_model=List[ExamFileOut])
def list_exams(subject_id: int, user=Depends(get_current_user)):
    return [ExamFileOut.from_dict(f) for f in _svc.list_past_exam_files(subject_id=subject_id, user_id=user["id"])]


@router.post("", status_code=202)
async def upload(file: UploadFile = File(...), subject_id: int = Form(...), user=Depends(get_current_user)):
    ext = os.path.splitext(file.filename)[1].lower()
    allowed = _get_allowed()
    if ext not in allowed:
        raise HTTPException(400, f"不支持的文件格式：{ext}")
    # 重复文件名检测
    existing = _svc.list_past_exam_files(subject_id=subject_id, user_id=user["id"])
    if any(f["filename"] == file.filename for f in existing):
        raise HTTPException(409, f"文件「{file.filename}」已存在，请先删除旧文件或重命名后上传")

    file_bytes = await file.read()
    filename = file.filename

    # 先创建 pending 记录，立即返回 file_id
    file_id = _svc.create_pending(filename=filename, subject_id=subject_id, user_id=user["id"])

    def _process():
        _svc.process_existing(file_id=file_id, file_bytes=file_bytes,
                               filename=filename, subject_id=subject_id, user_id=user["id"])

    threading.Thread(target=_process, daemon=True).start()
    return {"file_id": file_id}


@router.get("/{file_id}/questions", response_model=List[QuestionOut])
def get_questions(file_id: int, user=Depends(get_current_user)):
    with db_session() as db:
        # 先验证该文件属于当前用户，防止越权读取他人数据
        from database import PastExamFile
        exam_file = db.query(PastExamFile).filter_by(id=file_id, user_id=user["id"]).first()
        if not exam_file:
            raise HTTPException(404, "文件不存在")
        qs = db.query(PastExamQuestion).filter_by(exam_file_id=file_id).all()
        return [QuestionOut(id=q.id, question_number=q.question_number,
                            content=q.content, answer=q.answer) for q in qs]


@router.delete("/{file_id}", status_code=204)
def delete(file_id: int, subject_id: int, user=Depends(get_current_user)):
    r = _svc.delete_past_exam_file(file_id=file_id, subject_id=subject_id, user_id=user["id"])
    if not r["success"]:
        raise HTTPException(400, r["error"])
