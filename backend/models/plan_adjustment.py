"""计划调整记录模型"""
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.sql import func
from database import Base


class PlanAdjustment(Base):
    """计划调整历史"""
    __tablename__ = "plan_adjustments"
    
    id = Column(Integer, primary_key=True, index=True)
    plan_id = Column(Integer, ForeignKey("study_plans_v2.id"), nullable=False)
    
    adjustment_type = Column(String(32))  # "auto"/"manual"
    reason = Column(String(256))
    old_value = Column(String(128))
    new_value = Column(String(128))
    triggered_by = Column(String(16))  # "auto" / "user"
    
    created_at = Column(DateTime, server_default=func.now())
    
    def __repr__(self):
        return f"<PlanAdjustment {self.id}: {self.adjustment_type}>"