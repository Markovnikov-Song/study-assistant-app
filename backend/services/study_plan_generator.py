"""
学习计划生成服务
"""
from __future__ import annotations
import logging
from typing import Optional, List, Dict, Any
from datetime import date, datetime, timedelta
from dataclasses import dataclass, field
from enum import Enum

logger = logging.getLogger(__name__)


class PlanStatus(str, Enum):
    PENDING_CONFIRM = "pending_confirm"  # 待确认
    ACTIVE = "active"                     # 进行中
    PAUSED = "paused"                     # 已暂停
    COMPLETED = "completed"               # 已完成
    ADJUSTED = "adjusted"                 # 已调整


class TaskStatus(str, Enum):
    PENDING = "pending"
    COMPLETED = "completed"
    SKIPPED = "skipped"


@dataclass
class DailyTask:
    """每日学习任务"""
    node_id: str
    title: str
    skill_id: str
    duration_minutes: int
    phase: str  # "基础"/"强化"/"冲刺"
    date: str
    status: TaskStatus = TaskStatus.PENDING
    calendar_event_id: Optional[str] = None


@dataclass
class StudyPlan:
    """学习计划"""
    id: Optional[int] = None
    user_id: int = 0
    subject_id: int = 0
    title: str = ""
    status: PlanStatus = PlanStatus.PENDING_CONFIRM
    
    deadline: Optional[date] = None
    knowledge_navigation_id: Optional[int] = None
    
    # 阶段划分
    stages: List[Dict[str, Any]] = field(default_factory=list)
    
    # 每日任务
    daily_tasks: List[DailyTask] = field(default_factory=list)
    
    created_at: datetime = field(default_factory=datetime.now)
    updated_at: datetime = field(default_factory=datetime.now)
    
    def to_dict(self) -> dict:
        return {
            'id': self.id,
            'user_id': self.user_id,
            'subject_id': self.subject_id,
            'title': self.title,
            'status': self.status.value,
            'deadline': self.deadline.isoformat() if self.deadline else None,
            'stages': self.stages,
            'daily_tasks': [
                {
                    'node_id': t.node_id,
                    'title': t.title,
                    'skill_id': t.skill_id,
                    'duration': t.duration_minutes,
                    'phase': t.phase,
                    'date': t.date,
                    'status': t.status.value,
                }
                for t in self.daily_tasks
            ],
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat(),
        }


