from __future__ import annotations

import json
import threading
import uuid
from pathlib import Path
from typing import Any

from .models import MiniAppRecord, MiniAppVersion, now_iso

_STORE_PATH = Path(__file__).parent.parent / "data" / "mini_apps.json"
_VERSION_PATH = Path(__file__).parent.parent / "data" / "mini_app_versions.json"
_SESSION_PATH = Path(__file__).parent.parent / "data" / "mini_app_interviews.json"
_RUN_PATH = Path(__file__).parent.parent / "data" / "mini_app_runs.json"
_LOCK = threading.Lock()


def _read(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _write(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def list_apps(user_id: int | str) -> list[MiniAppRecord]:
    with _LOCK:
        data = _read(_STORE_PATH)
        raw_apps = data.get(str(user_id), [])
    apps: list[MiniAppRecord] = []
    for raw in raw_apps:
        try:
            apps.append(MiniAppRecord(**raw))
        except Exception:
            continue
    return sorted(apps, key=lambda app: app.updated_at, reverse=True)


def get_app(user_id: int | str, app_id: str) -> MiniAppRecord | None:
    for app in list_apps(user_id):
        if app.id == app_id:
            return app
    return None


def save_app(user_id: int | str, app: MiniAppRecord) -> MiniAppRecord:
    with _LOCK:
        data = _read(_STORE_PATH)
        key = str(user_id)
        apps = data.setdefault(key, [])
        payload = app.model_dump(mode="json")
        replaced = False
        for index, item in enumerate(apps):
            if item.get("id") == app.id:
                apps[index] = payload
                replaced = True
                break
        if not replaced:
            apps.append(payload)
        _write(_STORE_PATH, data)
    return app


def list_app_versions(user_id: int | str, app_id: str) -> list[MiniAppVersion]:
    with _LOCK:
        data = _read(_VERSION_PATH)
        raw_versions = data.get(str(user_id), {}).get(app_id, [])
    versions: list[MiniAppVersion] = []
    for raw in raw_versions:
        try:
            versions.append(MiniAppVersion(**raw))
        except Exception:
            continue
    return sorted(versions, key=lambda item: item.sequence, reverse=True)


def get_app_version(user_id: int | str, app_id: str, version_id: str) -> MiniAppVersion | None:
    for version in list_app_versions(user_id, app_id):
        if version.id == version_id:
            return version
    return None


def has_app_version(user_id: int | str, app_id: str, version_id: str | None) -> bool:
    if not version_id:
        return False
    return get_app_version(user_id, app_id, version_id) is not None


def create_app_version(
    user_id: int | str,
    app: MiniAppRecord,
    *,
    source: str,
    instruction: str | None = None,
    changed: list[str] | None = None,
    summary: str | None = None,
) -> MiniAppVersion:
    with _LOCK:
        data = _read(_VERSION_PATH)
        user_versions = data.setdefault(str(user_id), {})
        versions = user_versions.setdefault(app.id, [])
        sequence = len(versions) + 1
        parent_version_id = app.current_version_id
        created = now_iso()
        version_id = f"{app.id}_v{sequence}"
        app.current_version_id = version_id
        snapshot = app.model_dump(mode="json")
        version = MiniAppVersion(
            id=version_id,
            app_id=app.id,
            user_id=str(user_id),
            sequence=sequence,
            parent_version_id=parent_version_id,
            source=source,
            instruction=instruction,
            changed=changed or [],
            summary=summary or _version_summary(app, source, changed or []),
            snapshot=snapshot,
            created_at=created,
        )
        versions.append(version.model_dump(mode="json"))
        _write(_VERSION_PATH, data)
    return version


def ensure_app_version(
    user_id: int | str,
    app: MiniAppRecord,
    *,
    source: str = "backfill",
) -> MiniAppRecord:
    if has_app_version(user_id, app.id, app.current_version_id):
        return app
    create_app_version(user_id, app, source=source, summary="为历史小工具补建版本快照")
    return save_app(user_id, app)


def _version_summary(app: MiniAppRecord, source: str, changed: list[str]) -> str:
    changed_text = "、".join(changed) if changed else "小工具配置"
    return f"{source} 更新：{app.title}（{changed_text}）"


def delete_app(user_id: int | str, app_id: str) -> bool:
    with _LOCK:
        data = _read(_STORE_PATH)
        key = str(user_id)
        apps = data.get(key, [])
        next_apps = [item for item in apps if item.get("id") != app_id]
        if len(next_apps) == len(apps):
            return False
        data[key] = next_apps
        _write(_STORE_PATH, data)
        version_data = _read(_VERSION_PATH)
        user_versions = version_data.get(key)
        if isinstance(user_versions, dict) and app_id in user_versions:
            user_versions.pop(app_id, None)
            _write(_VERSION_PATH, version_data)
        return True


def create_session(user_id: int | str, initial_request: str, subject_id: int | None) -> dict[str, Any]:
    session = {
        "id": str(uuid.uuid4()),
        "user_id": str(user_id),
        "initial_request": initial_request,
        "subject_id": subject_id,
        "answers": [],
        "created_at": now_iso(),
        "updated_at": now_iso(),
    }
    with _LOCK:
        data = _read(_SESSION_PATH)
        data[session["id"]] = session
        _write(_SESSION_PATH, data)
    return session


def get_session(session_id: str) -> dict[str, Any] | None:
    with _LOCK:
        data = _read(_SESSION_PATH)
        session = data.get(session_id)
    return session if isinstance(session, dict) else None


def append_answer(session_id: str, answer: str) -> dict[str, Any] | None:
    with _LOCK:
        data = _read(_SESSION_PATH)
        session = data.get(session_id)
        if not isinstance(session, dict):
            return None
        session.setdefault("answers", []).append(answer)
        session["updated_at"] = now_iso()
        data[session_id] = session
        _write(_SESSION_PATH, data)
    return session


def create_run(
    user_id: int | str,
    app_id: str,
    graph: dict[str, Any],
    *,
    app_version_id: str | None = None,
    app_snapshot: dict[str, Any] | None = None,
) -> dict[str, Any]:
    created = now_iso()
    run = {
        "id": str(uuid.uuid4()),
        "user_id": str(user_id),
        "app_id": app_id,
        "app_version_id": app_version_id,
        "status": "running",
        "graph_version": graph.get("schema_version", "unknown"),
        "entry": graph.get("entry"),
        "graph_snapshot": graph,
        "app_snapshot": app_snapshot or {},
        "events": [],
        "created_at": created,
        "updated_at": created,
    }
    with _LOCK:
        data = _read(_RUN_PATH)
        data[run["id"]] = run
        _write(_RUN_PATH, data)
    return run


def get_run(run_id: str) -> dict[str, Any] | None:
    with _LOCK:
        data = _read(_RUN_PATH)
        run = data.get(run_id)
    return run if isinstance(run, dict) else None


def append_run_event(
    user_id: int | str,
    run_id: str,
    node_id: str,
    event_type: str,
    payload: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, Any]] | None:
    with _LOCK:
        data = _read(_RUN_PATH)
        run = data.get(run_id)
        if not isinstance(run, dict) or str(run.get("user_id")) != str(user_id):
            return None
        event = {
            "id": str(uuid.uuid4()),
            "node_id": node_id,
            "event_type": event_type,
            "payload": payload,
            "created_at": now_iso(),
        }
        run.setdefault("events", []).append(event)
        if event_type in {"session_completed", "run_completed"}:
            run["status"] = "completed"
        run["updated_at"] = now_iso()
        data[run_id] = run
        _write(_RUN_PATH, data)
    return run, event
