"""
递归摘要生成器，专供思维导图使用。

第一轮：生成全局一级大纲（根节点 + 一级子节点列表）
后续轮：对每个一级子节点递归展开二级子节点
深度限制：MINDMAP_MAX_DEPTH（默认 3）
叶节点判断：节点文本 token 数 < MINDMAP_LEAF_THRESHOLD（默认 200）
"""
from __future__ import annotations

import asyncio
import json
import logging
from dataclasses import dataclass, field
from typing import Optional

logger = logging.getLogger(__name__)


@dataclass
class HierarchicalOutline:
    """层级大纲节点"""
    title: str                    # 节点标题（非空，<=50 字符）
    summary: str = ""             # 节点摘要
    children: list[HierarchicalOutline] = field(default_factory=list)

    def to_dict(self) -> dict:
        """递归序列化为 JSON 可序列化的字典。"""
        return {
            "title": self.title,
            "summary": self.summary,
            "children": [c.to_dict() for c in self.children],
        }

    def depth(self) -> int:
        """递归计算最大嵌套深度（叶节点深度为 1）。"""
        if not self.children:
            return 1
        return 1 + max(c.depth() for c in self.children)

    def all_nodes(self) -> list[HierarchicalOutline]:
        """递归遍历所有节点（包含自身）。"""
        result = [self]
        for child in self.children:
            result.extend(child.all_nodes())
        return result


