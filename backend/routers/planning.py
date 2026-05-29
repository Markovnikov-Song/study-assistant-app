from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import date, timedelta

router = APIRouter(prefix="/api/planning", tags=["planning"])


class KnowledgeNavigationRequest(BaseModel):
    subject_id: int
    exam_scope: str
    deadline: str  # ISO format date string


class CreatePlanRequest(BaseModel):
    subject_id: int
    subject_name: str
    deadline: str  # ISO date
    daily_hours: float = 2.0
    knowledge_navigation_id: Optional[int] = None
    knowledge_nodes: Optional[List[Dict]] = None


def get_current_user_id() -> int:
    """获取当前用户 ID - 需要根据实际认证实现"""
    from fastapi import Request
    async def _get(request: Request) -> int:
        # TODO: 从 session/token 获取用户 ID
        return 1
    return 1  # 临时实现


@router.post("/knowledge-navigation")
async def generate_knowledge_navigation(request: KnowledgeNavigationRequest):
    """生成知识导航"""
    from services.knowledge_navigator import KnowledgeNavigator
    
    try:
        deadline = date.fromisoformat(request.deadline)
    except ValueError:
        raise HTTPException(status_code=400, detail="无效的日期格式")
    
    navigator = KnowledgeNavigator()
    nav = await navigator.generate_navigation(
        subject_id=request.subject_id,
        exam_scope=request.exam_scope,
        deadline=deadline
    )
    
    return nav.to_dict()


@router.get("/knowledge-navigation/{subject_id}")
async def get_knowledge_navigation(subject_id: int, scope: str = "全书"):
    """获取预设知识导航"""
    from services.knowledge_navigator import KnowledgeNavigator
    
    navigator = KnowledgeNavigator()
    # 使用默认的 30 天后作为截止日期
    nav = await navigator.generate_navigation(
        subject_id=subject_id,
        exam_scope=scope,
        deadline=date.today() + timedelta(days=30)
    )
    
    return nav.to_dict()


@router.post("/plans")
async def create_study_plan(request: CreatePlanRequest, user_id: int = Depends(get_current_user_id)):
    """创建学习计划"""
    from services.study_plan_generator import StudyPlanGenerator
    
    try:
        deadline = date.fromisoformat(request.deadline)
    except ValueError:
        raise HTTPException(status_code=400, detail="无效的日期格式")
    
    generator = StudyPlanGenerator()
    plan = await generator.generate_plan(
        user_id=user_id,
        subject_id=request.subject_id,
        subject_name=request.subject_name,
        exam_date=deadline,
        daily_hours=request.daily_hours,
        knowledge_nodes=request.knowledge_nodes
    )
    
    return {
        "plan_id": plan.id,
        "title": plan.title,
        "stages": plan.stages,
        "daily_tasks_preview": [
            {
                "date": t.date,
                "tasks": [{"title": t.title, "skill": t.skill_id, "duration": t.duration_minutes}]
            }
            for t in plan.daily_tasks[:7]  # 只返回前7天预览
        ]
    }


@router.get("/plans/{plan_id}")
async def get_study_plan(plan_id: int, user_id: int = Depends(get_current_user_id)):
    """获取学习计划详情"""
    from database import SessionLocal
    from models.study_plan import StudyPlanV2
    
    db = SessionLocal()
    try:
        plan = db.query(StudyPlanV2).filter(
            StudyPlanV2.id == plan_id,
            StudyPlanV2.user_id == user_id
        ).first()
        
        if not plan:
            raise HTTPException(status_code=404, detail="计划不存在")
        
        return {
            "id": plan.id,
            "title": plan.title,
            "status": plan.status,
            "deadline": plan.deadline.isoformat() if plan.deadline else None,
            "stages": plan.stages_json,
            "daily_tasks": plan.daily_tasks_json
        }
    finally:
        db.close()
@router.get("/recommend-skill")
async def recommend_skill(
    phase: str,  # learn/practice/review
    node_id: str,
    user_level: str = "intermediate",
    subject: str = None
):
    """推荐合适的 Skill"""
    from services.skill_dispatcher import SkillDispatcher
    
    dispatcher = SkillDispatcher()
    skills = dispatcher.recommend_skills(phase, node_id, user_level, subject)
    
    return {
        "phase": phase,
        "node_id": node_id,
        "recommended_skills": skills,
        "default_skill": skills[0] if skills else None
    }


@router.get("/skill-launch-params/{skill_id}")
async def get_skill_launch_params(skill_id: str, node_id: str):
    """获取启动 Skill 的参数"""
    from services.skill_dispatcher import SkillDispatcher
    
    dispatcher = SkillDispatcher()
    return dispatcher.get_skill_launch_params(skill_id, node_id)