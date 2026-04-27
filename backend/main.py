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

from routers import auth, subjects, sessions, chat, documents, past_exams, exam_gen, ocr, notebooks, notes, users, hints, library, agent, mcp, marketplace, council, calendar, review, feedback, quiz, token
from routers import cas
from routers import study_planner
from routers import spec_chat

app = FastAPI(title="学科学习助手 API", version="1.0.0")

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
async def _startup():
    from database import init_db
    init_db()
    # 预热 ActionRegistry + 导入所有内置 Executor（触发 @register_executor 装饰器）
    from cas.action_registry import get_action_registry
    import cas.executors.unknown_intent          # noqa: F401
    import cas.executors.open_calendar           # noqa: F401
    import cas.executors.open_notebook           # noqa: F401
    import cas.executors.solve_problem           # noqa: F401
    import cas.executors.add_calendar_event      # noqa: F401
    import cas.executors.explain_concept         # noqa: F401
    import cas.executors.make_quiz               # noqa: F401
    import cas.executors.make_plan               # noqa: F401
    import cas.executors.recommend_mistake_practice  # noqa: F401
    import cas.executors.open_course_space           # noqa: F401
    import cas.executors.start_feynman               # noqa: F401
    get_action_registry()  # 触发 YAML 加载

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
app.include_router(calendar.router,   prefix="/api/calendar",   tags=["calendar"])
app.include_router(review.router,     prefix="/api/review",      tags=["review"])
app.include_router(feedback.router,  prefix="/api/feedback",    tags=["feedback"])
app.include_router(token.router,      prefix="/api/token",       tags=["token"])
app.include_router(quiz.router,      prefix="/api/quiz",        tags=["quiz"])
app.include_router(cas.router,       prefix="/api/cas",         tags=["cas"])
app.include_router(study_planner.router, prefix="/api/study-planner", tags=["study-planner"])
app.include_router(spec_chat.router,   prefix="/api/spec",      tags=["spec"])

@app.get("/api/health")
def health():
    return {"status": "ok"}
