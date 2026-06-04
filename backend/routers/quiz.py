"""Quiz API for bounded practice generation and answer submission."""

from typing import Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from deps import get_current_user

router = APIRouter()


class NodeInfo(BaseModel):
    node_id: str
    node_title: str
    node_content: Optional[str] = None


class QuizGenerateRequest(BaseModel):
    node_id: str = Field(..., description="Current knowledge node id")
    node_title: str = Field(..., description="Current knowledge node title")
    node_content: Optional[str] = Field(None, description="Current node content")
    prerequisite_nodes: List[NodeInfo] = Field(default_factory=list)
    followup_nodes: List[NodeInfo] = Field(default_factory=list)
    question_count: int = Field(default=3, ge=1, le=20)
    question_types: List[str] = Field(default=["choice"])
    difficulty: str = Field(default="mixed")


class QuestionOption(BaseModel):
    key: str
    content: str
    is_correct: bool


class QuestionResponse(BaseModel):
    id: str
    type: str
    difficulty: str
    difficulty_label: str
    question: str
    options: Optional[List[QuestionOption]] = None
    correct_answer: str
    explanation: str
    source_node_id: str
    source_node_title: str
    knowledge_zone: str


class QuizGenerateResponse(BaseModel):
    success: bool
    total_count: int
    questions: List[QuestionResponse]
    knowledge_coverage: Dict[str, int]
    message: str


@router.post("/generate", response_model=QuizGenerateResponse)
async def generate_quiz(
    request: QuizGenerateRequest,
    user=Depends(get_current_user),
):
    """Generate practice questions around a knowledge node."""
    from services.quiz_generator_service import QuizGenerateIn, QuizGeneratorService

    service_request = QuizGenerateIn(
        node_id=request.node_id,
        node_title=request.node_title,
        node_content=request.node_content,
        prerequisite_nodes=[
            {
                "node_id": n.node_id,
                "node_title": n.node_title,
                "node_content": n.node_content or "",
            }
            for n in request.prerequisite_nodes
        ],
        followup_nodes=[
            {
                "node_id": n.node_id,
                "node_title": n.node_title,
                "node_content": n.node_content or "",
            }
            for n in request.followup_nodes
        ],
        question_count=request.question_count,
        question_types=request.question_types,
        difficulty=request.difficulty,
    )

    service = QuizGeneratorService()
    user_id = user["id"] if isinstance(user, dict) else getattr(user, "id", None)
    try:
        result = service.generate_quiz(service_request, user_id=user_id)
    except Exception as exc:
        import logging

        logging.getLogger(__name__).exception("generate_quiz failed: %s", exc)
        raise HTTPException(status_code=500, detail=f"quiz generation failed: {exc}")

    questions: List[QuestionResponse] = []
    for question in result.questions:
        try:
            questions.append(QuestionResponse(**question.model_dump()))
        except Exception:
            continue

    if not questions:
        raise HTTPException(status_code=500, detail="quiz generation produced no valid questions")

    return QuizGenerateResponse(
        success=result.success,
        total_count=result.total_count,
        questions=questions,
        knowledge_coverage=result.knowledge_coverage,
        message=result.message,
    )


@router.get("/question-types")
async def get_question_types(user=Depends(get_current_user)):
    return {
        "types": [
            {"code": "choice", "name": "choice", "has_options": True},
            {"code": "fill", "name": "fill", "has_options": False},
            {"code": "calc", "name": "calculation", "has_options": False},
            {"code": "judge", "name": "judge", "has_options": False},
        ],
        "difficulty_levels": [
            {"code": "L1", "name": "basic"},
            {"code": "L2", "name": "medium"},
            {"code": "L3", "name": "advanced"},
            {"code": "mixed", "name": "mixed"},
        ],
    }


class SubmitAnswerIn(BaseModel):
    question_id: str
    user_answer: str
    node_id: str = ""
    node_title: str = ""
    subject_id: Optional[int] = None
    question_text: str = ""
    correct_answer: str = ""
    question_type: str = "choice"


@router.post("/submit-answer")
async def submit_answer(body: SubmitAnswerIn, user=Depends(get_current_user)):
    """Judge an answer and, on wrong answers, create a mistake note plus review card."""
    is_correct = _judge_answer(
        question_type=body.question_type,
        user_answer=body.user_answer.strip(),
        correct_answer=body.correct_answer.strip(),
    )

    added_to_mistake_book = False
    review_card_id = None

    if not is_correct and body.node_id:
        try:
            from database import Note, Subject, get_session
            from routers.review import SM2Engine, get_or_create_mistake_notebook

            user_id = int(user["id"]) if isinstance(user, dict) else int(user.id)
            with get_session() as db:
                notebook = get_or_create_mistake_notebook(db, user_id)
                subject_name = None
                if body.subject_id:
                    subject = db.query(Subject).filter_by(id=body.subject_id).first()
                    if subject:
                        subject_name = subject.name

                note = Note(
                    notebook_id=notebook.id,
                    subject_id=body.subject_id,
                    title=f"错题：{body.node_title or body.node_id}",
                    original_content=(
                        f"题目：{body.question_text}\n\n"
                        f"我的答案：{body.user_answer}\n\n"
                        f"正确答案：{body.correct_answer}"
                    ),
                    role="user",
                    note_type="mistake",
                    mistake_status="pending",
                    node_id=body.node_id,
                    question_text=body.question_text,
                    user_answer=body.user_answer,
                    correct_answer=body.correct_answer,
                    mistake_category="concept",
                )
                db.add(note)
                db.flush()

                if body.subject_id:
                    review_card = SM2Engine.create_card(
                        db,
                        user_id=user_id,
                        subject_id=body.subject_id,
                        node_id=body.node_id,
                        subject_name=subject_name,
                        node_title=body.node_title or body.node_id,
                    )
                    note.review_card_id = review_card.id
                    review_card_id = review_card.id
                    db.flush()

                added_to_mistake_book = True
        except Exception as exc:
            import logging

            logging.getLogger(__name__).warning(
                "auto add quiz mistake failed: %s",
                exc,
            )

    return {
        "question_id": body.question_id,
        "user_answer": body.user_answer,
        "correct": is_correct,
        "correct_answer": body.correct_answer,
        "message": "回答正确" if is_correct else "答错了，已尝试加入错题本",
        "added_to_mistake_book": added_to_mistake_book,
        "review_card_id": review_card_id,
    }


def _judge_answer(question_type: str, user_answer: str, correct_answer: str) -> bool:
    if not user_answer or not correct_answer:
        return False
    if question_type in ("choice", "judge"):
        return user_answer.upper().strip() == correct_answer.upper().strip()

    import re

    def normalize(value: str) -> str:
        return re.sub(r"[\s\.,，。！？!？]", "", value).lower()

    return normalize(user_answer) == normalize(correct_answer)
