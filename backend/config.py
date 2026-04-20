# 兼容层：services/ 里的 `from config import get_config` 会找到这里
from backend_config import get_config, AppConfig, reset_config

__all__ = ["get_config", "AppConfig", "reset_config"]
