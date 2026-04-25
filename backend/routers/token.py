"""Token 配额与用量查询 API。"""
from fastapi import APIRouter, Depends
from pydantic import BaseModel

from deps import get_current_user

router = APIRouter(tags=["token"])


class TokenQuotaResponse(BaseModel):
    tier: str = "free"
    tier_name: str = "免费版"
    quota_daily: int = 50000
    quota_monthly: int = 0
    used_today: int = 0
    used_this_month: int = 0
    remaining_today: int = 50000
    remaining_monthly: int = 0
    bonus_tokens: int = 0
    bonus_used: int = 0
    remaining_bonus: int = 0
    daily_usage_percent: float = 0.0
    monthly_usage_percent: float = 0.0
    is_blocked: bool = False
    rate_limit_per_min: int = 10
    rate_limit_per_hour: int = 100
    total_tokens_all_time: int = 0
    total_cost_all_time: float = 0.0
    price_monthly: float = 0.0


class UsageSummaryResponse(BaseModel):
    period_days: int = 30
    total_tokens: int = 0
    total_cost: float = 0.0
    total_requests: int = 0
    by_endpoint: dict = {}


class UsageHistoryResponse(BaseModel):
    data: list = []
    total_tokens: int = 0
    total_requests: int = 0
    start_date: str = ""
    end_date: str = ""


@router.get("/quota", response_model=TokenQuotaResponse)
def get_quota(current_user: dict = Depends(get_current_user)):
    """返回当前用户的 token 配额与用量摘要。"""
    return TokenQuotaResponse()


@router.get("/usage")
def get_usage(current_user: dict = Depends(get_current_user)):
    """返回用量统计摘要。"""
    return UsageSummaryResponse()


@router.get("/usage/today")
def get_usage_today(current_user: dict = Depends(get_current_user)):
    """返回今日用量（UsageSummary 格式）。"""
    return UsageSummaryResponse(
        period_days=1,
        total_tokens=0,
        total_cost=0.0,
        total_requests=0,
        by_endpoint={},
    )


@router.get("/usage/history")
def get_usage_history(current_user: dict = Depends(get_current_user)):
    """返回用量历史记录。"""
    return UsageHistoryResponse()


@router.get("/tiers")
def get_tiers():
    """返回可选的订阅套餐列表。"""
    return {
        "tiers": [
            {
                "id": "free",
                "name": "免费版",
                "quota_daily": 50000,
                "price_monthly": 0.0,
            },
            {
                "id": "pro",
                "name": "Pro",
                "quota_daily": 200000,
                "price_monthly": 9.9,
            },
        ]
    }

