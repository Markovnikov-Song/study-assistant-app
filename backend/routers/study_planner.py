"""
study_planner.py — 大型学习规划路由
挂载在 /api/study-planner

端点：
  POST   /plans                          — 创建计划，触发 Multi-Agent 规划
  GET    /plans/active                   — 获取当前 active 计划
  GET    /plans/today                    — 今日 plan_items
  PATCH  /plans/{plan_id}/items/{item_id} — 更新 plan_item 状态
  PATCH  /plans/{plan_id}/status         — 更新计划状态（abandoned）
  GET    /plans/{plan_id}/summary        — 计划摘要
  GET    /plans/{plan_id}/progress       — 规划进度（轮询）
  POST   /notify/register                — Level 3 占位
  POST   /notify/send                    — Level 3 占位
  POST   /replan                         — 增量重规划（日历改动后调整剩余排课）
"""
from __future__ import annotations

import logging
from datetime import date, datetime, timezone
from typing import Any, List, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from pydantic import BaseModel

from database import PlanItem, StudyPlan, Subject, get_session as db_session
from deps import get_current_user

router = APIRouter()
logger = logging.getLogger(__name__)

# 内存中记录规划进度（plan_id → progress dict）
_plan_progress: dict[int, dict] = {}


# ── Pydantic 模型 ──────────────────────────────────────────────────────────────

class TargetSubjectIn(BaseModel):
    id: int
    name: str


class CreatePlanIn(BaseModel):
    subject_ids: List[int]
    deadline: str          # ISO date string, e.g. "2025-06-30"
    daily_minutes: int = 60
    name: str = "我的学习计划"


class PlanItemOut(BaseModel):
    id: int
    plan_id: int
    subject_id: Optional[int]
    subject_name: Optional[str]
    node_id: str
    node_text: Optional[str]
    estimated_minutes: int
    priority: str
    dependency_node_ids: List[str]
    planned_date: Optional[str]
    status: str
    completed_at: Optional[str]


class StudyPlanOut(BaseModel):
    id: int
    name: str
    target_subjects: List[Any]
    deadline: str
    daily_minutes: int
    status: str
    items: List[PlanItemOut]
    created_at: str


class ItemStatusIn(BaseModel):
    status: str   # done | skipped


class PlanStatusIn(BaseModel):
    status: str   # abandoned


class PlanSummaryOut(BaseModel):
    plan_id: int
    total_items: int
    completed_items: int
    days_remaining: int
    today_completion_rate: float
    today_items: List[PlanItemOut]


# ── 内部工具 ───────────────────────────────────────────────────────────────────

def _item_to_out(item: PlanItem) -> PlanItemOut:
    subject_name = None
    if item.subject:
        subject_name = item.subject.name
    return PlanItemOut(
        id=item.id,
        plan_id=item.plan_id,
        subject_id=item.subject_id,
        subject_name=subject_name,
        node_id=item.node_id,
        node_text=item.node_text,
        estimated_minutes=item.estimated_minutes,
        priority=item.priority,
        dependency_node_ids=item.dependency_node_ids or [],
        planned_date=item.planned_date.date().isoformat() if item.planned_date else None,
        status=item.status,
        completed_at=item.completed_at.isoformat() if item.completed_at else None,
    )


def _plan_to_out(plan: StudyPlan) -> StudyPlanOut:
    return StudyPlanOut(
        id=plan.id,
        name=plan.name,
        target_subjects=plan.target_subjects or [],
        deadline=plan.deadline.date().isoformat() if plan.deadline else '',
        daily_minutes=plan.daily_minutes,
        status=plan.status,
        items=sorted(
            [_item_to_out(i) for i in plan.items],
            key=lambda x: (x.planned_date or '', x.priority),
        ),
        created_at=plan.created_at.isoformat(),
    )


def _assert_plan_owner(db, plan_id: int, user_id: int) -> StudyPlan:
    plan = db.query(StudyPlan).filter_by(id=plan_id, user_id=user_id).first()
    if not plan:
        raise HTTPException(404, "计划不存在")
    return plan


# ── 后台规划任务 ───────────────────────────────────────────────────────────────

