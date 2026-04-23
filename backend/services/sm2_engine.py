"""
SM-2 改良版引擎：实现带学科差异化衰减的间隔重复算法。

核心改良点：
1. 评分简化为 0-3 分（忘了/模糊/想起/巩固），更符合直觉
2. 学科差异化衰减系数（数学0.85，英语1.15，历史0.95等）
3. 题目难度系数（难题需要更频繁复习）
4. 遗忘惩罚机制（连续错误后降低期望值）
5. 掌握度量化追踪（0-5分）

使用说明：
    card = session.query(ReviewCard).first()
    result = SM2Engine.calculate_next_review(session, card, quality=2)
    session.commit()
"""

from datetime import datetime, timedelta
from typing import Optional, Tuple

from sqlalchemy.orm import Session

from database import ReviewCard, ReviewLog


# ============================================================================
# 常量配置
# ============================================================================

# 学科衰减系数（放大100倍存储）
SUBJECT_DECAY_FACTORS = {
    # 理工科：公式容易忘，需要更频繁复习
    "math": 85,
    "mathematics": 85,
    "physics": 85,
    "chemistry": 90,
    "biology": 90,
    
    # 语言类：语感衰退慢
    "english": 115,
    "chinese": 110,
    "japanese": 110,
    "korean": 110,
    
    # 社会科学：理解性记忆，衰退适中
    "history": 95,
    "politics": 100,
    "geography": 95,
    
    # 默认值
    "default": 100,
}

# 评分转间隔倍数（放大100倍）
QUALITY_MULTIPLIERS = {
    0: 0,      # 完全遗忘 → 立即复习
    1: 50,     # 模糊 → 短间隔
    2: 100,    # 正常 → 标准间隔
    3: 130,    # 巩固 → 延长间隔
}

# 难度系数（放大100倍）
DIFFICULTY_FACTORS = {
    1: 130,    # 简单题目 → 可以稍长
    2: 100,    # 中等难度 → 标准
    3: 70,     # 困难题目 → 缩短间隔
}

# 间隔边界（天）
MIN_INTERVAL = 1
MAX_INTERVAL = 365

# 期望因子边界（放大100倍）
MIN_EASE_FACTOR = 130  # 1.3
MAX_EASE_FACTOR = 350  # 3.5


# ============================================================================
# 核心算法
# ============================================================================

