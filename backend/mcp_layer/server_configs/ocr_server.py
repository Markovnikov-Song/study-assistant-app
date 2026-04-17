"""
云端 OCR MCP 服务器配置（可选，远程）。

通过 HTTP/SSE 传输连接云端 OCR 服务。
需要网络连接，不可用时自动降级（需求 3.2）。

工具列表（预期）：
  ocr.recognize_image  — 识别图片中的文字
  ocr.extract_table    — 提取图片中的表格
"""
from __future__ import annotations

import os

from mcp_layer.models import MCPServerConfig, MCPServerType

# 通过环境变量配置 OCR 服务地址，未配置则不注册
OCR_SERVER_URL = os.getenv("MCP_OCR_SERVER_URL", "")

OCR_SERVER_CONFIG: MCPServerConfig | None = None
if OCR_SERVER_URL:
    OCR_SERVER_CONFIG = MCPServerConfig(
        server_id="ocr",
        name="云端 OCR 服务",
        type=MCPServerType.remote,
        url=OCR_SERVER_URL,
    )
