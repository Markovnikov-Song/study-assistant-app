from typing import Dict, List, Literal, Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from deps import get_current_user
from services.exam_service import ExamService

router = APIRouter()


def get_exam_service(user: dict = Depends(get_current_user)) -> ExamService:
    """创建带用户上下文的 ExamService"""
    return ExamService(user_id=user["id"])


class PredictedIn(BaseModel):
    subject_id: int
    use_broad: bool = False


class CustomIn(BaseModel):
    subject_id: int
    question_types: List[str]
    type_counts: Dict[str, int]
    type_scores: Dict[str, int]
    difficulty: str = "中等"
    topic: Optional[str] = None
    source_mode: Literal["material", "topic_only"] = Field(
        default="material",
        description="material=根据资料出题；topic_only=仅按自定义考点/主题，不注入资料库",
    )
    use_broad: bool = False


class GenOut(BaseModel):
    result: str


@router.post("/predicted", response_model=GenOut)
def predicted(body: PredictedIn, svc: ExamService = Depends(get_exam_service)):
    result = svc.generate_predicted_paper(
        subject_id=body.subject_id,
        use_broad=body.use_broad,
    )
    if not result:
        raise HTTPException(400, "暂无学科资料或历年题，请先上传资料")
    return GenOut(result=result)


@router.post("/custom", response_model=GenOut)
def custom(body: CustomIn, svc: ExamService = Depends(get_exam_service)):
    if not body.question_types:
        raise HTTPException(400, "请至少选择一种题型")
    total = sum(body.type_counts.get(t, 1) for t in body.question_types)
    if body.source_mode == "topic_only" and not (body.topic or "").strip():
        raise HTTPException(400, "自定义出题请填写考点/主题")
    result = svc.generate_custom_questions(
        subject_id=body.subject_id,
        question_types=body.question_types,
        count=total,
        difficulty=body.difficulty,
        topic=body.topic or "全部考点",
        type_counts=body.type_counts,
        type_scores=body.type_scores,
        source_mode=body.source_mode,
        use_broad=body.use_broad,
    )
    if not result:
        raise HTTPException(500, "生成失败，请稍后重试")
    return GenOut(result=result)
