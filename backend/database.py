"""
数据库模块：SQLAlchemy 懒加载 engine、session 工厂，以及所有表的 ORM 模型定义。
engine 在首次调用 get_engine() 时才创建，模块导入时不建立连接。
"""

from __future__ import annotations

from contextlib import contextmanager
from datetime import datetime
from typing import Generator, Optional

from sqlalchemy import (
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
    create_engine,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase, Session, relationship, sessionmaker

# ---------------------------------------------------------------------------
# ORM 基类
# ---------------------------------------------------------------------------


class Base(DeclarativeBase):
    pass


# ---------------------------------------------------------------------------
# 表模型定义
# ---------------------------------------------------------------------------


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=True)
    username = Column(String(64), unique=True, nullable=False)
    password_hash = Column(String(128), nullable=False)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    avatar = Column(Text, nullable=True)

    subjects = relationship("Subject", back_populates="user", cascade="all, delete-orphan")
    documents = relationship("Document", back_populates="user", cascade="all, delete-orphan")
    conversation_sessions = relationship(
        "ConversationSession", back_populates="user", cascade="all, delete-orphan"
    )
    past_exam_files = relationship(
        "PastExamFile", back_populates="user", cascade="all, delete-orphan"
    )
    notebooks = relationship("Notebook", back_populates="user", cascade="all, delete-orphan")
    memories = relationship("UserMemory", cascade="all, delete-orphan")


class Subject(Base):
    __tablename__ = "subjects"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(128), nullable=False)
    category = Column(String(64))
    description = Column(Text)
    is_pinned = Column(Integer, default=0, nullable=False)   # 1=置顶 0=普通
    is_archived = Column(Integer, default=0, nullable=False) # 1=归档 0=正常
    sort_order = Column(Integer, default=0, nullable=False)  # 手动排序
    created_at = Column(DateTime, default=func.now(), nullable=False)

    user = relationship("User", back_populates="subjects")
    documents = relationship("Document", back_populates="subject", cascade="all, delete-orphan")
    chunks = relationship("Chunk", back_populates="subject", cascade="all, delete-orphan")
    conversation_sessions = relationship(
        "ConversationSession", back_populates="subject", cascade="all, delete-orphan"
    )
    past_exam_files = relationship(
        "PastExamFile", back_populates="subject", cascade="all, delete-orphan"
    )
    past_exam_questions = relationship(
        "PastExamQuestion", back_populates="subject", cascade="all, delete-orphan"
    )


