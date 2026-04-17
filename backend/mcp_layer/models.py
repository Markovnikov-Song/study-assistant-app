"""
MCP 接入层数据模型。

所有 Pydantic 模型用于 MCPClient、MCPRegistry 和 API 端点之间的数据传递。
"""
from __future__ import annotations

from enum import Enum
from typing import Any

from pydantic import BaseModel, field_validator


# ── 枚举 ──────────────────────────────────────────────────────────────────────


class MCPServerType(str, Enum):
    """MCP 服务器传输类型。"""
    local = "local"    # Stdio 传输，本地进程，无需网络
    remote = "remote"  # HTTP/SSE 传输，需要网络


class MCPServerStatus(str, Enum):
    """MCP 服务器连接状态。"""
    connected = "connected"
    disconnected = "disconnected"
    discovery_failed = "discovery_failed"  # 工具发现失败
    connecting = "connecting"


# ── 服务器配置 ─────────────────────────────────────────────────────────────────


class MCPServerConfig(BaseModel):
    """MCP 服务器注册配置。

    本地服务器（Stdio 传输）：填写 command + args。
    远程服务器（HTTP/SSE 传输）：填写 url。
    """
    server_id: str          # 唯一标识，用于工具引用前缀，如 "filesystem"
    name: str               # 人类可读名称，如 "本地文件系统"
    type: MCPServerType
    command: str | None = None   # 本地服务器启动命令，如 "npx"
    args: list[str] = []         # 启动参数，如 ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"]
    url: str | None = None       # 远程服务器地址，如 "http://localhost:8080/sse"
    env: dict[str, str] = {}     # 额外环境变量

    @field_validator("server_id")
    @classmethod
    def validate_server_id(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("server_id 不能为空")
        if "." in v:
            raise ValueError("server_id 不能包含点号（点号用于工具引用分隔符）")
        return v

    @field_validator("command", "url")
    @classmethod
    def validate_connection(cls, v: str | None) -> str | None:
        return v


# ── 工具定义 ───────────────────────────────────────────────────────────────────


class MCPToolDef(BaseModel):
    """MCP 工具定义，由工具发现接口返回后缓存在 MCPRegistry 中。"""
    server_id: str
    tool_name: str
    global_ref: str          # 格式严格为 "{server_id}.{tool_name}"，需求 1.3、2.3
    description: str
    input_schema: dict[str, Any] = {}   # JSON Schema，描述工具输入参数

    @field_validator("global_ref")
    @classmethod
    def validate_global_ref(cls, v: str, info: Any) -> str:
        """确保 global_ref 格式为 {server_id}.{tool_name}。属性 1。"""
        data = info.data if hasattr(info, "data") else {}
        server_id = data.get("server_id", "")
        tool_name = data.get("tool_name", "")
        if server_id and tool_name:
            expected = f"{server_id}.{tool_name}"
            if v != expected:
                raise ValueError(
                    f"global_ref 必须为 '{expected}'，实际为 '{v}'"
                )
        return v

    @classmethod
    def create(cls, server_id: str, tool_name: str, description: str, input_schema: dict | None = None) -> "MCPToolDef":
        """工厂方法，自动生成 global_ref。"""
        return cls(
            server_id=server_id,
            tool_name=tool_name,
            global_ref=f"{server_id}.{tool_name}",
            description=description,
            input_schema=input_schema or {},
        )


# ── 工具调用结果 ───────────────────────────────────────────────────────────────


class MCPToolResult(BaseModel):
    """MCP 工具调用结果。

    success=False 时不抛出异常，由调用方决定是否触发 Fallback_Handler。
    需求 1.5：超时或错误时返回此对象，Skill 执行继续。
    """
    success: bool
    data: dict[str, Any] = {}
    error_message: str | None = None
    fallback_triggered: bool = False   # 是否已触发 Fallback_Handler
    degraded: bool = False             # 标注该工具调用已降级，注入执行上下文


# ── 连接状态摘要 ───────────────────────────────────────────────────────────────


class MCPConnectionState(str, Enum):
    """MCP 整体连接状态，用于 UI 层状态指示器。需求 3.5。"""
    all_online = "all_online"    # 全部在线（含远程服务器）
    local_only = "local_only"    # 仅本地服务器可用
    offline = "offline"          # 全部不可用


class MCPConnectionSummary(BaseModel):
    """MCP 连接状态摘要，由 /api/mcp/status 端点返回。"""
    state: MCPConnectionState
    connected_servers: list[str] = []   # 已连接的 server_id 列表
    failed_servers: list[str] = []      # 连接失败的 server_id 列表
    total_tools: int = 0                # 当前可用工具总数


# ── 服务器信息（含状态） ───────────────────────────────────────────────────────


class MCPServerInfo(BaseModel):
    """已注册服务器的完整信息，包含配置和运行时状态。"""
    config: MCPServerConfig
    status: MCPServerStatus
    tools: list[MCPToolDef] = []
    error_message: str | None = None    # 连接或发现失败时的错误信息
