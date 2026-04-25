"""
Token管理API路由
"""

from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from api.deps import get_current_user
from api.security import is_admin, admin_rate_limit
from services.token_service import (
    get_token_service,
    TokenService,
    TIER_CONFIG,
    TokenQuotaExceeded,
    RateLimitExceeded,
    UserBlockedException,
)


router = APIRouter(prefix="/api/token", tags=["token-management"])


# ============================================================================
# 响应模型
# ============================================================================

class QuotaResponse(BaseModel):
    """配额响应"""
    tier: str
    tier_name: str
    quota_daily: int
    quota_monthly: int
    used_today: int
    used_this_month: int
    remaining_today: int
    remaining_monthly: int
    bonus_tokens: int
    bonus_used: int
    remaining_bonus: int
    daily_usage_percent: float
    monthly_usage_percent: float
    is_blocked: bool
    rate_limit_per_min: int
    rate_limit_per_hour: int


class UsageSummaryResponse(BaseModel):
    """使用统计响应"""
    period_days: int
    total_tokens: int
    total_cost: float
    total_requests: int
    by_endpoint: dict


class TierInfo(BaseModel):
    """档位信息"""
    tier: str
    name: str
    price_monthly: float
    daily_quota: int
    monthly_quota: int
    rate_limit_per_min: int
    rate_limit_per_hour: int
    payg_enabled: bool


class TierListResponse(BaseModel):
    """档位列表响应"""
    tiers: list[TierInfo]


class UpgradeRequest(BaseModel):
    """升级请求"""
    tier: str


class UpgradeResponse(BaseModel):
    """升级响应"""
    success: bool
    message: str
    new_tier: str


class CheckQuotaRequest(BaseModel):
    """检查配额请求"""
    tokens: int


class CheckQuotaResponse(BaseModel):
    """检查配额响应"""
    allowed: bool
    reason: str
    required_tokens: int


# ============================================================================
# 用户接口
# ============================================================================

@router.get("/quota", response_model=QuotaResponse)
def get_my_quota(user=Depends(get_current_user)):
    """获取当前用户的Token配额"""
    service = get_token_service()
    quota = service.get_quota(user["id"])
    
    return QuotaResponse(
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
    )


@router.get("/usage", response_model=UsageSummaryResponse)
def get_my_usage(
    days: int = 30,
    user=Depends(get_current_user)
):
    """获取当前用户的使用统计"""
    service = get_token_service()
    summary = service.get_usage_summary(user["id"], days)
    
    return UsageSummaryResponse(**summary)


@router.get("/usage/today")
def get_today_usage(user=Depends(get_current_user)):
    """获取今日使用统计"""
    service = get_token_service()
    return service.get_today_usage(user["id"])


@router.get("/tiers", response_model=TierListResponse)
def list_tiers():
    """获取所有可用档位"""
    tiers = [
        TierInfo(
            tier=tier,
            name=config["name"],
            price_monthly=config["price_monthly"] / 100,
            daily_quota=config["daily_quota"],
            monthly_quota=config["monthly_quota"],
            rate_limit_per_min=config["rate_limit_per_min"],
            rate_limit_per_hour=config["rate_limit_per_hour"],
            payg_enabled=config["payg_enabled"],
        )
        for tier, config in TIER_CONFIG.items()
    ]
    return TierListResponse(tiers=tiers)


@router.post("/check-quota", response_model=CheckQuotaResponse)
def check_quota(
    body: CheckQuotaRequest,
    user=Depends(get_current_user)
):
    """检查配额是否足够"""
    service = get_token_service()
    allowed, reason = service.check_quota(user["id"], body.tokens)
    
    return CheckQuotaResponse(
        allowed=allowed,
        reason=reason,
        required_tokens=body.tokens,
    )


# ============================================================================
# 升级接口（暂时模拟，实际接入支付系统后完善）
# ============================================================================

@router.post("/upgrade", response_model=UpgradeResponse)
def upgrade_tier(
    body: UpgradeRequest,
    user=Depends(get_current_user)
):
    """
    升级用户档位
    
    暂时：直接升级到目标档位
    后续：接入支付系统，支付成功后再升级
    """
    service = get_token_service()
    
    if body.tier not in TIER_CONFIG:
        return UpgradeResponse(
            success=False,
            message=f"未知档位: {body.tier}",
            new_tier="",
        )
    
    # TODO: 接入支付系统
    # 目前：模拟支付成功，直接升级
    success = service.upgrade_tier(user["id"], body.tier)
    
    if success:
        return UpgradeResponse(
            success=True,
            message="升级成功",
            new_tier=body.tier,
        )
    else:
        return UpgradeResponse(
            success=False,
            message="升级失败",
            new_tier="",
        )


# ============================================================================
# 管理员接口
# ============================================================================

