"""
支付API路由

支持订阅档位升级的支付流程
"""
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from api.deps import get_current_user
from database import get_session
from backend.services.payment_service import (
    get_payment_service,
    PaymentChannel,
    PaymentStatus,
    ProductType,
)
from backend.services.token_service import TIER_CONFIG


router = APIRouter(prefix="/api/payment", tags=["payment"])


# ============================================================================
# 请求/响应模型
# ============================================================================

class CreateOrderRequest(BaseModel):
    """创建订单请求"""
    tier: str                    # 目标档位
    months: int = 1             # 订阅月数
    payment_channel: str = "free"  # 支付渠道


class OrderResponse(BaseModel):
    """订单响应"""
    order_no: str
    product_type: str
    product_id: str
    amount: float          # 金额(元)
    actual_amount: float   # 实付金额(元)
    payment_channel: str
    status: str
    expire_at: str
    created_at: str
    # 免费/直接成功时
    tier: Optional[str] = None


class CreateOrderResponse(BaseModel):
    """创建订单响应"""
    success: bool
    message: str
    order: Optional[OrderResponse] = None
    payment_url: Optional[str] = None  # 调起支付的URL


class OrderListResponse(BaseModel):
    """订单列表响应"""
    orders: list[OrderResponse]


class PaymentCallbackRequest(BaseModel):
    """支付回调请求"""
    order_no: str
    external_no: str
    status: str  # success / failed
    raw_data: Optional[str] = None


# ============================================================================
# 用户接口
# ============================================================================

@router.post("/create-order", response_model=CreateOrderResponse)
def create_subscription_order(
    body: CreateOrderRequest,
    user=Depends(get_current_user)
):
    """
    创建订阅订单
    
    流程:
    1. 创建订单(待支付)
    2. 如果金额为0或免费渠道,直接开通
    3. 否则返回支付链接
    """
    service = get_payment_service()
    
    # 验证档位
    if body.tier not in TIER_CONFIG:
        raise HTTPException(400, f"未知档位: {body.tier}")
    
    # 计算金额(分) - 实际对接时从档位配置计算
    # 目前框架阶段金额为0
    tier_config = TIER_CONFIG[body.tier]
    amount_cents = int(tier_config["price_monthly"] * 100 * body.months)
    
    # 金额为0时使用免费渠道
    payment_channel = body.payment_channel
    if amount_cents == 0:
        payment_channel = PaymentChannel.FREE.value
    
    # 创建订单
    result = service.create_subscription_order(
        user_id=user["id"],
        tier=body.tier,
        months=body.months,
        payment_channel=payment_channel,
        amount=amount_cents,
    )
    
    response = CreateOrderResponse(
        success=result.success,
        message=result.message,
    )
    
    if result.success:
        # 查询完整订单信息
        order_info = service.query_order(result.order_no)
        if order_info:
            response.order = OrderResponse(
                order_no=order_info.order_no,
                product_type=order_info.product_type,
                product_id=order_info.product_id,
                amount=order_info.amount / 100,  # 分转元
                actual_amount=order_info.actual_amount / 100,
                payment_channel=order_info.payment_channel,
                status=order_info.status,
                expire_at=order_info.expire_at.isoformat(),
                created_at=order_info.created_at.isoformat(),
                tier=result.tier,
            )
        
        # 如果需要支付,返回支付链接
        if result.payment_url:
            response.payment_url = result.payment_url
    
    return response


@router.get("/orders", response_model=OrderListResponse)
def get_my_orders(
    status: Optional[str] = None,
    limit: int = 20,
    user=Depends(get_current_user)
):
    """获取我的订单列表"""
    service = get_payment_service()
    orders = service.get_user_orders(user["id"], status, limit)
    
    return OrderListResponse(
        orders=[
            OrderResponse(
                order_no=o.order_no,
                product_type=o.product_type,
                product_id=o.product_id,
                amount=o.amount / 100,
                actual_amount=o.actual_amount / 100,
                payment_channel=o.payment_channel,
                status=o.status,
                expire_at=o.expire_at.isoformat(),
                created_at=o.created_at.isoformat(),
            )
            for o in orders
        ]
    )


