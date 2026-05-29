"""学习计划数据库模型"""
from sqlalchemy import Column, Integer, String, DateTime, Date, JSON, ForeignKey, Index
from sqlalchemy.sql import func
from database import Base


class StudyPlanV2(Base):
    """学习计划V2"""
    __tablename__ = "study_plans_v2"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    subject_id = Column(Integer, ForeignKey("subjects.id"), nullable=False)
    
    title = Column(String(256), nullable=False)
    status = Column(String(32), default="pending_confirm")  # pending_confirm/active/paused/completed/adjusted
    
    deadline = Column(Date)
    knowledge_navigation_id = Column(Integer)
    
    # JSON 字段
    stages_json = Column(JSON, default=list)
    daily_tasks_json = Column(JSON, default=list)
    
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
    
    def __repr__(self):
        return f"<StudyPlanV2 {self.id}: {self.title}>"