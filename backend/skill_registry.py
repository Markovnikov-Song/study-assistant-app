"""
SkillRegistry — 从 YAML 文件加载内置 Skill 定义，替代 agent.py 中的硬编码列表。

用法：
    from skill_registry import get_registry

    registry = get_registry()
    skills = registry.list_skills()           # 全部 Skill
    skill  = registry.get_skill("skill_feynman")  # 单个 Skill
    skills = registry.filter(tag="理工科")    # 按标签过滤
    skills = registry.search("费曼")          # 按关键词搜索
"""
from __future__ import annotations

import logging
from pathlib import Path
from typing import Any, Optional

import yaml

logger = logging.getLogger(__name__)

_SKILLS_YAML = Path(__file__).parent / "prompts" / "skills" / "builtin.yaml"


class SkillRegistry:
    """
    单例 Skill 注册表。
    从 YAML 文件懒加载，支持热重载（调用 reload()）。
    """

    _instance: Optional["SkillRegistry"] = None
    _skills: list[dict[str, Any]] = []
    _index: dict[str, dict[str, Any]] = {}
    _loaded: bool = False

    def __new__(cls) -> "SkillRegistry":
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def _ensure_loaded(self) -> None:
        if not self._loaded:
            self._load()

    def _load(self) -> None:
        """从 YAML 文件加载 Skill 定义，失败时保留现有数据（降级）。"""
        try:
            with open(_SKILLS_YAML, encoding="utf-8") as f:
                data = yaml.safe_load(f)
            skills = data.get("skills", [])
            # 规范化 promptChain 字段：YAML 中 prompt 可能是多行字符串，strip 一下
            for skill in skills:
                for node in skill.get("promptChain", []):
                    if isinstance(node.get("prompt"), str):
                        node["prompt"] = node["prompt"].strip()
                    # 兼容 YAML 的 inputMapping / input_mapping 两种写法
                    if "input_mapping" in node and "inputMapping" not in node:
                        node["inputMapping"] = node.pop("input_mapping")
                    node.setdefault("inputMapping", {})
            self._skills = skills
            self._index = {s["id"]: s for s in skills}
            self._loaded = True
            logger.info("SkillRegistry: loaded %d skills from %s", len(skills), _SKILLS_YAML)
        except FileNotFoundError:
            logger.error("SkillRegistry: YAML file not found: %s", _SKILLS_YAML)
            self._loaded = True  # 防止反复重试
        except Exception as e:
            logger.error("SkillRegistry: failed to load skills: %s", e)
            self._loaded = True

    def reload(self) -> None:
        """清空缓存，重新从 YAML 加载（开发/热更新用）。"""
        self._loaded = False
        self._skills = []
        self._index = {}
        self._load()

    # ── 查询接口 ──────────────────────────────────────────────────────────────

    def list_skills(self) -> list[dict[str, Any]]:
        """返回所有 Skill 的完整定义列表。"""
        self._ensure_loaded()
        return list(self._skills)

    def get_skill(self, skill_id: str) -> Optional[dict[str, Any]]:
        """按 ID 获取单个 Skill，不存在返回 None。"""
        self._ensure_loaded()
        return self._index.get(skill_id)

    def filter(
        self,
        tag: Optional[str] = None,
        keyword: Optional[str] = None,
    ) -> list[dict[str, Any]]:
        """
        按标签和/或关键词过滤 Skill 列表。

        :param tag: 标签精确匹配（如 "理工科"）
        :param keyword: 关键词模糊匹配 name 和 description（不区分大小写）
        """
        self._ensure_loaded()
        skills = list(self._skills)

        if tag:
            skills = [s for s in skills if tag in s.get("tags", [])]

        if keyword:
            kw = keyword.lower()
            skills = [
                s for s in skills
                if kw in s.get("name", "").lower()
                or kw in s.get("description", "").lower()
            ]

        return skills

    def get_node(self, skill_id: str, node_id: str) -> Optional[dict[str, Any]]:
        """获取 Skill 中指定节点的定义。"""
        skill = self.get_skill(skill_id)
        if not skill:
            return None
        for node in skill.get("promptChain", []):
            if node.get("id") == node_id:
                return node
        return None

    def summaries(self) -> str:
        """
        生成供 LLM 参考的 Skill 摘要文本（用于 resolve-intent 提示词）。
        格式：- skill_id：name（description）[标签: tag1, tag2]
        """
        self._ensure_loaded()
        return "\n".join(
            f"- {s['id']}：{s['name']}（{s['description']}）[标签: {', '.join(s.get('tags', []))}]"
            for s in self._skills
        )


# ── 模块级单例访问 ─────────────────────────────────────────────────────────────

_registry: Optional[SkillRegistry] = None


def get_registry() -> SkillRegistry:
    """获取全局 SkillRegistry 单例。"""
    global _registry
    if _registry is None:
        _registry = SkillRegistry()
    return _registry
