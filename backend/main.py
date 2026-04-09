"""
FastAPI 入口。
运行方式（在 backend/ 目录下）：
    uvicorn main:app --reload --port 8000
"""
import sys, os
# 把 study_assistant_streamlit/ 加入 path，
# 这样 `from database import ...`、`from services.xxx import ...` 都能找到
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "study_assistant_streamlit"))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# ── 关键：在导入任何 services/ 之前，把 streamlit config 替换成环境变量版本 ──
import config as _st_config
import backend_config as _api_config
_st_config.get_config = _api_config.get_config

from routers import auth, subjects, sessions, chat, documents, past_exams, exam_gen, ocr, notebooks, notes, users

app = FastAPI(title="学科学习助手 API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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

@app.get("/api/health")
def health():
    return {"status": "ok"}
