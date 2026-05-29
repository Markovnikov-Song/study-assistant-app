from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field


MiniAppStatus = Literal["draft", "validated", "published"]
InterviewStatus = Literal["collecting", "ready"]


class MiniAppValidation(BaseModel):
    ok: bool
    errors: list[str] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)


class MiniAppRecord(BaseModel):
    id: str
    user_id: str
    title: str
    app_type: str = "memory"
    subject_id: int | None = None
    status: MiniAppStatus = "draft"
    documents: dict[str, str] = Field(default_factory=dict)
    spec: dict[str, Any] = Field(default_factory=dict)
    graph: dict[str, Any] = Field(default_factory=dict)
    validation: MiniAppValidation = Field(default_factory=lambda: MiniAppValidation(ok=False))
    created_at: str
    updated_at: str


class MiniAppSummary(BaseModel):
    id: str
    title: str
    app_type: str
    subject_id: int | None = None
    status: MiniAppStatus
    description: str
    updated_at: str
    validation: MiniAppValidation


class MiniAppListOut(BaseModel):
    apps: list[MiniAppSummary]
    total: int


class MiniAppSaveIn(BaseModel):
    title: str
    app_type: str = "memory"
    subject_id: int | None = None
    documents: dict[str, str]
    spec: dict[str, Any]
    status: MiniAppStatus = "draft"


class MiniAppSaveOut(BaseModel):
    app: MiniAppRecord


class MiniAppUpdateIn(BaseModel):
    title: str | None = None
    documents: dict[str, str] | None = None
    spec: dict[str, Any] | None = None
    status: MiniAppStatus | None = None


class MiniAppReviseIn(BaseModel):
    instruction: str


class MiniAppReviseOut(BaseModel):
    app: MiniAppRecord
    changed: list[str] = Field(default_factory=list)


class InterviewStartIn(BaseModel):
    initial_request: str
    subject_id: int | None = None


class InterviewAnswerIn(BaseModel):
    answer: str


class InterviewTurnOut(BaseModel):
    session_id: str
    status: InterviewStatus
    question: str | None = None
    collected: dict[str, str] = Field(default_factory=dict)
    draft: MiniAppRecord | None = None
    validation: MiniAppValidation | None = None


class ValidateSpecIn(BaseModel):
    spec: dict[str, Any]


class ValidateSpecOut(BaseModel):
    validation: MiniAppValidation
    graph: dict[str, Any] = Field(default_factory=dict)


class ValidateGraphIn(BaseModel):
    graph: dict[str, Any]
    spec: dict[str, Any] | None = None


class MiniAppRunStartOut(BaseModel):
    run_id: str
    app_id: str
    status: str
    graph: dict[str, Any] = Field(default_factory=dict)
    preview: dict[str, Any] = Field(default_factory=dict)
    created_at: str


class GenerateCardsIn(BaseModel):
    subject_id: int
    document_ids: list[int] = Field(default_factory=list)
    spec: dict[str, Any] | None = None
    use_llm: bool = True


class GenerateCardsOut(BaseModel):
    items: list[dict[str, Any]] = Field(default_factory=list)
    meta: dict[str, Any] = Field(default_factory=dict)
    target_card_count: int = 0
    actual_card_count: int = 0


class GenerateCardsForAppIn(BaseModel):
    document_ids: list[int] = Field(default_factory=list)
    use_llm: bool = True


class GenerateCardsForAppOut(BaseModel):
    app: MiniAppRecord
    items: list[dict[str, Any]] = Field(default_factory=list)
    meta: dict[str, Any] = Field(default_factory=dict)
    target_card_count: int = 0
    actual_card_count: int = 0


class MiniAppRunEventIn(BaseModel):
    node_id: str
    event_type: str
    payload: dict[str, Any] = Field(default_factory=dict)


class MiniAppRunEventOut(BaseModel):
    run_id: str
    event: dict[str, Any]
    event_count: int


class MiniAppRunOut(BaseModel):
    run: dict[str, Any]


def now_iso() -> str:
    return datetime.utcnow().isoformat(timespec="seconds") + "Z"
