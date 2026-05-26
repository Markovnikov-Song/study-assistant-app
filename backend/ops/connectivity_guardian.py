"""连接守护智能体：探测 404/断路由，并尝试安全自动修复。"""
from __future__ import annotations

import logging
import os
import re
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastapi import FastAPI
from fastapi.testclient import TestClient

from .api_manifest import CRITICAL_API_ENDPOINTS, ApiEndpointSpec

logger = logging.getLogger(__name__)

_BACKEND_ROOT = Path(__file__).resolve().parent.parent
_MAIN_PY = _BACKEND_ROOT / "main.py"
_APP_ROUTES_PY = _BACKEND_ROOT / "app_routes.py"
_ROUTERS_DIR = _BACKEND_ROOT / "routers"

_last_scan: dict[str, Any] | None = None


@dataclass
class EndpointIssue:
    path: str
    feature: str
    status_code: int
    issue_type: str  # route_missing | server_error | unreachable
    message: str
    router_module: str = ""
    fix_applied: bool = False
    fix_detail: str = ""


@dataclass
class GuardianScanResult:
    scanned_at: str
    ok_count: int
    issue_count: int
    issues: list[EndpointIssue] = field(default_factory=list)
    fixes_applied: int = 0
    needs_restart: bool = False

    def to_dict(self) -> dict[str, Any]:
        return {
            "scanned_at": self.scanned_at,
            "ok_count": self.ok_count,
            "issue_count": self.issue_count,
            "fixes_applied": self.fixes_applied,
            "needs_restart": self.needs_restart,
            "issues": [asdict(i) for i in self.issues],
        }


def _probe(client: TestClient, spec: ApiEndpointSpec) -> int:
    if spec.method == "HEAD":
        return client.head(spec.path).status_code
    if spec.method == "POST":
        return client.post(spec.path, json={}).status_code
    return client.get(spec.path).status_code


def _router_file_exists(module: str) -> bool:
    if not module:
        return True
    return (_ROUTERS_DIR / f"{module}.py").exists()


def _is_router_registered(module: str, prefix: str) -> bool:
    if not module:
        return True
    patterns = [
        f"{module}.router",
        f'prefix="{prefix}"',
        f"prefix='{prefix}'",
    ]
    for path in (_MAIN_PY, _APP_ROUTES_PY):
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        if all(p in text for p in (patterns[0], patterns[1])) or (
            patterns[0] in text and prefix in text
        ):
            return True
    return False


def _patch_main_py_register_router(module: str, prefix: str, tag: str) -> str | None:
    if not _MAIN_PY.exists():
        return None
    text = _MAIN_PY.read_text(encoding="utf-8")
    if f"{module}.router" in text and prefix in text:
        return None

    if f", {module}" not in text and "from routers import" in text:
        text = text.replace(
            "from routers import cas",
            f"from routers import cas\nfrom routers import {module}",
        )

    line = f'app.include_router({module}.router, prefix="{prefix}", tags=["{tag}"])'
    anchors = [
        "app.include_router(spec_chat.router",
        "app.include_router(study_planner.router",
        "app.include_router(mcp.router",
    ]
    for anchor in anchors:
        if anchor in text and line not in text:
            text = text.replace(anchor, f"{line}\n{anchor}", 1)
            break
    else:
        return None

    _MAIN_PY.write_text(text, encoding="utf-8")
    return f"已在 main.py 注册 {module} -> {prefix}（需重启后端生效）"


def _patch_app_routes(module: str, prefix: str, tag: str) -> str | None:
    if not _APP_ROUTES_PY.exists():
        return None
    text = _APP_ROUTES_PY.read_text(encoding="utf-8")
    if f"include_router({module}.router" in text:
        return None

    # 补 import
    m = re.search(r"from routers import \(([\s\S]*?)\)\n", text)
    if m and module not in m.group(1):
        block = m.group(1).rstrip()
        if not block.endswith(","):
            block += ","
        block += f"\n    {module},\n"
        text = text[: m.start(1)] + block + text[m.end(1) :]

    insert_line = (
        f'    app.include_router({module}.router, prefix="{prefix}", tags=["{tag}"])\n'
    )
    marker = "    app.include_router(planning.router"
    if marker in text and insert_line.strip() not in text:
        text = text.replace(marker, insert_line + marker)

    _APP_ROUTES_PY.write_text(text, encoding="utf-8")
    return f"已在 app_routes.py 注册 {module} -> {prefix}"


def try_auto_fix_route(spec: ApiEndpointSpec) -> str | None:
    module = spec.router_module
    prefix = spec.router_prefix
    if not module or not prefix:
        return None
    if not _router_file_exists(module):
        return None
    if _is_router_registered(module, prefix):
        return None

    tag = module.replace("_", "-")
    detail = _patch_app_routes(module, prefix, tag)
    if detail:
        return detail
    return _patch_main_py_register_router(module, prefix, tag)


def run_scan(app: FastAPI, *, auto_fix: bool = False) -> GuardianScanResult:
    global _last_scan
    client = TestClient(app, raise_server_exceptions=False)
    issues: list[EndpointIssue] = []
    ok_count = 0
    fixes = 0

    for spec in CRITICAL_API_ENDPOINTS:
        try:
            status = _probe(client, spec)
        except Exception as exc:
            issues.append(
                EndpointIssue(
                    path=spec.path,
                    feature=spec.feature,
                    status_code=0,
                    issue_type="unreachable",
                    message=str(exc),
                    router_module=spec.router_module,
                )
            )
            continue

        if status in spec.ok_statuses:
            ok_count += 1
            continue

        if status == 404 and spec.router_module:
            issue_type = "route_missing"
            msg = f"接口返回 404，可能未注册路由 {spec.router_prefix}"
            fix_detail = ""
            fix_applied = False
            if auto_fix:
                fix_detail = try_auto_fix_route(spec) or ""
                fix_applied = bool(fix_detail)
                if fix_applied:
                    fixes += 1
                    # 重新探测
                    status = _probe(client, spec)
                    if status in spec.ok_statuses:
                        ok_count += 1
                        continue
            issues.append(
                EndpointIssue(
                    path=spec.path,
                    feature=spec.feature,
                    status_code=status,
                    issue_type=issue_type,
                    message=msg,
                    router_module=spec.router_module,
                    fix_applied=fix_applied,
                    fix_detail=fix_detail,
                )
            )
        else:
            issues.append(
                EndpointIssue(
                    path=spec.path,
                    feature=spec.feature,
                    status_code=status,
                    issue_type="server_error",
                    message=f"异常状态码 {status}",
                    router_module=spec.router_module,
                )
            )

    result = GuardianScanResult(
        scanned_at=datetime.now(timezone.utc).isoformat(),
        ok_count=ok_count,
        issue_count=len(issues),
        issues=issues,
        fixes_applied=fixes,
        needs_restart=fixes > 0,
    )
    _last_scan = result.to_dict()

    for issue in issues:
        logger.warning(
            "[ConnectivityGuardian] %s %s — %s (%s)",
            issue.path,
            issue.feature,
            issue.message,
            issue.issue_type,
        )
    if fixes:
        logger.info("[ConnectivityGuardian] 自动修复 %d 项路由注册", fixes)

    return result


def get_last_scan() -> dict[str, Any] | None:
    return _last_scan


def should_auto_fix_on_startup() -> bool:
    return os.getenv("OPS_AUTO_FIX", "").lower() in ("1", "true", "yes")
