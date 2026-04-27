"""Token 配额与用量查询 API。"""
from typing import Optional
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
    try:
        from services.token_service import get_token_service
        quota = get_token_service().get_quota(int(current_user["id"]))
        return TokenQuotaResponse(
            tier=quota.tier,
            tier_name=quota.tier_name,
            quota_daily=quota.quota_daily,
            quota_monthly=quota.quota_monthly,
            used_today=quota.used_today,
            used_this_month=quota.used_this_month,
            remaining_today=quota.remaining_today,
            remaining_monthly=quota.remaining_monthly,
            bonus_tokens=quota.bonus_tokens,
            bonus_used=quota.bonus_used,
            remaining_bonus=quota.remaining_bonus,
            daily_usage_percent=quota.daily_usage_percent,
            monthly_usage_percent=quota.monthly_usage_percent,
            is_blocked=quota.is_blocked,
            rate_limit_per_min=quota.rate_limit_per_min,
            rate_limit_per_hour=quota.rate_limit_per_hour,
            total_tokens_all_time=quota.total_tokens_all_time,
            total_cost_all_time=quota.total_cost_all_time,
            price_monthly=quota.price_monthly,
        )
    except Exception:
        return TokenQuotaResponse()


@router.get("/usage")
def get_usage(current_user: dict = Depends(get_current_user)):
    """返回用量统计摘要（近 30 天）。"""
    try:
        from services.token_service import get_token_service
        data = get_token_service().get_usage_summary(int(current_user["id"]), days=30)
        return UsageSummaryResponse(**data)
    except Exception:
        return UsageSummaryResponse()


@router.get("/usage/today")
def get_usage_today(current_user: dict = Depends(get_current_user)):
    """返回今日用量。"""
    try:
        from services.token_service import get_token_service
        data = get_token_service().get_today_usage(int(current_user["id"]))
        return UsageSummaryResponse(**data)
    except Exception:
        return UsageSummaryResponse(period_days=1)


@router.get("/usage/history")
def get_usage_history(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    current_user: dict = Depends(get_current_user),
):
    """返回用量历史记录（按日聚合）。"""
    try:
        from services.token_service import get_token_service
        data = get_token_service().get_usage_history(
            int(current_user["id"]),
            start_date=start_date,
            end_date=end_date,
        )
        return UsageHistoryResponse(
            data=data.get("data", []),
            total_tokens=data.get("total_tokens", 0),
            total_requests=data.get("total_requests", 0),
            start_date=data.get("start_date", ""),
            end_date=data.get("end_date", ""),
        )
    except Exception:
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
