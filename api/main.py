"""
FastAPI 应用入口。
"""
import os
# 让 config.py 的 get_config() 能被 services/ 里的代码调用
# （services/ 里 import config 时会找到根目录的 config.py，
#  但 get_config() 需要从环境变量读，所以这里做一个 monkey-patch）
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.routers import auth, subjects, sessions, chat, documents, past_exams, exam_gen, ocr
from database import init_db

app = FastAPI(title="学科学习助手 API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
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

@app.get("/api/health")
def health():
    return {"status": "ok"}
