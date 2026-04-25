"""
CAS Router — 受控动作空间 API
挂载在 /api/cas

端点：
  GET  /api/cas/actions   — 返回所有已注册 Action 摘要列表
  POST /api/cas/dispatch  — 接收用户输入，执行 DispatchPipeline，返回 ActionResult
  GET  /api/cas/logs      — 返回最近执行日志（仅管理员）
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from cas.action_registry import get_action_registry
from cas.dispatch_pipeline import get_dispatch_logs, get_pipeline
from cas.models import ActionResult, ActionSummary, ActionsListOut, DispatchIn
from deps import get_current_user

router = APIRouter()


@router.get("/actions", response_model=ActionsListOut)
def list_actions(user=Depends(get_current_user)):
    """
    返回所有已注册 Action 的摘要列表，供前端同步。
    需求 1.7
    """
    registry = get_action_registry()
    actions = registry.list_actions()
    summaries = [
        ActionSummary(
            action_id=a.action_id,
            name=a.name,
            description=a.description,
        )
        for a in actions
    ]
    return ActionsListOut(actions=summaries, total=len(summaries))


@router.post("/dispatch", response_model=ActionResult)
async def dispatch(body: DispatchIn, user=Depends(get_current_user)):
    """
    接收用户自然语言输入，执行完整 DispatchPipeline，返回 ActionResult。

    - text 为空时返回 HTTP 400
    - 任何其他情况均返回 HTTP 200，错误通过 ActionResult.success=False 传递
    需求 3.6、3.7、6.8
    """
    text = body.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="输入不能为空")

    pipeline = get_pipeline()
    result = await pipeline.run(
        text=text,
        session_id=body.session_id,
        user_id=int(user["id"]),
    )
    return result


@router.get("/logs")
def get_logs(user=Depends(get_current_user)):
    """
    返回最近 1000 条 Dispatch 执行日志（调试用）。
    需求 9.6
    """
    return {"logs": get_dispatch_logs(), "total": len(get_dispatch_logs())}
