"""Critical API endpoints the Flutter app depends on."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class EndpointSpec:
    """One probe target."""

    path: str
    method: str = "GET"
    router_module: str | None = None  # e.g. mini_apps
    router_attr: str = "router"
    register_prefix: str | None = None  # e.g. /api/mini-apps
    ok_statuses: frozenset[int] = frozenset({200, 401, 403, 422})
    feature: str = ""


# 401/403 = route exists but needs auth; 404 = route missing (the main failure mode).
CRITICAL_ENDPOINTS: tuple[EndpointSpec, ...] = (
    EndpointSpec("/api/health", feature="基础健康检查"),
    EndpointSpec("/api/app/version", feature="应用更新"),
    EndpointSpec(
        "/api/mini-apps",
        router_module="mini_apps",
        register_prefix="/api/mini-apps",
        feature="学习小软件工坊",
    ),
    EndpointSpec(
        "/api/api-config",
        router_module="api_config",
        register_prefix="/api/api-config",
        feature="API 配置",
    ),
    EndpointSpec(
        "/api/capabilities",
        router_module="capabilities",
        register_prefix="/api/capabilities",
        feature="工具箱能力",
    ),
    EndpointSpec(
        "/api/library/subjects",
        router_module="library",
        register_prefix="/api/library",
        feature="课程空间",
    ),
    EndpointSpec(
        "/api/cas/actions",
        method="POST",
        router_module="cas",
        register_prefix="/api/cas",
        ok_statuses=frozenset({200, 401, 403, 422, 405}),
        feature="CAS 意图",
    ),
    EndpointSpec(
        "/api/solve/sessions",
        router_module="solve",
        register_prefix="/api/solve",
        feature="解题",
    ),
    EndpointSpec(
        "/api/study-planner/plans",
        router_module="study_planner",
        register_prefix="/api/study-planner",
        feature="学习规划",
    ),
)
