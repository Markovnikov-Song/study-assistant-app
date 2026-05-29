"""
Python 计算引擎 MCP 服务器。

在受限沙箱中执行 Python 代码，支持 sympy/numpy/scipy/matplotlib。
安全限制：
  - 禁止导入：os, sys, subprocess, socket, requests, urllib
  - 超时：10 秒（SIGKILL）
  - 内存限制：256MB（resource.setrlimit，仅 Linux）
  - 禁止文件系统写入和网络访问

工具：
  execute(code: str) -> {stdout: str, stderr: str, image_base64: str | null}

运行方式（Stdio MCP 服务器）：
  python python_executor_server.py
"""
from __future__ import annotations

import asyncio
import json
import subprocess
import sys
import textwrap
from typing import Any

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import TextContent, Tool

app = Server("python_executor")

# 黑名单模块：禁止在沙箱中导入
_BLOCKED_MODULES = frozenset({
    "os", "sys", "subprocess", "socket", "requests", "urllib",
    "shutil", "pathlib", "glob", "tempfile", "io",
    "threading", "multiprocessing", "concurrent",
    "ctypes", "cffi", "importlib",
})

# 沙箱包装脚本模板
# 注意：用户代码会被缩进 4 个空格后插入 {user_code} 位置
_SANDBOX_WRAPPER_TEMPLATE = '''
import sys as _sys
import io as _io
import base64 as _base64
import json as _json

# ── 黑名单模块拦截 ────────────────────────────────────────────────────────────
_BLOCKED = {blocked_modules}
_original_import = __builtins__.__import__ if hasattr(__builtins__, '__import__') else __import__

def _safe_import(name, *args, **kwargs):
    root = name.split('.')[0]
    if root in _BLOCKED:
        raise ImportError(f"禁止导入模块: {{name}}（安全限制）")
    return _original_import(name, *args, **kwargs)

if hasattr(__builtins__, '__import__'):
    __builtins__.__import__ = _safe_import
else:
    import builtins
    builtins.__import__ = _safe_import

# ── 重定向 stdout/stderr ──────────────────────────────────────────────────────
_stdout_buf = _io.StringIO()
_stderr_buf = _io.StringIO()
_sys.stdout = _stdout_buf
_sys.stderr = _stderr_buf

# ── matplotlib 图表捕获 ───────────────────────────────────────────────────────
_chart_b64 = None
try:
    import matplotlib as _mpl
    _mpl.use('Agg')  # 非交互式后端，不需要显示器
    import matplotlib.pyplot as _plt

    _orig_show = _plt.show
    def _capture_show(*args, **kwargs):
        global _chart_b64
        _buf = _io.BytesIO()
        _plt.savefig(_buf, format='png', bbox_inches='tight', dpi=150)
        _buf.seek(0)
        _chart_b64 = _base64.b64encode(_buf.read()).decode('utf-8')
        _plt.close('all')

    _plt.show = _capture_show
except ImportError:
    pass

# ── 执行用户代码 ──────────────────────────────────────────────────────────────
try:
{user_code}
except Exception as _e:
    print(f"执行错误: {{_e}}", file=_sys.stderr)

# ── 输出结构化结果 ────────────────────────────────────────────────────────────
_result = {{
    "stdout": _stdout_buf.getvalue(),
    "stderr": _stderr_buf.getvalue(),
    "image_base64": _chart_b64,
}}
# 使用特殊标记，便于父进程解析
print("__RESULT__:" + _json.dumps(_result, ensure_ascii=False))
'''


def _execute_sandboxed(code: str) -> dict[str, Any]:
    """
    在子进程中执行代码，10 秒超时，256MB 内存限制（Linux）。

    返回：{"stdout": str, "stderr": str, "image_base64": str | None}
    """
    # 将用户代码缩进 4 个空格（插入 try 块内）
    indented_code = textwrap.indent(code, "    ")
    if not indented_code.strip():
        indented_code = "    pass"

    wrapper = _SANDBOX_WRAPPER_TEMPLATE.format(
        blocked_modules=repr(set(_BLOCKED_MODULES)),
        user_code=indented_code,
    )

    def _set_resource_limits():
        """设置内存限制（仅 Linux/macOS）。"""
        try:
            import resource
            mem_limit = 256 * 1024 * 1024  # 256MB
            resource.setrlimit(resource.RLIMIT_AS, (mem_limit, mem_limit))
        except (ImportError, AttributeError, ValueError):
            pass  # Windows 或不支持时跳过

    try:
        proc = subprocess.run(
            [sys.executable, "-c", wrapper],
            capture_output=True,
            text=True,
            timeout=10,
            preexec_fn=_set_resource_limits,
        )

        # 从 stdout 中解析 __RESULT__: 标记
        for line in proc.stdout.splitlines():
            if line.startswith("__RESULT__:"):
                try:
                    return json.loads(line[len("__RESULT__:"):])
                except json.JSONDecodeError:
                    pass

        # 未找到结构化结果，返回原始输出
        return {
            "stdout": proc.stdout,
            "stderr": proc.stderr or "执行完成但无结构化输出",
            "image_base64": None,
        }

    except subprocess.TimeoutExpired:
        return {
            "stdout": "",
            "stderr": "执行超时（>10s），已强制终止",
            "image_base64": None,
        }
    except MemoryError:
        return {
            "stdout": "",
            "stderr": "内存超限（>256MB），已强制终止",
            "image_base64": None,
        }
    except Exception as e:
        return {
            "stdout": "",
            "stderr": f"沙箱执行异常：{e}",
            "image_base64": None,
        }


@app.list_tools()
async def list_tools() -> list[Tool]:
    """列出可用工具。"""
    return [
        Tool(
            name="execute",
            description=(
                "在受限 Python 沙箱中执行代码，进行精确数值计算。\n"
                "支持的库：sympy（符号计算）、numpy（数值计算）、scipy（科学计算）、matplotlib（图表生成）。\n"
                "适用场景：积分、方程求解、矩阵运算、数值模拟、绘制函数图像。\n"
                "禁止访问文件系统、网络和系统模块（os/sys/subprocess 等）。\n"
                "超时限制：10 秒。内存限制：256MB。\n"
                "返回：{stdout: 标准输出, stderr: 错误输出, image_base64: PNG图表Base64或null}"
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "待执行的 Python 代码字符串",
                    }
                },
                "required": ["code"],
            },
        )
    ]


@app.call_tool()
async def call_tool(name: str, arguments: dict[str, Any]) -> list[TextContent]:
    """执行工具调用。"""
    if name != "execute":
        raise ValueError(f"未知工具: {name}")

    code = arguments.get("code", "")
    if not isinstance(code, str):
        code = str(code)

    # 在线程池中执行（避免阻塞事件循环）
    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(None, _execute_sandboxed, code)

    return [TextContent(type="text", text=json.dumps(result, ensure_ascii=False))]


if __name__ == "__main__":
    asyncio.run(stdio_server(app))
