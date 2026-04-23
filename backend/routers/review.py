"""
复习任务 API 路由：提供 SM-2 间隔重复的增删改查接口。

接口列表：
- GET  /api/review/today       - 获取今日复习任务
- GET  /api/review/stats       - 获取复习统计
- GET  /api/review/subjects    - 获取各学科掌握度
- POST /api/review/card        - 创建复习卡片
- POST /api/review/{id}/submit - 提交复习结果
- GET  /api/review/{id}        - 获取单个卡片详情
- DELETE /api/review/{id}      - 删除复习卡片
"""

from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from database import ReviewCard, get_session
from services.sm2_engine import SM2Engine, ReviewQueue

router = APIRouter(prefix="/api/review", tags=["review"])


# ============================================================================
# 请求/响应模型
# ============================================================================

class CreateCardRequest(BaseModel):
    user_id: int
    subject_id: int
    node_id: str
    subject_name: Optional[str] = None
    node_title: Optional[str] = None
    difficulty: int = 2


class SubmitReviewRequest(BaseModel):
    quality: int  # 0-3: 忘了/模糊/想起/巩固
    response_time_ms: Optional[int] = None


class CardResponse(BaseModel):
    id: int
    node_id: str
    node_title: Optional[str]
    difficulty: int
    ease_factor: float
    interval: int
    repetitions: int
    mastery_score: int
    last_reviewed: Optional[str]
    next_review: str
    total_reviews: int
    lapse_count: int
    
    class Config:
        from_attributes = True


class SubmitResultResponse(BaseModel):
    interval_days: int
    next_review_date: str
    ease_factor: float
    streak: int
    mastery_score: int
    message: str


class StatsResponse(BaseModel):
    total_cards: int
    today_review: int
    overdue_cards: int
    overdue_days: int
    mastered_cards: int
    today_done: int
    recall_rate: float


class SubjectMasteryResponse(BaseModel):
    subject_id: int
    subject_name: str
    total_cards: int
    mastered_cards: int
    avg_mastery: float
    avg_ease_factor: float


# ============================================================================
# 辅助函数
# ============================================================================

def get_card_or_404(session: Session, card_id: int) -> ReviewCard:
    card = session.query(ReviewCard).filter(ReviewCard.id == card_id).first()
    if not card:
        raise HTTPException(status_code=404, detail="复习卡片不存在")
    return card


def card_to_response(card: ReviewCard) -> dict:
    return {
        "id": card.id,
        "node_id": card.node_id,
        "node_title": card.node_title,
        "difficulty": card.difficulty,
        "ease_factor": round(card.ease_factor / 100, 2),
        "interval": card.interval,
        "repetitions": card.repetitions,
        "mastery_score": card.mastery_score,
        "last_reviewed": card.last_reviewed.isoformat() if card.last_reviewed else None,
        "next_review": card.next_review.isoformat(),
        "total_reviews": card.total_reviews,
        "lapse_count": card.lapse_count,
    }


# ============================================================================
# API 端点
# ============================================================================

@router.get("/today", response_model=list[CardResponse])
async def get_today_review(
    user_id: int = Query(..., description="用户ID"),
    limit: int = Query(20, ge=1, le=100, description="最大返回数量"),
    session: Session = Depends(get_session),
):
    """
    获取今日复习任务。
    
    返回按优先级排序的复习卡片列表：
    1. 过期卡片优先
    2. 遗忘次数多的优先
    3. 难题优先
    """
    queue = ReviewQueue(session)
    cards = queue.get_today_review(user_id, limit)
    return [card_to_response(c) for c in cards]


@router.get("/micro", response_model=list[CardResponse])
async def get_micro_review(
    user_id: int = Query(..., description="用户ID"),
    minutes: int = Query(5, ge=1, le=30, description="可用分钟数"),
    session: Session = Depends(get_session),
):
    """
    获取碎片时间微复习任务。
    
    根据可用时间动态调整任务数量（每张约2分钟）。
    """
    queue = ReviewQueue(session)
    cards = queue.get_micro_review(user_id, minutes)
    return [card_to_response(c) for c in cards]


@router.get("/stats", response_model=StatsResponse)
async def get_review_stats(
    user_id: int = Query(..., description="用户ID"),
    session: Session = Depends(get_session),
):
    """
    获取复习统计数据。
    
    包含：
    - 总卡片数
    - 今日待复习数
    - 过期卡片数
    - 已掌握卡片数
    - 今日已完成数
    - 预测记忆率
    """
    queue = ReviewQueue(session)
    return queue.get_review_stats(user_id)


@router.get("/subjects", response_model=list[SubjectMasteryResponse])
async def get_subject_mastery(
    user_id: int = Query(..., description="用户ID"),
    session: Session = Depends(get_session),
):
    """
    获取各学科的掌握度统计。
    
    返回按平均掌握度排序的学科列表。
    """
    queue = ReviewQueue(session)
    return queue.get_subject_mastery(user_id)


@router.post("/card", response_model=CardResponse)
async def create_card(
    req: CreateCardRequest,
    session: Session = Depends(get_session),
):
    """
    创建复习卡片。
    
    如果卡片已存在（相同 user_id + node_id），直接返回现有卡片。
    """
    card = SM2Engine.create_card(
        session=session,
        user_id=req.user_id,
        subject_id=req.subject_id,
        node_id=req.node_id,
        subject_name=req.subject_name,
        node_title=req.node_title,
        difficulty=req.difficulty,
    )
    session.commit()
    return card_to_response(card)


@router.post("/{card_id}/submit", response_model=SubmitResultResponse)
async def submit_review(
    card_id: int,
    req: SubmitReviewRequest,
    session: Session = Depends(get_session),
):
    """
    提交复习结果并计算下次复习时间。
    
    Args:
        card_id: 复习卡片ID
        req.quality: 评分 0-3（忘了/模糊/想起/巩固）
        req.response_time_ms: 可选，答题耗时（毫秒）
    
    Returns:
        下次复习时间及相关反馈
    """
    card = get_card_or_404(session, card_id)
    
    # 验证评分
    if req.quality < 0 or req.quality > 3:
        raise HTTPException(status_code=400, detail="评分必须在 0-3 之间")
    
    # 计算下次复习
    result = SM2Engine.calculate_next_review(
        session=session,
        card=card,
        quality=req.quality,
        response_time_ms=req.response_time_ms,
    )
    
    session.commit()
    return result


@router.get("/{card_id}", response_model=CardResponse)
async def get_card(
    card_id: int,
    session: Session = Depends(get_session),
):
    """
    获取单个复习卡片详情。
    """
    card = get_card_or_404(session, card_id)
    return card_to_response(card)


@router.delete("/{card_id}")
async def delete_card(
    card_id: int,
    session: Session = Depends(get_session),
):
    """
    删除复习卡片（同时删除关联的复习日志）。
    """
    card = get_card_or_404(session, card_id)
    session.delete(card)
    session.commit()
    return {"message": "复习卡片已删除"}
