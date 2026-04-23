"""
calendar.py — 学习日历路由
挂载在 /api/calendar

端点：
  POST   /api/calendar/events              — 创建单次事件
  GET    /api/calendar/events              — 查询事件列表（按日期范围）
  GET    /api/calendar/events/today        — 今日事件 + 完成率统计
  PATCH  /api/calendar/events/{id}         — 更新事件（部分字段）
  DELETE /api/calendar/events/{id}         — 删除事件
  POST   /api/calendar/events/batch        — 批量写入事件
  POST   /api/calendar/routines            — 创建例程（自动生成事件实例）
  GET    /api/calendar/routines            — 查询活跃例程列表
  PATCH  /api/calendar/routines/{id}       — 更新例程
  DELETE /api/calendar/routines/{id}       — 软删除例程
  POST   /api/calendar/sessions            — 记录学习 session
  GET    /api/calendar/stats               — 学习统计（7d / 30d）
"""
from __future__ import annotations

import math
from datetime import date, datetime, time, timedelta, timezone
from typing import Any, List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, field_validator
from sqlalchemy import text

from database import get_session as db_session
from deps import get_current_user

router = APIRouter()


# ── Pydantic 模型 ──────────────────────────────────────────────────────────────

class CalendarEventOut(BaseModel):
    id: int
    user_id: int
    title: str
    event_date: str          # ISO date string
    start_time: str          # HH:MM
    duration_minutes: int
    actual_duration_minutes: Optional[int]
    subject_id: Optional[int]
    subject_name: Optional[str]
    subject_color: Optional[str]
    color: str
    notes: Optional[str]
    is_completed: bool
    is_countdown: bool
    priority: str
    source: str
    routine_id: Optional[int]
    created_at: str
    updated_at: str