class Document(Base):
    __tablename__ = "documents"

    id = Column(Integer, primary_key=True, autoincrement=True)
    subject_id = Column(Integer, ForeignKey("subjects.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    filename = Column(String(256), nullable=False)
    status = Column(String(16), default="pending", nullable=False)  # pending/processing/completed/failed
    error = Column(Text)
    created_at = Column(DateTime, default=func.now(), nullable=False)

    subject = relationship("Subject", back_populates="documents")
    user = relationship("User", back_populates="documents")
    chunks = relationship("Chunk", back_populates="document", cascade="all, delete-orphan")


class Chunk(Base):
    __tablename__ = "chunks"

    id = Column(Integer, primary_key=True, autoincrement=True)
    document_id = Column(Integer, ForeignKey("documents.id", ondelete="CASCADE"), nullable=False)
    subject_id = Column(Integer, ForeignKey("subjects.id", ondelete="CASCADE"), nullable=False)
    chunk_index = Column(Integer, nullable=False)
    content = Column(Text, nullable=False)
    created_at = Column(DateTime, default=func.now(), nullable=False)

    document = relationship("Document", back_populates="chunks")
    subject = relationship("Subject", back_populates="chunks")


class ConversationSession(Base):
    __tablename__ = "conversation_sessions"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    subject_id = Column(Integer, ForeignKey("subjects.id", ondelete="SET NULL"), nullable=True)
    title = Column(String(256))
    session_type = Column(String(32), default="qa")  # qa/solve/mindmap/exam
    is_pinned = Column(Integer, default=0, nullable=False)   # 1=置顶 0=普通（mindmap 用）
    sort_order = Column(Integer, default=0, nullable=False)  # 手动排序（mindmap 用）
    created_at = Column(DateTime, default=func.now(), nullable=False)

    user = relationship("User", back_populates="conversation_sessions")
    subject = relationship("Subject", back_populates="conversation_sessions")
    history = relationship(
        "ConversationHistory", back_populates="session", cascade="all, delete-orphan"
    )


class ConversationHistory(Base):
    __tablename__ = "conversation_history"

    id = Column(Integer, primary_key=True, autoincrement=True)
    session_id = Column(
        Integer, ForeignKey("conversation_sessions.id", ondelete="CASCADE"), nullable=False
    )
    role = Column(String(16), nullable=False)  # user/assistant
    content = Column(Text, nullable=False)
    sources = Column(JSONB)  # 引用来源列表
    scope_choice = Column(String(16))  # strict/broad
    created_at = Column(DateTime, default=func.now(), nullable=False)

    session = relationship("ConversationSession", back_populates="history")


class PastExamFile(Base):
    __tablename__ = "past_exam_files"

    id = Column(Integer, primary_key=True, autoincrement=True)
    subject_id = Column(Integer, ForeignKey("subjects.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    filename = Column(String(256), nullable=False)
    status = Column(String(16), default="pending", nullable=False)  # pending/processing/completed/failed
    error = Column(Text)
    created_at = Column(DateTime, default=func.now(), nullable=False)

    subject = relationship("Subject", back_populates="past_exam_files")
    user = relationship("User", back_populates="past_exam_files")
    questions = relationship(
        "PastExamQuestion", back_populates="exam_file", cascade="all, delete-orphan"
    )


class PastExamQuestion(Base):
    __tablename__ = "past_exam_questions"

    id = Column(Integer, primary_key=True, autoincrement=True)
    exam_file_id = Column(
        Integer, ForeignKey("past_exam_files.id", ondelete="CASCADE"), nullable=False
    )
    subject_id = Column(Integer, ForeignKey("subjects.id", ondelete="CASCADE"), nullable=False)
    question_number = Column(String(16))
    content = Column(Text, nullable=False)
    answer = Column(Text)
    created_at = Column(DateTime, default=func.now(), nullable=False)

    exam_file = relationship("PastExamFile", back_populates="questions")
    subject = relationship("Subject", back_populates="past_exam_questions")


class Notebook(Base):
    __tablename__ = "notebooks"
    __table_args__ = (
        Index("idx_notebooks_user_id", "user_id"),
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(64), nullable=False)
    is_system = Column(Integer, default=0, nullable=False)    # 1=系统预设本 0=用户自定义本
    is_pinned = Column(Integer, default=0, nullable=False)    # 1=置顶 0=普通
    is_archived = Column(Integer, default=0, nullable=False)  # 1=归档 0=正常
    sort_order = Column(Integer, default=0, nullable=False)
    created_at = Column(DateTime(timezone=True), default=func.now(), nullable=False)

    user = relationship("User", back_populates="notebooks")
    notes = relationship("Note", back_populates="notebook", cascade="all, delete-orphan")


class Note(Base):
    __tablename__ = "notes"
    __table_args__ = (
        Index("idx_notes_notebook_subject", "notebook_id", "subject_id"),
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    notebook_id = Column(Integer, ForeignKey("notebooks.id", ondelete="CASCADE"), nullable=False)
    subject_id = Column(
        Integer, ForeignKey("subjects.id", ondelete="SET NULL"), nullable=True
    )
    source_session_id = Column(
        Integer, ForeignKey("conversation_sessions.id", ondelete="SET NULL"), nullable=True
    )
    source_message_id = Column(Integer, nullable=True)
    role = Column(String(16), nullable=False)          # user/assistant
    original_content = Column(Text, nullable=False)
    title = Column(String(64), nullable=True)
    outline = Column(JSONB, nullable=True)
    imported_to_doc_id = Column(
        Integer, ForeignKey("documents.id", ondelete="SET NULL"), nullable=True
    )
    sources = Column(JSONB, nullable=True)
    note_type = Column(String(16), nullable=False, default="general")   # general | mistake
    mistake_status = Column(String(16), nullable=True)                  # pending | reviewed
    # 错题扩展字段
    node_id = Column(String(512), nullable=True)
    question_text = Column(Text, nullable=True)
    user_answer = Column(Text, nullable=True)
    correct_answer = Column(Text, nullable=True)
    mistake_category = Column(String(32), nullable=True)
    review_card_id = Column(Integer, ForeignKey("review_cards.id", ondelete="SET NULL"), nullable=True)
    mastery_score = Column(Integer, default=0, nullable=False)
    review_count = Column(Integer, default=0, nullable=False)
    last_reviewed_at = Column(DateTime(timezone=True), nullable=True)
    mastery_history = Column(JSONB, nullable=True)
    created_at = Column(DateTime(timezone=True), default=func.now(), nullable=False)
    updated_at = Column(
        DateTime(timezone=True), default=func.now(), onupdate=func.now(), nullable=False
    )

    notebook = relationship("Notebook", back_populates="notes")
    subject = relationship("Subject")
    source_session = relationship("ConversationSession")
    imported_doc = relationship("Document")
    review_card = relationship("ReviewCard", foreign_keys=[review_card_id])


class UserMemory(Base):
    """
    用户记忆/画像：存储 LLM 从对话中提取的用户学习特征。
    每个用户每个学科一条记录，持续更新。
    """
    __tablename__ = "user_memory"
    __table_args__ = (
        Index("idx_user_memory_user_subject", "user_id", "subject_id", unique=True),
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    subject_id = Column(Integer, ForeignKey("subjects.id", ondelete="CASCADE"), nullable=True)
    # 结构化记忆，JSONB 存储，例如：
    # {
    #   "weak_points": ["弯曲应力", "截面惯性矩"],
    #   "frequent_topics": ["材料力学", "梁的变形"],
    #   "learning_style": "喜欢步骤详细的解释",
    #   "misconceptions": ["混淆正应力和切应力"],
    #   "summary": "用户对弯曲变形掌握较弱，偏好结构化解答"
    # }
    memory = Column(JSONB, nullable=False, default=dict)
    updated_at = Column(DateTime(timezone=True), default=func.now(), onupdate=func.now(), nullable=False)

    user = relationship("User", overlaps="memories")


class MindmapNodeState(Base):
    """节点点亮状态：记录用户在某大纲中每个节点的学习状态。"""
    __tablename__ = "mindmap_node_states"
    __table_args__ = (
        UniqueConstraint("user_id", "session_id", "node_id", name="uq_node_state"),
        Index("idx_node_states_user_session", "user_id", "session_id"),
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    session_id = Column(Integer, ForeignKey("conversation_sessions.id", ondelete="CASCADE"), nullable=False)
    node_id = Column(String(512), nullable=False)
    is_lit = Column(SmallInteger, nullable=False, default=1)  # 1=已点亮
    updated_at = Column(DateTime(timezone=True), default=func.now(), onupdate=func.now(), nullable=False)

    user = relationship("User")
    session = relationship("ConversationSession")


class NodeLecture(Base):
    """节点讲义：存储 AI 为某节点生成的富文本讲义内容（JSONB）。"""
    __tablename__ = "node_lectures"
    __table_args__ = (
        UniqueConstraint("user_id", "session_id", "node_id", name="uq_node_lecture"),
        Index("idx_node_lectures_user_session", "user_id", "session_id"),
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    session_id = Column(Integer, ForeignKey("conversation_sessions.id", ondelete="CASCADE"), nullable=False)
    node_id = Column(String(512), nullable=False)
    content = Column(JSONB, nullable=False)
    resource_scope = Column(JSONB, nullable=True)
    created_at = Column(DateTime(timezone=True), default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), default=func.now(), onupdate=func.now(), nullable=False)

    user = relationship("User")
    session = relationship("ConversationSession")


class HintSuggestion(Base):
    """LLM 生成的提示词建议缓存，按 (user_id, subject_id, hint_type) 唯一。"""
    __tablename__ = "hint_suggestions"
    __table_args__ = (
        Index("idx_hint_suggestions_user_subject", "user_id", "subject_id"),
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    subject_id = Column(Integer, ForeignKey("subjects.id", ondelete="CASCADE"), nullable=False)
    hint_type = Column(String(16), nullable=False)   # "qa" | "solve"
    hints = Column(JSONB, nullable=False)             # List[str]，3 条
    updated_at = Column(DateTime(timezone=True), default=func.now(), onupdate=func.now(), nullable=False)


class ReviewCard(Base):
    """SM-2 复习卡片：记录每个知识节点的间隔重复状态。"""
    __tablename__ = "review_cards"
    __table_args__ = (
        UniqueConstraint("user_id", "node_id", name="uq_review_card_user_node"),
        Index("idx_review_cards_user_next", "user_id", "next_review"),
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    subject_id = Column(Integer, ForeignKey("subjects.id", ondelete="CASCADE"), nullable=False)
    node_id = Column(String(512), nullable=False)
    node_title = Column(String(256), nullable=True)
    ease_factor = Column(Integer, default=250, nullable=False)   # 放大100倍，默认2.5
    interval = Column(Integer, default=0, nullable=False)        # 间隔天数
    repetitions = Column(Integer, default=0, nullable=False)     # 连续正确次数
    difficulty = Column(Integer, default=2, nullable=False)      # 1=简单 2=中等 3=困难
    subject_decay = Column(Integer, default=100, nullable=False) # 学科衰减系数，放大100倍
    total_reviews = Column(Integer, default=0, nullable=False)
    lapse_count = Column(Integer, default=0, nullable=False)     # 遗忘次数
    mastery_score = Column(Integer, default=0, nullable=False)   # 掌握度 0-5
    last_reviewed = Column(DateTime(timezone=True), nullable=True)
    next_review = Column(DateTime(timezone=True), nullable=False)
    created_at = Column(DateTime(timezone=True), default=func.now(), nullable=False)

    user = relationship("User")
    subject = relationship("Subject")
    source_note = relationship(
        "Note",
        primaryjoin="ReviewCard.id == foreign(Note.review_card_id)",
        uselist=False,
        overlaps="review_card",
    )
    logs = relationship("ReviewLog", back_populates="card", cascade="all, delete-orphan")


class ReviewLog(Base):
    """SM-2 复习日志：记录每次复习的详细数据。"""
    __tablename__ = "review_logs"
    __table_args__ = (
        Index("idx_review_logs_user_date", "user_id", "reviewed_at"),
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    card_id = Column(Integer, ForeignKey("review_cards.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    quality = Column(Integer, nullable=False)            # 0-3
    response_time_ms = Column(Integer, nullable=True)
    ease_before = Column(Integer, nullable=False)
    ease_after = Column(Integer, nullable=False)
    interval_before = Column(Integer, nullable=False)
    interval_after = Column(Integer, nullable=False)
    reviewed_at = Column(DateTime(timezone=True), nullable=False)

    card = relationship("ReviewCard", back_populates="logs")
    user = relationship("User")


class StudyPlan(Base):
    """学习规划：存储 Multi-Agent 生成的系统化学习计划。"""
    __tablename__ = "study_plans"
    __table_args__ = (
        Index("idx_study_plans_user_status", "user_id", "status"),
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(128), nullable=False, default="我的学习计划")
    target_subjects = Column(JSONB, nullable=False, default=list)  # [{id, name}]
    deadline = Column(DateTime(timezone=True), nullable=False)
    daily_minutes = Column(Integer, nullable=False, default=60)
    status = Column(String(16), nullable=False, default="draft")  # draft/active/completed/abandoned
    created_at = Column(DateTime(timezone=True), default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), default=func.now(), onupdate=func.now(), nullable=False)

    user = relationship("User")
    items = relationship("PlanItem", back_populates="plan", cascade="all, delete-orphan")


class PlanItem(Base):
    """计划条目：规划中的单个学习任务。"""
    __tablename__ = "plan_items"
    __table_args__ = (
        Index("idx_plan_items_plan_date", "plan_id", "planned_date"),
        Index("idx_plan_items_subject_status", "plan_id", "subject_id", "status"),
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    plan_id = Column(Integer, ForeignKey("study_plans.id", ondelete="CASCADE"), nullable=False)
    subject_id = Column(Integer, ForeignKey("subjects.id", ondelete="SET NULL"), nullable=True)
    node_id = Column(String(512), nullable=False)
    node_text = Column(String(256), nullable=True)
    estimated_minutes = Column(Integer, nullable=False, default=20)
    priority = Column(String(8), nullable=False, default="medium")  # high/medium/low
    dependency_node_ids = Column(JSONB, nullable=True, default=list)
    planned_date = Column(DateTime(timezone=True), nullable=True)
    status = Column(String(16), nullable=False, default="pending")  # pending/done/skipped
    completed_at = Column(DateTime(timezone=True), nullable=True)

    plan = relationship("StudyPlan", back_populates="items")
    subject = relationship("Subject")


class FeedbackSignal(Base):
    """Agent Council 反馈信号：记录学习过程中的快/中/慢反馈。"""
    __tablename__ = "feedback_signals"
    __table_args__ = (
        Index("idx_feedback_signals_user", "user_id", "created_at"),
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    subject_id = Column(Integer, ForeignKey("subjects.id", ondelete="SET NULL"), nullable=True)
    level = Column(String(16), nullable=False)          # fast | medium | slow
    signal_type = Column(String(64), nullable=False)
    description = Column(Text, nullable=False)
    suggestion = Column(Text, nullable=True)
    trigger_context = Column(JSONB, nullable=True)
    is_acknowledged = Column(Integer, default=0, nullable=False)
    is_actioned = Column(Integer, default=0, nullable=False)
    acknowledged_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=func.now(), nullable=False)

    user = relationship("User")
    subject = relationship("Subject")


class UserTokenQuota(Base):
    """用户 Token 配额：记录每个用户的档位和用量。"""
    __tablename__ = "user_token_quotas"
    __table_args__ = (
        Index("idx_user_token_quotas_user", "user_id", unique=True),
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    tier = Column(String(32), nullable=False, default="free")
    quota_daily = Column(Integer, nullable=False, default=50_000)
    quota_monthly = Column(Integer, nullable=False, default=0)
    used_today = Column(Integer, nullable=False, default=0)
    used_this_month = Column(Integer, nullable=False, default=0)
    bonus_tokens = Column(Integer, nullable=False, default=0)
    bonus_used = Column(Integer, nullable=False, default=0)
    total_tokens_all_time = Column(Integer, nullable=False, default=0)
    total_cost_all_time = Column(Integer, nullable=False, default=0)  # 放大1000000倍
    rate_limit_per_min = Column(Integer, nullable=False, default=10)
    rate_limit_per_hour = Column(Integer, nullable=False, default=100)
    payg_enabled = Column(Integer, nullable=False, default=1)
    is_blocked = Column(Integer, nullable=False, default=0)
    last_reset_date = Column(DateTime(timezone=True), default=func.now(), nullable=False)
    created_at = Column(DateTime(timezone=True), default=func.now(), nullable=False)

    user = relationship("User")


class TokenUsageLog(Base):
    """Token 使用日志：记录每次 LLM 调用的 token 消耗。"""
    __tablename__ = "token_usage_logs"
    __table_args__ = (
        Index("idx_token_usage_logs_user_date", "user_id", "created_at"),
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    session_id = Column(Integer, ForeignKey("conversation_sessions.id", ondelete="SET NULL"), nullable=True)
    model_name = Column(String(128), nullable=False, default="default")
    input_tokens = Column(Integer, nullable=False, default=0)
    output_tokens = Column(Integer, nullable=False, default=0)
    total_tokens = Column(Integer, nullable=False, default=0)
    api_cost = Column(Integer, nullable=False, default=0)  # 放大1000000倍
    endpoint = Column(String(64), nullable=False, default="chat")
    request_id = Column(String(64), nullable=True)
    created_at = Column(DateTime(timezone=True), default=func.now(), nullable=False)

    user = relationship("User")


class MindmapKnowledgeLink(Base):
    """知识关联图：存储 LLM 从思维导图中提取的跨节点关联关系。"""
    __tablename__ = "mindmap_knowledge_links"
    __table_args__ = (
        Index("idx_knowledge_links_user_session", "user_id", "session_id"),
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    session_id = Column(Integer, ForeignKey("conversation_sessions.id", ondelete="CASCADE"), nullable=False)
    source_node_id = Column(String(512), nullable=False)
    target_node_id = Column(String(512), nullable=False)
    source_node_text = Column(String(512), nullable=False)
    target_node_text = Column(String(512), nullable=False)
    link_type = Column(String(16), nullable=False)  # causal / dependency / contrast / evolution
    rationale = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), default=func.now(), nullable=False)

    user = relationship("User")
    session = relationship("ConversationSession")


class TierDefinition(Base):
    """档位定义表：存储各档位的配置（与 TIER_CONFIG 同步）。"""
    __tablename__ = "tier_definitions"

    id = Column(Integer, primary_key=True, autoincrement=True)
    tier = Column(String(32), unique=True, nullable=False)
    name = Column(String(64), nullable=False)
    price_monthly = Column(Integer, nullable=False, default=0)  # 放大100倍
    daily_quota = Column(Integer, nullable=False, default=50_000)
    monthly_quota = Column(Integer, nullable=False, default=0)
    rate_limit_per_min = Column(Integer, nullable=False, default=10)
    rate_limit_per_hour = Column(Integer, nullable=False, default=100)
    payg_enabled = Column(Integer, nullable=False, default=1)
    created_at = Column(DateTime(timezone=True), default=func.now(), nullable=False)


class PaymentOrder(Base):
    """支付订单：记录用户的充值/订阅订单。"""
    __tablename__ = "payment_orders"
    __table_args__ = (
        Index("idx_payment_orders_user_id", "user_id"),
        Index("idx_payment_orders_order_no", "order_no", unique=True),
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    order_no = Column(String(64), unique=True, nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    product_type = Column(String(32), nullable=False)       # subscription | bonus
    product_id = Column(String(32), nullable=False)         # 档位名或充值包 ID
    amount = Column(Integer, nullable=False, default=0)     # 应付金额（分）
    actual_amount = Column(Integer, nullable=True)          # 实付金额（分）
    payment_channel = Column(String(16), nullable=False, default="free")  # free | alipay | wechat
    status = Column(String(16), nullable=False, default="pending")        # pending | paid | cancelled | refunded | expired
    expire_at = Column(DateTime(timezone=True), nullable=True)
    paid_at = Column(DateTime(timezone=True), nullable=True)
    external_no = Column(String(128), nullable=True)        # 第三方支付单号
    callback_time = Column(DateTime(timezone=True), nullable=True)
    callback_raw = Column(Text, nullable=True)              # 回调原始数据
    created_at = Column(DateTime(timezone=True), default=func.now(), nullable=False)

    user = relationship("User")


# ---------------------------------------------------------------------------
# 懒加载 Engine 与 Session 工厂
# ---------------------------------------------------------------------------

_engine = None
_SessionFactory = None


def get_engine():
    """
    返回 SQLAlchemy engine（懒加载：首次调用时才创建）。
    使用 pool_pre_ping=True 保证连接健康，pool_size=5，max_overflow=10。
    """
    global _engine
    if _engine is None:
        from backend_config import get_config

        cfg = get_config()
        _engine = create_engine(
            cfg.DATABASE_URL,
            pool_pre_ping=True,
            pool_size=5,
            max_overflow=10,
        )
    return _engine


def get_session_factory():
    """返回 sessionmaker 工厂（懒加载）。"""
    global _SessionFactory
    if _SessionFactory is None:
        _SessionFactory = sessionmaker(bind=get_engine(), autocommit=False, autoflush=False)
    return _SessionFactory


@contextmanager
def get_session() -> Generator[Session, None, None]:
    """
    上下文管理器：提供数据库 session，自动 commit/rollback/close。

    用法::

        with get_session() as session:
            session.add(obj)
    """
    factory = get_session_factory()
    session: Session = factory()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


def init_db() -> None:
    """
    创建所有表（CREATE TABLE IF NOT EXISTS）。
    应在应用启动时调用一次。
    遇到残留复合类型冲突时自动清理后重试。
    """
    import logging
    _log = logging.getLogger(__name__)
    try:
        Base.metadata.create_all(bind=get_engine(), checkfirst=True)
    except Exception as exc:
        if "pg_type_typname_nsp_index" in str(exc) or "UniqueViolation" in str(exc):
            # PostgreSQL 残留复合类型冲突：尝试逐表创建
            _log.warning("init_db 遇到残留类型冲突，逐表创建: %s", exc)
            engine = get_engine()
            for table in Base.metadata.sorted_tables:
                try:
                    table.create(bind=engine, checkfirst=True)
                except Exception as e2:
                    _log.warning("跳过表 %s: %s", table.name, e2)
        else:
            raise


def reset_engine() -> None:
    """重置缓存的 engine 和 session 工厂（主要用于测试）。"""
    global _engine, _SessionFactory
    if _engine is not None:
        _engine.dispose()
        _engine = None
    _SessionFactory = None
