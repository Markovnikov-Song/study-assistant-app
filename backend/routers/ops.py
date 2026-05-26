"""运维：连接守护、客户端反馈收件箱。"""
from __future__ import annotations

import json
from pathlib import Path

from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, HTTPException, Query, Request, UploadFile
from fastapi.responses import FileResponse, HTMLResponse, Response

from deps import get_current_user
from ops.connectivity_guardian import get_last_scan, run_scan, should_auto_fix_on_startup
from ops.incident_store import (
    build_bundle_zip,
    create_incident,
    get_incident,
    get_incident_storage_dir,
    list_incidents,
    mark_read,
    mark_resolved,
)
from ops.incident_email import incident_email_configured, send_incident_email
from ops.inbox_auth import require_inbox_operator

router = APIRouter()
_INBOX_HTML = Path(__file__).resolve().parent.parent / "ops" / "inbox.html"


# ── 连接守护 ──────────────────────────────────────────────────────────────


@router.get("/guardian/status")
def guardian_status(user=Depends(get_current_user)):
    """最近一次扫描结果（启动时或手动触发后）。"""
    _ = user
    last = get_last_scan()
    return {
        "auto_fix_enabled": should_auto_fix_on_startup(),
        "last_scan": last,
    }


@router.post("/guardian/scan")
def guardian_scan(request: Request, user=Depends(get_current_user)):
    """立即扫描关键 API；可选自动修复缺失路由注册（需 OPS_AUTO_FIX）。"""
    _ = user
    auto_fix = should_auto_fix_on_startup()
    result = run_scan(request.app, auto_fix=auto_fix)
    return result.to_dict()


@router.get("/guardian/manifest")
def guardian_manifest(user=Depends(get_current_user)):
    """返回监控清单（供客户端对齐）。"""
    _ = user
    from ops.api_manifest import CRITICAL_API_ENDPOINTS

    return {
        "endpoints": [
            {
                "path": s.path,
                "method": s.method,
                "feature": s.feature,
                "router_module": s.router_module,
            }
            for s in CRITICAL_API_ENDPOINTS
        ]
    }


# ── 客户端反馈提交（任意登录用户）────────────────────────────────────────


@router.post("/incidents")
async def submit_incident(
    background_tasks: BackgroundTasks,
    route: str = Form(""),
    description: str = Form(""),
    contact: str = Form(""),
    app_version: str = Form(""),
    device_info: str = Form("{}"),
    client_logs: str = Form("[]"),
    screenshot: UploadFile | None = File(None),
    user: dict = Depends(get_current_user),
):
    """提交当前页面反馈：附可选描述、联系方式、截图与本地日志。"""
    try:
        device = json.loads(device_info) if device_info else {}
    except json.JSONDecodeError:
        device = {"raw": device_info}
    try:
        logs = json.loads(client_logs) if client_logs else []
    except json.JSONDecodeError:
        logs = []

    shot_bytes: bytes | None = None
    if screenshot and screenshot.filename:
        raw = await screenshot.read()
        if raw and len(raw) <= 8 * 1024 * 1024:
            shot_bytes = raw

    if len(logs) > 300:
        logs = logs[:300]

    detail = create_incident(
        user_id=user["id"],
        username=user["username"],
        route=route,
        description=description,
        contact=contact,
        app_version=app_version,
        device_info=device if isinstance(device, dict) else {},
        client_logs=logs if isinstance(logs, list) else [],
        screenshot_bytes=shot_bytes,
    )
    email_enabled = incident_email_configured()
    if email_enabled:
        background_tasks.add_task(
            send_incident_email,
            incident=detail,
            storage_dir=get_incident_storage_dir(int(detail["id"])),
        )
    return {
        "ok": True,
        "incident": detail,
        "email": {
            "enabled": email_enabled,
            "queued": email_enabled,
        },
    }


# ── 收件箱（仅 OPS_INBOX_USERNAMES）──────────────────────────────────────


@router.get("/inbox/incidents")
def inbox_list(
    status: str | None = Query(None),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    _op: dict = Depends(require_inbox_operator),
):
    items, total, unread = list_incidents(status=status, limit=limit, offset=offset)
    return {"items": items, "total": total, "unread": unread}


@router.get("/inbox/incidents/{incident_id}")
def inbox_detail(incident_id: int, _op: dict = Depends(require_inbox_operator)):
    detail = get_incident(incident_id)
    if not detail:
        raise HTTPException(404, "反馈不存在")
    return detail


@router.post("/inbox/incidents/{incident_id}/read")
def inbox_mark_read(incident_id: int, _op: dict = Depends(require_inbox_operator)):
    if not mark_read(incident_id):
        raise HTTPException(404, "反馈不存在")
    return {"ok": True}


@router.post("/inbox/incidents/{incident_id}/resolve")
def inbox_mark_resolved(incident_id: int, _op: dict = Depends(require_inbox_operator)):
    if not mark_resolved(incident_id):
        raise HTTPException(404, "反馈不存在")
    return {"ok": True}


@router.get("/inbox/incidents/{incident_id}/bundle")
def inbox_download_bundle(incident_id: int, _op: dict = Depends(require_inbox_operator)):
    """下载 Cursor 修复包（zip）：拖入 Cursor 即可。"""
    data = build_bundle_zip(incident_id)
    if not data:
        raise HTTPException(404, "反馈或附件不存在")
    return Response(
        content=data,
        media_type="application/zip",
        headers={
            "Content-Disposition": f'attachment; filename="incident-{incident_id}-cursor.zip"'
        },
    )


@router.get("/inbox", response_class=HTMLResponse)
def inbox_page():
    """结构化反馈收件箱 Web 页（浏览器打开，用 App 账号登录后查看）。"""
    if not _INBOX_HTML.is_file():
        raise HTTPException(404, "inbox.html 缺失")
    return HTMLResponse(_INBOX_HTML.read_text(encoding="utf-8"))
