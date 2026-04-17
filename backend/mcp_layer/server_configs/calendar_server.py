"""
本地日历 MCP 服务器配置。

使用 mcp-server-calendar（Python 实现，读写系统日历）。
阶段一：配置骨架，实际连接在阶段二验证。

工具列表（预期）：
  calendar.get_events    — 查询日历事件
  calendar.create_event  — 创建日历事件
  calendar.delete_event  — 删除日历事件
"""
from __future__ import annotations

from mcp_layer.models import MCPServerConfig, MCPServerType

CALENDAR_SERVER_CONFIG = MCPServerConfig(
    server_id="calendar",
    name="本地日历",
    type=MCPServerType.local,
    command="uvx",
    args=["mcp-server-calendar"],
    env={},
)
