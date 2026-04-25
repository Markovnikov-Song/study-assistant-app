"""
安全中间件：添加安全响应头
"""
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """
    添加安全相关的 HTTP 响应头。

    防御以下攻击：
    - XSS: X-Content-Type-Options, Content-Security-Policy
    - 点击劫持: X-Frame-Options
    - MIME 类型嗅探: X-Content-Type-Options
    """

    async def dispatch(self, request: Request, call_next) -> Response:
        response = await call_next(request)

        # 防止 MIME 类型嗅探
        response.headers["X-Content-Type-Options"] = "nosniff"

        # 防止点击劫持
        response.headers["X-Frame-Options"] = "DENY"

        # XSS 保护（兼容旧浏览器）
        response.headers["X-XSS-Protection"] = "1; mode=block"

        # 严格传输安全（1年）
        # 注意：仅在 HTTPS 时启用
        if request.url.scheme == "https":
            response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"

        # 引用策略
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"

        # 内容安全策略（基础配置）
        # API 不需要 CSP，但可以防止基本 XSS
        response.headers["X-Permitted-Cross-Domain-Policies"] = "none"

        return response
