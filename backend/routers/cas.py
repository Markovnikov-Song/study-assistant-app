"""
CAS Router — 受控动作空间 API
挂载在 /api/cas

端点：
  GET  /api/cas/actions   — 返回所有已注册 Action 摘要列表
  POST /api/cas/dispatch  — 接收用户输入，执行 DispatchPipeline，返回 ActionResult 或 SSE 流
  GET  /api/cas/logs      — 返回最近执行日志（仅管理员）
"""
from __future__ import annotations

import base64
import binascii

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse

from cas.action_registry import get_action_registry
from cas.dispatch_pipeline import get_dispatch_logs, get_pipeline
from cas.models import ActionResult, ActionSummary, ActionsListOut, DispatchIn
from deps import get_current_user

router = APIRouter()

_MAX_DISPATCH_IMAGES = 4
_MAX_IMAGE_BYTES = 8 * 1024 * 1024


def _normalize_dispatch_images(raw_images: list[str] | None) -> list[str]:
    images: list[str] = []
    for raw in raw_images or []:
        img = (raw or "").strip()
        if not img:
            continue
        if "," in img and img.lower().startswith("data:image/"):
            img = img.split(",", 1)[1].strip()
        images.append(img)

    if len(images) > _MAX_DISPATCH_IMAGES:
        raise HTTPException(
            status_code=400,
            detail=f"一次最多上传 {_MAX_DISPATCH_IMAGES} 张题目图片",
        )

    for img in images:
        try:
            decoded = base64.b64decode(img, validate=True)
        except (binascii.Error, ValueError):
            raise HTTPException(status_code=400, detail="图片数据无效，请重新拍照后再试")
        if len(decoded) > _MAX_IMAGE_BYTES:
            raise HTTPException(status_code=400, detail="图片太大，请重新拍照或换一张更清晰的截图")

    return images


@router.get("/actions", response_model=ActionsListOut)
def list_actions(user=Depends(get_current_user)):
    """
    返回所有已注册 Action 的摘要列表，供前端同步。
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


@router.post("/dispatch")
async def dispatch(body: DispatchIn, user=Depends(get_current_user)):
    """
    接收用户自然语言输入（含可选图片），执行完整 DispatchPipeline。

    - 纯文字请求：text 不能为空
    - 多模态请求：images 非空时允许 text 为空（补充说明可选）
    - 普通 action 返回 ActionResult（JSON）
    - 解题等流式 action 返回 StreamingResponse（text/event-stream SSE）
    - 任何其他情况均返回 HTTP 200，错误通过 ActionResult.success=False 传递
    """
    text = (body.text or "").strip()
    supplement = (body.supplement_text or "").strip()
    if not text and supplement:
        text = supplement

    # 过滤空 Base64，并对 data URI / 非法 Base64 / 过大图片做明确校验。
    images = _normalize_dispatch_images(body.images)
    has_images = len(images) > 0

    # 纯文字请求时 text 不能为空；有有效图片时允许 text 为空
    if not text and not has_images:
        raise HTTPException(
            status_code=400,
            detail="请上传题目图片或输入文字说明",
        )

    pipeline = get_pipeline()
    result = await pipeline.run(
        text=text,
        session_id=body.session_id,
        user_id=int(user["id"]),
        images=images if has_images else None,
        supplement_text=supplement or None,
    )
    # StreamingResponse 直接返回，FastAPI 自动处理流式响应
    return result


@router.get("/logs")
def get_logs(user=Depends(get_current_user)):
    """
    返回最近 1000 条 Dispatch 执行日志（调试用）。
    """
    return {"logs": get_dispatch_logs(), "total": len(get_dispatch_logs())}
