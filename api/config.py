"""
FastAPI 配置：从环境变量读取，与 Streamlit 的 st.secrets 版本并存。
"""
from __future__ import annotations
import os
from dataclasses import dataclass
from typing import Optional

_REQUIRED = [
    "DATABASE_URL", "LLM_API_KEY", "LLM_BASE_URL",
    "LLM_CHAT_MODEL", "LLM_EMBEDDING_MODEL", "JWT_SECRET",
]

@dataclass
class AppConfig:
    DATABASE_URL: str
    LLM_API_KEY: str
    LLM_BASE_URL: str
    LLM_CHAT_MODEL: str
    LLM_EMBEDDING_MODEL: str
    LLM_VISION_MODEL: str = "Qwen/Qwen2.5-VL-7B-Instruct"
    SIMILARITY_THRESHOLD: float = 0.3
    CHUNK_SIZE: int = 1000
    CHUNK_OVERLAP: int = 200
    TOP_K: int = 5
    JWT_SECRET: str = ""  # 必须在环境变量中设置
    JWT_EXPIRE_HOURS: int = 24 * 7  # 7 天

_config: Optional[AppConfig] = None

def get_config() -> AppConfig:
    global _config
    if _config is None:
        missing = [k for k in _REQUIRED if not os.getenv(k)]
        if missing:
            raise RuntimeError(f"缺少环境变量：{', '.join(missing)}")

        # JWT_SECRET 强度验证
        jwt_secret = os.getenv("JWT_SECRET", "")
        if len(jwt_secret) < 32:
            raise RuntimeError("JWT_SECRET 必须至少 32 个字符，请使用强随机密钥")

        _config = AppConfig(
            DATABASE_URL=os.environ["DATABASE_URL"],
            LLM_API_KEY=os.environ["LLM_API_KEY"],
            LLM_BASE_URL=os.environ["LLM_BASE_URL"],
            LLM_CHAT_MODEL=os.environ["LLM_CHAT_MODEL"],
            LLM_EMBEDDING_MODEL=os.environ["LLM_EMBEDDING_MODEL"],
            LLM_VISION_MODEL=os.getenv("LLM_VISION_MODEL", "Qwen/Qwen2.5-VL-7B-Instruct"),
            SIMILARITY_THRESHOLD=float(os.getenv("SIMILARITY_THRESHOLD", "0.3")),
            CHUNK_SIZE=int(os.getenv("CHUNK_SIZE", "1000")),
            CHUNK_OVERLAP=int(os.getenv("CHUNK_OVERLAP", "200")),
            TOP_K=int(os.getenv("TOP_K", "5")),
            JWT_SECRET=jwt_secret,
            JWT_EXPIRE_HOURS=int(os.getenv("JWT_EXPIRE_HOURS", str(24 * 7))),
        )
    return _config
