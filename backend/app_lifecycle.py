"""Application setup that is not specific to one API router."""

import os
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

logger = logging.getLogger(__name__)


def configure_cors(app: FastAPI) -> None:
    origins_env = os.getenv("CORS_ALLOWED_ORIGINS", "")
    origins = [origin.strip() for origin in origins_env.split(",") if origin.strip()]

    # "*" 通配符与 allow_credentials=True 不兼容，需要用 allow_origin_regex 代替
    if origins and origins != ["*"]:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=origins,
            allow_credentials=True,
            allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
            allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
        )
        return

    # 未配置或配置为 "*" 时，允许所有来源（用正则匹配任意 origin）
    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=r".*",
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
        allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
    )


def register_lifecycle(app: FastAPI) -> None:
    @app.on_event("startup")
    async def _startup() -> None:
        from database import init_db

        init_db()
        _mount_downloads(app)
        _warm_action_registry()
        _run_connectivity_guardian(app)


def register_system_routes(app: FastAPI) -> None:
    @app.get("/api/health")
    def health() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/api/app/version")
    def app_version() -> dict[str, str]:
        return {
            "version": os.getenv("APP_VERSION", "1.0.0"),
            "min_version": os.getenv("APP_MIN_VERSION", "1.0.0"),
            "download_url": os.getenv("APP_DOWNLOAD_URL", ""),
            "changelog": os.getenv("APP_CHANGELOG", ""),
        }


def _mount_downloads(app: FastAPI) -> None:
    downloads_dir = os.path.join(os.path.dirname(__file__), "downloads")
    os.makedirs(downloads_dir, exist_ok=True)
    app.mount("/downloads", StaticFiles(directory=downloads_dir), name="downloads")


def _warm_action_registry() -> None:
    # Import built-in executors so their @register_executor decorators run.
    import cas.executors.add_calendar_event  # noqa: F401
    import cas.executors.create_mini_app  # noqa: F401
    import cas.executors.explain_concept  # noqa: F401
    import cas.executors.generate_mindmap  # noqa: F401
    import cas.executors.make_plan  # noqa: F401
    import cas.executors.make_quiz  # noqa: F401
    import cas.executors.open_calendar  # noqa: F401
    import cas.executors.open_course_space  # noqa: F401
    import cas.executors.open_notebook  # noqa: F401
    import cas.executors.recommend_mistake_practice  # noqa: F401
    import cas.executors.solve_problem  # noqa: F401
    import cas.executors.start_feynman  # noqa: F401
    import cas.executors.unknown_intent  # noqa: F401
    from cas.action_registry import get_action_registry

    get_action_registry()

    try:
        from cas.wiring import assert_cas_wiring_ok

        assert_cas_wiring_ok(load_executors=False)
    except RuntimeError as exc:
        logger.error("CAS 接线检查失败：%s", exc)

    # 注册 Python 计算引擎 MCP 服务器。工具发现可能较慢，放到后台避免阻塞 API 启动。
    try:
        import threading
        from mcp_layer.mcp_registry import get_registry
        from mcp_layer.server_configs.python_executor_server import PYTHON_EXECUTOR_SERVER_CONFIG

        def _register_python_executor_mcp() -> None:
            try:
                registry = get_registry()
                registry.register_server(PYTHON_EXECUTOR_SERVER_CONFIG)
            except Exception as exc:
                import logging
                logging.getLogger(__name__).warning(
                    "Python 计算引擎 MCP 服务器注册失败（不影响其他功能）: %s", exc
                )

        threading.Thread(
            target=_register_python_executor_mcp,
            daemon=True,
            name="python-executor-mcp-register",
        ).start()
    except Exception as exc:
        import logging
        logging.getLogger(__name__).warning(
            "Python 计算引擎 MCP 服务器注册失败（不影响其他功能）: %s", exc
        )


def _run_connectivity_guardian(app: FastAPI) -> None:
    """启动时扫描关键 API；OPS_AUTO_FIX=1 时尝试补注册缺失路由。"""
    try:
        from ops.connectivity_guardian import run_scan, should_auto_fix_on_startup

        result = run_scan(app, auto_fix=should_auto_fix_on_startup())
        if result.issue_count:
            logger.warning(
                "连接守护：发现 %d 个接口异常（已修复 %d 项）",
                result.issue_count,
                result.fixes_applied,
            )
        if result.needs_restart:
            logger.warning("连接守护：已修改路由注册，请重启 study-assistant 服务后生效")
    except Exception as exc:
        logger.warning("连接守护启动扫描失败（非致命）: %s", exc)
