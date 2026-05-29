"""
知识导航服务 - 根据学习目标生成结构化的知识点学习顺序
"""
from __future__ import annotations
import logging
from typing import Optional, List, Dict, Any
from datetime import date, datetime
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)


@dataclass
class KnowledgeNode:
    """知识节点"""
    node_id: str
    title: str
    priority: str  # "core", "basic", "extended"
    prerequisites: List[str] = field(default_factory=list)
    estimated_hours: float = 1.0
    description: str = ""


@dataclass
class KnowledgeNavigation:
    """知识导航结构"""
    id: Optional[int]
    subject_id: int
    scope: str
    nodes: List[KnowledgeNode]
    created_at: datetime = field(default_factory=datetime.now)
    
    def to_dict(self) -> dict:
        return {
            'id': self.id,
            'subject_id': self.subject_id,
            'scope': self.scope,
            'nodes': [
                {
                    'nodeId': n.node_id,
                    'title': n.title,
                    'priority': n.priority,
                    'prerequisites': n.prerequisites,
                    'hours': n.estimated_hours,
                    'description': n.description,
                }
                for n in self.nodes
            ]
        }


class KnowledgeNavigator:
    """知识导航器"""
    
    # 预设路径缓存
    _preset_paths_cache: Dict[int, KnowledgeNavigation] = {}
    
    async def generate_navigation(
        self,
        subject_id: int,
        exam_scope: str,
        deadline: date,
        user_id: Optional[int] = None
    ) -> KnowledgeNavigation:
        """
        生成知识导航
        1. 尝试获取预设路径
        2. 如果没有预设路径，调用 LLM 生成
        """
        # 1. 尝试获取预设路径
        preset = await self._get_preset_path(subject_id, exam_scope)
        if preset:
            logger.info(f"使用预设路径 subject_id={subject_id}, scope={exam_scope}")
            return preset
        
        # 2. 调用 LLM 生成
        logger.info(f"调用 LLM 生成知识导航 subject_id={subject_id}")
        return await self._generate_with_llm(subject_id, exam_scope, deadline)
    
    async def _get_preset_path(self, subject_id: int, scope: str) -> Optional[KnowledgeNavigation]:
        """从数据库获取预设路径"""
        from database import SessionLocal
        from database import LearningPath
        
        try:
            db = SessionLocal()
            # 查找该学科的默认预设路径
            path = db.query(LearningPath).filter(
                LearningPath.subject_id == subject_id,
                LearningPath.is_default == True
            ).first()
            
            if not path:
                return None
            
            # 根据考试范围过滤节点
            nodes = self._filter_nodes_by_scope(path.node_ids, path.prerequisites, scope)
            
            return KnowledgeNavigation(
                id=path.id,
                subject_id=subject_id,
                scope=scope,
                nodes=nodes
            )
        except Exception as e:
            logger.error(f"获取预设路径失败: {e}")
            return None
        finally:
            db.close()
    
    def _filter_nodes_by_scope(
        self,
        node_ids: List[str],
        prerequisites: Dict[str, List[str]],
        scope: str
    ) -> List[KnowledgeNode]:
        """根据考试范围过滤节点"""
        # 解析范围：如 "前五章" -> 需要包含前5个章节的节点
        # 暂时返回所有节点，由后续优化
        nodes = []
        for i, node_id in enumerate(node_ids):
            nodes.append(KnowledgeNode(
                node_id=node_id,
                title=self._extract_title_from_node_id(node_id),
                priority="core" if i < 5 else "basic",
                prerequisites=prerequisites.get(node_id, []),
                estimated_hours=1.5 if i < 5 else 1.0
            ))
        return nodes
    
    def _extract_title_from_node_id(self, node_id: str) -> str:
        """从节点ID提取标题"""
        # 格式: L1_chap1_force -> "力的基本概念"
        # 这里需要维护一个映射表，暂时返回简化版
        parts = node_id.split('_')
        if len(parts) >= 2:
            return '_'.join(parts[1:]).replace('_', ' ')
        return node_id
    
    async def _generate_with_llm(
        self,
        subject_id: int,
        scope: str,
        deadline: date
    ) -> KnowledgeNavigation:
        """调用 LLM 生成知识导航"""
        from services.llm_service import LLMService
        from backend_config import get_config
        
        cfg = get_config()
        
        # 构建 prompt
        prompt = f"""请为学生生成一个{subject_id}科目的知识学习导航。
考试范围：{scope}
距离考试还有{(deadline - date.today()).days}天

请生成结构化的知识节点列表，每个节点包含：
- node_id: 节点唯一标识（如 L1_chap1）
- title: 知识点名称
- priority: 优先级 (core/basic/extended)
- prerequisites: 前置知识点列表
- estimated_hours: 预估学习时长

请以 JSON 数组格式输出。"""
        
        llm = LLMService()
        response = llm.chat(
            [
                {"role": "system", "content": "你是一位教育专家，擅长将学科知识拆解为循序渐进的学习节点。"},
                {"role": "user", "content": prompt}
            ],
            max_tokens=cfg.LLM_EXECUTE_NODE_MAX_TOKENS
        )
        
        # 解析 LLM 响应
        try:
            import json
            # 尝试从响应中提取 JSON
            nodes_data = json.loads(response)
            nodes = [KnowledgeNode(**n) for n in nodes_data]
        except:
            # 解析失败，使用默认节点
            nodes = self._generate_default_nodes(subject_id, scope)
        
        # 保存到数据库（可选）
        nav = KnowledgeNavigation(
            id=None,
            subject_id=subject_id,
            scope=scope,
            nodes=nodes
        )
        
        return nav
    
    def _generate_default_nodes(self, subject_id: int, scope: str) -> List[KnowledgeNode]:
        """生成默认节点（LLM 失败时的降级方案）"""
        # 生成基础节点列表
        return [
            KnowledgeNode(node_id="L1_chap1", title="基础知识入门", priority="core", estimated_hours=2.0),
            KnowledgeNode(node_id="L1_chap2", title="核心概念", priority="core", prerequisites=["L1_chap1"], estimated_hours=2.5),
            KnowledgeNode(node_id="L1_chap3", title="基本方法", priority="core", prerequisites=["L1_chap2"], estimated_hours=2.0),
            KnowledgeNode(node_id="L2_chap1", title="进阶理论", priority="basic", prerequisites=["L1_chap3"], estimated_hours=3.0),
            KnowledgeNode(node_id="L2_chap2", title="应用实践", priority="basic", prerequisites=["L2_chap1"], estimated_hours=2.5),
            KnowledgeNode(node_id="L3_chap1", title="综合应用", priority="extended", prerequisites=["L2_chap2"], estimated_hours=3.0),
        ]