def _run_generation(plan_id: int, user_id: int, subject_ids: list[int],
                    deadline: datetime, daily_minutes: int) -> None:
    """后台线程：执行 Multi-Agent 规划，更新 _plan_progress。"""
    from services.study_planner_service import StudyPlannerService

    _plan_progress[plan_id] = {'status': 'running', 'progress': 0.1}
    try:
        with db_session() as db:
            svc = StudyPlannerService()
            ok = svc.generate_plan(
                plan_id=plan_id,
                user_id=user_id,
                subject_ids=subject_ids,
                deadline=deadline,
                daily_minutes=daily_minutes,
                db=db,
            )
            _plan_progress[plan_id] = {
                'status': 'done' if ok else 'failed',
                'progress': 1.0,
            }
    except Exception as e:
        logger.exception("规划生成失败 plan_id=%s: %s", plan_id, e)
        _plan_progress[plan_id] = {'status': 'failed', 'progress': 0, 'error': str(e)}
        # 回滚计划状态
        try:
            with db_session() as db:
                plan = db.query(StudyPlan).filter_by(id=plan_id).first()
                if plan:
                    plan.status = 'draft'
        except Exception:
            pass


# ── 端点 ───────────────────────────────────────────────────────────────────────

@router.post("/plans", status_code=201)
def create_plan(
    body: CreatePlanIn,
    background_tasks: BackgroundTasks,
    user=Depends(get_current_user),
):
    """
    创建学习计划，触发 Multi-Agent 规划。
    - 若用户已有 active 计划，返回 409
    - 规划在后台异步执行，立即返回 plan_id
    - 前端可轮询 GET /plans/{plan_id}/progress 查询进度
    """
    user_id = int(user["id"])

    with db_session() as db:
        # 检查是否已有 active 计划
        existing = db.query(StudyPlan).filter_by(user_id=user_id, status='active').first()
        if existing:
            raise HTTPException(409, "已有进行中的学习计划，请先完成或放弃当前计划")

        # 获取学科信息
        subjects = db.query(Subject).filter(Subject.id.in_(body.subject_ids)).all()
        target_subjects = [{'id': s.id, 'name': s.name} for s in subjects]

        # 解析截止时间
        try:
            deadline_date = date.fromisoformat(body.deadline)
            deadline_dt = datetime(
                deadline_date.year, deadline_date.month, deadline_date.day,
                23, 59, 59, tzinfo=timezone.utc
            )
        except ValueError:
            raise HTTPException(400, "deadline 格式错误，请使用 YYYY-MM-DD")

        # 创建 draft 计划
        plan = StudyPlan(
            user_id=user_id,
            name=body.name,
            target_subjects=target_subjects,
            deadline=deadline_dt,
            daily_minutes=body.daily_minutes,
            status='draft',
        )
        db.add(plan)
        db.flush()
        plan_id = plan.id

    # 后台异步规划
    background_tasks.add_task(
        _run_generation,
        plan_id=plan_id,
        user_id=user_id,
        subject_ids=body.subject_ids,
        deadline=deadline_dt,
        daily_minutes=body.daily_minutes,
    )

    return {"plan_id": plan_id, "status": "generating"}


@router.get("/plans/active", response_model=StudyPlanOut)
def get_active_plan(user=Depends(get_current_user)):
    """获取当前 active 计划及所有 plan_items（按计划日期排序）。"""
    user_id = int(user["id"])
    with db_session() as db:
        plan = (
            db.query(StudyPlan)
            .filter(StudyPlan.user_id == user_id, StudyPlan.status.in_(['active', 'draft']))
            .order_by(StudyPlan.created_at.desc())
            .first()
        )
        if not plan:
            raise HTTPException(404, "暂无进行中的学习计划")
        return _plan_to_out(plan)


@router.get("/plans/today")
def get_today_items(user=Depends(get_current_user)):
    """获取今日 plan_items（pending 状态，按优先级排序）。"""
    user_id = int(user["id"])
    today = date.today()

    with db_session() as db:
        plan = (
            db.query(StudyPlan)
            .filter_by(user_id=user_id, status='active')
            .first()
        )
        if not plan:
            return {"items": [], "plan_id": None}

        items = (
            db.query(PlanItem)
            .filter(
                PlanItem.plan_id == plan.id,
                PlanItem.planned_date >= datetime(today.year, today.month, today.day, tzinfo=timezone.utc),
                PlanItem.planned_date < datetime(today.year, today.month, today.day, tzinfo=timezone.utc) + timedelta(days=1),
            )
            .all()
        )

        priority_order = {'high': 0, 'medium': 1, 'low': 2}
        items.sort(key=lambda x: priority_order.get(x.priority, 1))

        return {
            "plan_id": plan.id,
            "items": [_item_to_out(i) for i in items],
        }


