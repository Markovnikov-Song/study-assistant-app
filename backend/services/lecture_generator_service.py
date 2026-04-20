"""
LectureGeneratorService — 为思维导图节点生成讲义内容。
"""
from __future__ import annotations

from typing import Generator, List, Optional

from backend_config import get_config


class LectureGeneratorService:
    def __init__(self):
        self._cfg = get_config()

    def generate(
        self,
        node_id: str,
        node_title: str,
        subject_id: int,
        session_id: int,
        resource_scope: Optional[dict] = None,
    ) -> dict:
        """同步生成节点讲义，返回结构化内容 dict。"""
        from services.document_service import DocumentService
        from services.embedding_service import EmbeddingService
        from services.llm_service import LLMService

        cfg = self._cfg
        # 检索相关资料
        q_vec = EmbeddingService().embed_text(node_title)
        doc_id = resource_scope.get("doc_id") if resource_scope else None
        chunks = DocumentService().search(
            query_vector=q_vec,
            subject_id=subject_id,
            top_k=cfg.TOP_K,
            threshold=1 - cfg.SIMILARITY_THRESHOLD,
            doc_id=doc_id,
        )
        context = "\n\n".join(c["content"] for c in chunks)

        prompt = self._build_prompt(node_title, context)
        content_text = LLMService().chat(
            messages=[{"role": "user", "content": prompt}],
            temperature=cfg.LLM_LECTURE_TEMPERATURE,
            max_tokens=cfg.LLM_LECTURE_MAX_TOKENS,
            heavy=True,
        )
        return {"markdown": content_text, "sources": chunks}

    def generate_stream(
        self,
        node_id: str,
        node_title: str,
        subject_id: int,
        session_id: int,
        resource_scope: Optional[dict] = None,
    ) -> Generator[str, None, None]:
        """流式生成节点讲义。"""
        from services.document_service import DocumentService
        from services.embedding_service import EmbeddingService
        from services.llm_service import LLMService

        cfg = self._cfg
        q_vec = EmbeddingService().embed_text(node_title)
        doc_id = resource_scope.get("doc_id") if resource_scope else None
        chunks = DocumentService().search(
            query_vector=q_vec,
            subject_id=subject_id,
            top_k=cfg.TOP_K,
            threshold=1 - cfg.SIMILARITY_THRESHOLD,
            doc_id=doc_id,
        )
        context = "\n\n".join(c["content"] for c in chunks)
        prompt = self._build_prompt(node_title, context)

        yield from LLMService().chat_stream(
            messages=[{"role": "user", "content": prompt}],
            temperature=cfg.LLM_LECTURE_TEMPERATURE,
            max_tokens=cfg.LLM_LECTURE_MAX_TOKENS,
            heavy=True,
        )

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
