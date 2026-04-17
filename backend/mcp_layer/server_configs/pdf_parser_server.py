"""
本地 PDF 解析 MCP 服务器配置。

使用 mcp-server-pdf（基于 pymupdf，本地解析 PDF 文件）。
阶段一：配置骨架，实际连接在阶段二验证。

工具列表（预期）：
  pdf.extract_text   — 提取 PDF 文本内容
  pdf.extract_pages  — 提取指定页范围的文本
  pdf.get_metadata   — 获取 PDF 元信息（标题、作者、页数等）
"""
from __future__ import annotations

from mcp_layer.models import MCPServerConfig, MCPServerType

PDF_PARSER_SERVER_CONFIG = MCPServerConfig(
    server_id="pdf",
    name="本地 PDF 解析",
    type=MCPServerType.local,
    command="uvx",
    args=["mcp-server-pdf"],
    env={},
)