class SM2Engine:
    """SM-2 改良版间隔重复算法引擎"""
    
    @staticmethod
    def get_subject_decay(subject_name: str) -> int:
        """
        获取学科衰减系数。
        
        Args:
            subject_name: 学科名称（不区分大小写）
            
        Returns:
            衰减系数（放大100倍），默认100
        """
        if not subject_name:
            return 100
        
        # 标准化学科名
        normalized = subject_name.lower().strip()
        
        # 精确匹配
        if normalized in SUBJECT_DECAY_FACTORS:
            return SUBJECT_DECAY_FACTORS[normalized]
        
        # 部分匹配（处理类似 "高等数学" -> "math" 的情况）
        for key, value in SUBJECT_DECAY_FACTORS.items():
            if key != "default" and key in normalized:
                return value
        
        return SUBJECT_DECAY_FACTORS["default"]
    
    @staticmethod
    def calculate_next_review(
        session: Session,
        card: ReviewCard,
        quality: int,
        response_time_ms: Optional[int] = None
    ) -> dict:
        """
        计算下次复习时间和更新卡片状态。
        
        Args:
            session: 数据库会话
            card: 复习卡片
            quality: 评分 0-3（忘了/模糊/想起/巩固）
            response_time_ms: 可选，答题耗时（毫秒）
            
        Returns:
            dict: {
                "interval_days": int,       # 新间隔天数
                "next_review_date": datetime,
                "ease_factor": float,       # 新的期望因子
                "streak": int,               # 新的连续正确次数
                "mastery_score": int,        # 新的掌握度
                "message": str               # 反馈消息
            }
        """
        now = datetime.now()
        
        # 边界检查
        quality = max(0, min(3, quality))
        
        # 保存复习前状态
        ease_before = card.ease_factor
        interval_before = card.interval
        
        # 1. 更新期望因子
        if quality == 0:
            # 完全遗忘：大幅降低期望值
            card.ease_factor = max(MIN_EASE_FACTOR, card.ease_factor - 20)
            card.lapse_count += 1
        else:
            # 正确时提高期望因子（奖励优秀表现）
            bonus = 10 if quality == 3 else (5 if quality == 2 else 0)
            card.ease_factor = min(MAX_EASE_FACTOR, card.ease_factor + bonus)
            card.lapse_count = 0
        
        # 2. 计算新间隔
        if card.repetitions == 0:
            # 第一次复习
            new_interval = 1
        elif card.repetitions == 1:
            # 第二次复习
            new_interval = 3
        else:
            # 核心公式：
            # interval_new = interval_old * (ease/100) * (subject_decay/100) * (difficulty/100) * (quality/100)
            ease_mult = card.ease_factor
            decay_mult = card.subject_decay
            diff_mult = DIFFICULTY_FACTORS.get(card.difficulty, 100)
            qual_mult = QUALITY_MULTIPLIERS.get(quality, 100)
            
            new_interval = int(
                card.interval * ease_mult * decay_mult * diff_mult * qual_mult / (100 * 100 * 100 * 100)
            )
        
        # 3. 边界约束
        new_interval = max(MIN_INTERVAL, min(MAX_INTERVAL, new_interval))
        
        # 4. 遗忘惩罚：忘记后间隔重置
        if quality == 0:
            new_interval = 1
            card.repetitions = 0
        else:
            card.repetitions += 1
        
        # 5. 更新卡片状态
        card.interval = new_interval
        card.last_reviewed = now
        card.next_review = now + timedelta(days=new_interval)
        card.total_reviews += 1
        card.mastery_score = SM2Engine._calculate_mastery(card)
        
        # 6. 记录复习日志
        log = ReviewLog(
            card_id=card.id,
            user_id=card.user_id,
            quality=quality,
            response_time_ms=response_time_ms,
            ease_before=ease_before,
            ease_after=card.ease_factor,
            interval_before=interval_before,
            interval_after=card.interval,
            reviewed_at=now,
        )
        session.add(log)
        
        # 7. 生成反馈消息
        message = SM2Engine._generate_feedback_message(quality, new_interval, card)
        
        return {
            "interval_days": new_interval,
            "next_review_date": card.next_review.isoformat(),
            "ease_factor": round(card.ease_factor / 100, 2),
            "streak": card.repetitions,
            "mastery_score": card.mastery_score,
            "message": message,
        }
    
    @staticmethod
    def _calculate_mastery(card: ReviewCard) -> int:
        """
        计算掌握度分数（0-5分）。
        
        考虑因素：
        - 连续正确次数（权重40%）
        - 总复习次数（权重20%）
        - 当前期望因子（权重20%）
        - 遗忘次数惩罚（权重20%）
        """
        # 连续正确次数（最多计5次）
        streak_score = min(5, card.repetitions) * 8  # 0-40
        
        # 总复习次数（最多计20次）
        review_score = min(20, card.total_reviews) * 2  # 0-40
        
        # 期望因子（1.3-3.5 -> 0-100）
        ease_score = int((card.ease_factor - 130) / 22) * 2  # 0-20
        
        # 遗忘惩罚（每遗忘一次扣5分，最多扣20分）
        lapse_penalty = min(20, card.lapse_count * 5)
        
        # 综合评分
        total = streak_score + review_score + ease_score + (20 - lapse_penalty)
        
        # 归一化到 0-5
        return max(0, min(5, int(total / 20)))
    
    @staticmethod
    def _generate_feedback_message(quality: int, interval: int, card: ReviewCard) -> str:
        """生成复习反馈消息"""
        messages = {
            0: f"有点生疏了，明天再来挑战！间隔重置为1天，期望因子已调整为{card.ease_factor/100:.2f}。",
            1: f"有点模糊哦，建议{interval}天后再看一遍加深印象。",
            2: f"掌握得不错！{interval}天后复习效果最佳，继续保持！",
            3: f"太棒了！这段知识已经巩固，{interval}天后简单回顾即可。",
        }
        return messages.get(quality, messages[2])
    
    @staticmethod
    def create_card(
        session: Session,
        user_id: int,
        subject_id: int,
        node_id: str,
        subject_name: str = None,
        node_title: str = None,
        difficulty: int = 2,
    ) -> ReviewCard:
        """
        创建新的复习卡片。
        
        Args:
            session: 数据库会话
            user_id: 用户ID
            subject_id: 学科ID
            node_id: 知识节点ID
            subject_name: 学科名称（用于获取衰减系数）
            node_title: 节点标题（用于展示）
            difficulty: 难度 1-3
            
        Returns:
            ReviewCard: 新创建的卡片
        """
        now = datetime.now()
        
        # 检查是否已存在
        existing = session.query(ReviewCard).filter(
            ReviewCard.user_id == user_id,
            ReviewCard.node_id == node_id
        ).first()
        
        if existing:
            return existing
        
        # 获取学科衰减系数
        subject_decay = 100
        if subject_name:
            subject_decay = SM2Engine.get_subject_decay(subject_name)
        
        card = ReviewCard(
            user_id=user_id,
            subject_id=subject_id,
            node_id=node_id,
            node_title=node_title,
            ease_factor=250,  # 2.5
            interval=0,
            repetitions=0,
            difficulty=difficulty,
            subject_decay=subject_decay,
            total_reviews=0,
            lapse_count=0,
            mastery_score=0,
            last_reviewed=None,
            next_review=now + timedelta(days=1),  # 首次复习在1天后
        )
        
        session.add(card)
        return card


