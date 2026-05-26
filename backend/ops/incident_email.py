"""Email notification for client incident reports."""
from __future__ import annotations

import json
import logging
import os
import smtplib
from dataclasses import dataclass
from email.message import EmailMessage
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class IncidentEmailResult:
    enabled: bool
    sent: bool
    message: str


def _truthy(value: str | None) -> bool:
    return str(value or "").strip().lower() in {"1", "true", "yes", "on"}


def _split_recipients(value: str | None) -> list[str]:
    if not value:
        return []
    return [part.strip() for part in value.replace(";", ",").split(",") if part.strip()]


def incident_email_configured() -> bool:
    recipients = _split_recipients(
        os.getenv("INCIDENT_ADMIN_EMAILS") or os.getenv("INCIDENT_ADMIN_EMAIL")
    )
    return bool(recipients and os.getenv("SMTP_HOST", "").strip())


def _smtp_port(use_ssl: bool) -> int:
    raw = os.getenv("SMTP_PORT")
    if raw:
        try:
            return int(raw)
        except ValueError:
            logger.warning("Invalid SMTP_PORT=%r, using default", raw)
    return 465 if use_ssl else 587


def _build_body(incident: dict[str, Any], bundle_url: str) -> str:
    device = incident.get("device_info") or {}
    logs = incident.get("client_logs") or []
    latest_logs = logs[:8] if isinstance(logs, list) else []
    latest_log_text = "\n".join(
        f"- [{item.get('level', '')}] {item.get('message', '')}"
        for item in latest_logs
        if isinstance(item, dict)
    )
    if not latest_log_text:
        latest_log_text = "(no client logs)"

    return (
        f"收到新的客户端反馈 #{incident.get('id')}。\n\n"
        f"用户: {incident.get('username')} (ID: {incident.get('user_id')})\n"
        f"页面: {incident.get('route')}\n"
        f"版本: {incident.get('app_version')}\n"
        f"联系方式: {incident.get('contact') or '(未填写)'}\n"
        f"截图: {'有' if incident.get('has_screenshot') else '无'}\n"
        f"描述: {incident.get('description') or '(用户未填写描述)'}\n\n"
        f"设备信息:\n{json.dumps(device, ensure_ascii=False, indent=2)}\n\n"
        f"最近日志:\n{latest_log_text}\n\n"
        f"收件箱: {os.getenv('PUBLIC_BASE_URL', 'https://www.study-assistant.cn')}/api/ops/inbox\n"
        f"修复包: {bundle_url}\n"
    )


def send_incident_email(
    *,
    incident: dict[str, Any],
    storage_dir: str | None,
) -> IncidentEmailResult:
    """Send an optional email notification with logs and screenshot attached."""
    recipients = _split_recipients(
        os.getenv("INCIDENT_ADMIN_EMAILS") or os.getenv("INCIDENT_ADMIN_EMAIL")
    )
    host = os.getenv("SMTP_HOST", "").strip()
    if not recipients or not host:
        return IncidentEmailResult(
            enabled=False,
            sent=False,
            message="email disabled: missing INCIDENT_ADMIN_EMAILS or SMTP_HOST",
        )

    use_ssl = _truthy(os.getenv("SMTP_USE_SSL"))
    use_tls = _truthy(os.getenv("SMTP_USE_TLS", "true")) and not use_ssl
    username = os.getenv("SMTP_USERNAME", "").strip()
    password = os.getenv("SMTP_PASSWORD", "")
    sender = (
        os.getenv("SMTP_FROM", "").strip()
        or username
        or f"study-assistant@{host}"
    )
    public_base = os.getenv("PUBLIC_BASE_URL", "https://www.study-assistant.cn").rstrip("/")
    bundle_url = f"{public_base}{incident.get('bundle_url', '')}"

    msg = EmailMessage()
    msg["Subject"] = f"[伴学反馈] #{incident.get('id')} {incident.get('route') or 'client incident'}"
    msg["From"] = sender
    msg["To"] = ", ".join(recipients)
    msg.set_content(_build_body(incident, bundle_url))

    folder = Path(storage_dir or "")
    if folder.is_dir():
        logs_path = folder / "client_logs.json"
        if logs_path.is_file():
            msg.add_attachment(
                logs_path.read_bytes(),
                maintype="application",
                subtype="json",
                filename="client_logs.json",
            )
        screenshot_path = folder / "screenshot.png"
        if screenshot_path.is_file():
            msg.add_attachment(
                screenshot_path.read_bytes(),
                maintype="image",
                subtype="png",
                filename="screenshot.png",
            )

    try:
        if use_ssl:
            with smtplib.SMTP_SSL(host, _smtp_port(use_ssl), timeout=15) as smtp:
                if username:
                    smtp.login(username, password)
                smtp.send_message(msg)
        else:
            with smtplib.SMTP(host, _smtp_port(use_ssl), timeout=15) as smtp:
                if use_tls:
                    smtp.starttls()
                if username:
                    smtp.login(username, password)
                smtp.send_message(msg)
    except Exception as exc:
        logger.warning("Incident email notification failed: %s", exc, exc_info=True)
        return IncidentEmailResult(enabled=True, sent=False, message=str(exc))

    return IncidentEmailResult(enabled=True, sent=True, message="sent")
