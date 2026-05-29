"""
Python 计算引擎 MCP 服务器注册配置。

本地 Stdio MCP 服务器，在独立子进程中运行 python_executor_server.py。
"""
from __future__ import annotations

import os
import sys

from mcp_layer.models import MCPServerConfig, MCPServerType

# python_executor_server.py 的绝对路径
_SERVER_SCRIPT = os.path.join(
    os.path.dirname(__file__),   # .../backend/mcp_layer/server_configs/
    "..",                         # .../backend/mcp_layer/
    "..",                         # .../backend/
    "mcp_servers",
    "python_executor_server.py",
)
_SERVER_SCRIPT = os.path.normpath(_SERVER_SCRIPT)

PYTHON_EXECUTOR_SERVER_CONFIG = MCPServerConfig(
    server_id="python_executor",
    name="Python 计算引擎",
    type=MCPServerType.local,
    command=sys.executable,   # 使用当前 Python 解释器
    args=[_SERVER_SCRIPT],
    env={},
)
