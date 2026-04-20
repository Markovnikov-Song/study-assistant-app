"""
提示词管理器（backend 版）：从 YAML 文件加载提示词模板，支持变量替换。

用法：
    pm = PromptManager()
    system = pm.get("council/agents.yaml", "principal", **vars)
    user_msg = pm.get("agent/skill.yaml", "recommend_skill", field="user", **vars)
"""
from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, Optional

import yaml

_PROMPTS_DIR = Path(__file__).parent / "prompts"


class PromptManager:
    """单例提示词管理器，懒加载 YAML 文件，支持子目录。"""

    _instance: Optional["PromptManager"] = None
    _cache: Dict[str, Any] = {}

    def __new__(cls) -> "PromptManager":
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def _load(self, filename: str) -> Dict[str, Any]:
        """加载 YAML 文件，支持 'category/file.yaml' 路径。"""
        if filename not in self._cache:
            path = _PROMPTS_DIR / filename
            if not path.exists():
                raise FileNotFoundError(f"Prompt file not found: {path}")
            with open(path, encoding="utf-8") as f:
                self._cache[filename] = yaml.safe_load(f)
        return self._cache[filename]

    def get(self, filename: str, key: str, field: str = "system", **kwargs: Any) -> str:
        """
        获取提示词模板并填充变量。

        :param filename: YAML 文件路径（如 "council/agents.yaml"）
        :param key: 模板键（如 "principal"）
        :param field: 字段名（默认 "system"，可选 "user"）
        :param kwargs: 变量替换
        :return: 填充后的提示词字符串
        """
        data = self._load(filename)
        entry = data[key]
        if isinstance(entry, dict) and field in entry:
            template = entry[field]
        else:
            template = entry
        if kwargs:
            template = template.format(**kwargs)
        return template.strip()

    def reload(self) -> None:
        """清空缓存，下次访问时重新加载 YAML 文件。"""
        self._cache.clear()