@router.get("/admin/overview")
@admin_rate_limit(max_requests=60, window_seconds=60)
def admin_overview(user=Depends(get_current_user)):
    """
    管理员：全局Token使用概览
    """
    from database import func, TokenUsageLog, UserTokenQuota, User
    from database import get_session

    # 管理员权限检查
    if not is_admin(user["id"]):
        raise HTTPException(403, "需要管理员权限")
    
    with get_session() as db:
        today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        
        # 今日统计
        today_stats = db.query(
            func.sum(TokenUsageLog.total_tokens).label("total_tokens"),
            func.sum(TokenUsageLog.api_cost).label("total_cost"),
            func.count(func.distinct(TokenUsageLog.user_id)).label("active_users"),
            func.count(TokenUsageLog.id).label("request_count"),
        ).filter(
            TokenUsageLog.created_at >= today_start
        ).first()
        
        # 各档位用户数
        tier_stats = db.query(
            UserTokenQuota.tier,
            func.count(UserTokenQuota.id).label("user_count"),
        ).join(User, User.id == UserTokenQuota.user_id).group_by(
            UserTokenQuota.tier
        ).all()
        
        # 封禁用户数
        blocked_count = db.query(func.count(UserTokenQuota.id)).filter(
            UserTokenQuota.is_blocked == 1
        ).scalar() or 0
        
        # 总用户数
        total_users = db.query(func.count(User.id)).scalar() or 0
        
        return {
            "today": {
                "total_tokens": today_stats.total_tokens or 0,
                "total_cost": (today_stats.total_cost or 0) / 1_000_000,
                "active_users": today_stats.active_users or 0,
                "request_count": today_stats.request_count or 0,
            },
            "tier_distribution": {
                row.tier: row.user_count for row in tier_stats
            },
            "total_users": total_users,
            "blocked_users": blocked_count,
        }


@router.get("/admin/user/{target_user_id}/quota", response_model=QuotaResponse)
@admin_rate_limit(max_requests=60, window_seconds=60)
def admin_get_user_quota(
    target_user_id: int,
    user=Depends(get_current_user)
):
    """管理员：查看指定用户的配额"""
    # 管理员权限检查
    if not is_admin(user["id"]):
        raise HTTPException(403, "需要管理员权限")

    service = get_token_service()
    quota = service.get_quota(target_user_id)

    return QuotaResponse(
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
    )


@router.post("/admin/user/{target_user_id}/upgrade", response_model=UpgradeResponse)
@admin_rate_limit(max_requests=10, window_seconds=60)
def admin_upgrade_user(
    target_user_id: int,
    body: UpgradeRequest,
    user=Depends(get_current_user)
):
    """管理员：手动升级指定用户档位"""
    # 管理员权限检查
    if not is_admin(user["id"]):
        raise HTTPException(403, "需要管理员权限")

    service = get_token_service()

    if body.tier not in TIER_CONFIG:
        return UpgradeResponse(
            success=False,
            message=f"未知档位: {body.tier}",
            new_tier="",
        )

    success = service.upgrade_tier(target_user_id, body.tier)

    return UpgradeResponse(
        success=success,
        message="升级成功" if success else "升级失败",
        new_tier=body.tier if success else "",
    )


@router.post("/admin/user/{target_user_id}/bonus")
@admin_rate_limit(max_requests=10, window_seconds=60)
def admin_add_bonus(
    target_user_id: int,
    tokens: int,
    user=Depends(get_current_user)
):
    """管理员：给用户添加bonus token"""
    # 管理员权限检查
    if not is_admin(user["id"]):
        raise HTTPException(403, "需要管理员权限")

    # 防止恶意添加大量 tokens
    if tokens > 1000000 or tokens < 0:
        raise HTTPException(400, "bonus tokens 数量必须在 0-1000000 之间")

    service = get_token_service()
    success = service.add_bonus_tokens(target_user_id, tokens)

    return {"success": success, "bonus_tokens_added": tokens if success else 0}


# ============================================================================
# 使用历史API（用于日历热力图）
# ============================================================================

class DailyUsageResponse(BaseModel):
    """单日使用数据"""
    date: str  # YYYY-MM-DD
    total_tokens: int
    request_count: int
    input_tokens: int
    output_tokens: int


class UsageHistoryResponse(BaseModel):
    """使用历史响应"""
    data: list[DailyUsageResponse]
    total_tokens: int
    total_requests: int
    start_date: str
    end_date: str


@router.get("/usage/history", response_model=UsageHistoryResponse)
def get_usage_history(
    start_date: Optional[str] = None,  # YYYY-MM-DD
    end_date: Optional[str] = None,    # YYYY-MM-DD
    user=Depends(get_current_user)
):
    """
    获取用户使用历史（用于日历热力图）
    
    - 默认返回最近90天的数据
    - 支持按日期范围筛选
    """
    service = get_token_service()
    history = service.get_usage_history(user["id"], start_date, end_date)
    
    return UsageHistoryResponse(**history)
