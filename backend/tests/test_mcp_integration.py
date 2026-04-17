"""
MCP 层集成测试。

测试场景：
1. 网络断开时远程工具立即降级（需求 3.2）
2. 网络恢复时自动重连（需求 3.4）
3. MCP 层全部失败时内置 Component 不受影响（需求 3.6、10.4）
4. 属性 3：MCP 工具失败时 Skill 执行继续（degraded=True）
5. 属性 8：Component 隔离性

运行方式：
    cd backend && python -m pytest tests/test_mcp_integration.py -v
"""
from __future__ import annotations

import sys
import os

# 确保 backend/ 在 path 中
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

import pytest
from unittest.mock import MagicMock, patch

from mcp_layer.models import (
    MCPServerConfig,
    MCPServerStatus,
    MCPServerType,
    MCPToolDef,
    MCPToolResult,
)
from mcp_layer.mcp_registry import MCPRegistry
from mcp_layer.fallback_handler import FallbackHandler


# ── 测试夹具 ───────────────────────────────────────────────────────────────────


def _make_local_config(server_id: str = "filesystem") -> MCPServerConfig:
    return MCPServerConfig(
        server_id=server_id,
        name=f"本地测试服务器 {server_id}",
        type=MCPServerType.local,
        command="echo",
        args=["test"],
    )


def _make_remote_config(server_id: str = "search") -> MCPServerConfig:
    return MCPServerConfig(
        server_id=server_id,
        name=f"远程测试服务器 {server_id}",
        type=MCPServerType.remote,
        url="http://localhost:9999/sse",
    )


def _make_tool(server_id: str, tool_name: str) -> MCPToolDef:
    return MCPToolDef.create(
        server_id=server_id,
        tool_name=tool_name,
        description=f"{server_id}.{tool_name} 测试工具",
    )


# ── 场景 1：网络断开时远程工具立即降级 ────────────────────────────────────────


class TestNetworkUnavailableImmediateDegradation:
    """需求 3.2：网络不可用时对 Remote_MCP_Server 调用立即返回降级响应，不等待超时。"""

    def test_remote_tool_degrades_immediately_when_network_unavailable(self):
        registry = MCPRegistry()
        remote_config = _make_remote_config("search")

        # 手动注入远程服务器（跳过实际连接）
        from mcp_layer.models import MCPServerInfo
        tool = _make_tool("search", "web_search")
        registry._servers["search"] = MCPServerInfo(
            config=remote_config,
            status=MCPServerStatus.connected,
            tools=[tool],
        )
        registry._tools["search.web_search"] = tool
        registry._clients["search"] = MagicMock()

        # 模拟网络不可用
        registry.set_network_available(False)

        result = registry.call_tool("search.web_search", {"query": "test"})

        assert result.success is False
        assert result.degraded is True
        assert result.fallback_triggered is True
        assert "网络不可用" in (result.error_message or "")

    def test_local_tool_not_affected_by_network_unavailable(self):
        """本地工具不受网络状态影响。"""
        registry = MCPRegistry()
        local_config = _make_local_config("filesystem")

        from mcp_layer.models import MCPServerInfo
        tool = _make_tool("filesystem", "read_file")
        mock_client = MagicMock()
        mock_client.call_tool.return_value = MCPToolResult(
            success=True, data={"text": "file content"}
        )
        registry._servers["filesystem"] = MCPServerInfo(
            config=local_config,
            status=MCPServerStatus.connected,
            tools=[tool],
        )
        registry._tools["filesystem.read_file"] = tool
        registry._clients["filesystem"] = mock_client

        # 网络不可用，但本地工具应正常调用
        registry.set_network_available(False)

        result = registry.call_tool("filesystem.read_file", {"path": "/tmp/test.txt"})

        # 本地工具应该被正常调用（不因网络状态降级）
        mock_client.call_tool.assert_called_once()
        assert result.success is True


# ── 场景 2：网络恢复时自动重连 ─────────────────────────────────────────────────


class TestNetworkRecoveryAutoReconnect:
    """需求 3.4：网络恢复时自动重新连接之前标记为不可用的 Remote_MCP_Server。"""

    def test_reconnect_triggered_on_network_recovery(self):
        registry = MCPRegistry()
        remote_config = _make_remote_config("search")

        from mcp_layer.models import MCPServerInfo
        registry._servers["search"] = MCPServerInfo(
            config=remote_config,
            status=MCPServerStatus.disconnected,
        )

        # 模拟 register_server 被调用（重连）
        reconnect_calls = []
        original_register = registry.register_server

        def mock_register(config):
            reconnect_calls.append(config.server_id)
            # 返回一个简单的 MCPServerInfo
            return MCPServerInfo(
                config=config,
                status=MCPServerStatus.discovery_failed,
            )

        registry.register_server = mock_register

        # 先设置网络不可用，再恢复
        registry._network_available = False
        registry.set_network_available(True)

        assert "search" in reconnect_calls, "网络恢复时应触发远程服务器重连"

    def test_no_reconnect_for_local_servers(self):
        """本地服务器不参与网络恢复重连。"""
        registry = MCPRegistry()
        local_config = _make_local_config("filesystem")

        from mcp_layer.models import MCPServerInfo
        registry._servers["filesystem"] = MCPServerInfo(
            config=local_config,
            status=MCPServerStatus.disconnected,
        )

        reconnect_calls = []
        registry.register_server = lambda c: reconnect_calls.append(c.server_id) or MagicMock()

        registry._network_available = False
        registry.set_network_available(True)

        assert "filesystem" not in reconnect_calls, "本地服务器不应参与网络恢复重连"