@router.patch("/plans/{plan_id}/items/{item_id}")
def update_item_status(
    plan_id: int,
    item_id: int,
    body: ItemStatusIn,
    user=Depends(get_current_user),
):
    """更新单个 plan_item 状态（done / skipped）。"""
    if body.status not in ('done', 'skipped'):
        raise HTTPException(400, "status 必须为 done 或 skipped")

    user_id = int(user["id"])
    with db_session() as db:
        plan = _assert_plan_owner(db, plan_id, user_id)
        item = db.query(PlanItem).filter_by(id=item_id, plan_id=plan_id).first()
        if not item:
            raise HTTPException(404, "计划条目不存在")

        item.status = body.status
        if body.status == 'done':
            item.completed_at = datetime.now(timezone.utc)

        # 检查计划是否全部完成
        from services.study_planner_service import StudyPlannerService
        StudyPlannerService().check_plan_completion(plan_id, db)

    return {"ok": True}


@router.patch("/plans/{plan_id}/status")
def update_plan_status(
    plan_id: int,
    body: PlanStatusIn,
    user=Depends(get_current_user),
):
    """更新计划状态（目前只支持 abandoned）。
    放弃计划时自动清理关联的日历事件（不再产生孤儿事件）。
    """
    if body.status != 'abandoned':
        raise HTTPException(400, "只支持将状态更新为 abandoned")

    user_id = int(user["id"])
    with db_session() as db:
        plan = _assert_plan_owner(db, plan_id, user_id)
        if plan.status not in ('active', 'draft'):
            raise HTTPException(400, f"计划当前状态为 {plan.status}，无法放弃")
        plan.status = 'abandoned'

        # 清理关联的日历事件（plan_id 关联）
        from sqlalchemy import text
        result = db.execute(text("""
            DELETE FROM calendar_events
            WHERE user_id = :uid AND plan_id = :plan_id AND source = 'study-planner'
            RETURNING id
        """), {"uid": user_id, "plan_id": plan_id})
        deleted_count = len(result.fetchall())
        if deleted_count > 0:
            logger.info("放弃计划 %s，已清理 %d 条日历事件", plan_id, deleted_count)

    return {"ok": True, "calendar_events_cleaned": deleted_count}


@router.get("/plans/{plan_id}/summary", response_model=PlanSummaryOut)
def get_plan_summary(plan_id: int, user=Depends(get_current_user)):
    """获取计划摘要：总条目数、已完成数、剩余天数、今日完成率。"""
    user_id = int(user["id"])
    today = date.today()

    with db_session() as db:
        plan = _assert_plan_owner(db, plan_id, user_id)

        all_items = db.query(PlanItem).filter_by(plan_id=plan_id).all()
        total = len(all_items)
        completed = sum(1 for i in all_items if i.status in ('done', 'skipped'))

        deadline_date = plan.deadline.date() if plan.deadline else today
        days_remaining = max(0, (deadline_date - today).days)

        # 今日条目
        today_items = [
            i for i in all_items
            if i.planned_date and i.planned_date.date() == today
        ]
        today_done = sum(1 for i in today_items if i.status in ('done', 'skipped'))
        today_rate = today_done / len(today_items) if today_items else 0.0

        return PlanSummaryOut(
            plan_id=plan_id,
            total_items=total,
            completed_items=completed,
            days_remaining=days_remaining,
            today_completion_rate=round(today_rate, 2),
            today_items=[_item_to_out(i) for i in today_items],
        )


@router.get("/plans/{plan_id}/progress")
def get_plan_progress(plan_id: int, user=Depends(get_current_user)):
    """轮询规划进度（后台异步生成时使用）。"""
    user_id = int(user["id"])
    with db_session() as db:
        plan = _assert_plan_owner(db, plan_id, user_id)
        # 如果已经 active，直接返回完成
        if plan.status == 'active':
            return {"status": "done", "progress": 1.0, "plan_id": plan_id}
        if plan.status == 'draft':
            progress = _plan_progress.get(plan_id, {"status": "pending", "progress": 0})
            return {**progress, "plan_id": plan_id}        return {"status": plan.status, "progress": 1.0, "plan_id": plan_id}


# ── Level 3 占位端点 ───────────────────────────────────────────────────────────

@router.post("/notify/register")
def notify_register(user=Depends(get_current_user)):
    return {"status": "not_implemented"}


