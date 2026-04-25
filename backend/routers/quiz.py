"""
AI 出题 API：边界控制的练习题生成。

核心功能：
1. 基于知识点及其前置/后置知识生成练习题
2. 支持多种题型：选择、填空、计算、判断
3. 难度分级：L1基础/L2中等/L3进阶
4. 数量控制：单知识点3-5道，章节8-15道
"""

from typing import Any, Dict, List, Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from deps import get_current_user

router = APIRouter()


# ============================================================================
# 请求/响应模型
# ============================================================================

class NodeInfo(BaseModel):
    """知识点信息"""
    node_id: str
    node_title: str
    node_content: Optional[str] = None


class QuizGenerateRequest(BaseModel):
    """生成题目请求"""
    node_id: str = Field(..., description="当前知识点 ID")
    node_title: str = Field(..., description="当前知识点标题")
    node_content: Optional[str] = Field(None, description="当前知识点内容")

    # 边界控制
    prerequisite_nodes: List[NodeInfo] = Field(
        default_factory=list,
        description="前置知识节点列表"
    )
    followup_nodes: List[NodeInfo] = Field(
        default_factory=list,
        description="后置知识节点列表"
    )

    # 生成参数
    question_count: int = Field(
        default=3, ge=1, le=20,
        description="题目数量，默认3道，最多20道"
    )
    question_types: List[str] = Field(
        default=["choice"],
        description="题型: choice(选择) | fill(填空) | calc(计算) | judge(判断)"
    )
    difficulty: str = Field(
        default="mixed",
        description="难度: L1(基础) | L2(中等) | L3(进阶) | mixed(混合)"
    )


class QuestionOption(BaseModel):
    """选择题选项"""
    key: str
    content: str
    is_correct: bool


class QuestionResponse(BaseModel):
    """题目响应"""
    id: str
    type: str  # choice, fill, calc, judge
    difficulty: str
    difficulty_label: str

    question: str
    options: Optional[List[QuestionOption]] = None
    correct_answer: str
    explanation: str

    source_node_id: str
    source_node_title: str
    knowledge_zone: str  # pre, current, post


class QuizGenerateResponse(BaseModel):
    """生成题目响应"""
    success: bool
    total_count: int
    questions: List[QuestionResponse]
    knowledge_coverage: Dict[str, int]
    message: str


# ============================================================================
# API 路由
# ============================================================================

@router.post("/generate", response_model=QuizGenerateResponse)
async def generate_quiz(
    request: QuizGenerateRequest,
    user=Depends(get_current_user),
):
    """
    生成练习题。

    边界控制：
    - 前置知识区：占比约20%，打牢基础
    - 当前知识区：占比约60%，重点练习
    - 后置知识区：占比约20%，适当挑战

    难度分布：
    - L1(基础)：40%
    - L2(中等)：40%
    - L3(进阶)：20%

    题型说明：
    - choice: 选择题（4个选项）
    - fill: 填空题
    - calc: 计算题
    - judge: 判断题
    """
    from services.quiz_generator_service import QuizGeneratorService

    # 转换为服务层模型
    from services.quiz_generator_service import QuizGenerateIn, NodeInfo as ServiceNodeInfo

    service_request = QuizGenerateIn(
        node_id=request.node_id,
        node_title=request.node_title,
        node_content=request.node_content,
        prerequisite_nodes=[
            {"node_id": n.node_id, "node_title": n.node_title, "node_content": n.node_content or ""}
            for n in request.prerequisite_nodes
        ],
        followup_nodes=[
            {"node_id": n.node_id, "node_title": n.node_title, "node_content": n.node_content or ""}
            for n in request.followup_nodes
        ],
        question_count=request.question_count,
        question_types=request.question_types,
        difficulty=request.difficulty,
    )

    service = QuizGeneratorService()
    result = service.generate_quiz(service_request, user_id=user.id if hasattr(user, 'id') else None)

    # 转换响应
    questions = []
    for q in result.questions:
        q_dict = q.model_dump()
        questions.append(QuestionResponse(**q_dict))


    return QuizGenerateResponse(
        success=result.success,
        total_count=result.total_count,
        questions=questions,
        knowledge_coverage=result.knowledge_coverage,
        message=result.message,
    )


