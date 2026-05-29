"""FastAPI router registration."""

from fastapi import FastAPI

from routers import (
    agent,
    api_config,
    auth,
    ops,
    calendar,
    capabilities,
    cas,
    chat,
    council,
    documents,
    exam_prep,
    exam_gen,
    feedback,
    hints,
    library,
    marketplace,
    mcp,
    mini_apps,
    notebooks,
    notes,
    ocr,
    past_exams,
    planning,
    quiz,
    review,
    sessions,
    solve,
    spec_chat,
    study_planner,
    subjects,
    token,
    users,
)


def register_routers(app: FastAPI) -> None:
    app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
    app.include_router(subjects.router, prefix="/api/subjects", tags=["subjects"])
    app.include_router(sessions.router, prefix="/api/sessions", tags=["sessions"])
    app.include_router(chat.router, prefix="/api/chat", tags=["chat"])
    app.include_router(documents.router, prefix="/api/documents", tags=["documents"])
    app.include_router(past_exams.router, prefix="/api/past-exams", tags=["past-exams"])
    app.include_router(exam_prep.router, prefix="/api/exam-prep", tags=["exam-prep"])
    app.include_router(exam_gen.router, prefix="/api/exam", tags=["exam"])
    app.include_router(ocr.router, prefix="/api/ocr", tags=["ocr"])
    app.include_router(notebooks.router, prefix="/api/notebooks", tags=["notebooks"])
    app.include_router(notes.router, prefix="/api", tags=["notes"])
    app.include_router(users.router, prefix="/api/users", tags=["users"])
    app.include_router(hints.router, prefix="/api/hints", tags=["hints"])
    app.include_router(library.router, prefix="/api/library", tags=["library"])
    app.include_router(agent.router, prefix="/api/agent", tags=["agent"])
    app.include_router(mcp.router, prefix="/api/mcp", tags=["mcp"])
    app.include_router(mini_apps.router, prefix="/api/mini-apps", tags=["mini-apps"])
    app.include_router(marketplace.router, prefix="/api/marketplace", tags=["marketplace"])
    app.include_router(council.router, prefix="/api/council", tags=["council"])
    app.include_router(calendar.router, prefix="/api/calendar", tags=["calendar"])
    app.include_router(capabilities.router, prefix="/api/capabilities", tags=["capabilities"])
    app.include_router(review.router, prefix="/api/review", tags=["review"])
    app.include_router(feedback.router, prefix="/api/feedback", tags=["feedback"])
    app.include_router(quiz.router, prefix="/api/quiz", tags=["quiz"])
    app.include_router(api_config.router, prefix="/api/api-config", tags=["api-config"])
    app.include_router(token.router, prefix="/api/token", tags=["token"])
    app.include_router(cas.router, prefix="/api/cas", tags=["cas"])
    app.include_router(
        study_planner.router,
        prefix="/api/study-planner",
        tags=["study-planner"],
    )
    app.include_router(spec_chat.router, prefix="/api/spec", tags=["spec"])
    app.include_router(solve.router, prefix="/api/solve", tags=["solve"])
    app.include_router(planning.router, prefix="/api/planning", tags=["planning"])
    app.include_router(ops.router, prefix="/api/ops", tags=["ops"])
