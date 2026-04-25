"""FastAPI 应用入口。"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.routers import auth, subjects, sessions, chat, documents, past_exams, exam_gen, ocr, token_management, payment
from api.security_headers import SecurityHeadersMiddleware
from database import init_db

app = FastAPI(title="学科学习助手 API", version="1.0.0")

# 安全中间件（按添加顺序从外到内执行）
app.add_middleware(SecurityHeadersMiddleware)

# CORS 安全配置
_cors_origins_env = os.getenv("CORS_ALLOWED_ORIGINS", "")
_cors_origins = [o.strip() for o in _cors_origins_env.split(",") if o.strip()]

if _cors_origins:
    # 生产环境：使用明确配置的 origin 列表
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_cors_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
        allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
    )
else:
    # 开发环境：限制本地网络
    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=r"http://(localhost|127\.0\.0\.1|192\.168\.\d+\.\d+)(:\d+)?",
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
        allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
    )

@app.on_event("startup")
async def startup():
    # 用 api/config 覆盖 streamlit config，让 services/ 共用同一套逻辑
    import api.config as api_cfg
    import config as st_cfg
    # 将 api 的 get_config 注入到根目录 config 模块
    st_cfg.get_config = api_cfg.get_config
    init_db()

app.include_router(auth.router,       prefix="/api/auth",       tags=["auth"])
app.include_router(subjects.router,   prefix="/api/subjects",   tags=["subjects"])
app.include_router(sessions.router,   prefix="/api/sessions",   tags=["sessions"])
app.include_router(chat.router,       prefix="/api/chat",       tags=["chat"])
app.include_router(documents.router,  prefix="/api/documents",  tags=["documents"])
app.include_router(past_exams.router, prefix="/api/past-exams", tags=["past-exams"])
app.include_router(exam_gen.router,   prefix="/api/exam",       tags=["exam-gen"])
app.include_router(ocr.router,        prefix="/api/ocr",        tags=["ocr"])
app.include_router(token_management.router, prefix="/api/token", tags=["token-management"])
app.include_router(payment.router, prefix="/api/payment", tags=["payment"])

@app.get("/api/health")
def health():
    return {"status": "ok"}