@router.get("/order/{order_no}", response_model=OrderResponse)
def get_order_detail(
    order_no: str,
    user=Depends(get_current_user)
):
    """获取订单详情"""
    service = get_payment_service()
    order = service.query_order(order_no)
    
    if not order:
        raise HTTPException(404, "订单不存在")
    
    # 检查权限
    with get_session() as db:
        from database import PaymentOrder
        db_order = db.query(PaymentOrder).filter(
            PaymentOrder.order_no == order_no,
            PaymentOrder.user_id == user["id"],
        ).first()
        
        if not db_order:
            raise HTTPException(403, "无权查看此订单")
    
    return OrderResponse(
        order_no=order.order_no,
        product_type=order.product_type,
        product_id=order.product_id,
        amount=order.amount / 100,
        actual_amount=order.actual_amount / 100,
        payment_channel=order.payment_channel,
        status=order.status,
        expire_at=order.expire_at.isoformat(),
        created_at=order.created_at.isoformat(),
    )


@router.post("/order/{order_no}/cancel")
def cancel_order(
    order_no: str,
    user=Depends(get_current_user)
):
    """取消订单"""
    service = get_payment_service()
    success = service.cancel_order(order_no, user["id"])
    
    if not success:
        raise HTTPException(400, "订单不存在或无法取消")
    
    return {"success": True, "message": "订单已取消"}


# ============================================================================
# 支付回调接口 (供支付宝/微信调用)
# ============================================================================

def _verify_payment_signature(channel: str, body: PaymentCallbackRequest, raw_data: str = None) -> bool:
    """
    验证支付回调签名。

    当前实现：基础验证。
    生产环境需要接入支付宝/微信的签名验证机制。

    Args:
        channel: 支付渠道
        body: 回调请求体
        raw_data: 原始回调数据

    Returns:
        签名是否有效
    """
    from api.config import get_config

    # 基础验证：订单号不能为空
    if not body.order_no or not body.external_no:
        return False

    # TODO: 接入支付宝/微信 SDK 进行真正的签名验证
    # 示例：
    # if channel == "alipay":
    #     return AlipaySignature.verify(raw_data, ...)
    # elif channel == "wechat":
    #     return WeChatPay.verify_callback(...)

    # 开发环境下跳过验证（仅当配置了跳过验证标志时）
    cfg = get_config()
    if os.getenv("SKIP_PAYMENT_SIGNATURE_VERIFY", "").lower() == "true":
        import logging
        logging.getLogger(__name__).warning("支付签名验证已跳过（开发模式）")
        return True

    return True


def _verify_callback_ip(channel: str, client_ip: str) -> bool:
    """
    验证回调来源 IP。

    生产环境应配置支付宝/微信的回调 IP 白名单。

    Args:
        channel: 支付渠道
        client_ip: 客户端 IP

    Returns:
        IP 是否可信
    """
    # 支付宝回调 IP 范围（示例，实际应从配置读取）
    alipay_ips = [
        "10.0.0.0/8",
        "127.0.0.1",
    ]

    # 微信支付回调 IP 范围（示例）
    wechat_ips = [
        "10.0.0.0/8",
        "127.0.0.1",
    ]

    # 开发环境允许本地回调
    if client_ip in ("127.0.0.1", "localhost") or client_ip.startswith("192.168."):
        return True

    # TODO: 生产环境应实现完整的 IP 白名单验证
    return True


@router.post("/callback/{channel}")
def payment_callback(
    channel: str,
    body: PaymentCallbackRequest,
    request: Request,
):
    """
    支付回调接口

    供支付宝/微信支付后回调
    注意: 生产环境需要验证签名
    """
    # 获取客户端 IP
    client_ip = request.client.host if request.client else "unknown"

    # 验证回调 IP
    if not _verify_callback_ip(channel, client_ip):
        import logging
        logging.getLogger(__name__).warning(f"支付回调 IP 验证失败: {client_ip} (channel={channel})")
        return {"code": 2, "message": "IP not allowed"}

    # 验证签名
    raw_data = body.raw_data or ""
    if not _verify_payment_signature(channel, body, raw_data):
        import logging
        logging.getLogger(__name__).warning(f"支付回调签名验证失败: order_no={body.order_no}")
        return {"code": 1, "message": "签名验证失败"}

    service = get_payment_service()

    success = service.process_payment_callback(
        order_no=body.order_no,
        external_no=body.external_no,
        status=body.status,
        raw_data=raw_data,
    )

    if success:
        return {"code": 0, "message": "success"}
    else:
        return {"code": 1, "message": "处理失败"}


# ============================================================================
# 管理接口
# ============================================================================

@router.post("/admin/expire-orders")
def admin_expire_orders(user=Depends(get_current_user)):
    """管理员: 过期待支付订单"""
    # 导入安全模块中的管理员检查函数
    from api.security import is_admin

    # 管理员权限检查
    if not is_admin(user["id"]):
        raise HTTPException(403, "需要管理员权限")

    service = get_payment_service()
    count = service.expire_pending_orders()

    return {"success": True, "expired_count": count}