# ============================================================================
# 复习队列管理
# ============================================================================

class ReviewQueue:
    """智能复习队列管理器"""
    
    def __init__(self, session: Session):
        self.session = session
    
    def get_today_review(self, user_id: int, limit: int = 20) -> list[ReviewCard]:
        """
        获取今日复习任务。
        
        优先级策略：
        1. 过期卡片（next_review < today）按过期时长排序
        2. 遗忘次数多的优先
        3. 难题优先
        
        Args:
            user_id: 用户ID
            limit: 最大返回数量
            
        Returns:
            list[ReviewCard]: 排序后的复习卡片列表
        """
        now = datetime.now()
        today_end = now.replace(hour=23, minute=59, second=59)
        
        cards = self.session.query(ReviewCard).filter(
            ReviewCard.user_id == user_id,
            ReviewCard.next_review <= today_end
        ).order_by(
            # 1. 过期越久越优先（next_review 最早的先复习）
            ReviewCard.next_review.asc(),
            # 2. 遗忘次数多的优先
            ReviewCard.lapse_count.desc(),
            # 3. 难度大的优先
            ReviewCard.difficulty.desc(),
        ).limit(limit).all()
        
        return cards
    
    def get_overdue_cards(self, user_id: int) -> Tuple[list[ReviewCard], int]:
        """
        获取已过期卡片及过期天数统计。
        
        Args:
            user_id: 用户ID
            
        Returns:
            Tuple[list, int]: (过期卡片列表, 总过期天数)
        """
        now = datetime.now()
        
        cards = self.session.query(ReviewCard).filter(
            ReviewCard.user_id == user_id,
            ReviewCard.next_review < now.replace(hour=0, minute=0, second=0)
        ).order_by(ReviewCard.next_review.asc()).all()
        
        total_overdue_days = sum(
            (now - card.next_review).days for card in cards
        )
        
        return cards, total_overdue_days
    
    def get_micro_review(self, user_id: int, minutes: int = 5) -> list[ReviewCard]:
        """
        碎片时间微复习：根据剩余时间动态调整任务数量。
        
        Args:
            user_id: 用户ID
            minutes: 可用分钟数
            
        Returns:
            list[ReviewCard]: 适合碎片时间复习的卡片
        """
        # 每张卡片约2分钟
        max_cards = max(1, minutes // 2)
        now = datetime.now()
        
        return self.session.query(ReviewCard).filter(
            ReviewCard.user_id == user_id,
            ReviewCard.next_review <= now
        ).order_by(
            # 最久没看的优先
            ReviewCard.last_reviewed.asc().nullsfirst(),
            # 遗忘次数多的优先
            ReviewCard.lapse_count.desc(),
        ).limit(max_cards).all()
    
    def get_review_stats(self, user_id: int) -> dict:
        """
        获取复习统计数据。
        
        Args:
            user_id: 用户ID
            
        Returns:
            dict: 统计数据
        """
        now = datetime.now()
        today_start = now.replace(hour=0, minute=0, second=0)
        today_end = now.replace(hour=23, minute=59, second=59)
        
        # 基础统计
        total_cards = self.session.query(ReviewCard).filter(
            ReviewCard.user_id == user_id
        ).count()
        
        # 今日待复习
        today_review = self.session.query(ReviewCard).filter(
            ReviewCard.user_id == user_id,
            ReviewCard.next_review <= today_end
        ).count()
        
        # 过期卡片
        overdue_cards, overdue_days = self.get_overdue_cards(user_id)
        
        # 已掌握（连续3次以上正确）
        mastered_cards = self.session.query(ReviewCard).filter(
            ReviewCard.user_id == user_id,
            ReviewCard.repetitions >= 3
        ).count()
        
        # 今日已复习
        today_done = self.session.query(ReviewLog).filter(
            ReviewLog.user_id == user_id,
            ReviewLog.reviewed_at >= today_start,
            ReviewLog.reviewed_at <= today_end
        ).count()
        
        # 预测记忆率（基于最近30天日志）
        thirty_days_ago = now - timedelta(days=30)
        recent_logs = self.session.query(ReviewLog).filter(
            ReviewLog.user_id == user_id,
            ReviewLog.reviewed_at >= thirty_days_ago
        ).all()
        
        if recent_logs:
            recall_rate = sum(1 for log in recent_logs if log.quality >= 2) / len(recent_logs) * 100
        else:
            recall_rate = 0
        
        return {
            "total_cards": total_cards,
            "today_review": today_review,
            "overdue_cards": len(overdue_cards),
            "overdue_days": overdue_days,
            "mastered_cards": mastered_cards,
            "today_done": today_done,
            "recall_rate": round(recall_rate, 1),
        }
    
    def get_subject_mastery(self, user_id: int) -> list[dict]:
        """
        获取各学科的掌握度统计。
        
        Args:
            user_id: 用户ID
            
        Returns:
            list[dict]: 各学科的掌握度数据
        """
        from database import Subject
        
        subjects = self.session.query(Subject).filter(
            Subject.user_id == user_id,
            Subject.is_archived == 0
        ).all()
        
        result = []
        for subject in subjects:
            cards = self.session.query(ReviewCard).filter(
                ReviewCard.user_id == user_id,
                ReviewCard.subject_id == subject.id
            ).all()
            
            if cards:
                avg_mastery = sum(c.mastery_score for c in cards) / len(cards)
                avg_ease = sum(c.ease_factor for c in cards) / len(cards) / 100
                mastered = sum(1 for c in cards if c.repetitions >= 3)
                
                result.append({
                    "subject_id": subject.id,
                    "subject_name": subject.name,
                    "total_cards": len(cards),
                    "mastered_cards": mastered,
                    "avg_mastery": round(avg_mastery, 1),
                    "avg_ease_factor": round(avg_ease, 2),
                })
        
        # 按平均掌握度排序
        result.sort(key=lambda x: x["avg_mastery"])
        return result
