"""
反馈信号 API 路由：提供 Agent Council 反馈信号的持久化和追踪。

接口列表：
- GET  /api/feedback              - 获取用户反馈信号列表
- POST /api/feedback              - 创建新反馈信号
- GET  /api/feedback/{id}         - 获取单个反馈详情
- POST /api/feedback/{id}/ack     - 确认反馈信号
- POST /api/feedback/{id}/action  - 标记已执行建议
- GET  /api/feedback/trends       - 获取反馈趋势分析
"""

from datetime import datetime, timedelta
from typing import Optional, List

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from database import FeedbackSignal, get_session

router = APIRouter(prefix="/api/feedback", tags=["feedback"])


# ============================================================================
# 请求/响应模型
# ============================================================================

class CreateFeedbackRequest(BaseModel):
    user_id: int
    subject_id: Optional[int] = None
    level: str  # "fast" | "medium" | "slow"
    signal_type: str
    description: str
    suggestion: Optional[str] = None
    trigger_context: Optional[dict] = None


class FeedbackResponse(BaseModel):
    id: int
    user_id: int
    subject_id: Optional[int]
    level: str
    signal_type: str
    description: str
    suggestion: Optional[str]
    trigger_context: Optional[dict]
    is_acknowledged: bool
    is_actioned: bool
    created_at: str
    acknowledged_at: Optional[str]
    
    class Config:
        from_attributes = True


class TrendResponse(BaseModel):
    period: str
    total_signals: int
    by_level: dict
    by_subject: dict
    action_rate: float  # 执行率


# ============================================================================
# 辅助函数
# ============================================================================

def get_feedback_or_404(session: Session, feedback_id: int) -> FeedbackSignal:
    fb = session.query(FeedbackSignal).filter(FeedbackSignal.id == feedback_id).first()
    if not fb:
        raise HTTPException(status_code=404, detail="反馈信号不存在")
    return fb


def feedback_to_response(fb: FeedbackSignal) -> dict:
    return {
        "id": fb.id,
        "user_id": fb.user_id,
        "subject_id": fb.subject_id,
        "level": fb.level,
        "signal_type": fb.signal_type,
        "description": fb.description,
        "suggestion": fb.suggestion,
        "trigger_context": fb.trigger_context,
        "is_acknowledged": bool(fb.is_acknowledged),
        "is_actioned": bool(fb.is_actioned),
        "created_at": fb.created_at.isoformat(),
        "acknowledged_at": fb.acknowledged_at.isoformat() if fb.acknowledged_at else None,
    }


# ============================================================================
# API 端点
# ============================================================================

@router.get("", response_model=List[FeedbackResponse])
async def list_feedback(
    user_id: int = Query(..., description="用户ID"),
    level: Optional[str] = Query(None, description="过滤级别: fast/medium/slow"),
    acknowledged: Optional[bool] = Query(None, description="是否已确认"),
    limit: int = Query(50, ge=1, le=100),
    session: Session = Depends(get_session),
):
    """
    获取用户的反馈信号列表。
    """
    query = session.query(FeedbackSignal).filter(FeedbackSignal.user_id == user_id)
    
    if level:
        query = query.filter(FeedbackSignal.level == level)
    if acknowledged is not None:
        query = query.filter(FeedbackSignal.is_acknowledged == (1 if acknowledged else 0))
    
    feedbacks = query.order_by(FeedbackSignal.created_at.desc()).limit(limit).all()
    return [feedback_to_response(fb) for fb in feedbacks]


@router.post("", response_model=FeedbackResponse)
async def create_feedback(
    req: CreateFeedbackRequest,
    session: Session = Depends(get_session),
):
    """
    创建新的反馈信号。
    
    通常由 Agent Council 自动调用。
    """
    # 验证级别
    if req.level not in ("fast", "medium", "slow"):
        raise HTTPException(status_code=400, detail="level 必须是 fast/medium/slow 之一")
    
    fb = FeedbackSignal(
        user_id=req.user_id,
        subject_id=req.subject_id,
        level=req.level,
        signal_type=req.signal_type,
        description=req.description,
        suggestion=req.suggestion,
        trigger_context=req.trigger_context,
        is_acknowledged=0,
        is_actioned=0,
    )
    
    session.add(fb)
    session.commit()
    session.refresh(fb)
    
    return feedback_to_response(fb)


@router.get("/{feedback_id}", response_model=FeedbackResponse)
async def get_feedback(
    feedback_id: int,
    session: Session = Depends(get_session),
):
    """
    获取单个反馈信号详情。
    """
    fb = get_feedback_or_404(session, feedback_id)
    return feedback_to_response(fb)


@router.post("/{feedback_id}/ack", response_model=FeedbackResponse)
async def acknowledge_feedback(
    feedback_id: int,
    session: Session = Depends(get_session),
):
    """
    确认反馈信号（用户已查看）。
    """
    fb = get_feedback_or_404(session, feedback_id)
    fb.is_acknowledged = 1
    fb.acknowledged_at = datetime.now()
    session.commit()
    return feedback_to_response(fb)


@router.post("/{feedback_id}/action", response_model=FeedbackResponse)
async def mark_actioned(
    feedback_id: int,
    session: Session = Depends(get_session),
):
    """
    标记反馈建议已执行。
    """
    fb = get_feedback_or_404(session, feedback_id)
    fb.is_actioned = 1
    session.commit()
    return feedback_to_response(fb)


@router.get("/trends/analysis", response_model=TrendResponse)
async def get_trends(
    user_id: int = Query(..., description="用户ID"),
    days: int = Query(30, ge=7, le=90, description="统计天数"),
    session: Session = Depends(get_session),
):
    """
    获取反馈趋势分析。
    
    分析维度：
    - 各级别反馈数量分布
    - 各学科反馈分布
    - 建议执行率
    """
    since = datetime.now() - timedelta(days=days)
    
    feedbacks = session.query(FeedbackSignal).filter(
        FeedbackSignal.user_id == user_id,
        FeedbackSignal.created_at >= since
    ).all()
    
    if not feedbacks:
        return {
            "period": f"最近{days}天",
            "total_signals": 0,
            "by_level": {},
            "by_subject": {},
            "action_rate": 0.0,
        }
    
    # 按级别统计
    by_level = {"fast": 0, "medium": 0, "slow": 0}
    for fb in feedbacks:
        if fb.level in by_level:
            by_level[fb.level] += 1
    
    # 按学科统计
    by_subject = {}
    for fb in feedbacks:
        key = str(fb.subject_id) if fb.subject_id else "general"
        by_subject[key] = by_subject.get(key, 0) + 1
    
    # 执行率
    actioned = sum(1 for fb in feedbacks if fb.is_actioned)
    action_rate = actioned / len(feedbacks) * 100
    
    return {
        "period": f"最近{days}天",
        "total_signals": len(feedbacks),
        "by_level": by_level,
        "by_subject": by_subject,
        "action_rate": round(action_rate, 1),
    }