class StudyPlanGenerator:
    """学习计划生成器"""
    
    # 知识点到 Skill 的映射
    NODE_SKILL_MAP = {
        'learn': ['mindmap_learning', 'feynman_technique', 'lecture'],
        'practice': ['quiz', 'mistake_review', 'drill'],
        'review': ['mindmap', 'comprehensive_test']
    }
    
    async def generate_plan(
        self,
        user_id: int,
        subject_id: int,
        subject_name: str,
        exam_date: date,
        daily_hours: float = 2.0,
        knowledge_nodes: Optional[List[Dict]] = None
    ) -> StudyPlan:
        """生成学习计划"""
        
        # 计算剩余天数
        days_left = (exam_date - date.today()).days
        if days_left <= 0:
            days_left = 7  # 至少一周
        
        # 生成阶段划分
        stages = self._generate_stages(days_left)
        
        # 生成每日任务
        daily_tasks = self._generate_daily_tasks(
            nodes=knowledge_nodes or [],
            days_left=days_left,
            daily_hours=daily_hours,
            stages=stages
        )
        
        # 创建计划
        plan = StudyPlan(
            user_id=user_id,
            subject_id=subject_id,
            title=f"{subject_name} - 备考计划",
            deadline=exam_date,
            stages=stages,
            daily_tasks=daily_tasks
        )
        
        # 保存到数据库
        plan_id = await self._save_plan(plan)
        plan.id = plan_id
        
        return plan
    
    def _generate_stages(self, days_left: int) -> List[Dict[str, Any]]:
        """生成阶段划分"""
        if days_left <= 7:
            # 短周期：直接冲刺
            return [
                {"name": "冲刺阶段", "week": "第1周", "tasks_count": days_left}
            ]
        
        # 正常周期划分
        basic_end = int(days_left * 0.5)
        intensive_end = int(days_left * 0.8)
        
        stages = [
            {
                "name": "基础阶段",
                "week": f"第1-{basic_end}天",
                "tasks_count": basic_end
            }
        ]
        
        if days_left > 10:
            stages.append({
                "name": "强化阶段",
                "week": f"第{basic_end + 1}-{intensive_end}天",
                "tasks_count": intensive_end - basic_end
            })
        
        stages.append({
            "name": "冲刺阶段",
            "week": f"第{intensive_end + 1}-{days_left}天",
            "tasks_count": days_left - intensive_end
        })
        
        return stages
    
    def _generate_daily_tasks(
        self,
        nodes: List[Dict],
        days_left: int,
        daily_hours: float,
        stages: List[Dict[str, Any]]
    ) -> List[DailyTask]:
        """生成每日任务"""
        tasks = []
        daily_minutes = int(daily_hours * 60)
        
        # 如果没有节点，生成默认任务
        if not nodes:
            for day in range(days_left):
                task_date = date.today() + timedelta(days=day)
                phase = self._get_phase_for_day(day, days_left, stages)
                
                tasks.append(DailyTask(
                    node_id=f"L{day // 3 + 1}_default",
                    title=f"第{day + 1}天学习任务",
                    skill_id=self._get_skill_for_phase(phase),
                    duration_minutes=min(daily_minutes, 45),
                    phase=phase,
                    date=task_date.isoformat()
                ))
            return tasks
        
        # 根据节点生成任务
        current_day = 0
        for node in nodes:
            phase = self._get_phase_for_day(current_day, days_left, stages)
            task_date = date.today() + timedelta(days=current_day)
            
            # 每个节点分配一定时间
            node_hours = node.get('estimated_hours', 1.5)
            duration = min(int(node_hours * 60), 45)  # 最多45分钟
            
            tasks.append(DailyTask(
                node_id=node.get('nodeId', f"L{current_day}"),
                title=node.get('title', '学习任务'),
                skill_id=self._get_skill_for_phase(phase),
                duration_minutes=duration,
                phase=phase,
                date=task_date.isoformat()
            ))
            
            # 根据每日学习时长决定每天安排多少任务
            current_day += 1
            if current_day >= days_left:
                break
        
        return tasks
    
    def _get_phase_for_day(
        self,
        day: int,
        total_days: int,
        stages: List[Dict[str, Any]]
    ) -> str:
        """获取指定日期的阶段"""
        if total_days <= 7:
            return "冲刺"
        
        basic_end = int(total_days * 0.5)
        intensive_end = int(total_days * 0.8)
        
        if day < basic_end:
            return "基础"
        elif day < intensive_end:
            return "强化"
        else:
            return "冲刺"
    
    def _get_skill_for_phase(self, phase: str) -> str:
        """根据阶段推荐 Skill"""
        skill_map = {
            "基础": "mindmap_learning",
            "强化": "quiz",
            "冲刺": "comprehensive_test"
        }
        return skill_map.get(phase, "mindmap_learning")
    
    async def _save_plan(self, plan: StudyPlan) -> int:
        """保存计划到数据库"""
        from database import SessionLocal
        from database import Base
        from sqlalchemy import Column, Integer, String, DateTime, Date, JSON, ForeignKey, Index
        from sqlalchemy.sql import func
        
        # 定义本地模型类（如果表不存在则创建）
        class StudyPlanModel(Base):
            __tablename__ = "study_plans_v2"
            
            id = Column(Integer, primary_key=True, index=True)
            user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
            subject_id = Column(Integer, ForeignKey("subjects.id"), nullable=False)
            
            title = Column(String(256), nullable=False)
            status = Column(String(32), default="pending_confirm")
            
            deadline = Column(Date)
            knowledge_navigation_id = Column(Integer)
            
            stages_json = Column(JSON, default=list)
            daily_tasks_json = Column(JSON, default=list)
            
            created_at = Column(DateTime, server_default=func.now())
            updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
        
        try:
            db = SessionLocal()
            model = StudyPlanModel(
                user_id=plan.user_id,
                subject_id=plan.subject_id,
                title=plan.title,
                status=plan.status.value,
                deadline=plan.deadline,
                knowledge_navigation_id=plan.knowledge_navigation_id,
                stages_json=plan.stages,
                daily_tasks_json=[
                    {
                        'node_id': t.node_id,
                        'title': t.title,
                        'skill_id': t.skill_id,
                        'duration_minutes': t.duration_minutes,
                        'phase': t.phase,
                        'date': t.date,
                        'status': t.status.value,
                    }
                    for t in plan.daily_tasks
                ]
            )
            db.add(model)
            db.commit()
            db.refresh(model)
            return model.id
        except Exception as e:
            logger.error(f"保存学习计划失败: {e}")
            db.rollback()
            return 0
        finally:
            db.close()