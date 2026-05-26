"""关键 API 清单：连接守护智能体按此探测路由是否可达。"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Literal


@dataclass(frozen=True)
class ApiEndpointSpec:
    path: str
    method: Literal["GET", "POST", "HEAD"] = "GET"
    router_module: str = ""
    router_prefix: str = ""
    feature: str = ""
    # 路由存在时常见状态（401=需登录，403=无权限）
    ok_statuses: tuple[int, ...] = (200, 401, 403, 405)


CRITICAL_API_ENDPOINTS: tuple[ApiEndpointSpec, ...] = (
    ApiEndpointSpec("/api/health", feature="服务健康", ok_statuses=(200,)),
    ApiEndpointSpec("/api/app/version", feature="版本检查", ok_statuses=(200,)),
    ApiEndpointSpec(
        "/api/mini-apps",
        router_module="mini_apps",
        router_prefix="/api/mini-apps",
        feature="学习小软件工坊",
    ),
    ApiEndpointSpec(
        "/api/api-config",
        router_module="api_config",
        router_prefix="/api/api-config",
        feature="API 配置",
    ),
    ApiEndpointSpec(
        "/api/capabilities",
        router_module="capabilities",
        router_prefix="/api/capabilities",
        feature="工具箱能力",
    ),
    ApiEndpointSpec(
        "/api/library/subjects",
        router_module="library",
        router_prefix="/api/library",
        feature="课程空间",
    ),
    ApiEndpointSpec(
        "/api/cas/actions",
        router_module="cas",
        router_prefix="/api/cas",
        feature="CAS 动作",
    ),
    ApiEndpointSpec(
        "/api/study-planner/plans",
        router_module="study_planner",
        router_prefix="/api/study-planner",
        feature="学习规划",
    ),
    ApiEndpointSpec(
        "/api/planning/plans",
        router_module="planning",
        router_prefix="/api/planning",
        feature="自动化规划",
    ),
    ApiEndpointSpec(
        "/api/solve/sessions",
        router_module="solve",
        router_prefix="/api/solve",
        feature="解题",
    ),
)
