"""
支付服务

支持多种支付渠道：
- free: 免费/金额为0时直接成功
- alipay: 支付宝 (预留接口)
- wechat: 微信支付 (预留接口)
"""
import time
import uuid
from datetime import datetime, timedelta
from typing import Optional
from dataclasses import dataclass
from enum import Enum

from database import get_session
from database import PaymentOrder


class PaymentChannel(str, Enum):
    """支付渠道"""
    FREE = "free"      # 免费/金额为0
    ALIPAY = "alipay"  # 支付宝
    WECHAT = "wechat"  # 微信支付


class PaymentStatus(str, Enum):
    """支付状态"""
    PENDING = "pending"    # 待支付
    PAID = "paid"          # 已支付
    CANCELLED = "cancelled"  # 已取消
    REFUNDED = "refunded"    # 已退款
    EXPIRED = "expired"     # 已过期


class ProductType(str, Enum):
    """商品类型"""
    SUBSCRIPTION = "subscription"  # 订阅
    BONUS = "bonus"                # 充值


@dataclass
class OrderInfo:
    """订单信息"""
    order_no: str
    product_type: str
    product_id: str
    amount: int           # 分
    payment_channel: str
    status: str
    expire_at: datetime
    created_at: datetime
    actual_amount: int    # 实付金额(分)


@dataclass
class PaymentResult:
    """支付结果"""
    success: bool
    order_no: str
    message: str
    # 付费模式需要的信息
    payment_url: Optional[str] = None   # 调起支付的URL
    qr_code: Optional[str] = None        # 二维码(用于扫码支付)
    # 免费模式直接返回
    tier: Optional[str] = None           # 订阅模式返回新档位


