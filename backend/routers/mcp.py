"""
mcp.py — MCP 管理路由
挂载在 /api/mcp

端点：
  GET    /api/mcp/status              — 返回 MCPConnectionSummary
  GET    /api/mcp/servers             — 列出所有已注册服务器及状态
  POST   /api/mcp/servers             — 注册新服务器（触发工具发现）
  DELETE /api/mcp/servers/{server_id} — 注销服务器，清除工具缓存
  GET    /api/mcp/tools               — 查询工具列表（支持过滤）
  POST   /api/mcp/tools/call          — 直接调用工具（调试用，需认证）
"""
from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from deps import get_current_user
from mcp_layer.mcp_registry import get_registry
from mcp_layer.models import (
    MCPConnectionSummary,
    MCPServerConfig,
    MCPServerInfo,
    MCPServerStatus,
    MCPToolDef,
    MCPToolResult,
)

router = APIRouter()


# ── Pydantic 请求/响应模型 ─────────────────────────────────────────────────────


class RegisterServerRequest(BaseModel):
    """注册 MCP 服务器的请求体。"""
    server_id: str
    name: str
    type: str                          # "local" | "remote"
    command: Optional[str] = None      # 本地服务器启动命令
    args: list[str] = []
    url: Optional[str] = None          # 远程服务器地址
    env: dict[str, str] = {}


class CallToolRequest(BaseModel):
    """直接调用 MCP 工具的请求体（调试用）。"""
    tool_ref: str                      # "{server_id}.{tool_name}"
    arguments: dict = {}
    timeout_seconds: float = 10.0


# ── 端点实现 ───────────────────────────────────────────────────────────────────


@router.get("/status", response_model=MCPConnectionSummary)
def get_status(user=Depends(get_current_user)):
    """
    返回 MCP 整体连接状态摘要。
    需求 3.5：区分全部在线 / 仅本地 / 离线模式三种状态。
    """
    registry = get_registry()
    return registry.get_connection_summary()


@router.get("/servers", response_model=list[MCPServerInfo])
def list_servers(user=Depends(get_current_user)):
    """列出所有已注册 MCP 服务器及其状态和工具列表。"""
    registry = get_registry()
    return registry.list_servers()


@router.post("/servers", response_model=MCPServerInfo)
def register_server(body: RegisterServerRequest, user=Depends(get_current_user)):
    """
    注册新 MCP 服务器，自动触发工具发现。
    发现失败时返回 discovery_failed 状态，不返回 4xx/5xx（需求 2.5）。
    """
    from mcp_layer.models import MCPServerType

    try:
        server_type = MCPServerType(body.type)
    except ValueError:
        raise HTTPException(400, f"不支持的服务器类型 '{body.type}'，请使用 'local' 或 'remote'")

    config = MCPServerConfig(
        server_id=body.server_id,
        name=body.name,
        type=server_type,
        command=body.command,
        args=body.args,
        url=body.url,
        env=body.env,
    )

    registry = get_registry()
    info = registry.register_server(config)
    return info


@router.delete("/servers/{server_id}")
def unregister_server(server_id: str, user=Depends(get_current_user)):
    """
    注销 MCP 服务器，清除该服务器的所有工具缓存（需求 2.4）。
    """
    registry = get_registry()
    if registry.get_server(server_id) is None:
        raise HTTPException(404, f"服务器 '{server_id}' 未注册")
    registry.unregister_server(server_id)
    return {"ok": True, "server_id": server_id}


@router.get("/tools", response_model=list[MCPToolDef])
def list_tools(
    server_id: Optional[str] = None,
    tool_name: Optional[str] = None,
    status: Optional[str] = None,
    user=Depends(get_current_user),
):
    """
    查询工具列表，支持按 server_id、tool_name、status 过滤（需求 2.6）。
    属性 6：返回结果中所有条目均满足过滤条件。
    """
    status_enum: MCPServerStatus | None = None
    if status is not None:
        try:
            status_enum = MCPServerStatus(status)
        except ValueError:
            raise HTTPException(
                400,
                f"不支持的状态值 '{status}'，可选值：connected / disconnected / discovery_failed / connecting",
            )

    registry = get_registry()
    return registry.list_tools(
        server_id=server_id,
        tool_name=tool_name,
        status=status_enum,
    )


@router.post("/tools/call", response_model=MCPToolResult)
def call_tool(body: CallToolRequest, user=Depends(get_current_user)):
    """
    直接调用 MCP 工具（调试用，需认证）。
    工具不存在或调用失败时返回 MCPToolResult(success=False)，不抛出 5xx。
    """
    if "." not in body.tool_ref:
        raise HTTPException(
            400,
            f"工具引用格式错误 '{body.tool_ref}'，正确格式为 {{server_id}}.{{tool_name}}",
        )

    registry = get_registry()
    result = registry.call_tool(
        tool_ref=body.tool_ref,
        arguments=body.arguments,
        timeout_seconds=body.timeout_seconds,
    )
    return result