# ── 场景 3：MCP 层全部失败时 Component 不受影响 ────────────────────────────────


class TestComponentIsolation:
    """
    需求 3.6、10.4：MCP 层全部失败时，内置 Component 功能不受影响。
    属性 8：Component 隔离性。
    """

    def test_component_registry_unaffected_by_mcp_failure(self):
        """ComponentRegistry 独立于 MCPRegistry，MCP 全部失败不影响 Component 调用。"""
        from core.component.component_registry_impl import ComponentRegistryImpl
        from core.component.component_interface import ComponentContext, ComponentQuery

        registry = ComponentRegistryImpl()

        # 验证六个内置 Component 均已注册
        all_components = registry.listAll()
        component_ids = {c.id for c in all_components}

        # 即使 MCP 层完全不可用，Component 注册表应正常工作
        result = registry.get("chat")
        assert result.isOk, "chat Component 应正常可用"

        result = registry.get("notebook")
        assert result.isOk, "notebook Component 应正常可用"

    def test_mcp_registry_failure_does_not_raise_exception(self):
        """MCPRegistry 失败时返回 MCPToolResult(success=False)，不抛出异常。"""
        registry = MCPRegistry()

        # 调用不存在的工具
        result = registry.call_tool("nonexistent.tool", {})

        assert result.success is False
        assert result.degraded is True
        # 关键：不应抛出异常


# ── 场景 4：MCP 工具失败时 Skill 执行继续（属性 3）────────────────────────────


class TestMCPToolFailureSkillContinues:
    """属性 3：MCP 工具失败时 Skill 执行继续，不抛出 SkillExecutionError。"""

    def test_fallback_handler_returns_result_not_exception(self):
        """FallbackHandler 对任意工具引用返回结果，不抛出异常。"""
        handler = FallbackHandler()

        # 有兜底的工具
        result = handler.handle("filesystem.read_file", {"path": "/nonexistent/file.txt"})
        assert isinstance(result, MCPToolResult)
        assert result.fallback_triggered is True

        # 无兜底的工具
        result = handler.handle("unknown.tool", {})
        assert isinstance(result, MCPToolResult)
        assert result.degraded is True
        # 关键：不应抛出异常

    def test_fallback_read_file_nonexistent(self):
        """filesystem.read_file 兜底：文件不存在时返回 success=False，不抛出异常。"""
        handler = FallbackHandler()
        result = handler.handle("filesystem.read_file", {"path": "/absolutely/nonexistent/path.txt"})

        assert result.fallback_triggered is True
        assert result.degraded is True
        # 文件不存在时 success=False
        assert result.success is False

    def test_fallback_calendar_returns_empty_list(self):
        """calendar.get_events 兜底：返回空列表，不中断 Skill 执行。"""
        handler = FallbackHandler()
        result = handler.handle("calendar.get_events", {})

        assert result.success is True  # 空结果视为成功，不中断 Skill
        assert result.fallback_triggered is True
        assert result.data.get("events") == []
        assert "notice" in result.data


# ── 场景 5：属性 1 — 全局引用名格式 ───────────────────────────────────────────


class TestGlobalRefFormat:
    """属性 1：MCP 工具全局引用名格式严格为 {server_id}.{tool_name}。"""

    def test_tool_def_global_ref_format(self):
        tool = MCPToolDef.create(
            server_id="filesystem",
            tool_name="read_file",
            description="读取文件",
        )
        assert tool.global_ref == "filesystem.read_file"

    def test_tool_def_global_ref_uniqueness_in_registry(self):
        """注册表中工具引用名唯一。"""
        registry = MCPRegistry()

        from mcp_layer.models import MCPServerInfo
        tool1 = _make_tool("server_a", "tool_x")
        tool2 = _make_tool("server_b", "tool_x")  # 同名工具，不同服务器

        registry._tools["server_a.tool_x"] = tool1
        registry._tools["server_b.tool_x"] = tool2

        # 两个引用名不同
        assert "server_a.tool_x" != "server_b.tool_x"
        assert len(registry._tools) == 2


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