class PaymentService:
    """支付服务"""
    
    def __init__(self):
        pass
    
    def _generate_order_no(self) -> str:
        """生成订单号"""
        # 格式: PAY{时间戳}{随机6位}
        return f"PAY{int(time.time())}{uuid.uuid4().hex[:6].upper()}"
    
    def create_subscription_order(
        self,
        user_id: int,
        tier: str,
        months: int = 1,
        payment_channel: str = PaymentChannel.FREE.value,
        amount: int = 0,  # 金额(分), 0表示免费
    ) -> PaymentResult:
        """
        创建订阅订单
        
        Args:
            user_id: 用户ID
            tier: 目标档位
            months: 订阅月数
            payment_channel: 支付渠道
            amount: 金额(分)
            
        Returns:
            PaymentResult: 支付结果
        """
        order_no = self._generate_order_no()
        expire_at = datetime.now() + timedelta(minutes=15)
        
        with get_session() as db:
            # 创建订单
            order = PaymentOrder(
                order_no=order_no,
                user_id=user_id,
                product_type=ProductType.SUBSCRIPTION.value,
                product_id=tier,
                amount=amount,
                payment_channel=payment_channel,
                status=PaymentStatus.PENDING.value,
                subscription_months=months,
                expire_at=expire_at,
            )
            db.add(order)
            db.flush()
            
            # 免费/金额为0，直接标记为已支付
            if amount == 0 or payment_channel == PaymentChannel.FREE.value:
                return self._process_free_payment(order)
            
            # 付费模式，返回支付链接
            return self._create_payment_link(order)
    
    def _process_free_payment(self, order: PaymentOrder) -> PaymentResult:
        """处理免费支付"""
        with get_session() as db:
            # 更新订单状态为已支付
            order.status = PaymentStatus.PAID.value
            order.actual_amount = 0
            order.paid_at = datetime.now()
            db.flush()
            
            # 升级用户档位
            from services.token_service import get_token_service
            token_service = get_token_service()
            token_service.upgrade_tier(order.user_id, order.product_id)
            
            return PaymentResult(
                success=True,
                order_no=order.order_no,
                message="开通成功",
                tier=order.product_id,
            )
    
    def _create_payment_link(self, order: PaymentOrder) -> PaymentResult:
        """
        创建支付链接
        
        这里预留支付宝/微信的支付接口
        实际接入时需要调用相应的SDK
        """
        # TODO: 接入真实的支付宝/微信支付
        payment_url = None
        
        if order.payment_channel == PaymentChannel.ALIPAY.value:
            # 支付宝支付
            # payment_url = alipay_sdk.create_payment_url(order)
            payment_url = f"https://api.example.com/alipay?order_no={order.order_no}"
            
        elif order.payment_channel == PaymentChannel.WECHAT.value:
            # 微信支付
            # payment_url = wechat_sdk.create_payment_url(order)
            payment_url = f"https://api.example.com/wechat?order_no={order.order_no}"
        
        return PaymentResult(
            success=True,
            order_no=order.order_no,
            message="订单已创建，请在支付页面完成付款",
            payment_url=payment_url,
        )
    
    def query_order(self, order_no: str) -> Optional[OrderInfo]:
        """查询订单"""
        with get_session() as db:
            order = db.query(PaymentOrder).filter(
                PaymentOrder.order_no == order_no
            ).first()
            
            if not order:
                return None
            
            return OrderInfo(
                order_no=order.order_no,
                product_type=order.product_type,
                product_id=order.product_id,
                amount=order.amount or 0,
                payment_channel=order.payment_channel,
                status=order.status,
                expire_at=order.expire_at,
                created_at=order.created_at,
                actual_amount=order.actual_amount or 0,
            )
    
    def get_user_orders(
        self,
        user_id: int,
        status: Optional[str] = None,
        limit: int = 20,
    ) -> list[OrderInfo]:
        """获取用户的订单列表"""
        with get_session() as db:
            query = db.query(PaymentOrder).filter(
                PaymentOrder.user_id == user_id
            )
            
            if status:
                query = query.filter(PaymentOrder.status == status)
            
            orders = query.order_by(
                PaymentOrder.created_at.desc()
            ).limit(limit).all()
            
            return [
                OrderInfo(
                    order_no=o.order_no,
                    product_type=o.product_type,
                    product_id=o.product_id,
                    amount=o.amount or 0,
                    payment_channel=o.payment_channel,
                    status=o.status,
                    expire_at=o.expire_at,
                    created_at=o.created_at,
                    actual_amount=o.actual_amount or 0,
                )
                for o in orders
            ]
    
    def cancel_order(self, order_no: str, user_id: int) -> bool:
        """取消订单"""
        with get_session() as db:
            order = db.query(PaymentOrder).filter(
                PaymentOrder.order_no == order_no,
                PaymentOrder.user_id == user_id,
                PaymentOrder.status == PaymentStatus.PENDING.value,
            ).first()
            
            if not order:
                return False
            
            order.status = PaymentStatus.CANCELLED.value
            return True
    
    def process_payment_callback(
        self,
        order_no: str,
        external_no: str,
        status: str,
        raw_data: str = None,
    ) -> bool:
        """
        处理支付回调
        
        Args:
            order_no: 订单号
            external_no: 外部支付单号
            status: 支付状态 (success/failed)
            raw_data: 原始回调数据
            
        Returns:
            bool: 处理是否成功
        """
        with get_session() as db:
            order = db.query(PaymentOrder).filter(
                PaymentOrder.order_no == order_no
            ).first()
            
            if not order:
                return False
            
            # 检查订单状态
            if order.status != PaymentStatus.PENDING.value:
                return True  # 已经是终态
            
            # 检查是否过期
            if datetime.now() > order.expire_at:
                order.status = PaymentStatus.EXPIRED.value
                return True
            
            # 更新回调信息
            order.external_no = external_no
            order.callback_time = datetime.now()
            order.callback_raw = raw_data
            
            # 处理支付结果
            if status == "success":
                order.status = PaymentStatus.PAID.value
                order.actual_amount = order.amount
                
                # 如果是订阅订单，升级档位
                if order.product_type == ProductType.SUBSCRIPTION.value:
                    from services.token_service import get_token_service
                    token_service = get_token_service()
                    token_service.upgrade_tier(order.user_id, order.product_id)
                
                return True
            else:
                order.status = PaymentStatus.CANCELLED.value
                return True
    
    def expire_pending_orders(self) -> int:
        """
        将超时的待支付订单标记为过期
        
        Returns:
            int: 过期订单数量
        """
        with get_session() as db:
            result = db.query(PaymentOrder).filter(
                PaymentOrder.status == PaymentStatus.PENDING.value,
                PaymentOrder.expire_at < datetime.now(),
            ).update({
                "status": PaymentStatus.EXPIRED.value
            })
            return result


# 单例
_payment_service: Optional[PaymentService] = None


def get_payment_service() -> PaymentService:
    """获取支付服务单例"""
    global _payment_service
    if _payment_service is None:
        _payment_service = PaymentService()
    return _payment_service
