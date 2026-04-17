"""
本地文件系统 MCP 服务器配置。

使用官方 @modelcontextprotocol/server-filesystem（Node.js 实现）。
通过 npx 启动，无需全局安装。

工具列表（由服务器暴露）：
  filesystem.read_file       — 读取文件内容
  filesystem.write_file      — 写入文件内容
  filesystem.list_directory  — 列出目录内容
  filesystem.create_directory — 创建目录
  filesystem.delete_file     — 删除文件
  filesystem.move_file       — 移动/重命名文件
  filesystem.search_files    — 搜索文件
  filesystem.get_file_info   — 获取文件元信息
"""
from __future__ import annotations

import os

from mcp_layer.models import MCPServerConfig, MCPServerType

# 允许访问的根目录，默认为用户主目录下的学习数据目录
# 可通过环境变量 MCP_FILESYSTEM_ROOT 覆盖
_DEFAULT_ROOT = os.path.expanduser("~/learning_os_data")
FILESYSTEM_ROOT = os.getenv("MCP_FILESYSTEM_ROOT", _DEFAULT_ROOT)

FILESYSTEM_SERVER_CONFIG = MCPServerConfig(
    server_id="filesystem",
    name="本地文件系统",
    type=MCPServerType.local,
    command="npx",
    args=[
        "-y",
        "@modelcontextprotocol/server-filesystem",
        FILESYSTEM_ROOT,
    ],
    env={},
)
