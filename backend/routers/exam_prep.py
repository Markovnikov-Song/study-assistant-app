from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from database import get_session as db_session
from deps import get_current_user
from services.exam_prep_orchestrator import ExamPrepOrchestrator

router = APIRouter()


class ExamPrepIntakeIn(BaseModel):
    goal: str = Field(..., min_length=1, max_length=500)


class ExamPrepIntakeOut(BaseModel):
    goal: str
    subject_id: int | None
    subject_name: str | None
    deadline: str | None
    daily_minutes: int | None
    missing_slots: list[str]
    capability_mix: list[dict[str, Any]]
    suggested_widgets: list[str]


@router.post("/intake", response_model=ExamPrepIntakeOut)
def intake(body: ExamPrepIntakeIn, user=Depends(get_current_user)):
    user_id = int(user["id"])
    with db_session() as db:
        draft = ExamPrepOrchestrator().draft(db, user_id, body.goal)
        return ExamPrepIntakeOut(**draft.__dict__)
