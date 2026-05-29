"""
Skill 智能调度服务
根据学习阶段和知识点推荐合适的 Skill
"""
from __future__ import annotations
import logging
from typing import Optional, List, Dict, Any
from enum import Enum

logger = logging.getLogger(__name__)


class LearningPhase(str, Enum):
    LEARN = "learn"      # 学习新知识
    PRACTICE = "practice"  # 巩固练习
    REVIEW = "review"    # 阶段复盘


class SkillDispatcher:
    """Skill 调度器"""
    
    # 知识点到 Skill 的映射（初始数据，可以从数据库加载）
    NODE_SKILL_DEFAULT_MAP = {
        # 学习新知识阶段
        "learn": [
            {"skill_id": "mindmap_learning", "name": "思维导图学习", "weight": 0.4},
            {"skill_id": "feynman_technique", "name": "费曼学习法", "weight": 0.3},
            {"skill_id": "lecture", "name": "讲义阅读", "weight": 0.3},
        ],
        # 巩固练习阶段
        "practice": [
            {"skill_id": "quiz", "name": "专项练习", "weight": 0.5},
            {"skill_id": "mistake_review", "name": "错题复习", "weight": 0.3},
            {"skill_id": "drill", "name": "强化训练", "weight": 0.2},
        ],
        # 阶段复盘阶段
        "review": [
            {"skill_id": "mindmap", "name": "知识导图", "weight": 0.4},
            {"skill_id": "comprehensive_test", "name": "综合测试", "weight": 0.4},
            {"skill_id": "summary", "name": "知识总结", "weight": 0.2},
        ]
    }
    
    # 学科特定映射（扩展用）
    SUBJECT_SKILL_MAP = {
        "math": {
            "practice": [
                {"skill_id": "math_quiz", "name": "数学练习", "weight": 0.5},
                {"skill_id": "problem_solving", "name": "解题训练", "weight": 0.5},
            ]
        },
        "physics": {
            "practice": [
                {"skill_id": "physics_quiz", "name": "物理练习", "weight": 0.5},
                {"skill_id": "experiment_simulation", "name": "实验模拟", "weight": 0.5},
            ]
        }
    }
    
    def __init__(self):
        # 从数据库加载自定义映射（如果有）
        self._custom_maps = {}
    
    def recommend_skills(
        self,
        phase: str,
        node_id: str,
        user_level: str = "intermediate",
        subject: str = None
    ) -> List[Dict[str, Any]]:
        """
        推荐 Skill 列表
        """
        phase_key = phase.lower()
        
        # 获取该阶段的基础 Skill 列表
        skills = self.NODE_SKILL_DEFAULT_MAP.get(phase_key, [])
        
        # 如果有学科特定映射，合并
        if subject and subject in self.SUBJECT_SKILL_MAP:
            subject_skills = self.SUBJECT_SKILL_MAP[subject].get(phase_key, [])
            # 合并并按 weight 排序
            skills = self._merge_skills(skills, subject_skills)
        
        # 根据用户水平过滤/调整
        skills = self._adjust_by_level(skills, user_level)
        
        return skills
    
    def _merge_skills(
        self,
        base_skills: List[Dict],
        subject_skills: List[Dict]
    ) -> List[Dict]:
        """合并基础映射和学科特定映射"""
        skill_map = {s["skill_id"]: s for s in base_skills}
        
        for s in subject_skills:
            if s["skill_id"] in skill_map:
                skill_map[s["skill_id"]]["weight"] += s["weight"]
            else:
                skill_map[s["skill_id"]] = s
        
        # 按 weight 降序排序
        return sorted(skill_map.values(), key=lambda x: x["weight"], reverse=True)
    
    def _adjust_by_level(
        self,
        skills: List[Dict],
        user_level: str
    ) -> List[Dict]:
        """根据用户水平调整 Skill 推荐"""
        if user_level == "beginner":
            # 新手：优先推荐思维导图和讲义
            return sorted(skills, key=lambda x: {
                "mindmap_learning": 0,
                "lecture": 1,
                "feynman_technique": 2,
                "quiz": 3,
                "mistake_review": 3,
                "comprehensive_test": 4,
            }.get(x["skill_id"], 10))
        elif user_level == "intermediate":
            # 中级：平衡学习和练习
            return skills
        else:
            # 高级：优先练习和测试
            return sorted(skills, key=lambda x: {
                "comprehensive_test": 0,
                "quiz": 1,
                "mistake_review": 2,
                "mindmap": 3,
                "feynman_technique": 4,
                "mindmap_learning": 5,
            }.get(x["skill_id"], 10))
    
    def get_skill_launch_params(self, skill_id: str, node_id: str) -> Dict[str, Any]:
        """获取启动 Skill 所需的参数"""
        return {
            "skill_id": skill_id,
            "node_id": node_id,
            "route": self._get_skill_route(skill_id),
        }
    
    def _get_skill_route(self, skill_id: str) -> str:
        """获取 Skill 的路由"""
        route_map = {
            "mindmap_learning": "/mindmap-entry",
            "mindmap": "/mindmap-entry",
            "quiz": "/toolkit/quiz",
            "mistake_review": "/toolkit/mistake-book",
            "feynman_technique": "/feynman",
            "lecture": "/course-space/{subject_id}/lecture",
            "comprehensive_test": "/toolkit/quiz",
            "drill": "/toolkit/quiz",
        }
        return route_map.get(skill_id, "/toolkit")