"""
chunker.py — HierarchicalChunker：基于 Markdown 标题树的层级切片器。

切片策略：
  1. 有 H1/H2/H3 标题 → 层级切片（按标题边界切分，保留 heading_path）
  2. 无标题 → 语义切片（按句子边界，滑动窗口）
  3. 单节点超长 → 二次切片（滑动窗口，is_secondary=True）

每个 Chunk 携带 heading_path 和 filename 元数据，供 RAG 检索时标注来源。
token 估算：len(text) // 4（无需 tokenizer 依赖）
"""
from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# 数据模型
# ---------------------------------------------------------------------------

@dataclass
class HeadingNode:
    """Markdown 标题节点。"""
    level: int          # 1=H1, 2=H2, 3=H3
    title: str          # 标题文本（不含 # 前缀）
    content: str        # 该标题下的正文内容（不含子标题）
    heading_path: str   # 完整路径，如 "第三章 > 3.2 牛顿第二定律"


@dataclass
class Chunk:
    """知识块，RAG 检索的基本单元。"""
    content: str
    heading_path: str       # 标题路径，如 "第三章 > 3.2 牛顿第二定律"
    chunk_index: int        # 全局切片序号（从 0 开始）
    filename: str           # 来源文件名
    is_secondary: bool = False  # 是否为二次切片（超长节点拆分）
    token_count: int = 0    # 估算 token 数


# ---------------------------------------------------------------------------
# 辅助函数
# ---------------------------------------------------------------------------

def _estimate_tokens(text: str) -> int:
    """估算文本 token 数（len // 4，无需 tokenizer 依赖）。"""
    if not text:
        return 0
    cjk = sum(1 for ch in text if "\u4e00" <= ch <= "\u9fff")
    other = len(text) - cjk
    return max(1, int(cjk / 1.5 + other / 4))


def _split_sentences(text: str) -> list[str]:
    parts = re.split(r"(?<=[\u3002\uff01\uff1f.!?\n])\s*", text)
    return [part.strip() for part in parts if part and part.strip()]


# ---------------------------------------------------------------------------
# HierarchicalChunker
# ---------------------------------------------------------------------------

