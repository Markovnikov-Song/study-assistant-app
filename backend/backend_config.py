"""
FastAPI 配置：从环境变量读取，接口与 Streamlit 版 config.py 完全一致，
services/ 里的 `from config import get_config` 会优先找到这个文件。
"""
from __future__ import annotations
import os
from dataclasses import dataclass
from typing import Optional

# 自动加载 backend/.env
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))

_REQUIRED = ["DATABASE_URL", "LLM_API_KEY", "LLM_BASE_URL", "LLM_CHAT_MODEL", "LLM_EMBEDDING_MODEL"]

@dataclass
class AppConfig:
    DATABASE_URL: str
    LLM_API_KEY: str
    LLM_BASE_URL: str
    LLM_CHAT_MODEL: str
    LLM_EMBEDDING_MODEL: str
    LLM_VISION_MODEL: str = "Qwen/Qwen2.5-VL-7B-Instruct"
    # PGVector cosine 距离阈值：距离 < 阈值才视为相关（0=完全相同，2=完全相反）
    # BGE-M3 实测：相关内容距离通常在 0.2~0.5，0.7 是合理上限
    SIMILARITY_THRESHOLD: float = 0.7
    CHUNK_SIZE: int = 800
    CHUNK_OVERLAP: int = 150
    TOP_K: int = 8
    JWT_SECRET: str = "change-me-in-production"
    JWT_EXPIRE_HOURS: int = 24 * 7

_config: Optional[AppConfig] = None

def get_config() -> AppConfig:
    global _config
    if _config is None:
        missing = [k for k in _REQUIRED if not os.getenv(k)]
        if missing:
            raise RuntimeError(f"缺少环境变量：{', '.join(missing)}")
        _config = AppConfig(
            DATABASE_URL=os.environ["DATABASE_URL"],
            LLM_API_KEY=os.environ["LLM_API_KEY"],
            LLM_BASE_URL=os.environ["LLM_BASE_URL"],
            LLM_CHAT_MODEL=os.environ["LLM_CHAT_MODEL"],
            LLM_EMBEDDING_MODEL=os.environ["LLM_EMBEDDING_MODEL"],
            LLM_VISION_MODEL=os.getenv("LLM_VISION_MODEL", "Qwen/Qwen2.5-VL-7B-Instruct"),
            SIMILARITY_THRESHOLD=float(os.getenv("SIMILARITY_THRESHOLD", "0.7")),
            CHUNK_SIZE=int(os.getenv("CHUNK_SIZE", "800")),
            CHUNK_OVERLAP=int(os.getenv("CHUNK_OVERLAP", "150")),
            TOP_K=int(os.getenv("TOP_K", "8")),
            JWT_SECRET=os.getenv("JWT_SECRET", "change-me-in-production"),
            JWT_EXPIRE_HOURS=int(os.getenv("JWT_EXPIRE_HOURS", str(24 * 7))),
        )
    return _config

def reset_config() -> None:
    global _config
    _config = None
