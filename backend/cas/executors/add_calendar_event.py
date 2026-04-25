from cas.executor_registry import register_executor
from cas.models import ActionResult, RenderType

_FALLBACK = "添加日历事件失败，请稍后再试"


@register_executor("add_calendar_event")
async def add_calendar_event_executor(params: dict, user_id: int) -> ActionResult:
    """调用日历后端接口创建事件。"""
    try:
        from database import get_session
        from routers.calendar import CalendarEventCreate
        import sqlalchemy as sa

        title = params.get("title", "").strip()
        date_str = params.get("date", "")

        if not title or not date_str:
            return ActionResult.fallback("add_calendar_event", "标题和日期不能为空", "missing_params")

        # 调用日历服务创建事件（复用现有 calendar router 逻辑）
        from services.llm_service import LLMService
        from datetime import date, time as dtime

        event_date = date.fromisoformat(date_str)

        with get_session() as db:
            db.execute(
                sa.text(
                    "INSERT INTO calendar_events "
                    "(user_id, title, event_date, start_time, duration_minutes, source) "
                    "VALUES (:uid, :title, :date, :start, :dur, :src)"
                ),
                {
                    "uid": user_id,
                    "title": title,
                    "date": event_date,
                    "start": dtime(9, 0),
                    "dur": 60,
                    "src": "cas",
                },
            )
            db.commit()

        return ActionResult.ok(
            action_id="add_calendar_event",
            render_type=RenderType.text,
            text=f"✅ 已添加到日历：**{title}**（{date_str}）",
        )

    except Exception as exc:
        import logging
        logging.getLogger(__name__).exception("add_calendar_event 执行失败：%s", exc)
        return ActionResult.fallback("add_calendar_event", _FALLBACK)