@router.get("/question-types")
async def get_question_types(
    user=Depends(get_current_user),
):
    """获取支持的题型列表"""
    return {
        "types": [
            {
                "code": "choice",
                "name": "选择题",
                "description": "4个选项，单选",
                "has_options": True
            },
            {
                "code": "fill",
                "name": "填空题",
                "description": "根据题意填写答案",
                "has_options": False
            },
            {
                "code": "calc",
                "name": "计算题",
                "description": "需要计算过程的题目",
                "has_options": False
            },
            {
                "code": "judge",
                "name": "判断题",
                "description": "判断说法的对错",
                "has_options": False
            },
        ],
        "difficulty_levels": [
            {"code": "L1", "name": "基础", "weight": "40%"},
            {"code": "L2", "name": "中等", "weight": "40%"},
            {"code": "L3", "name": "进阶", "weight": "20%"},
            {"code": "mixed", "name": "混合", "weight": "自动分布"},
        ],
    }


@router.post("/submit-answer")
async def submit_answer(
    question_id: str,
    user_answer: str,
    node_id: str = "",
    node_title: str = "",
    subject_id: Optional[int] = None,
    question_text: str = "",
    correct_answer: str = "",
    question_type: str = "choice",
    user=Depends(get_current_user),
):
    """
    提交答题结果。
    - 判断是否答对（choice/judge 精确匹配，fill/calc 模糊匹配）
    - 答错时自动调用 /mistakes/from-practice 写入错题本
    """
    from services.quiz_generator_service import QuizGeneratorService

    # 判题逻辑
    is_correct = _judge_answer(
        question_type=question_type,
        user_answer=user_answer.strip(),
        correct_answer=correct_answer.strip(),
    )

    # 答错 → 自动入错题本
    if not is_correct and node_id:
        try:
            from database import get_session, Notebook, Note, Subject
            from routers.review import get_or_create_mistake_notebook, SM2Engine

            user_id = int(user["id"]) if isinstance(user, dict) else user.id
            with get_session() as db:
                notebook = get_or_create_mistake_notebook(db, user_id)
                subject_name = None
                if subject_id:
                    subj = db.query(Subject).filter_by(id=subject_id).first()
                    if subj:
                        subject_name = subj.name

                note = Note(
                    notebook_id=notebook.id,
                    subject_id=subject_id,
                    title=f"错题：{node_title or node_id}",
                    original_content=f"题目：{question_text}\n\n我的答案：{user_answer}\n\n正确答案：{correct_answer}",
                    role="user",
                    note_type="mistake",
                    mistake_status="pending",
                    node_id=node_id,
                    question_text=question_text,
                    user_answer=user_answer,
                    correct_answer=correct_answer,
                    mistake_category="concept",
                )
                db.add(note)
                db.flush()

                # 自动创建 SM-2 复习卡片
                if node_id or subject_id:
                    review_card = SM2Engine.create_card(
                        db,
                        user_id=user_id,
                        subject_id=subject_id or 0,
                        node_id=node_id or f"note_{note.id}",
                        subject_name=subject_name,
                        node_title=node_title or node_id,
                    )
                    note.review_card_id = review_card.id
                    db.flush()
        except Exception as e:
            import logging
            logging.getLogger(__name__).warning("自动入错题本失败（非致命）：%s", e)

    return {
        "question_id": question_id,
        "user_answer": user_answer,
        "correct": is_correct,
        "correct_answer": correct_answer,
        "message": "回答正确！" if is_correct else "答错了，已加入错题本",
        "added_to_mistake_book": not is_correct and bool(node_id),
    }


def _judge_answer(question_type: str, user_answer: str, correct_answer: str) -> bool:
    """判题：choice/judge 精确匹配，fill/calc 模糊匹配（去除空格、大小写）。"""
    if not user_answer or not correct_answer:
        return False
    if question_type in ("choice", "judge"):
        return user_answer.upper().strip() == correct_answer.upper().strip()
    # fill / calc：去除空格和标点后比较
    import re
    def normalize(s: str) -> str:
        return re.sub(r'[\s\.,，。！!？?]', '', s).lower()
    return normalize(user_answer) == normalize(correct_answer)
