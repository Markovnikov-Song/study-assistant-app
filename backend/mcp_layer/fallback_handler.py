"""
FallbackHandler — 当 MCP 工具不可用时执行的硬编码兜底逻辑。

设计原则：
- AI 完全不参与兜底逻辑，所有实现均为硬编码（需求 3.3）
- 无对应兜底时返回空结果并标注 degraded=True，Skill 执行继续（需求 1.5）
- 兜底实现尽量简单可靠，不引入新的失败点
"""
from __future__ import annotations

import logging
import os
from typing import Any, Callable

from .models import MCPToolResult

logger = logging.getLogger(__name__)


# ── 兜底实现函数 ───────────────────────────────────────────────────────────────


def _fallback_read_file(arguments: dict[str, Any]) -> MCPToolResult:
    """
    filesystem.read_file 的兜底：直接读取本地文件系统。
    参数：path (str)
    """
    path = arguments.get("path", "")
    if not path:
        return MCPToolResult(
            success=False,
            error_message="read_file 兜底：缺少 path 参数",
            fallback_triggered=True,
            degraded=True,
        )
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            content = f.read()
        return MCPToolResult(
            success=True,
            data={"text": content, "path": path},
            fallback_triggered=True,
            degraded=True,  # 标注为降级，即使成功也告知调用方走了兜底路径
        )
    except FileNotFoundError:
        return MCPToolResult(
            success=False,
            error_message=f"文件不存在：{path}",
            fallback_triggered=True,
            degraded=True,
        )
    except PermissionError:
        return MCPToolResult(
            success=False,
            error_message=f"无权限读取文件：{path}",
            fallback_triggered=True,
            degraded=True,
        )
    except Exception as exc:
        return MCPToolResult(
            success=False,
            error_message=f"读取文件失败：{exc}",
            fallback_triggered=True,
            degraded=True,
        )


def _fallback_write_file(arguments: dict[str, Any]) -> MCPToolResult:
    """
    filesystem.write_file 的兜底：直接写入本地文件系统。
    参数：path (str), content (str)
    """
    path = arguments.get("path", "")
    content = arguments.get("content", "")
    if not path:
        return MCPToolResult(
            success=False,
            error_message="write_file 兜底：缺少 path 参数",
            fallback_triggered=True,
            degraded=True,
        )
    try:
        os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        return MCPToolResult(
            success=True,
            data={"path": path, "bytes_written": len(content.encode("utf-8"))},
            fallback_triggered=True,
            degraded=True,
        )
    except PermissionError:
        return MCPToolResult(
            success=False,
            error_message=f"无权限写入文件：{path}",
            fallback_triggered=True,
            degraded=True,
        )
    except Exception as exc:
        return MCPToolResult(
            success=False,
            error_message=f"写入文件失败：{exc}",
            fallback_triggered=True,
            degraded=True,
        )


def _fallback_list_directory(arguments: dict[str, Any]) -> MCPToolResult:
    """
    filesystem.list_directory 的兜底：直接列出目录内容。
    参数：path (str)
    """
    path = arguments.get("path", ".")
    try:
        entries = os.listdir(path)
        return MCPToolResult(
            success=True,
            data={"entries": entries, "path": path},
            fallback_triggered=True,
            degraded=True,
        )
    except Exception as exc:
        return MCPToolResult(
            success=False,
            error_message=f"列出目录失败：{exc}",
            fallback_triggered=True,
            degraded=True,
        )


def _fallback_calendar_get_events(arguments: dict[str, Any]) -> MCPToolResult:
    """
    calendar.get_events 的兜底：返回空列表并附带提示信息（需求 3.3）。
    日历服务不可用时，不阻塞 Skill 执行，提示用户手动查看。
    """
    return MCPToolResult(
        success=True,  # 返回空结果视为成功，不中断 Skill
        data={
            "events": [],
            "notice": "日历服务暂时不可用，请手动查看系统日历。",
        },
        fallback_triggered=True,
        degraded=True,
    )


def _fallback_calendar_create_event(arguments: dict[str, Any]) -> MCPToolResult:
    """
    calendar.create_event 的兜底：记录待创建事件信息，提示用户手动添加。
    """
    title = arguments.get("title", "未命名事件")
    start = arguments.get("start", "")
    return MCPToolResult(
        success=True,
        data={
            "created": False,
            "notice": f"日历服务暂时不可用，请手动添加事件：{title}（{start}）",
            "pending_event": arguments,
        },
        fallback_triggered=True,
        degraded=True,
    )


# ── FallbackHandler 主类 ───────────────────────────────────────────────────────


class FallbackHandler:
    """
    硬编码兜底实现。
    每个工具引用对应一个 fallback 函数，AI 完全不参与兜底逻辑（需求 3.3）。

    FALLBACK_MAP 键为工具全局引用名（{server_id}.{tool_name}）。
    """

    FALLBACK_MAP: dict[str, Callable[[dict[str, Any]], MCPToolResult]] = {
        "filesystem.read_file":       _fallback_read_file,
        "filesystem.write_file":      _fallback_write_file,
        "filesystem.list_directory":  _fallback_list_directory,
        "calendar.get_events":        _fallback_calendar_get_events,
        "calendar.create_event":      _fallback_calendar_create_event,
    }

    def handle(self, tool_ref: str, arguments: dict[str, Any]) -> MCPToolResult:
        """
        执行兜底逻辑。
        若无对应兜底，返回空结果并标注 degraded=True，Skill 执行继续（需求 1.5）。
        """
        fallback_fn = self.FALLBACK_MAP.get(tool_ref)
        if fallback_fn is None:
            logger.warning(
                "MCP 工具 '%s' 无对应兜底实现，返回空结果（degraded）",
                tool_ref,
            )
            return MCPToolResult(
                success=True,   # 不中断 Skill 执行
                data={},
                error_message=f"工具 '{tool_ref}' 不可用且无兜底实现",
                fallback_triggered=True,
                degraded=True,
            )

        logger.info("触发兜底实现 tool_ref=%s", tool_ref)
        return fallback_fn(arguments)

    def has_fallback(self, tool_ref: str) -> bool:
        """检查指定工具是否有兜底实现。"""
        return tool_ref in self.FALLBACK_MAP


# ── 全局单例 ───────────────────────────────────────────────────────────────────

_fallback_handler: FallbackHandler | None = None


def get_fallback_handler() -> FallbackHandler:
    """获取全局 FallbackHandler 单例。"""
    global _fallback_handler
    if _fallback_handler is None:
        _fallback_handler = FallbackHandler()
    return _fallback_handler
