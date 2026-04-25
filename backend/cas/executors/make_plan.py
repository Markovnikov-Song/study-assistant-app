from cas.executor_registry import register_executor
from cas.models import ActionResult, RenderType

_FALLBACK = "学习计划生成失败，请稍后再试"


@register_executor("make_plan")
async def make_plan_executor(params: dict, user_id: int) -> ActionResult:
    """调用 LLM 生成学习计划文本。"""
    try:
        from services.llm_service import LLMService
        from backend_config import get_config

        subject = params.get("subject", "")
        exam_date = params.get("exam_date", "")
        daily_hours = float(params.get("daily_hours", 2))

        if not subject or not exam_date:
            return ActionResult.fallback("make_plan", "请提供学科和考试日期", "missing_params")

        from datetime import date
        today = date.today()
        try:
            exam = date.fromisoformat(exam_date)
            days_left = (exam - today).days
        except ValueError:
            days_left = 30

        prompt = (
            f"请为学生制定一份{subject}的学习计划。\n"
            f"考试日期：{exam_date}（距今 {days_left} 天）\n"
            f"每日可用时长：{daily_hours} 小时\n\n"
            f"要求：\n"
            f"1. 按周分阶段，每阶段有明确目标\n"
            f"2. 每日具体任务不超过 3 条\n"
            f"3. 最后一周留作冲刺复习\n"
            f"4. 格式清晰，用 Markdown 输出"
        )

        llm = LLMService()
        content = llm.chat(
            [
                {"role": "system", "content": "你是一位经验丰富的学习规划师，擅长制定高效的备考计划。"},
                {"role": "user", "content": prompt},
            ],
            max_tokens=get_config().LLM_EXECUTE_NODE_MAX_TOKENS,
        )

        return ActionResult.ok(
            action_id="make_plan",
            render_type=RenderType.text,
            text=content,
        )

    except Exception as exc:
        import logging
        logging.getLogger(__name__).exception("make_plan 执行失败：%s", exc)
        return ActionResult.fallback("make_plan", _FALLBACK)