class HierarchicalChunker:
    """
    基于 Markdown 标题树的层级切片器。

    配置项（从 backend_config.py 读取）：
      - CHUNK_MAX_TOKENS：单 Chunk 最大 token 数（默认 512）
      - CHUNK_OVERLAP_TOKENS：相邻 Chunk 重叠 token 数（默认 64）
      - CHUNK_SIZE：语义切片字符数（默认 800，向后兼容）
      - CHUNK_OVERLAP：语义切片重叠字符数（默认 150，向后兼容）
    """

    # 匹配 H1/H2/H3 标题的正则（行首 1~3 个 #，后跟空格）
    _HEADING_RE = re.compile(r'^(#{1,6})\s+(.+)$', re.MULTILINE)

    def __init__(
        self,
        max_tokens: int | None = None,
        overlap_tokens: int | None = None,
    ) -> None:
        """
        初始化 HierarchicalChunker。

        Args:
            max_tokens: 单 Chunk 最大 token 数，None 时从配置读取。
            overlap_tokens: 相邻 Chunk 重叠 token 数，None 时从配置读取。
        """
        self._max_tokens = max_tokens
        self._overlap_tokens = overlap_tokens

    def _get_config(self) -> tuple[int, int, int, int]:
        """返回 (max_tokens, overlap_tokens, chunk_size, chunk_overlap)。"""
        if self._max_tokens is not None and self._overlap_tokens is not None:
            return self._max_tokens, self._overlap_tokens, self._max_tokens * 4, self._overlap_tokens * 4
        try:
            from config import get_config
            cfg = get_config()
            max_tokens = self._max_tokens if self._max_tokens is not None else cfg.CHUNK_MAX_TOKENS
            overlap_tokens = self._overlap_tokens if self._overlap_tokens is not None else cfg.CHUNK_OVERLAP_TOKENS
            chunk_size = cfg.CHUNK_SIZE
            chunk_overlap = cfg.CHUNK_OVERLAP
        except Exception:
            max_tokens = self._max_tokens if self._max_tokens is not None else 512
            overlap_tokens = self._overlap_tokens if self._overlap_tokens is not None else 64
            chunk_size = 800
            chunk_overlap = 150
        return max_tokens, overlap_tokens, chunk_size, chunk_overlap

    # ------------------------------------------------------------------
    # 主入口
    # ------------------------------------------------------------------

    def chunk(self, markdown: str, metadata: dict) -> list[Chunk]:
        """
        将 Markdown 文本切分为 Chunk 列表。

        有标题时使用层级切片，无标题时回退到语义切片。

        Args:
            markdown: 输入的 Markdown 文本（可以是 Structured Markdown 或纯文本）。
            metadata: 文档元数据，必须包含 'filename' 键。

        Returns:
            Chunk 列表，每个 Chunk 携带 heading_path 和 filename。
        """
        filename = metadata.get("filename", "")
        nodes = self._extract_heading_tree(markdown)

        if nodes:
            chunks = self._hierarchical_chunk(nodes, filename)
        else:
            logger.debug("文档 %s 无标题，使用语义切片", filename)
            chunks = self._semantic_chunk(markdown, filename)

        logger.info(
            "切片完成：文件=%s，策略=%s，共 %d 个 Chunk",
            filename,
            "hierarchical" if nodes else "semantic",
            len(chunks),
        )
        return chunks

    # ------------------------------------------------------------------
    # 层级切片
    # ------------------------------------------------------------------

    def _extract_heading_tree(self, markdown: str) -> list[HeadingNode]:
        """
        从 Markdown 中提取标题树，构建 HeadingNode 列表。

        每个节点包含该标题下的正文内容（不含子标题内容）。
        heading_path 格式：父标题 > 当前标题（如 "第三章 > 3.2 牛顿第二定律"）。
        """
        matches = list(self._HEADING_RE.finditer(markdown))
        if not matches:
            return []

        nodes: list[HeadingNode] = []
        # 用于追踪各级别的当前标题，构建 heading_path
        current_path: dict[int, str] = {}  # level → title

        for i, match in enumerate(matches):
            level = len(match.group(1))  # # 的数量
            title = match.group(2).strip()

            # 更新当前路径
            current_path[level] = title
            # 清除更深层级的路径（切换到新的父节点时）
            for deeper_level in list(current_path.keys()):
                if deeper_level > level:
                    del current_path[deeper_level]

            # 构建 heading_path
            path_parts = [current_path[lvl] for lvl in sorted(current_path.keys())]
            heading_path = " > ".join(path_parts)

            # 提取该标题下的正文内容（到下一个同级或更高级标题之前）
            content_start = match.end()
            if i + 1 < len(matches):
                content_end = matches[i + 1].start()
            else:
                content_end = len(markdown)

            content = markdown[content_start:content_end].strip()

            nodes.append(HeadingNode(
                level=level,
                title=title,
                content=content,
                heading_path=heading_path,
            ))

        return nodes

    def _hierarchical_chunk(
        self,
        nodes: list[HeadingNode],
        filename: str,
    ) -> list[Chunk]:
        """
        按标题边界切分，每个节点为一个 Chunk。
        超长节点调用 _secondary_chunk() 进行二次切片。
        """
        max_tokens, overlap_tokens, _, _ = self._get_config()
        chunks: list[Chunk] = []
        chunk_index = 0

        for node in nodes:
            # 节点内容 = 标题 + 正文
            node_text = f"{'#' * node.level} {node.title}\n\n{node.content}".strip()
            if not node.content.strip():
                continue
            token_count = _estimate_tokens(node_text)

            if token_count <= max_tokens:
                chunks.append(Chunk(
                    content=node_text,
                    heading_path=node.heading_path,
                    chunk_index=chunk_index,
                    filename=filename,
                    is_secondary=False,
                    token_count=token_count,
                ))
                chunk_index += 1
            else:
                # 超长节点：二次切片
                secondary = self._secondary_chunk(
                    content=node_text,
                    heading_path=node.heading_path,
                    filename=filename,
                    start_index=chunk_index,
                )
                chunks.extend(secondary)
                chunk_index += len(secondary)

        return chunks

    def _secondary_chunk(
        self,
        content: str,
        heading_path: str,
        filename: str,
        start_index: int,
    ) -> list[Chunk]:
        """
        对超长节点进行滑动窗口二次切片。

        步长 = max_tokens - overlap_tokens（字符估算：* 4）
        is_secondary=True 标记为二次切片。
        """
        max_tokens, overlap_tokens, _, _ = self._get_config()
        # 转换为字符数（token 估算：1 token ≈ 4 字符）
        max_chars = max(int(max_tokens * 1.4), 120)
        overlap_chars = int(overlap_tokens * 1.4)
        chunks: list[Chunk] = []
        local_index = 0
        current_parts: list[str] = []
        current_chars = 0

        for sentence in _split_sentences(content) or [content]:
            if current_parts and current_chars + len(sentence) > max_chars:
                chunk_text = " ".join(current_parts).strip()
                chunks.append(Chunk(
                    content=chunk_text,
                    heading_path=heading_path,
                    chunk_index=start_index + local_index,
                    filename=filename,
                    is_secondary=True,
                    token_count=_estimate_tokens(chunk_text),
                ))
                local_index += 1
                overlap_text = chunk_text[-overlap_chars:] if overlap_chars > 0 else ""
                current_parts = [overlap_text] if overlap_text else []
                current_chars = len(overlap_text)

            if len(sentence) > max_chars:
                pos = 0
                while pos < len(sentence):
                    part = sentence[pos:pos + max_chars].strip()
                    if part:
                        chunks.append(Chunk(
                            content=part,
                            heading_path=heading_path,
                            chunk_index=start_index + local_index,
                            filename=filename,
                            is_secondary=True,
                            token_count=_estimate_tokens(part),
                        ))
                        local_index += 1
                    pos += max(max_chars - overlap_chars, max_chars // 2)
                current_parts = []
                current_chars = 0
            else:
                current_parts.append(sentence)
                current_chars += len(sentence)

        if current_parts:
            chunk_text = " ".join(current_parts).strip()
            if chunk_text:
                chunks.append(Chunk(
                    content=chunk_text,
                    heading_path=heading_path,
                    chunk_index=start_index + local_index,
                    filename=filename,
                    is_secondary=True,
                    token_count=_estimate_tokens(chunk_text),
                ))

        return chunks

    # ------------------------------------------------------------------
    # 语义切片（无标题时的回退策略）
    # ------------------------------------------------------------------

    def _semantic_chunk(self, text: str, filename: str) -> list[Chunk]:
        """
        按句子边界进行语义切片（无标题时使用）。

        使用 CHUNK_SIZE / CHUNK_OVERLAP 配置（字符数），
        在句子边界处切分，避免在句子中间截断。
        """
        _, _, chunk_size, chunk_overlap = self._get_config()
        # 按句子边界分割（中文句号、英文句号、换行）
        sentences = _split_sentences(text) or [text]

        chunks: list[Chunk] = []
        chunk_index = 0
        current_chars = 0
        current_parts: list[str] = []

        for sentence in sentences:
            sentence_len = len(sentence)

            if current_chars + sentence_len > chunk_size and current_parts:
                # 当前 chunk 已满，输出
                chunk_text = " ".join(current_parts)
                chunks.append(Chunk(
                    content=chunk_text,
                    heading_path="",
                    chunk_index=chunk_index,
                    filename=filename,
                    is_secondary=False,
                    token_count=_estimate_tokens(chunk_text),
                ))
                chunk_index += 1

                # 保留重叠部分（从末尾取 overlap 字符）
                overlap_text = chunk_text[-chunk_overlap:] if chunk_overlap > 0 else ""
                current_parts = [overlap_text] if overlap_text else []
                current_chars = len(overlap_text)

            current_parts.append(sentence)
            current_chars += sentence_len

        # 输出最后一个 chunk
        if current_parts:
            chunk_text = " ".join(current_parts)
            if chunk_text.strip():
                chunks.append(Chunk(
                    content=chunk_text,
                    heading_path="",
                    chunk_index=chunk_index,
                    filename=filename,
                    is_secondary=False,
                    token_count=_estimate_tokens(chunk_text),
                ))

        return chunks
