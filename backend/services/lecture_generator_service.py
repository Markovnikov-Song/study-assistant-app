"""
LectureGeneratorService — 为思维导图节点生成讲义内容并保存到数据库。
"""
from __future__ import annotations

import re
from typing import Generator, Optional

from backend_config import get_config


def _markdown_to_blocks(markdown: str) -> list[dict]:
    """将 Markdown 文本转换为 LectureBlock 格式的 dict 列表。"""
    blocks = []
    lines = markdown.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        # 代码块
        if line.startswith("```"):
            lang = line[3:].strip()
            code_lines = []
            i += 1
            while i < len(lines) and not lines[i].startswith("```"):
                code_lines.append(lines[i])
                i += 1
            blocks.append({"type": "code", "text": "\n".join(code_lines), "language": lang or None})
        # 块级公式 \[...\] 或 $$...$$
        elif line.strip().startswith(r"\[") or line.strip().startswith("$$"):
            delimiter_end = r"\]" if line.strip().startswith(r"\[") else "$$"
            formula_lines = [line.strip().lstrip(r"\[").lstrip("$$")]
            i += 1
            while i < len(lines):
                l = lines[i]
                if delimiter_end in l:
                    formula_lines.append(l.replace(delimiter_end, "").strip())
                    i += 1
                    break
                formula_lines.append(l)
                i += 1
            formula = "\n".join(formula_lines).strip()
            if formula:
                blocks.append({"type": "formula", "text": formula})
            continue
        # 标题
        elif m := re.match(r"^(#{1,4})\s+(.*)", line):
            level = len(m.group(1))
            blocks.append({"type": "heading", "text": m.group(2).strip(), "level": level})
        # 引用
        elif line.startswith("> "):
            blocks.append({"type": "quote", "text": line[2:].strip()})
        # 列表
        elif re.match(r"^[-*+]\s+", line):
            blocks.append({"type": "list", "text": re.sub(r"^[-*+]\s+", "", line).strip()})
        elif re.match(r"^\d+\.\s+", line):
            blocks.append({"type": "list", "text": re.sub(r"^\d+\.\s+", "", line).strip()})
        # 空行跳过
        elif line.strip() == "":
            pass
        # 普通段落
        else:
            blocks.append({"type": "paragraph", "text": line.strip()})
        i += 1
    return blocks


def _retrieve_context(node_title: str, subject_id: int, top_k: int, threshold: float) -> str:
    """用 PGVector 检索与节点标题相关的文档片段，返回拼接后的上下文字符串。"""
    try:
        from services.rag_pipeline import RAGPipeline
        pipeline = RAGPipeline()
        vector_store = pipeline.get_vector_store(subject_id)
        docs_with_scores = vector_store.similarity_search_with_score(node_title, k=top_k)
        chunks = [
            doc.page_content
            for doc, score in docs_with_scores
            if score <= threshold
        ]
        return "\n\n".join(chunks)
    except Exception:
        # 检索失败时降级为无上下文生成
        return ""


class LectureGeneratorService:
    def __init__(self):
        self._cfg = get_config()

    def generate(
        self,
        node_id: str,
        node_title: str,
        subject_id: int,
        session_id: int,
        user_id: int,
        resource_scope: Optional[dict] = None,
    ) -> dict:
        """同步生成节点讲义，保存到数据库，返回 {"id": lecture_id}。"""
        from services.llm_service import LLMService
        from database import NodeLecture, get_session as db_session

        cfg = self._cfg
        context = _retrieve_context(
            node_title, subject_id,
            top_k=cfg.TOP_K,
            threshold=cfg.SIMILARITY_THRESHOLD,
        )
        prompt = self._build_prompt(node_title, context)
        content_text = LLMService().chat(
            messages=[{"role": "user", "content": prompt}],
            temperature=cfg.LLM_LECTURE_TEMPERATURE,
            max_tokens=cfg.LLM_LECTURE_MAX_TOKENS,
            heavy=True,
        )
        blocks = _markdown_to_blocks(content_text)
        content = {"blocks": blocks}
        with db_session() as db:
            existing = (
                db.query(NodeLecture)
                .filter_by(user_id=user_id, session_id=session_id, node_id=node_id)
                .first()
            )
            if existing:
                existing.content = content
                db.flush()
                lecture_id = existing.id
            else:
                lecture = NodeLecture(
                    user_id=user_id,
                    session_id=session_id,
                    node_id=node_id,
                    content=content,
                    resource_scope=resource_scope,
                )
                db.add(lecture)
                db.flush()
                lecture_id = lecture.id
        return {"id": lecture_id}

    def generate_stream(
        self,
        node_id: str,
        node_title: str,
        subject_id: int,
        session_id: int,
        resource_scope: Optional[dict] = None,
    ) -> Generator[str, None, None]:
        """流式生成节点讲义（只 yield token，保存由调用方负责）。"""
        from services.llm_service import LLMService

        cfg = self._cfg
        context = _retrieve_context(
            node_title, subject_id,
            top_k=cfg.TOP_K,
            threshold=cfg.SIMILARITY_THRESHOLD,
        )
        prompt = self._build_prompt(node_title, context)

        yield from LLMService().chat_stream(
            messages=[{"role": "user", "content": prompt}],
            temperature=cfg.LLM_LECTURE_TEMPERATURE,
            max_tokens=cfg.LLM_LECTURE_MAX_TOKENS,
            heavy=True,
        )

    def save_stream_result(
        self,
        full_markdown: str,
        node_id: str,
        session_id: int,
        user_id: int,
        resource_scope: Optional[dict] = None,
    ) -> int:
        """将流式生成的完整 markdown 保存到数据库，返回 lecture_id。"""
        from database import NodeLecture, get_session as db_session

        blocks = _markdown_to_blocks(full_markdown)
        content = {"blocks": blocks}
        with db_session() as db:
            existing = (
                db.query(NodeLecture)
                .filter_by(user_id=user_id, session_id=session_id, node_id=node_id)
                .first()
            )
            if existing:
                existing.content = content
                db.flush()
                return existing.id
            else:
                lecture = NodeLecture(
                    user_id=user_id,
                    session_id=session_id,
                    node_id=node_id,
                    content=content,
                    resource_scope=resource_scope,
                )
                db.add(lecture)
                db.flush()
                return lecture.id

    def _build_prompt(self, node_title: str, context: str) -> str:
        base = (
            f"你是一位专业的教学助手。请为知识点「{node_title}」生成一份详细的讲义。\n\n"
            "讲义要求：\n"
            "1. 结构清晰，包含：概念定义、核心原理、公式推导（如有）、典型例题、总结\n"
            "2. 使用 Markdown 格式\n"
            "3. 语言简洁专业\n\n"
        )
        if context:
            base += f"参考资料：\n{context}\n\n"
        base += f"请生成「{node_title}」的讲义："
        return base
