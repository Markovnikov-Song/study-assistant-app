"""
MCPRegistry — 统一管理多个 MCP 服务器的连接状态和工具缓存。

工具全局引用名格式：{server_id}.{tool_name}
本地优先策略：同名工具优先选择 Local_MCP_Server（需求 3.1）。
网络状态监听：后台线程定期检测远程服务器可达性，网络恢复时自动重连（需求 3.4）。
"""
from __future__ import annotations

import logging
import threading
import time
from threading import Lock

from .mcp_client import MCPClient
from .models import (
    MCPConnectionState,
    MCPConnectionSummary,
    MCPServerConfig,
    MCPServerInfo,
    MCPServerStatus,
    MCPServerType,
    MCPToolDef,
    MCPToolResult,
)

logger = logging.getLogger(__name__)

# 网络检测间隔（秒）- 从配置读取
def _get_reconnect_interval() -> int:
    from backend_config import get_config
    return get_config().MCP_RECONNECT_INTERVAL_SECONDS


class MCPRegistry:
    """
    注册表，维护所有 MCP 服务器的配置、状态和工具缓存。

    线程安全：所有读写操作通过 _lock 保护。
    """

    def __init__(self) -> None:
        self._servers: dict[str, MCPServerInfo] = {}   # server_id → MCPServerInfo
        self._tools: dict[str, MCPToolDef] = {}        # global_ref → MCPToolDef
        self._clients: dict[str, MCPClient] = {}       # server_id → MCPClient
        self._lock = Lock()
        # 网络状态监听后台线程
        self._reconnect_thread: threading.Thread | None = None
        self._stop_reconnect = threading.Event()
        self._network_available: bool = True

    # ── 服务器注册 / 注销 ──────────────────────────────────────────────────────

    def register_server(self, config: MCPServerConfig) -> MCPServerInfo:
        """
        注册服务器并自动触发工具发现。
        发现失败时标记为 discovery_failed，不中断其他服务器（需求 2.5）。
        返回注册后的服务器信息。
        """
        client = MCPClient(config)

        with self._lock:
            # 若已注册，先清除旧工具缓存
            if config.server_id in self._servers:
                self._remove_server_tools(config.server_id)

            # 标记为 connecting
            info = MCPServerInfo(config=config, status=MCPServerStatus.connecting)
            self._servers[config.server_id] = info
            self._clients[config.server_id] = client

        # 工具发现（在锁外执行，避免阻塞其他操作）
        tools = client.discover_tools()

        with self._lock:
            if tools:
                # 注册工具到缓存（需求 2.2）
                for tool in tools:
                    self._tools[tool.global_ref] = tool
                info = MCPServerInfo(
                    config=config,
                    status=MCPServerStatus.connected,
                    tools=tools,
                )
                logger.info(
                    "MCP 服务器注册成功 server_id=%s 工具数=%d",
                    config.server_id,
                    len(tools),
                )
            else:
                # 工具发现失败（需求 2.5）
                info = MCPServerInfo(
                    config=config,
                    status=MCPServerStatus.discovery_failed,
                    error_message="工具发现返回空列表或失败",
                )
                logger.warning(
                    "MCP 服务器工具发现失败 server_id=%s，标记为 discovery_failed",
                    config.server_id,
                )
            self._servers[config.server_id] = info

        return info

    def unregister_server(self, server_id: str) -> None:
        """
        注销服务器，清除该服务器的所有工具缓存（需求 2.4）。
        属性 4：注销后 list_tools(server_id=id) 应返回空列表。
        """
        with self._lock:
            if server_id not in self._servers:
                return
            self._remove_server_tools(server_id)
            del self._servers[server_id]
            self._clients.pop(server_id, None)
            logger.info("MCP 服务器已注销 server_id=%s", server_id)

    def _remove_server_tools(self, server_id: str) -> None:
        """从工具缓存中移除指定服务器的所有工具（内部方法，调用前需持有锁）。"""
        to_remove = [
            ref for ref, tool in self._tools.items()
            if tool.server_id == server_id
        ]
        for ref in to_remove:
            del self._tools[ref]

    # ── 工具查找 ───────────────────────────────────────────────────────────────

    def get_tool(self, tool_ref: str) -> MCPToolDef | None:
        """
        按 {server_id}.{tool_name} 格式查找工具定义。
        本地优先策略：同名工具优先返回 Local_MCP_Server 的版本（需求 3.1，属性 7）。

        tool_ref 可以是：
        - 完整引用 "filesystem.read_file"
        - 仅工具名 "read_file"（此时按本地优先策略搜索）
        """
        with self._lock:
            # 完整引用直接查找
            if "." in tool_ref:
                return self._tools.get(tool_ref)

            # 仅工具名：本地优先搜索
            return self._find_by_tool_name(tool_ref)

    def _find_by_tool_name(self, tool_name: str) -> MCPToolDef | None:
        """按工具名搜索，本地服务器优先（内部方法，调用前需持有锁）。"""
        local_match: MCPToolDef | None = None
        remote_match: MCPToolDef | None = None

        for tool in self._tools.values():
            if tool.tool_name != tool_name:
                continue
            server_info = self._servers.get(tool.server_id)
            if server_info and server_info.config.type == MCPServerType.local:
                local_match = tool
            else:
                remote_match = tool

        return local_match or remote_match

    # ── 工具列表查询 ───────────────────────────────────────────────────────────

    def list_tools(
        self,
        server_id: str | None = None,
        tool_name: str | None = None,
        status: MCPServerStatus | None = None,
    ) -> list[MCPToolDef]:
        """
        查询工具列表，支持按服务器 ID、工具名称、连接状态过滤（需求 2.6）。
        属性 6：返回结果中所有条目均满足过滤条件。
        """
        with self._lock:
            results = list(self._tools.values())

            if server_id is not None:
                results = [t for t in results if t.server_id == server_id]

            if tool_name is not None:
                results = [t for t in results if t.tool_name == tool_name]

            if status is not None:
                # 按服务器状态过滤
                valid_server_ids = {
                    sid for sid, info in self._servers.items()
                    if info.status == status
                }
                results = [t for t in results if t.server_id in valid_server_ids]

            return results

    # ── 服务器列表查询 ─────────────────────────────────────────────────────────

    def list_servers(self) -> list[MCPServerInfo]:
        """列出所有已注册服务器及其状态。"""
        with self._lock:
            return list(self._servers.values())

    def get_server(self, server_id: str) -> MCPServerInfo | None:
        """获取单个服务器信息。"""
        with self._lock:
            return self._servers.get(server_id)

    # ── 连接状态摘要 ───────────────────────────────────────────────────────────

    def get_connection_summary(self) -> MCPConnectionSummary:
        """
        返回整体连接状态摘要（需求 3.5）。
        - all_online：所有服务器（含远程）均已连接
        - local_only：至少一个本地服务器连接，但远程服务器不可用
        - offline：无任何服务器连接
        """
        with self._lock:
            connected = [
                sid for sid, info in self._servers.items()
                if info.status == MCPServerStatus.connected
            ]
            failed = [
                sid for sid, info in self._servers.items()
                if info.status in (
                    MCPServerStatus.disconnected,
                    MCPServerStatus.discovery_failed,
                )
            ]

            has_local_connected = any(
                self._servers[sid].config.type == MCPServerType.local
                for sid in connected
            )
            has_remote_connected = any(
                self._servers[sid].config.type == MCPServerType.remote
                for sid in connected
            )
            has_remote_registered = any(
                info.config.type == MCPServerType.remote
                for info in self._servers.values()
            )

            if not connected:
                state = MCPConnectionState.offline
            elif has_remote_registered and not has_remote_connected:
                state = MCPConnectionState.local_only
            else:
                state = MCPConnectionState.all_online

            return MCPConnectionSummary(
                state=state,
                connected_servers=connected,
                failed_servers=failed,
                total_tools=len(self._tools),
            )

    # ── 工具调用（委托给 MCPClient） ───────────────────────────────────────────

    def call_tool(
        self,
        tool_ref: str,
        arguments: dict,
        timeout_seconds: float = 10.0,
    ) -> MCPToolResult:
        """
        调用工具。本地优先策略（需求 3.1）。
        网络不可用时对 Remote_MCP_Server 立即返回降级响应，不等待超时（需求 3.2）。
        工具不存在时返回 MCPToolResult(success=False)。
        """
        tool = self.get_tool(tool_ref)
        if tool is None:
            return MCPToolResult(
                success=False,
                error_message=f"工具 '{tool_ref}' 未在 MCP_Registry 中注册",
                degraded=True,
            )

        # 网络不可用时，远程工具立即降级（需求 3.2）
        with self._lock:
            server_info = self._servers.get(tool.server_id)
        if (
            server_info is not None
            and server_info.config.type == MCPServerType.remote
            and not self._network_available
        ):
            logger.info(
                "网络不可用，远程工具 '%s' 立即降级，不等待超时",
                tool_ref,
            )
            return MCPToolResult(
                success=False,
                error_message="网络不可用，远程工具已降级",
                fallback_triggered=True,
                degraded=True,
            )

        client = self._clients.get(tool.server_id)
        if client is None:
            return MCPToolResult(
                success=False,
                error_message=f"服务器 '{tool.server_id}' 的客户端不存在",
                degraded=True,
            )

        return client.call_tool(
            tool_name=tool.tool_name,
            arguments=arguments,
            timeout_seconds=timeout_seconds,
        )

    # ── 网络状态监听与自动重连 ─────────────────────────────────────────────────

    def start_reconnect_monitor(self) -> None:
        """
        启动后台线程，定期检测远程服务器可达性，网络恢复时自动重连（需求 3.4）。
        幂等：已启动时不重复启动。
        """
        if self._reconnect_thread is not None and self._reconnect_thread.is_alive():
            return
        self._stop_reconnect.clear()
        self._reconnect_thread = threading.Thread(
            target=self._reconnect_loop,
            daemon=True,
            name="mcp-reconnect-monitor",
        )
        self._reconnect_thread.start()
        logger.info("MCP 自动重连监听器已启动（间隔 %ds）", _get_reconnect_interval())

    def stop_reconnect_monitor(self) -> None:
        """停止后台重连监听线程。"""
        self._stop_reconnect.set()
        if self._reconnect_thread is not None:
            from backend_config import get_config
            self._reconnect_thread.join(timeout=get_config().MCP_STOP_MONITOR_TIMEOUT_SECONDS)
            self._reconnect_thread = None

    def set_network_available(self, available: bool) -> None:
        """
        手动设置网络可用状态（供测试和外部网络监听器调用）。
        网络恢复时触发远程服务器重连（需求 3.4）。
        """
        was_unavailable = not self._network_available
        self._network_available = available
        if available and was_unavailable:
            logger.info("网络已恢复，触发远程 MCP 服务器重连")
            self._reconnect_failed_remote_servers()

    def _reconnect_loop(self) -> None:
        """后台重连循环：定期检测网络并重连失败的远程服务器。"""
        while not self._stop_reconnect.wait(timeout=_get_reconnect_interval()):
            self._check_and_reconnect()

    def _check_and_reconnect(self) -> None:
        """检测网络可达性，对失败的远程服务器尝试重连。"""
        # 简单网络检测：尝试连接 DNS 服务器
        network_ok = self._ping_network()
        prev = self._network_available
        self._network_available = network_ok

        if network_ok and not prev:
            logger.info("网络恢复，触发远程 MCP 服务器重连")
            self._reconnect_failed_remote_servers()
        elif not network_ok and prev:
            logger.warning("网络不可用，远程 MCP 工具将立即降级")

    def _ping_network(self) -> bool:
        """简单网络可达性检测（连接 8.8.8.8:53）。"""
        import socket
        try:
            socket.setdefaulttimeout(3)
            socket.socket(socket.AF_INET, socket.SOCK_STREAM).connect(
                ("8.8.8.8", 53)
            )
            return True
        except OSError:
            return False

    def _reconnect_failed_remote_servers(self) -> None:
        """对所有 disconnected/discovery_failed 的远程服务器尝试重连（需求 3.4）。"""
        with self._lock:
            failed_remote = [
                info.config
                for info in self._servers.values()
                if (
                    info.config.type == MCPServerType.remote
                    and info.status in (
                        MCPServerStatus.disconnected,
                        MCPServerStatus.discovery_failed,
                    )
                )
            ]

        for config in failed_remote:
            logger.info("尝试重连远程 MCP 服务器 server_id=%s", config.server_id)
            self.register_server(config)


# ── 全局单例 ───────────────────────────────────────────────────────────────────

_registry: MCPRegistry | None = None


def get_registry() -> MCPRegistry:
    """获取全局 MCPRegistry 单例。"""
    global _registry
    if _registry is None:
        _registry = MCPRegistry()
    return _registry
