"""
MCPClient — 封装官方 mcp Python SDK，支持 Stdio（本地）和 HTTP/SSE（远程）两种传输。

由 MCPRegistry 持有，对 Skill 执行层透明。
超时或错误时返回 MCPToolResult(success=False)，不抛出异常。
"""
from __future__ import annotations

import asyncio
import logging
from contextlib import asynccontextmanager
from typing import Any

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

from .models import MCPServerConfig, MCPServerType, MCPToolDef, MCPToolResult

logger = logging.getLogger(__name__)


class MCPClient:
    """
    封装官方 mcp SDK，提供工具发现和工具调用两个核心能力。

    设计原则：
    - 所有方法均为同步接口（内部用 asyncio.run 驱动异步 SDK）
    - 超时或错误时返回 MCPToolResult(success=False)，不抛出异常（需求 1.5）
    - 每次调用独立建立连接，无长连接状态（简化错误处理）
    """

    def __init__(self, config: MCPServerConfig) -> None:
        self._config = config

    # ── 工具发现 ───────────────────────────────────────────────────────────────

    def discover_tools(self) -> list[MCPToolDef]:
        """
        调用服务器的工具发现接口，返回工具定义列表。
        发现失败时返回空列表并记录日志，不抛出异常（需求 2.5）。
        """
        try:
            return asyncio.run(self._async_discover_tools())
        except Exception as exc:
            logger.warning("MCP 工具发现失败 server_id=%s: %s", self._config.server_id, exc)
            return []

    async def _async_discover_tools(self) -> list[MCPToolDef]:
        async with self._session_context() as session:
            result = await session.list_tools()
            return [
                MCPToolDef.create(
                    server_id=self._config.server_id,
                    tool_name=tool.name,
                    description=tool.description or "",
                    input_schema=tool.inputSchema if hasattr(tool, "inputSchema") else {},
                )
                for tool in result.tools
            ]

    # ── 工具调用 ───────────────────────────────────────────────────────────────

    def call_tool(
        self,
        tool_name: str,
        arguments: dict[str, Any],
        timeout_seconds: float = 10.0,
    ) -> MCPToolResult:
        """
        调用指定工具。超时或错误时返回 MCPToolResult(success=False)，不抛出异常。
        需求 1.5。
        """
        try:
            return asyncio.run(
                asyncio.wait_for(
                    self._async_call_tool(tool_name, arguments),
                    timeout=timeout_seconds,
                )
            )
        except asyncio.TimeoutError:
            logger.warning(
                "MCP 工具调用超时 server_id=%s tool=%s timeout=%.1fs",
                self._config.server_id, tool_name, timeout_seconds,
            )
            return MCPToolResult(
                success=False,
                error_message=f"工具调用超时（>{timeout_seconds}s）",
                fallback_triggered=True,
                degraded=True,
            )
        except Exception as exc:
            logger.warning(
                "MCP 工具调用失败 server_id=%s tool=%s: %s",
                self._config.server_id, tool_name, exc,
            )
            return MCPToolResult(
                success=False,
                error_message=str(exc),
                fallback_triggered=True,
                degraded=True,
            )

    async def _async_call_tool(self, tool_name: str, arguments: dict[str, Any]) -> MCPToolResult:
        async with self._session_context() as session:
            result = await session.call_tool(tool_name, arguments)
            content_data: dict[str, Any] = {}
            if result.content:
                texts = [c.text for c in result.content if hasattr(c, "text") and c.text]
                if texts:
                    content_data["text"] = "\n".join(texts)
                content_data["raw"] = [
                    c.model_dump() if hasattr(c, "model_dump") else str(c)
                    for c in result.content
                ]
            return MCPToolResult(
                success=not (result.isError if hasattr(result, "isError") else False),
                data=content_data,
            )

    # ── 连接上下文管理器 ───────────────────────────────────────────────────────

    @asynccontextmanager
    async def _session_context(self):
        """根据服务器类型建立对应的传输连接。"""
        if self._config.type == MCPServerType.local:
            async with self._stdio_session_ctx() as session:
                yield session
        else:
            async with self._sse_session_ctx() as session:
                yield session

    @asynccontextmanager
    async def _stdio_session_ctx(self):
        """建立 Stdio 传输会话（本地进程）。"""
        if not self._config.command:
            raise ValueError(f"本地 MCP 服务器 '{self._config.server_id}' 未配置 command")
        params = StdioServerParameters(
            command=self._config.command,
            args=self._config.args,
            env=self._config.env or None,
        )
        async with stdio_client(params) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                yield session

    @asynccontextmanager
    async def _sse_session_ctx(self):
        """建立 HTTP/SSE 传输会话（远程服务器）。需求 1.1、2.1。"""
        if not self._config.url:
            raise ValueError(f"远程 MCP 服务器 '{self._config.server_id}' 未配置 url")
        try:
            from mcp.client.sse import sse_client
        except ImportError:
            raise RuntimeError("mcp[sse] 未安装，请运行 pip install 'mcp[sse]'")

        async with sse_client(self._config.url) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                yield session
