"""FastAPI application entrypoint.

Run from backend/:
    uvicorn main:app --reload --port 8000
"""

import os
import sys

from fastapi import FastAPI

sys.path.insert(0, os.path.dirname(__file__))

from app_lifecycle import configure_cors, register_lifecycle, register_system_routes
from app_routes import register_routers


def create_app() -> FastAPI:
    app = FastAPI(title="学科学习助手 API", version="1.0.0")
    configure_cors(app)
    register_lifecycle(app)
    register_routers(app)
    register_system_routes(app)
    return app


app = create_app()
