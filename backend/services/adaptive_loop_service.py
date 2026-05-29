"""
自适应循环服务 - 根据错题反馈自动调整学习计划
"""
from __future__ import annotations
import logging
from typing import List, Dict, Any, Optional
from datetime import datetime, date, timedelta

logger = logging.getLogger(__name__)


class AdaptiveLoopService:
    """自适应循环服务"""
    
    async def analyze_and_adjust(
        self,
        plan_id: int,
        user_id: int,
        wrong_answers: List[Dict]
    ) -> Dict[str, Any]:
        """
        分析错题并调整计划
        """
        if not wrong_answers:
            return {"adjustments": [], "message": "没有错题，无需调整"}
        
        # 1. 识别薄弱知识点
        weak_nodes = self._identify_weak_nodes(wrong_answers)
        
        # 2. 获取当前计划
        plan = await self._get_plan(plan_id, user_id)
        if not plan:
            return {"error": "计划不存在"}
        
        # 3. 生成调整方案
        adjustments = await self._generate_adjustments(plan, weak_nodes)
        
        # 4. 执行调整
        await self._apply_adjustments(plan_id, adjustments)
        
        # 5. 记录调整历史
        await self._record_adjustment_history(plan_id, wrong_answers, adjustments)
        
        return {
            "adjustments": adjustments,
            "message": f"根据您的练习情况，已为您调整了学习计划，重点加强 {len(weak_nodes)} 个薄弱知识点"
        }
    
    def _identify_weak_nodes(self, wrong_answers: List[Dict]) -> List[str]:
        """识别薄弱知识点"""
        node_counts = {}
        for answer in wrong_answers:
            node_id = answer.get("node_id", "")
            if node_id:
                node_counts[node_id] = node_counts.get(node_id, 0) + 1
        
        # 按错误次数降序排序，返回前5个
        sorted_nodes = sorted(node_counts.items(), key=lambda x: x[1], reverse=True)
        return [n[0] for n in sorted_nodes[:5]]
    
    async def _get_plan(self, plan_id: int, user_id: int) -> Optional[Dict]:
        """获取学习计划"""
        from database import SessionLocal
        from models.study_plan import StudyPlanV2
        
        db = SessionLocal()
        try:
            plan = db.query(StudyPlanV2).filter(
                StudyPlanV2.id == plan_id,
                StudyPlanV2.user_id == user_id
            ).first()
            
            if plan:
                return {
                    "id": plan.id,
                    "daily_tasks": plan.daily_tasks_json or [],
                    "status": plan.status
                }
            return None
        finally:
            db.close()
    
    async def _generate_adjustments(
        self,
        plan: Dict,
        weak_nodes: List[str]
    ) -> List[Dict]:
        """生成调整方案"""
        adjustments = []
        daily_tasks = plan.get("daily_tasks", [])
        
        # 找到需要调整的任务
        for task in daily_tasks:
            node_id = task.get("node_id", "")
            
            if node_id in weak_nodes:
                # 延长该知识点的学习时间
                old_duration = task.get("duration", 30)
                new_duration = int(old_duration * 1.5)  # 增加50%
                
                adjustments.append({
                    "type": "extend_duration",
                    "task_id": node_id,
                    "old_duration": old_duration,
                    "new_duration": new_duration,
                    "reason": "该知识点掌握不牢，延长学习时间"
                })
                
                task["duration"] = new_duration
        
        # 添加复习任务
        today = date.today()
        for i, node_id in enumerate(weak_nodes[:3]):  # 最多添加3个复习任务
            review_date = (today + timedelta(days=3 + i)).isoformat()
            adjustments.append({
                "type": "add_review",
                "node_id": node_id,
                "scheduled_date": review_date,
                "reason": "针对薄弱点安排复习"
            })
        
        return adjustments
    
    async def _apply_adjustments(self, plan_id: int, adjustments: List[Dict]):
        """应用调整到数据库"""
        from database import SessionLocal
        from models.study_plan import StudyPlanV2
        
        db = SessionLocal()
        try:
            plan = db.query(StudyPlanV2).filter(
                StudyPlanV2.id == plan_id
            ).first()
            
            if plan:
                # 更新状态
                plan.status = "adjusted"
                plan.updated_at = datetime.now()
                
                # 添加复习任务到 daily_tasks
                review_tasks = [
                    a for a in adjustments if a["type"] == "add_review"
                ]
                if review_tasks:
                    existing = plan.daily_tasks_json or []
                    for rt in review_tasks:
                        existing.append({
                            "node_id": rt["node_id"],
                            "title": f"复习: {rt['node_id']}",
                            "skill_id": "mistake_review",
                            "duration": 20,
                            "phase": "强化",
                            "date": rt["scheduled_date"],
                            "status": "pending",
                            "is_review": True
                        })
                    plan.daily_tasks_json = existing
                
                db.commit()
        except Exception as e:
            logger.error(f"应用调整失败: {e}")
            db.rollback()
        finally:
            db.close()
    
    async def _record_adjustment_history(
        self,
        plan_id: int,
        wrong_answers: List[Dict],
        adjustments: List[Dict]
    ):
        """记录调整历史"""
        from database import SessionLocal
        from models.plan_adjustment import PlanAdjustment
        
        db = SessionLocal()
        try:
            record = PlanAdjustment(
                plan_id=plan_id,
                adjustment_type="auto",
                reason=f"错题分析: {len(wrong_answers)}题错误",
                old_value=str(len(wrong_answers)),
                new_value=f"调整{len(adjustments)}项",
                triggered_by="auto"
            )
            db.add(record)
            db.commit()
        except Exception as e:
            logger.error(f"记录调整历史失败: {e}")
        finally:
            db.close()