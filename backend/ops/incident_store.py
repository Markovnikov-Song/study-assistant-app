"""客户端反馈：落库、附件目录、保留策略、Cursor 修复包。"""
from __future__ import annotations

import io
import json
import logging
import os
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from sqlalchemy.orm import Session

from database import ClientIncident, get_session

logger = logging.getLogger(__name__)

_BACKEND_ROOT = Path(__file__).resolve().parent.parent
_INCIDENTS_ROOT = _BACKEND_ROOT / "data" / "incidents"
_MAX_PER_USER = int(os.getenv("INCIDENT_MAX_PER_USER", "30"))
_MAX_GLOBAL = int(os.getenv("INCIDENT_MAX_GLOBAL", "2000"))


def incidents_data_root() -> Path:
    root = Path(os.getenv("INCIDENT_DATA_DIR", str(_INCIDENTS_ROOT)))
    root.mkdir(parents=True, exist_ok=True)
    return root


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _incident_dir(incident_id: int) -> Path:
    return incidents_data_root() / str(incident_id)


def _prune_old(session: Session, user_id: int) -> None:
    q = (
        session.query(ClientIncident)
        .filter(ClientIncident.user_id == user_id)
        .order_by(ClientIncident.created_at.desc())
    )
    rows = q.all()
    if len(rows) <= _MAX_PER_USER:
        return
    for row in rows[_MAX_PER_USER:]:
        _delete_storage(row)
        session.delete(row)

    total = session.query(ClientIncident).count()
    if total <= _MAX_GLOBAL:
        return
    overflow = (
        session.query(ClientIncident)
        .order_by(ClientIncident.created_at.asc())
        .limit(total - _MAX_GLOBAL)
        .all()
    )
    for row in overflow:
        _delete_storage(row)
        session.delete(row)


def _delete_storage(row: ClientIncident) -> None:
    if row.storage_dir:
        path = Path(row.storage_dir)
        if path.is_dir():
            for child in path.iterdir():
                child.unlink(missing_ok=True)
            path.rmdir()


def create_incident(
    *,
    user_id: int,
    username: str,
    route: str,
    description: str | None,
    contact: str | None,
    app_version: str,
    device_info: dict[str, Any],
    client_logs: list[dict[str, Any]],
    screenshot_bytes: bytes | None,
) -> ClientIncident:
    with get_session() as session:
        row = ClientIncident(
            user_id=user_id,
            username=username,
            route=route or "",
            description=(description or "").strip() or None,
            contact=(contact or "").strip() or None,
            app_version=app_version or "",
            device_info=device_info or {},
            client_logs=client_logs or [],
            has_screenshot=bool(screenshot_bytes),
            status="new",
        )
        session.add(row)
        session.flush()
        incident_id = row.id
        folder = _incident_dir(incident_id)
        folder.mkdir(parents=True, exist_ok=True)
        row.storage_dir = str(folder)

        meta = {
            "id": incident_id,
            "user_id": user_id,
            "username": username,
            "route": row.route,
            "description": row.description,
            "contact": row.contact,
            "app_version": row.app_version,
            "device_info": row.device_info,
            "created_at": _utc_now().isoformat(),
        }
        (folder / "incident.json").write_text(
            json.dumps(meta, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        (folder / "client_logs.json").write_text(
            json.dumps(client_logs, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        if screenshot_bytes:
            (folder / "screenshot.png").write_bytes(screenshot_bytes)

        _write_cursor_readme(folder, row)
        _prune_old(session, user_id)
        session.refresh(row)
        return _row_to_detail(row)


def _write_cursor_readme(folder: Path, row: ClientIncident) -> None:
    desc = row.description or "(用户未填写描述)"
    prompt = (
        f"请根据 incident-{row.id} 目录中的结构化信息修复非业务类 bug。\n"
        f"- 页面路由: {row.route}\n"
        f"- 用户描述: {desc}\n"
        f"- 应用版本: {row.app_version}\n"
        f"- 详见 incident.json、client_logs.json、screenshot.png\n"
    )
    (folder / "cursor_prompt.txt").write_text(prompt, encoding="utf-8")
    readme = f"""# 反馈 #{row.id}

将本文件夹拖入 Cursor 对话，或解压后引用 `cursor_prompt.txt`。

| 文件 | 说明 |
|------|------|
| incident.json | 路由、版本、设备、联系方式 |
| client_logs.json | 提交时 App 本地最近错误日志 |
| screenshot.png | 提交瞬间页面截图（若有） |
| cursor_prompt.txt | 预填给模型的修复提示 |

用户: {row.username} | 路由: {row.route}
"""
    (folder / "README.md").write_text(readme, encoding="utf-8")


def list_incidents(
    *,
    status: str | None = None,
    limit: int = 50,
    offset: int = 0,
) -> tuple[list[dict[str, Any]], int, int]:
    with get_session() as session:
        q = session.query(ClientIncident)
        if status:
            q = q.filter(ClientIncident.status == status)
        total = q.count()
        unread = (
            session.query(ClientIncident)
            .filter(ClientIncident.status == "new")
            .count()
        )
        rows = (
            q.order_by(ClientIncident.created_at.desc())
            .offset(offset)
            .limit(min(limit, 100))
            .all()
        )
        return [_row_to_summary(r) for r in rows], total, unread


def get_incident(incident_id: int) -> dict[str, Any] | None:
    with get_session() as session:
        row = session.get(ClientIncident, incident_id)
        if not row:
            return None
        return _row_to_detail(row)


def get_incident_storage_dir(incident_id: int) -> str | None:
    with get_session() as session:
        row = session.get(ClientIncident, incident_id)
        if not row:
            return None
        return row.storage_dir


def mark_read(incident_id: int) -> bool:
    with get_session() as session:
        row = session.get(ClientIncident, incident_id)
        if not row:
            return False
        if row.status == "new":
            row.status = "read"
            row.read_at = _utc_now()
        return True


def mark_resolved(incident_id: int) -> bool:
    with get_session() as session:
        row = session.get(ClientIncident, incident_id)
        if not row:
            return False
        row.status = "resolved"
        return True


def build_bundle_zip(incident_id: int) -> bytes | None:
    with get_session() as session:
        row = session.get(ClientIncident, incident_id)
        if not row or not row.storage_dir:
            return None
        folder = Path(row.storage_dir)
        if not folder.is_dir():
            return None

    buf = io.BytesIO()
    prefix = f"incident-{incident_id}"
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
        for path in sorted(folder.iterdir()):
            if path.is_file():
                arc = f"{prefix}/{path.name}"
                zf.write(path, arcname=arc)
    buf.seek(0)
    return buf.read()


def _row_to_summary(row: ClientIncident) -> dict[str, Any]:
    preview = (row.description or row.route or "")[:120]
    return {
        "id": row.id,
        "user_id": row.user_id,
        "username": row.username,
        "route": row.route,
        "description_preview": preview,
        "contact": row.contact,
        "app_version": row.app_version,
        "has_screenshot": row.has_screenshot,
        "log_count": len(row.client_logs) if isinstance(row.client_logs, list) else 0,
        "status": row.status,
        "created_at": row.created_at.isoformat() if row.created_at else None,
    }


def _row_to_detail(row: ClientIncident) -> dict[str, Any]:
    d = _row_to_summary(row)
    d.update(
        {
            "description": row.description,
            "device_info": row.device_info,
            "client_logs": row.client_logs,
            "read_at": row.read_at.isoformat() if row.read_at else None,
            "bundle_url": f"/api/ops/inbox/incidents/{row.id}/bundle",
        }
    )
    return d
