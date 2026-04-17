"""
网页搜索 MCP 服务器配置（可选，远程）。

通过 HTTP/SSE 传输连接网页搜索服务。
需要网络连接，不可用时自动降级（需求 3.2）。

工具列表（预期）：
  search.web_search    — 搜索网页内容
  search.fetch_page    — 获取指定 URL 的页面内容
"""
from __future__ import annotations

import os

from mcp_layer.models import MCPServerConfig, MCPServerType

# 通过环境变量配置搜索服务地址，未配置则不注册
WEB_SEARCH_SERVER_URL = os.getenv("MCP_WEB_SEARCH_SERVER_URL", "")

WEB_SEARCH_SERVER_CONFIG: MCPServerConfig | None = None
if WEB_SEARCH_SERVER_URL:
    WEB_SEARCH_SERVER_CONFIG = MCPServerConfig(
        server_id="search",
        name="网页搜索服务",
        type=MCPServerType.remote,
        url=WEB_SEARCH_SERVER_URL,
    )