class RecursiveSummarizer:
    """
    递归摘要生成器，专供思维导图使用。
    
    第一轮：生成全局一级大纲（根节点 + 一级子节点列表）
    后续轮：对每个一级子节点递归展开二级子节点
    深度限制：MINDMAP_MAX_DEPTH（默认 3）
    叶节点判断：节点文本 token 数 < MINDMAP_LEAF_THRESHOLD（默认 200）
    """
    
    def __init__(self):
        """初始化递归摘要生成器"""
        from backend_config import get_config
        self.config = get_config()
        self._section_texts: dict[str, str] = {}  # 临时存储节点对应的原文片段
    
    async def generate_outline(
        self,
        document_text: str,
        max_depth: int | None = None,
    ) -> HierarchicalOutline:
        """
        主入口：生成层级大纲。
        
        Args:
            document_text: 文档文本
            max_depth: 最大递归深度，None 时从配置读取
        
        Returns:
            HierarchicalOutline: 层级大纲根节点
        """
        if max_depth is None:
            max_depth = self.config.MINDMAP_MAX_DEPTH
        
        leaf_threshold = self.config.MINDMAP_LEAF_THRESHOLD
        
        logger.info(f"开始生成层级大纲，max_depth={max_depth}, leaf_threshold={leaf_threshold}")
        
        # 第一轮：生成根节点和一级子节点
        root = await self._generate_root(document_text)
        
        # 对每个一级子节点递归展开
        for child in root.children:
            section_text = self._section_texts.get(child.title, "")
            if section_text:
                await self._expand_node(child, section_text, current_depth=2, max_depth=max_depth)
        
        # 清理临时数据
        self._section_texts.clear()
        
        logger.info(f"层级大纲生成完成，深度={root.depth()}, 节点数={len(root.all_nodes())}")
        return root
    
    async def _generate_root(self, document_text: str) -> HierarchicalOutline:
        """
        第一轮 LLM 调用：生成根节点 + 一级子节点列表。
        
        Prompt 要求 LLM 返回 JSON：
        {
          "title": "文档主题",
          "summary": "整体摘要",
          "children": [
            {"title": "一级节点1", "summary": "摘要", "section_text": "对应原文片段"},
            ...
          ]
        }
        
        LLM 返回非法 JSON 时重试一次，失败则返回只有根节点的大纲。
        title 超过 50 字符时截断。
        
        Args:
            document_text: 文档文本
        
        Returns:
            HierarchicalOutline: 根节点（包含一级子节点）
        """
        # 截断文档文本到合理长度（避免超出 LLM context）
        max_input_chars = 8000
        if len(document_text) > max_input_chars:
            logger.warning(f"文档文本过长（{len(document_text)} 字符），截断到 {max_input_chars} 字符")
            document_text = document_text[:max_input_chars]
        
        prompt = self._build_root_prompt(document_text)
        
        # 尝试调用 LLM（最多重试一次）
        for attempt in range(2):
            try:
                response = await self._call_llm(prompt)
                parsed = self._parse_json_response(response)
                
                # 构建根节点
                root_title = self._truncate_title(parsed.get("title", "文档大纲"))
                root_summary = parsed.get("summary", "")
                root = HierarchicalOutline(title=root_title, summary=root_summary)
                
                # 构建一级子节点
                children_data = parsed.get("children", [])
                for child_data in children_data:
                    child_title = self._truncate_title(child_data.get("title", ""))
                    if not child_title:
                        continue
                    
                    child_summary = child_data.get("summary", "")
                    section_text = child_data.get("section_text", "")
                    
                    child = HierarchicalOutline(title=child_title, summary=child_summary)
                    root.children.append(child)
                    
                    # 存储 section_text 供后续展开使用
                    if section_text:
                        self._section_texts[child_title] = section_text
                
                logger.info(f"根节点生成成功，一级子节点数={len(root.children)}")
                return root
                
            except Exception as e:
                logger.warning(f"根节点生成失败（尝试 {attempt + 1}/2）：{e}")
                if attempt == 1:
                    # 最后一次尝试失败，返回只有根节点的大纲
                    logger.error("根节点生成失败，返回默认大纲")
                    return HierarchicalOutline(title="文档大纲", summary="")
        
        # 不应该到达这里
        return HierarchicalOutline(title="文档大纲", summary="")
    
    async def _expand_node(
        self,
        node: HierarchicalOutline,
        section_text: str,
        current_depth: int,
        max_depth: int,
    ) -> None:
        """
        递归展开单个节点，原地修改 node.children。
        
        停止条件：
        1. current_depth >= max_depth
        2. _estimate_tokens(section_text) < MINDMAP_LEAF_THRESHOLD
        
        Prompt 要求 LLM 返回 JSON：
        {
          "children": [
            {"title": "子节点标题", "summary": "摘要", "section_text": "对应原文片段"},
            ...
          ]
        }
        
        Args:
            node: 要展开的节点
            section_text: 节点对应的原文片段
            current_depth: 当前深度
            max_depth: 最大深度
        """
        # 停止条件 1：达到最大深度
        if current_depth >= max_depth:
            logger.debug(f"节点 '{node.title}' 达到最大深度 {max_depth}，停止展开")
            return
        
        # 停止条件 2：文本长度低于叶节点阈值
        token_count = self._estimate_tokens(section_text)
        if token_count < self.config.MINDMAP_LEAF_THRESHOLD:
            logger.debug(f"节点 '{node.title}' token 数 {token_count} < {self.config.MINDMAP_LEAF_THRESHOLD}，标记为叶节点")
            return
        
        # 调用 LLM 生成子节点
        prompt = self._build_expand_prompt(node.title, section_text)
        
        try:
            response = await self._call_llm(prompt)
            parsed = self._parse_json_response(response)
            
            children_data = parsed.get("children", [])
            if not children_data:
                logger.debug(f"节点 '{node.title}' 无子节点")
                return
            
            # 构建子节点
            for child_data in children_data:
                child_title = self._truncate_title(child_data.get("title", ""))
                if not child_title:
                    continue
                
                child_summary = child_data.get("summary", "")
                child_section_text = child_data.get("section_text", "")
                
                child = HierarchicalOutline(title=child_title, summary=child_summary)
                node.children.append(child)
                
                # 递归展开子节点
                if child_section_text:
                    await self._expand_node(child, child_section_text, current_depth + 1, max_depth)
            
            logger.debug(f"节点 '{node.title}' 展开完成，子节点数={len(node.children)}")
            
        except Exception as e:
            logger.warning(f"节点 '{node.title}' 展开失败：{e}")
            # 失败时 node.children 保持为空
    
    def _build_root_prompt(self, document_text: str) -> str:
        """构建根节点生成的 Prompt"""
        return f"""请分析以下文档内容，生成一个结构化的层级大纲。

要求：
1. 识别文档的主题作为根节点标题
2. 提取 3-7 个主要章节/主题作为一级子节点
3. 每个节点标题不超过 20 个字
4. 为每个一级子节点提供对应的原文片段（section_text）

请严格按以下 JSON 格式输出，不要有任何其他文字：
{{
  "title": "文档主题（不超过20字）",
  "summary": "整体内容摘要（不超过100字）",
  "children": [
    {{
      "title": "一级节点标题",
      "summary": "该节点摘要（不超过50字）",
      "section_text": "对应原文片段（用于进一步展开）"
    }}
  ]
}}

文档内容：
{document_text}"""
    
    def _build_expand_prompt(self, node_title: str, section_text: str) -> str:
        """构建节点展开的 Prompt"""
        return f"""请分析以下文本片段，为节点「{node_title}」生成子节点。

要求：
1. 提取 2-5 个子主题作为子节点
2. 每个节点标题不超过 20 个字
3. 为每个子节点提供对应的原文片段

请严格按以下 JSON 格式输出，不要有任何其他文字：
{{
  "children": [
    {{
      "title": "子节点标题",
      "summary": "摘要（不超过50字）",
      "section_text": "对应原文片段"
    }}
  ]
}}

文本片段：
{section_text}"""
    
    async def _call_llm(self, prompt: str) -> str:
        """
        调用 LLM 服务（在线程池中执行同步调用）
        
        Args:
            prompt: 提示词
        
        Returns:
            str: LLM 响应
        """
        from services.llm_service import LLMService
        
        messages = [
            {"role": "system", "content": "你是一个专业的文档分析助手，擅长提取文档结构和生成层级大纲。"},
            {"role": "user", "content": prompt}
        ]
        
        # 在线程池中执行同步的 LLM 调用
        loop = asyncio.get_event_loop()
        llm_service = LLMService()
        response = await loop.run_in_executor(
            None,
            lambda: llm_service.chat(messages, temperature=0.3, max_tokens=2000)
        )
        
        return response
    
    def _parse_json_response(self, raw: str) -> dict:
        """
        解析 LLM 返回的 JSON，处理常见格式问题：
        - 去除 ```json ... ``` 代码块包裹
        - 去除首尾空白
        
        Args:
            raw: LLM 原始响应
        
        Returns:
            dict: 解析后的 JSON 对象
        
        Raises:
            json.JSONDecodeError: JSON 解析失败
        """
        raw = raw.strip()
        
        # 去除 Markdown 代码块包裹
        if raw.startswith("```"):
            lines = raw.splitlines()
            # 去除首行（```json 或 ```）和末行（```）
            if len(lines) > 2 and lines[-1].strip() == "```":
                inner = lines[1:-1]
            else:
                inner = lines[1:]
            raw = "\n".join(inner).strip()
        
        return json.loads(raw)
    
    def _estimate_tokens(self, text: str) -> int:
        """
        估算文本的 token 数量
        
        Args:
            text: 文本内容
        
        Returns:
            int: 估算的 token 数
        """
        return len(text) // 4
    
    def _truncate_title(self, title: str, max_len: int = 50) -> str:
        """
        截断标题到指定长度
        
        Args:
            title: 原始标题
            max_len: 最大长度
        
        Returns:
            str: 截断后的标题
        """
        if len(title) > max_len:
            logger.warning(f"节点标题超过 {max_len} 字符，截断：{title[:max_len]}")
            return title[:max_len]
        return title