class CalendarEventIn(BaseModel):
    title: str
    event_date: str
    start_time: str
    duration_minutes: int
    actual_duration_minutes: Optional[int] = None
    subject_id: Optional[int] = None
    color: Optional[str] = None
    notes: Optional[str] = None
    is_completed: bool = False
    is_countdown: bool = False
    priority: str = "medium"
    source: str = "manual"

    @field_validator("title")
    @classmethod
    def validate_title(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("标题不能为空")
        if len(v) > 50:
            raise ValueError("标题不能超过 50 个字符")
        return v

    @field_validator("duration_minutes")
    @classmethod
    def validate_duration(cls, v: int) -> int:
        if not (15 <= v <= 480):
            raise ValueError("duration_minutes 必须在 15-480 之间")
        return v

    @field_validator("priority")
    @classmethod
    def validate_priority(cls, v: str) -> str:
        if v not in ("high", "medium", "low"):
            raise ValueError("priority 必须为 high/medium/low")
        return v


class CalendarEventPatch(BaseModel):
    title: Optional[str] = None
    event_date: Optional[str] = None
    start_time: Optional[str] = None
    duration_minutes: Optional[int] = None
    actual_duration_minutes: Optional[int] = None
    subject_id: Optional[int] = None
    color: Optional[str] = None
    notes: Optional[str] = None
    is_completed: Optional[bool] = None
    is_countdown: Optional[bool] = None
    priority: Optional[str] = None


class BatchEventItem(BaseModel):
    title: str
    event_date: str
    start_time: str
    duration_minutes: int
    subject_id: Optional[int] = None
    color: Optional[str] = None
    notes: Optional[str] = None
    source: str = "manual"
    is_countdown: bool = False
    priority: str = "medium"


class BatchEventIn(BaseModel):
    events: List[BatchEventItem]


class BatchResultItem(BaseModel):
    index: int
    success: bool
    id: Optional[int] = None
    error: Optional[str] = None


class BatchEventOut(BaseModel):
    results: List[BatchResultItem]
    created_count: int
    failed_count: int


class RoutineIn(BaseModel):
    title: str
    repeat_type: str          # daily / weekly / monthly
    day_of_week: Optional[int] = None
    start_time: str
    duration_minutes: int
    subject_id: Optional[int] = None
    color: Optional[str] = None
    start_date: str
    end_date: Optional[str] = None

    @field_validator("repeat_type")
    @classmethod
    def validate_repeat_type(cls, v: str) -> str:
        if v not in ("daily", "weekly", "monthly"):
            raise ValueError("repeat_type 必须为 daily/weekly/monthly")
        return v

    @field_validator("duration_minutes")
    @classmethod
    def validate_duration(cls, v: int) -> int:
        if not (15 <= v <= 480):
            raise ValueError("duration_minutes 必须在 15-480 之间")
        return v


class RoutineOut(BaseModel):
    id: int
    title: str
    repeat_type: str
    day_of_week: Optional[int]
    start_time: str
    duration_minutes: int
    subject_id: Optional[int]
    color: str
    start_date: str
    end_date: Optional[str]
    is_active: bool
    created_at: str


class RoutinePatch(BaseModel):
    title: Optional[str] = None
    start_time: Optional[str] = None
    duration_minutes: Optional[int] = None
    subject_id: Optional[int] = None
    color: Optional[str] = None
    end_date: Optional[str] = None


class StudySessionIn(BaseModel):
    event_id: Optional[int] = None
    subject_id: Optional[int] = None
    started_at: str
    ended_at: str
    duration_minutes: int
    pomodoro_count: int = 0


class StudySessionOut(BaseModel):
    id: int
    event_id: Optional[int]
    subject_id: Optional[int]
    started_at: str
    ended_at: str
    duration_minutes: int
    pomodoro_count: int
    created_at: str


class TodayStatsOut(BaseModel):
    total: int
    completed: int
    completion_rate: float
    total_duration_minutes: int
    actual_duration_minutes: int


class TodayEventsOut(BaseModel):
    events: List[CalendarEventOut]
    stats: TodayStatsOut


class DailyStatItem(BaseModel):
    date: str
    duration_minutes: int


class SubjectStatItem(BaseModel):
    subject_id: Optional[int]
    subject_name: str
    color: str
    duration_minutes: int
    percentage: float


class CalendarStatsOut(BaseModel):
    period: str
    total_duration_minutes: int
    checkin_days: int
    streak_days: int
    daily_stats: List[DailyStatItem]
    subject_stats: List[SubjectStatItem]


# ── 内部工具函数 ───────────────────────────────────────────────────────────────

def _row_to_event_out(row: Any) -> CalendarEventOut:
    return CalendarEventOut(
        id=row.id,
        user_id=row.user_id,
        title=row.title,
        event_date=str(row.event_date),
        start_time=str(row.start_time)[:5],
        duration_minutes=row.duration_minutes,
        actual_duration_minutes=row.actual_duration_minutes,
        subject_id=row.subject_id,
        subject_name=getattr(row, "subject_name", None),
        subject_color=getattr(row, "subject_color", None),
        color=row.color,
        notes=row.notes,
        is_completed=bool(row.is_completed),
        is_countdown=bool(row.is_countdown),
        priority=row.priority,
        source=row.source,
        routine_id=row.routine_id,
        created_at=row.created_at.isoformat() if row.created_at else "",
        updated_at=row.updated_at.isoformat() if row.updated_at else "",
    )


def _default_color(subject_id: Optional[int], db_session_obj: Any) -> str:
    """若未指定颜色，尝试从学科获取颜色，否则返回默认靛蓝色。"""
    return "#6366F1"


def _generate_routine_events(routine_id: int, routine: Any, db: Any) -> int:
    """根据例程定义批量生成 calendar_events 实例，返回生成数量。"""
    start = date.fromisoformat(str(routine.start_date))
    end = date.fromisoformat(str(routine.end_date)) if routine.end_date else start + timedelta(days=365)
    today = date.today()
    # 只生成今天及以后的实例
    current = max(start, today)
    count = 0
    while current <= end:
        should_create = False
        if routine.repeat_type == "daily":
            should_create = True
        elif routine.repeat_type == "weekly":
            # day_of_week: 1=周一, 7=周日；Python isoweekday() 同
            if routine.day_of_week and current.isoweekday() == routine.day_of_week:
                should_create = True
        elif routine.repeat_type == "monthly":
            if current.day == start.day:
                should_create = True

        if should_create:
            db.execute(text("""
                INSERT INTO calendar_events
                    (user_id, title, event_date, start_time, duration_minutes,
                     subject_id, color, is_completed, is_countdown, priority, source, routine_id)
                VALUES
                    (:user_id, :title, :event_date, :start_time, :duration_minutes,
                     :subject_id, :color, FALSE, FALSE, 'medium', 'routine', :routine_id)
            """), {
                "user_id": routine.user_id,
                "title": routine.title,
                "event_date": current,
                "start_time": routine.start_time,
                "duration_minutes": routine.duration_minutes,
                "subject_id": routine.subject_id,
                "color": routine.color,
                "routine_id": routine_id,
            })
            count += 1
        current += timedelta(days=1)
    return count


# ── 事件端点 ───────────────────────────────────────────────────────────────────

@router.post("/events", status_code=201)
def create_event(body: CalendarEventIn, user=Depends(get_current_user)) -> CalendarEventOut:
    """创建单次学习事件。"""
    color = body.color or "#6366F1"
    with db_session() as db:
        result = db.execute(text("""
            INSERT INTO calendar_events
                (user_id, title, event_date, start_time, duration_minutes,
                 actual_duration_minutes, subject_id, color, notes,
                 is_completed, is_countdown, priority, source)
            VALUES
                (:user_id, :title, :event_date, :start_time, :duration_minutes,
                 :actual_duration_minutes, :subject_id, :color, :notes,
                 :is_completed, :is_countdown, :priority, :source)
            RETURNING id, user_id, title, event_date, start_time, duration_minutes,
                      actual_duration_minutes, subject_id, color, notes,
                      is_completed, is_countdown, priority, source, routine_id,
                      created_at, updated_at
        """), {
            "user_id": user["id"],
            "title": body.title,
            "event_date": body.event_date,
            "start_time": body.start_time,
            "duration_minutes": body.duration_minutes,
            "actual_duration_minutes": body.actual_duration_minutes,
            "subject_id": body.subject_id,
            "color": color,
            "notes": body.notes,
            "is_completed": body.is_completed,
            "is_countdown": body.is_countdown,
            "priority": body.priority,
            "source": body.source,
        })
        row = result.fetchone()
        return _row_to_event_out(row)


@router.get("/events")
def list_events(
    start_date: str,
    end_date: str,
    subject_id: Optional[int] = None,
    is_completed: Optional[bool] = None,
    user=Depends(get_current_user),
) -> dict:
    """查询事件列表（按日期范围，支持学科和完成状态过滤）。"""
    with db_session() as db:
        sql = """
            SELECT e.*, s.name AS subject_name, s.category AS subject_color
            FROM calendar_events e
            LEFT JOIN subjects s ON s.id = e.subject_id
            WHERE e.user_id = :user_id
              AND e.event_date BETWEEN :start_date AND :end_date
        """
        params: dict = {
            "user_id": user["id"],
            "start_date": start_date,
            "end_date": end_date,
        }
        if subject_id is not None:
            sql += " AND e.subject_id = :subject_id"
            params["subject_id"] = subject_id
        if is_completed is not None:
            sql += " AND e.is_completed = :is_completed"
            params["is_completed"] = is_completed
        sql += " ORDER BY e.event_date, e.start_time"
        rows = db.execute(text(sql), params).fetchall()
        events = [_row_to_event_out(r) for r in rows]
        return {"events": events, "total": len(events)}


@router.get("/events/today")
def today_events(user=Depends(get_current_user)) -> TodayEventsOut:
    """今日事件列表 + 完成率统计。"""
    today = date.today().isoformat()
    with db_session() as db:
        rows = db.execute(text("""
            SELECT e.*, s.name AS subject_name, s.category AS subject_color
            FROM calendar_events e
            LEFT JOIN subjects s ON s.id = e.subject_id
            WHERE e.user_id = :user_id AND e.event_date = :today
            ORDER BY e.start_time
        """), {"user_id": user["id"], "today": today}).fetchall()

        events = [_row_to_event_out(r) for r in rows]
        total = len(events)
        completed = sum(1 for e in events if e.is_completed)
        total_dur = sum(e.duration_minutes for e in events)
        actual_dur = sum(e.actual_duration_minutes or 0 for e in events)

        return TodayEventsOut(
            events=events,
            stats=TodayStatsOut(
                total=total,
                completed=completed,
                completion_rate=round(completed / total, 2) if total > 0 else 0.0,
                total_duration_minutes=total_dur,
                actual_duration_minutes=actual_dur,
            ),
        )


@router.patch("/events/{event_id}")
def update_event(
    event_id: int,
    body: CalendarEventPatch,
    user=Depends(get_current_user),
) -> CalendarEventOut:
    """更新事件（部分字段）。支持拖拽移动、打卡完成、更新实际时长等场景。"""
    with db_session() as db:
        # 验证归属
        existing = db.execute(
            text("SELECT id FROM calendar_events WHERE id = :id AND user_id = :uid"),
            {"id": event_id, "uid": user["id"]},
        ).fetchone()
        if not existing:
            raise HTTPException(404, "事件不存在")

        updates = {k: v for k, v in body.model_dump().items() if v is not None}
        if not updates:
            raise HTTPException(400, "没有需要更新的字段")

        set_clauses = ", ".join(f"{k} = :{k}" for k in updates)
        updates["id"] = event_id
        updates["updated_at"] = datetime.now(timezone.utc)
        set_clauses += ", updated_at = :updated_at"

        row = db.execute(text(f"""
            UPDATE calendar_events SET {set_clauses}
            WHERE id = :id
            RETURNING id, user_id, title, event_date, start_time, duration_minutes,
                      actual_duration_minutes, subject_id, color, notes,
                      is_completed, is_countdown, priority, source, routine_id,
                      created_at, updated_at
        """), updates).fetchone()
        return _row_to_event_out(row)


@router.delete("/events/{event_id}", status_code=204)
def delete_event(event_id: int, user=Depends(get_current_user)):
    """删除事件。"""
    with db_session() as db:
        result = db.execute(
            text("DELETE FROM calendar_events WHERE id = :id AND user_id = :uid RETURNING id"),
            {"id": event_id, "uid": user["id"]},
        )
        if not result.fetchone():
            raise HTTPException(404, "事件不存在")


# ── 批量写入端点 ───────────────────────────────────────────────────────────────

@router.post("/events/batch")
def batch_create_events(body: BatchEventIn, user=Depends(get_current_user)) -> BatchEventOut:
    """批量写入事件（最多 100 条），每条独立验证，互不影响。"""
    if not body.events:
        raise HTTPException(400, "events array is empty")
    if len(body.events) > 100:
        raise HTTPException(400, "batch size exceeds limit of 100")

    results: List[BatchResultItem] = []
    created = 0

    with db_session() as db:
        for i, item in enumerate(body.events):
            try:
                # 基本验证
                title = item.title.strip()
                if not title:
                    raise ValueError("title 不能为空")
                if len(title) > 50:
                    raise ValueError("title 不能超过 50 个字符")
                if not (15 <= item.duration_minutes <= 480):
                    raise ValueError("duration_minutes 必须在 15-480 之间")

                row = db.execute(text("""
                    INSERT INTO calendar_events
                        (user_id, title, event_date, start_time, duration_minutes,
                         subject_id, color, notes, is_countdown, priority, source)
                    VALUES
                        (:user_id, :title, :event_date, :start_time, :duration_minutes,
                         :subject_id, :color, :notes, :is_countdown, :priority, :source)
                    RETURNING id
                """), {
                    "user_id": user["id"],
                    "title": title,
                    "event_date": item.event_date,
                    "start_time": item.start_time,
                    "duration_minutes": item.duration_minutes,
                    "subject_id": item.subject_id,
                    "color": item.color or "#6366F1",
                    "notes": item.notes,
                    "is_countdown": item.is_countdown,
                    "priority": item.priority,
                    "source": item.source,
                }).fetchone()
                results.append(BatchResultItem(index=i, success=True, id=row.id))
                created += 1
            except Exception as e:
                results.append(BatchResultItem(index=i, success=False, error=str(e)))

    return BatchEventOut(
        results=results,
        created_count=created,
        failed_count=len(body.events) - created,
    )


# ── 例程端点 ───────────────────────────────────────────────────────────────────

@router.post("/routines", status_code=201)
def create_routine(body: RoutineIn, user=Depends(get_current_user)) -> RoutineOut:
    """创建例程，并在事务内批量生成对应的 calendar_events 实例。"""
    color = body.color or "#6366F1"
    with db_session() as db:
        row = db.execute(text("""
            INSERT INTO calendar_routines
                (user_id, title, repeat_type, day_of_week, start_time, duration_minutes,
                 subject_id, color, start_date, end_date)
            VALUES
                (:user_id, :title, :repeat_type, :day_of_week, :start_time, :duration_minutes,
                 :subject_id, :color, :start_date, :end_date)
            RETURNING *
        """), {
            "user_id": user["id"],
            "title": body.title,
            "repeat_type": body.repeat_type,
            "day_of_week": body.day_of_week,
            "start_time": body.start_time,
            "duration_minutes": body.duration_minutes,
            "subject_id": body.subject_id,
            "color": color,
            "start_date": body.start_date,
            "end_date": body.end_date,
        }).fetchone()

        # 批量生成事件实例
        _generate_routine_events(row.id, row, db)

        return RoutineOut(
            id=row.id,
            title=row.title,
            repeat_type=row.repeat_type,
            day_of_week=row.day_of_week,
            start_time=str(row.start_time)[:5],
            duration_minutes=row.duration_minutes,
            subject_id=row.subject_id,
            color=row.color,
            start_date=str(row.start_date),
            end_date=str(row.end_date) if row.end_date else None,
            is_active=bool(row.is_active),
            created_at=row.created_at.isoformat(),
        )


@router.get("/routines")
def list_routines(user=Depends(get_current_user)) -> dict:
    """查询当前用户的活跃例程列表。"""
    with db_session() as db:
        rows = db.execute(text("""
            SELECT * FROM calendar_routines
            WHERE user_id = :uid AND is_active = TRUE
            ORDER BY created_at DESC
        """), {"uid": user["id"]}).fetchall()
        return {"routines": [
            RoutineOut(
                id=r.id, title=r.title, repeat_type=r.repeat_type,
                day_of_week=r.day_of_week, start_time=str(r.start_time)[:5],
                duration_minutes=r.duration_minutes, subject_id=r.subject_id,
                color=r.color, start_date=str(r.start_date),
                end_date=str(r.end_date) if r.end_date else None,
                is_active=bool(r.is_active), created_at=r.created_at.isoformat(),
            ) for r in rows
        ]}


@router.patch("/routines/{routine_id}")
def update_routine(
    routine_id: int,
    body: RoutinePatch,
    user=Depends(get_current_user),
) -> RoutineOut:
    """更新例程，同步更新未来的关联事件实例。"""
    with db_session() as db:
        existing = db.execute(
            text("SELECT * FROM calendar_routines WHERE id = :id AND user_id = :uid"),
            {"id": routine_id, "uid": user["id"]},
        ).fetchone()
        if not existing:
            raise HTTPException(404, "例程不存在")

        updates = {k: v for k, v in body.model_dump().items() if v is not None}
        if updates:
            set_clauses = ", ".join(f"{k} = :{k}" for k in updates)
            updates["id"] = routine_id
            db.execute(text(f"UPDATE calendar_routines SET {set_clauses} WHERE id = :id"), updates)

            # 同步更新未来的关联事件实例（只更新今天及以后的）
            if "title" in updates or "start_time" in updates or "duration_minutes" in updates:
                event_updates = {k: updates[k] for k in ("title", "start_time", "duration_minutes") if k in updates}
                if event_updates:
                    ev_set = ", ".join(f"{k} = :{k}" for k in event_updates)
                    event_updates["routine_id"] = routine_id
                    event_updates["today"] = date.today().isoformat()
                    db.execute(text(f"""
                        UPDATE calendar_events SET {ev_set}
                        WHERE routine_id = :routine_id AND event_date >= :today
                    """), event_updates)

        row = db.execute(
            text("SELECT * FROM calendar_routines WHERE id = :id"), {"id": routine_id}
        ).fetchone()
        return RoutineOut(
            id=row.id, title=row.title, repeat_type=row.repeat_type,
            day_of_week=row.day_of_week, start_time=str(row.start_time)[:5],
            duration_minutes=row.duration_minutes, subject_id=row.subject_id,
            color=row.color, start_date=str(row.start_date),
            end_date=str(row.end_date) if row.end_date else None,
            is_active=bool(row.is_active), created_at=row.created_at.isoformat(),
        )


@router.delete("/routines/{routine_id}", status_code=204)
def delete_routine(routine_id: int, user=Depends(get_current_user)):
    """软删除例程（is_active=False），保留历史事件实例。"""
    with db_session() as db:
        result = db.execute(
            text("UPDATE calendar_routines SET is_active = FALSE WHERE id = :id AND user_id = :uid RETURNING id"),
            {"id": routine_id, "uid": user["id"]},
        )
        if not result.fetchone():
            raise HTTPException(404, "例程不存在")


# ── 学习 Session 端点 ──────────────────────────────────────────────────────────

@router.post("/sessions", status_code=201)
def create_session(body: StudySessionIn, user=Depends(get_current_user)) -> StudySessionOut:
    """记录一次学习 session（番茄钟完成或手动停止时调用）。"""
    with db_session() as db:
        row = db.execute(text("""
            INSERT INTO study_sessions
                (user_id, event_id, subject_id, started_at, ended_at, duration_minutes, pomodoro_count)
            VALUES
                (:user_id, :event_id, :subject_id, :started_at, :ended_at, :duration_minutes, :pomodoro_count)
            RETURNING *
        """), {
            "user_id": user["id"],
            "event_id": body.event_id,
            "subject_id": body.subject_id,
            "started_at": body.started_at,
            "ended_at": body.ended_at,
            "duration_minutes": body.duration_minutes,
            "pomodoro_count": body.pomodoro_count,
        }).fetchone()
        return StudySessionOut(
            id=row.id,
            event_id=row.event_id,
            subject_id=row.subject_id,
            started_at=row.started_at.isoformat(),
            ended_at=row.ended_at.isoformat(),
            duration_minutes=row.duration_minutes,
            pomodoro_count=row.pomodoro_count,
            created_at=row.created_at.isoformat(),
        )


# ── 统计端点 ───────────────────────────────────────────────────────────────────

@router.get("/stats")
def get_stats(period: str = "7d", user=Depends(get_current_user)) -> CalendarStatsOut:
    """学习统计：每日时长趋势 + 学科占比 + 打卡天数 + 连续打卡天数。"""
    days = 30 if period == "30d" else 7
    since = (date.today() - timedelta(days=days - 1)).isoformat()

    with db_session() as db:
        # 每日时长
        daily_rows = db.execute(text("""
            SELECT DATE(started_at AT TIME ZONE 'UTC') AS day,
                   SUM(duration_minutes) AS total_minutes
            FROM study_sessions
            WHERE user_id = :uid AND started_at >= :since
            GROUP BY day
            ORDER BY day
        """), {"uid": user["id"], "since": since}).fetchall()

        daily_stats = [DailyStatItem(date=str(r.day), duration_minutes=r.total_minutes) for r in daily_rows]
        total_minutes = sum(r.duration_minutes for r in daily_stats)
        checkin_days = len(daily_stats)

        # 连续打卡天数（从今天往前数）
        checkin_dates = {r.date for r in daily_stats}
        streak = 0
        check = date.today()
        while str(check) in checkin_dates:
            streak += 1
            check -= timedelta(days=1)

        # 学科占比
        subject_rows = db.execute(text("""
            SELECT ss.subject_id, s.name AS subject_name,
                   SUM(ss.duration_minutes) AS total_minutes
            FROM study_sessions ss
            LEFT JOIN subjects s ON s.id = ss.subject_id
            WHERE ss.user_id = :uid AND ss.started_at >= :since
            GROUP BY ss.subject_id, s.name
            ORDER BY total_minutes DESC
        """), {"uid": user["id"], "since": since}).fetchall()

        subject_stats = []
        for r in subject_rows:
            pct = round(r.total_minutes / total_minutes, 4) if total_minutes > 0 else 0.0
            subject_stats.append(SubjectStatItem(
                subject_id=r.subject_id,
                subject_name=r.subject_name or "未分类",
                color="#6366F1",
                duration_minutes=r.total_minutes,
                percentage=pct,
            ))

        return CalendarStatsOut(
            period=period,
            total_duration_minutes=total_minutes,
            checkin_days=checkin_days,
            streak_days=streak,
            daily_stats=daily_stats,
            subject_stats=subject_stats,
        )
