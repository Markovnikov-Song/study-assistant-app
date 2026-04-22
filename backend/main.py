"""
FastAPI 入口。
运行方式（在 backend/ 目录下）：
    uvicorn main:app --reload --port 8000
"""
import sys, os
# backend/ 自身加入 path 最前面（book_services 包需要）
sys.path.insert(0, os.path.dirname(__file__))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers import auth, subjects, sessions, chat, documents, past_exams, exam_gen, ocr, notebooks, notes, users, hints, library, agent, mcp, marketplace, council

app = FastAPI(title="学科学习助手 API", version="1.0.0")

# CORS：开发环境默认只允许本地，生产部署时通过 CORS_ALLOWED_ORIGINS 环境变量配置
# 示例：CORS_ALLOWED_ORIGINS=https://app.example.com,https://www.example.com
_cors_origins_env = os.getenv("CORS_ALLOWED_ORIGINS", "")
_cors_origins = [o.strip() for o in _cors_origins_env.split(",") if o.strip()]

if _cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
else:
    # 未配置时仅允许本地开发
    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

@app.on_event("startup")
async def _startup():
    from database import init_db
    init_db()

app.include_router(auth.router,       prefix="/api/auth",       tags=["auth"])
app.include_router(subjects.router,   prefix="/api/subjects",   tags=["subjects"])
app.include_router(sessions.router,   prefix="/api/sessions",   tags=["sessions"])
app.include_router(chat.router,       prefix="/api/chat",       tags=["chat"])
app.include_router(documents.router,  prefix="/api/documents",  tags=["documents"])
app.include_router(past_exams.router, prefix="/api/past-exams", tags=["past-exams"])
app.include_router(exam_gen.router,   prefix="/api/exam",       tags=["exam"])
app.include_router(ocr.router,        prefix="/api/ocr",        tags=["ocr"])
app.include_router(notebooks.router,  prefix="/api/notebooks",  tags=["notebooks"])
app.include_router(notes.router,      prefix="/api",            tags=["notes"])
app.include_router(users.router,      prefix="/api/users",      tags=["users"])
app.include_router(hints.router,      prefix="/api/hints",      tags=["hints"])
app.include_router(library.router,    prefix="/api/library",    tags=["library"])
app.include_router(agent.router,      prefix="/api/agent",      tags=["agent"])
app.include_router(mcp.router,        prefix="/api/mcp",        tags=["mcp"])
app.include_router(marketplace.router, prefix="/api/marketplace", tags=["marketplace"])
app.include_router(council.router,    prefix="/api/council",    tags=["council"])

@app.get("/api/health")
def health():
    return {"status": "ok"}
