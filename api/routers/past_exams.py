"""
历年题路由：上传 / 列表 / 题目查看 / 删除
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from pydantic import BaseModel

from api.deps import get_current_user
from services.exam_service import ExamService
from database import get_session as db_session, PastExamQuestion

router = APIRouter()
_svc = ExamService()


class ExamFileOut(BaseModel):
    id: int
    filename: str
    status: str
    question_count: int
    error: Optional[str]
    created_at: str

    @classmethod
    def from_dict(cls, d: dict) -> "ExamFileOut":
        return cls(
            id=d["id"], filename=d["filename"],
            status=d["status"], question_count=d.get("question_count", 0),
            error=d.get("error"),
            created_at=d["created_at"].isoformat(),
        )


class QuestionOut(BaseModel):
    id: int
    question_number: Optional[str]
    content: str
    answer: Optional[str]


@router.get("", response_model=List[ExamFileOut])
def list_exams(subject_id: int, user=Depends(get_current_user)):
    files = _svc.list_past_exam_files(subject_id=subject_id, user_id=user["id"])
    return [ExamFileOut.from_dict(f) for f in files]


@router.post("", status_code=202)
async def upload(
    file: UploadFile = File(...),
    subject_id: int = Form(...),
    user=Depends(get_current_user),
):
    allowed = {".pdf", ".jpg", ".jpeg", ".png", ".docx"}
    import os
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in allowed:
        raise HTTPException(400, f"不支持的文件格式：{ext}")

    file_bytes = await file.read()
    result = _svc.process_past_exam_file(
        file_bytes=file_bytes,
        filename=file.filename,
        subject_id=subject_id,
        user_id=user["id"],
    )
    if not result["success"]:
        raise HTTPException(500, result["error"])
    return {"file_id": result["file_id"], "question_count": result["question_count"]}


@router.get("/{file_id}/questions", response_model=List[QuestionOut])
def get_questions(file_id: int, user=Depends(get_current_user)):
    with db_session() as db:
        qs = db.query(PastExamQuestion).filter_by(exam_file_id=file_id).all()
        return [
            QuestionOut(
                id=q.id,
                question_number=q.question_number,
                content=q.content,
                answer=q.answer,
            )
            for q in qs
        ]


@router.delete("/{file_id}", status_code=204)
def delete(file_id: int, subject_id: int, user=Depends(get_current_user)):
    result = _svc.delete_past_exam_file(file_id=file_id, subject_id=subject_id, user_id=user["id"])
    if not result["success"]:
        raise HTTPException(400, result["error"])