@router.post("/notify/send")
def notify_send(user=Depends(get_current_user)):
    return {"status": "not_implemented"}


# ── 增量重规划（Delta Replan）─────────────────────────────────────────────────

@router.post("/replan")
def delta_replan(
    background_tasks: BackgroundTasks,
    user=Depends(get_current_user),
):
    """
    增量重规划：日历改动后，重新调整剩余的 study-planner 排课。
    流程：
    1. 查找用户的 active 计划
    2. 保留已完成/skipped 的 plan_items
    3. 删除所有 pending 的 calendar_events（plan_id 关联）
    4. 查询当前日历状态（已有事件）
    5. 对 pending items 重新调用排课算法
    6. 重新写入日历
    """
    user_id = int(user["id"])

    with db_session() as db:
        plan = db.query(StudyPlan).filter_by(user_id=user_id, status='active').first()
        if not plan:
            raise HTTPException(404, "暂无进行中的学习计划")

        pending_items = (
            db.query(PlanItem)
            .filter_by(plan_id=plan.id, status='pending')
            .all()
        )

        if not pending_items:
            return {"ok": True, "message": "没有待调整的任务", "adjusted_count": 0}

        plan_id = plan.id

    background_tasks.add_task(
        _run_delta_replan, plan_id=plan_id, user_id=user_id,
        deadline=plan.deadline, daily_minutes=plan.daily_minutes,
    )
    return {"ok": True, "status": "replanning", "plan_id": plan_id}


def _run_delta_replan(
    plan_id: int,
    user_id: int,
    deadline: datetime,
    daily_minutes: int,
):
    """后台线程：执行增量重规划。"""
    from datetime import date as date_type
    from services.study_planner_service import (
        _get_existing_calendar_events,
        _schedule_items,
        _advisor_schedule_suggestion,
        _sync_plan_to_calendar,
    )
    from sqlalchemy import text

    try:
        with db_session() as db:
            # 获取 pending items
            rows = db.execute(text("""
                SELECT id, subject_id, node_id, node_text, estimated_minutes, priority, planned_date
                FROM plan_items
                WHERE plan_id = :plan_id AND status = 'pending'
                ORDER BY planned_date
            """), {"plan_id": plan_id}).fetchall()

            if not rows:
                return

            # 构建 subject_analyses（仅包含 pending 节点）
            subject_map: dict[int, dict] = {}
            for row in rows:
                sid = row.subject_id or 0
                if sid not in subject_map:
                    from database import Subject
                    subj = db.query(Subject).filter_by(id=sid).first()
                    subject_map[sid] = {
                        "subject_id": sid,
                        "subject_name": subj.name if subj else f"学科{sid}",
                        "nodes": [],
                    }
                subject_map[sid]["nodes"].append({
                    "node_id": row.node_id,
                    "text": row.node_text or "",
                    "priority": row.priority,
                    "estimated_minutes": row.estimated_minutes,
                    "parent_id": None,
                })

            subject_analyses = list(subject_map.values())
            start = date_type.today()

            # 查询已有日历事件
            deadline_date = deadline.date() if hasattr(deadline, 'date') else deadline
            existing = _get_existing_calendar_events(user_id, start, deadline_date, db)

            # 重新排课
            scheduled = _advisor_schedule_suggestion(
                subject_analyses, deadline, daily_minutes, start,
                existing_events=existing,
            )
            if not scheduled:
                scheduled = _schedule_items(
                    subject_analyses, deadline, daily_minutes, start,
                    existing_events=existing,
                )

            # 清理旧的日历事件 + 重新写入
            calendar_count = _sync_plan_to_calendar(user_id, plan_id, scheduled, db)

            # 更新 plan_items 的 planned_date
            for item in scheduled:
                new_date = item.get("planned_date")
                if new_date:
                    node_id = item.get("node_id", "")
                    db.execute(text("""
                        UPDATE plan_items SET planned_date = :dt::timestamptz
                        WHERE plan_id = :plan_id AND node_id = :node_id AND status = 'pending'
                    """), {
                        "plan_id": plan_id,
                        "node_id": node_id,
                        "dt": new_date.isoformat(),
                    })

            db.flush()
            logger.info("增量重规划完成：plan_id=%s，调整 %d 条任务，写入 %d 条日历事件",
                       plan_id, len(scheduled), calendar_count)
    except Exception as e:
        logger.exception("增量重规划失败 plan_id=%s: %s", plan_id, e)
