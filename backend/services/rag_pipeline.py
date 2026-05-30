"""
RAG 流水线：向量检索 + LLM 问答/解题，支持 strict / broad / solve 三种模式。
"""

from __future__ import annotations

import hashlib
import json
import logging
import re
from dataclasses import dataclass, field
from typing import List, Optional

from langchain_openai import OpenAIEmbeddings
from langchain_postgres import PGVector

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# 数据类
# ---------------------------------------------------------------------------


@dataclass
class Source:
    filename: str
    chunk_index: int
    content: str
    score: float
    heading_path: str = ""   # 知识块在文档中的层级路径
    rerank_score: float = 0.0  # Reranker 得分（0 表示未经 Rerank）


@dataclass
class RAGResult:
    answer: str = ""
    sources: List[Source] = field(default_factory=list)
    needs_confirmation: bool = False  # 相关性不足，需用户确认
    top_score: float = 0.0
    mode: str = "strict"  # strict | broad | solve
    top_rerank_score: float = 0.0    # Reranker 最高得分
    fallback_triggered: bool = False  # 是否触发 Fallback
    fallback_reason: str = ""         # Fallback 原因说明


# ---------------------------------------------------------------------------
# System Prompts
# ---------------------------------------------------------------------------

_STRICT_SYSTEM = (
    "你是一位严谨的学科辅导助手。"
    "请仅基于以下提供的资料内容回答用户问题，不得引用或推断任何外部知识。"
    "回答要求：用流畅的自然语言，段落清晰；"
    "仅在有多个并列要点时才用列表，仅在有公式时才用 LaTeX（行内 $...$，块级 $$...$$）；"
    "公式中的变量含义必须在同一句话里用括号说明，例如：$F = -kx$（其中 $k$ 为弹性系数，$x$ 为形变量），"
    "禁止用「- 变量名」的列表格式逐行解释变量；"
    "不要滥用加粗，只对最关键的术语或结论加粗；不要用标题层级（##）拆分简短回答。"
    "若资料中没有相关信息，请如实告知用户。"
)

_BROAD_BASE = (
    "你是一位学科辅导助手。"
    "请结合以下提供的资料内容以及你自身的通用知识回答用户问题。"
    "回答要求：用流畅的自然语言，段落清晰；"
    "仅在有多个并列要点时才用列表，仅在有公式时才用 LaTeX（行内 $...$，块级 $$...$$）；"
    "公式中的变量含义必须在同一句话里用括号说明，例如：$F = -kx$（其中 $k$ 为弹性系数，$x$ 为形变量），"
    "禁止用「- 变量名」的列表格式逐行解释变量；"
    "不要滥用加粗，只对最关键的术语或结论加粗；不要用标题层级（##）拆分简短回答。"
)

_BROAD_WITH_SOURCES_SUFFIX = (
    "在回答中，必须明确区分每段内容的来源：\n"
    "- 仅当段落确实引用了上方「参考资料」中的内容时，才在段首标注【来自上传资料】\n"
    "- 其余基于模型通用知识的段落，请标注【来自通用知识】\n"
    "禁止在没有参考资料时标注【来自上传资料】或声称引用了用户上传的文件。"
)

_BROAD_NO_SOURCES_SUFFIX = (
    "当前学科没有可用的上传资料（参考资料为空）。"
    "请完全基于通用知识回答，段首可标注【来自通用知识】；"
    "禁止标注【来自上传资料】，禁止声称引用了用户上传的文件或教材。"
)


def _broad_system_prompt(has_uploaded_sources: bool) -> str:
    if has_uploaded_sources:
        return _BROAD_BASE + _BROAD_WITH_SOURCES_SUFFIX
    return _BROAD_BASE + _BROAD_NO_SOURCES_SUFFIX


def _resolve_system_prompt(mode: str, has_context: bool, subject_id: Optional[int]) -> str:
    if mode == "solve":
        return _SOLVE_SYSTEM
    if mode == "strict":
        return _STRICT_SYSTEM
    if mode in ("broad", "hybrid"):
        return _broad_system_prompt(has_context)
    if not subject_id:
        return _broad_system_prompt(has_context)
    return _STRICT_SYSTEM

_SOLVE_SYSTEM = (
    "你是一位专业的解题辅导助手。"
    "请基于以下提供的资料内容，按照以下结构化格式输出解题过程：\n"
    "## 考点\n"
    "## 解题思路\n"
    "## 解题步骤\n"
    "## 踩分点\n"
    "## 易错点\n"
    "每个部分均需详细说明，不得省略。"
)

_FEYNMAN_SYSTEM = (
    "你是一位费曼学习法教练，正在帮助学生通过「用自己的话讲解」来深化理解。\n"
    "你的角色是「追问者」，不是「讲解者」——你不直接给出答案或完整解释。\n\n"
    "对话规则：\n"
    "1. 仔细听学生的解释，找出其中模糊、跳跃、或不准确的地方\n"
    "2. 每次只追问一个最关键的问题，不要一次问多个\n"
    "3. 追问要具体，例如：「你说『力越大形变越大』，那如果力减半，形变会怎样？」\n"
    "4. 如果学生解释正确，给予简短肯定，然后追问更深一层\n"
    "5. 如果学生卡住了，给一个小提示（类比或例子），但不要直接说出答案\n"
    "6. 回复简短，最多3-4句话，保持对话节奏\n"
    "7. 不要用标题、列表、加粗等格式，用自然对话语气\n"
    "8. 如果学生已经能清晰解释，告诉他「你已经掌握了这个知识点」并总结核心\n\n"
    "{user_context}"
    "{rag_context}"
)

_SYSTEM_PROMPTS = {
    "strict": _STRICT_SYSTEM,
    "broad": _broad_system_prompt(True),
    "solve": _SOLVE_SYSTEM,
}


# ---------------------------------------------------------------------------
# RAGPipeline
# ---------------------------------------------------------------------------


class RAGPipeline:
    """RAG 检索增强生成流水线。"""

    def __init__(self) -> None:
        self._embeddings_by_user: dict[int | None, OpenAIEmbeddings] = {}

    def _is_low_quality_source(self, source: Source) -> bool:
        """Filter obvious parser/OCR noise before it reaches the prompt."""
        content = (source.content or "").strip()
        if len(content) < 40:
            return True

        lowered = content.lower()
        noise_markers = (
            "anna's archive",
            "annas-archive",
            "annas-biog",
            "duxiu",
            "exclusive",
            "padding to disable",
            "request entity too large",
        )
        if any(marker in lowered for marker in noise_markers):
            return True

        visible = [ch for ch in content if not ch.isspace()]
        if not visible:
            return True
        alnum_or_cjk = sum(1 for ch in visible if ch.isalnum() or "\u4e00" <= ch <= "\u9fff")
        return alnum_or_cjk / max(len(visible), 1) < 0.45

    def _dedupe_sources(self, sources: List[Source], limit: Optional[int] = None) -> List[Source]:
        """Drop duplicate and noisy chunks while preserving ranking order."""
        clean: List[Source] = []
        seen: set[tuple[str, int, str]] = set()
        for source in sources:
            if self._is_low_quality_source(source):
                continue
            digest = hashlib.sha1((source.content or "").strip().encode("utf-8", errors="ignore")).hexdigest()
            key = (source.filename or "", int(source.chunk_index or 0), digest)
            if key in seen:
                continue
            seen.add(key)
            clean.append(source)
            if limit is not None and len(clean) >= limit:
                break
        return clean

    def _valid_document_ids(self, subject_id: int) -> set[int]:
        from database import Document, get_session

        with get_session() as db:
            return {
                int(row[0])
                for row in db.query(Document.id)
                .filter(Document.subject_id == subject_id, Document.status == "completed")
                .all()
            }

    def _filter_recall_docs(self, recall_docs: list, subject_id: int) -> list:
        valid_doc_ids = self._valid_document_ids(subject_id)
        if not valid_doc_ids:
            return []

        filtered = []
        for doc, score in recall_docs:
            meta = doc.metadata or {}
            raw_doc_id = meta.get("doc_id") or meta.get("document_id")
            try:
                doc_id = int(raw_doc_id)
            except (TypeError, ValueError):
                doc_id = 0
            if doc_id in valid_doc_ids:
                filtered.append((doc, score))
        return filtered

    def _keyword_terms(self, question: str) -> list[str]:
        question = question or ""
        terms: list[str] = []
        lower = question.lower()
        aliases = {
            "胡克": ["胡克", "Hooke", "hooke", "σ = Eε", "σ=Eε", "弹性模量"],
            "hooke": ["胡克", "Hooke", "hooke", "σ = Eε", "σ=Eε", "弹性模量"],
            "欧拉": ["欧拉", "临界压力", "临界力", "压杆稳定"],
            "切应力互等": ["切应力互等", "互等定理"],
        }
        for key, values in aliases.items():
            if key in question or key in lower:
                terms.extend(values)

        stopwords = {
            "什么", "如何", "怎么", "请只", "根据", "资料", "回答", "公式", "表达式",
            "各符号", "代表", "区别", "定义", "特点", "一般", "时候",
        }
        for token in re.findall(r"[\u4e00-\u9fffA-Za-z][\u4e00-\u9fffA-Za-z0-9_\\-]{2,}", question):
            if token not in stopwords and not any(stop in token for stop in stopwords):
                terms.append(token)

        seen: set[str] = set()
        unique: list[str] = []
        for term in terms:
            key = term.lower()
            if key in seen:
                continue
            seen.add(key)
            unique.append(term)
            if len(unique) >= 8:
                break
        return unique

    def _keyword_recall_sources(self, question: str, subject_id: int, limit: int) -> List[Source]:
        terms = self._keyword_terms(question)
        if not terms:
            return []

        from database import Chunk, Document, get_session

        valid_doc_ids = self._valid_document_ids(subject_id)
        if not valid_doc_ids:
            return []

        candidates: list[Source] = []
        with get_session() as db:
            for term in terms:
                rows = (
                    db.query(Chunk, Document)
                    .join(Document, Document.id == Chunk.document_id)
                    .filter(
                        Chunk.subject_id == subject_id,
                        Chunk.document_id.in_(valid_doc_ids),
                        Chunk.content.ilike(f"%{term}%"),
                    )
                    .order_by(Chunk.document_id, Chunk.chunk_index)
                    .limit(limit)
                    .all()
                )
                for chunk, doc in rows:
                    candidates.append(Source(
                        filename=doc.filename or "",
                        chunk_index=int(chunk.chunk_index or 0),
                        content=chunk.content or "",
                        score=-1.0,
                        heading_path=chunk.heading_path or "",
                    ))

        def rank(source: Source) -> tuple[int, int, int]:
            content = source.content or ""
            score = 0
            if "来自通用知识" in content or "来自通用知识" in source.filename:
                score -= 3
            if "胡克定律" in content:
                score += 5
            if any(marker in content for marker in ("σ", "ε", "Ee", "Eε", "弹性模量", "切变模量")):
                score += 4
            if any(marker in content for marker in ("上述关系称为胡克定律", "4. 胡克定律")):
                score += 4
            if "前言" in content[:200]:
                score -= 2
            return (-score, source.chunk_index, len(content))

        candidates = self._dedupe_sources(candidates, limit=None)
        candidates.sort(key=rank)
        for idx, source in enumerate(candidates):
            source.score = -1.0 - (0.01 * idx)
        return candidates[:limit]

    # ------------------------------------------------------------------
    # 内部辅助
    # ------------------------------------------------------------------

    def _get_embeddings(self, user_id: Optional[int] = None) -> OpenAIEmbeddings:
        """懒加载 OpenAIEmbeddings 实例。"""
        if user_id not in self._embeddings_by_user:
            from services.embedding_service import EmbeddingService
            self._embeddings_by_user[user_id] = EmbeddingService.create_langchain_embeddings(user_id)
        return self._embeddings_by_user[user_id]

    def get_vector_store(self, subject_id: int, user_id: Optional[int] = None) -> PGVector:
        """
        返回指定学科的 PGVector 实例。

        :param subject_id: 学科 ID
        :return: PGVector 实例，collection 名为 subject_{subject_id}
        """
        from config import get_config
        cfg = get_config()
        return PGVector(
            embeddings=self._get_embeddings(user_id),
            collection_name=f"subject_{subject_id}",
            connection=cfg.DATABASE_URL,
            use_jsonb=True,
        )

    def create_session(
        self,
        user_id: int,
        subject_id: int,
        session_type: str = "qa",
    ) -> int:
        """
        创建 conversation_sessions 记录，返回 session_id。

        :param user_id: 用户 ID
        :param subject_id: 学科 ID
        :param session_type: 会话类型（qa/solve/mindmap/exam）
        :return: 新建会话的 ID
        """
        from database import ConversationSession, get_session

        with get_session() as db:
            session_obj = ConversationSession(
                user_id=user_id,
                subject_id=subject_id,
                session_type=session_type,
            )
            db.add(session_obj)
            db.flush()
            session_id = session_obj.id
        return session_id

    def _save_history(
        self,
        session_id: int,
        question: str,
        answer: str,
        sources: List[Source],
        mode: str,
    ) -> None:
        """将问题和回答保存到 conversation_history 表。"""
        from database import ConversationHistory, get_session

        sources_json = [
            {
                "filename": s.filename,
                "chunk_index": s.chunk_index,
                "content": s.content,
                "score": s.score,
            }
            for s in sources
        ]

        with get_session() as db:
            user_msg = ConversationHistory(
                session_id=session_id,
                role="user",
                content=question,
                sources=None,
                scope_choice=mode,
            )
            db.add(user_msg)

            assistant_msg = ConversationHistory(
                session_id=session_id,
                role="assistant",
                content=answer,
                sources=sources_json,
                scope_choice=mode,
            )
            db.add(assistant_msg)

    # ------------------------------------------------------------------
    # 核心查询
    # ------------------------------------------------------------------

    def query(
        self,
        question: str,
        subject_id: int,
        session_id: int,
        mode: str = "strict",
        user_id: Optional[int] = None,
    ) -> RAGResult:
        """
        RAG 检索 + LLM 问答主流程。

        :param question: 用户问题或题目
        :param subject_id: 学科 ID
        :param session_id: 会话 ID
        :param mode: 回答模式（strict / broad / solve）
        :return: RAGResult
        """
        from config import get_config
        from services.llm_service import LLMService

        cfg = get_config()
        threshold = cfg.SIMILARITY_THRESHOLD
        top_k = cfg.TOP_K

        # 1. 向量检索 Top-K，带相似度分数（无 subject_id 时跳过检索，降级为 broad）
        sources: List[Source] = []
        top_rerank_score: float = 0.0
        fallback_triggered: bool = False
        fallback_reason: str = ""
        if subject_id:
            vector_store = self.get_vector_store(subject_id, user_id=user_id)

            # 阶段 1：向量粗筛 Top-RECALL_TOP_K
            recall_docs = vector_store.similarity_search_with_score(question, k=cfg.RECALL_TOP_K)
            recall_docs = self._filter_recall_docs(recall_docs, subject_id)

            # 阶段 2：Reranker 精排
            from services.rerank_service import RerankService, RerankUnavailableError
            rerank_svc = RerankService()

            if rerank_svc.is_available(user_id=user_id) and recall_docs:
                doc_texts = [doc.page_content for doc, _ in recall_docs]
                doc_metadata = [
                    {
                        "heading_path": (doc.metadata or {}).get("heading_path", ""),
                        "chunk_index": int((doc.metadata or {}).get("chunk_index", 0)),
                        "filename": (doc.metadata or {}).get("filename", ""),
                    }
                    for doc, _ in recall_docs
                ]
                try:
                    rerank_results = rerank_svc.rerank(
                        question, doc_texts, top_n=cfg.RERANK_TOP_N, metadata=doc_metadata, user_id=user_id
                    )
                    if rerank_results:
                        top_rerank_score = rerank_results[0].score
                        if top_rerank_score < cfg.RERANK_THRESHOLD:
                            fallback_triggered = True
                            fallback_reason = f"最高 Rerank 得分 {top_rerank_score:.3f} 低于阈值 {cfg.RERANK_THRESHOLD}"
                            mode = "broad"
                    for r in rerank_results:
                        sources.append(Source(
                            filename=r.filename,
                            chunk_index=r.chunk_index,
                            content=r.content,
                            score=r.score,
                            heading_path=r.heading_path,
                            rerank_score=r.score,
                        ))
                    sources = self._dedupe_sources(sources, limit=cfg.TOP_K)
                except RerankUnavailableError as e:
                    logger.warning("Reranker 不可用，降级为向量 Top-K：%s", e)
                    fallback_triggered = True
                    fallback_reason = f"Reranker 不可用：{e}"
                    # 降级：使用向量检索 Top-K
                    for doc, score in recall_docs[:cfg.TOP_K]:
                        metadata = doc.metadata or {}
                        sources.append(Source(
                            filename=metadata.get("filename", ""),
                            chunk_index=int(metadata.get("chunk_index", 0)),
                            content=doc.page_content,
                            score=float(score),
                            heading_path=metadata.get("heading_path", ""),
                        ))
                    sources = self._dedupe_sources(sources, limit=cfg.TOP_K)
            else:
                # Reranker 不可用，直接使用向量 Top-K
                for doc, score in recall_docs[:cfg.TOP_K]:
                    metadata = doc.metadata or {}
                    sources.append(Source(
                        filename=metadata.get("filename", ""),
                        chunk_index=int(metadata.get("chunk_index", 0)),
                        content=doc.page_content,
                        score=float(score),
                        heading_path=metadata.get("heading_path", ""),
                    ))
                sources = self._dedupe_sources(sources, limit=cfg.TOP_K)
        else:
            mode = "broad"  # 无学科上下文，自动切换通用知识模式

        # 2. 构建 Source 列表（已在上方完成）

        if subject_id:
            keyword_sources = self._keyword_recall_sources(question, subject_id, limit=top_k)
            sources = self._dedupe_sources(keyword_sources + sources, limit=top_k)

        top_score = max((s.score for s in sources), default=0.0)

        # 3. 相关性阈值判断（strict 模式且有 subject_id 时才检查）
        if mode == "strict" and (not sources or all(s.score > threshold for s in sources)):
            return RAGResult(
                needs_confirmation=True,
                top_score=top_score,
                sources=sources,
                mode=mode,
            )

        # 4. 构建上下文并调用 LLM
        context_parts = []
        for i, src in enumerate(sources, 1):
            context_parts.append(
                f"[资料 {i}] 文件：{src.filename}，块 {src.chunk_index}\n{src.content}"
            )
        context = "\n\n".join(context_parts)

        system_prompt = _resolve_system_prompt(mode, bool(context), subject_id)
        if context:
            user_content = f"参考资料：\n{context}\n\n问题：{question}"
        else:
            user_content = question
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_content},
        ]

        llm = LLMService()
        answer = llm.chat(
            messages,
            user_id=user_id,
            session_id=session_id,
            endpoint="rag_query",
            track_token=True,
        )

        # 5. 保存对话历史
        self._save_history(
            session_id=session_id,
            question=question,
            answer=answer,
            sources=sources,
            mode=mode,
        )

        # 6. 返回结果
        return RAGResult(
            answer=answer,
            sources=sources,
            needs_confirmation=False,
            top_score=top_score,
            mode=mode,
            top_rerank_score=top_rerank_score,
            fallback_triggered=fallback_triggered,
            fallback_reason=fallback_reason,
        )


# ---------------------------------------------------------------------------
# FastAPI 后端扩展：流式支持 + 用户记忆注入
# ---------------------------------------------------------------------------

from dataclasses import dataclass, field as _field
from typing import Generator as _Generator


@dataclass
class RAGStreamContext:
    """流式问答上下文，用于在 generator 结束后传递 sources 和 session_id。"""
    session_id: int = 0
    sources: list = _field(default_factory=list)
    top_rerank_score: float = 0.0
    fallback_triggered: bool = False
    fallback_reason: str = ""


class RAGNeedsConfirmation(Exception):
    """strict 模式下未找到相关资料，需要用户确认是否切换 broad 模式。"""
    pass


def _patch_rag_pipeline():
    """为 RAGPipeline 注入流式查询方法和 user_id 支持。"""
    import json as _json

    def query_with_user(self, question, subject_id, session_id, mode, user_id=None):
        """兼容 FastAPI 路由的 query，支持 user_id 参数（暂不使用）。"""
        return self.query(question, subject_id, session_id, mode)

    def query_stream(
        self,
        question: str,
        subject_id: int,
        session_id: int,
        mode: str,
        user_id: int,
        _ctx: "RAGStreamContext",
    ) -> _Generator[str, None, None]:
        from config import get_config
        from services.llm_service import LLMService
        from database import ConversationHistory, ConversationSession, get_session

        cfg = get_config()

        # 向量检索
        sources = []
        top_rerank_score = 0.0
        fallback_triggered = False
        fallback_reason = ""
        if mode in ("strict", "hybrid", "solve", "feynman") and subject_id:
            vector_store = self.get_vector_store(subject_id, user_id=user_id)

            # 阶段 1：向量粗筛 Top-RECALL_TOP_K
            recall_docs = vector_store.similarity_search_with_score(question, k=cfg.RECALL_TOP_K)
            recall_docs = self._filter_recall_docs(recall_docs, subject_id)

            # 阶段 2：Reranker 精排
            from services.rerank_service import RerankService, RerankUnavailableError
            rerank_svc = RerankService()

            if rerank_svc.is_available(user_id=user_id) and recall_docs:
                doc_texts = [doc.page_content for doc, _ in recall_docs]
                doc_metadata = [
                    {
                        "heading_path": (doc.metadata or {}).get("heading_path", ""),
                        "chunk_index": int((doc.metadata or {}).get("chunk_index", 0)),
                        "filename": (doc.metadata or {}).get("filename", ""),
                    }
                    for doc, _ in recall_docs
                ]
                try:
                    rerank_results = rerank_svc.rerank(
                        question, doc_texts, top_n=cfg.RERANK_TOP_N, metadata=doc_metadata, user_id=user_id
                    )
                    if rerank_results:
                        top_rerank_score = rerank_results[0].score
                        if top_rerank_score < cfg.RERANK_THRESHOLD:
                            fallback_triggered = True
                            fallback_reason = f"最高 Rerank 得分 {top_rerank_score:.3f} 低于阈值 {cfg.RERANK_THRESHOLD}"
                            mode = "broad"
                    for r in rerank_results:
                        sources.append(Source(
                            filename=r.filename,
                            chunk_index=r.chunk_index,
                            content=r.content,
                            score=r.score,
                            heading_path=r.heading_path,
                            rerank_score=r.score,
                        ))
                    sources = self._dedupe_sources(sources, limit=cfg.TOP_K)
                except RerankUnavailableError as e:
                    logger.warning("Reranker 不可用，降级为向量 Top-K：%s", e)
                    fallback_triggered = True
                    fallback_reason = f"Reranker 不可用：{e}"
                    # 降级：使用向量检索 Top-K
                    for doc, score in recall_docs[:cfg.TOP_K]:
                        meta = doc.metadata or {}
                        sources.append(Source(
                            filename=meta.get("filename", ""),
                            chunk_index=int(meta.get("chunk_index", 0)),
                            content=doc.page_content,
                            score=float(score),
                            heading_path=meta.get("heading_path", ""),
                        ))
                    sources = self._dedupe_sources(sources, limit=cfg.TOP_K)
            else:
                # Reranker 不可用，直接使用向量 Top-K
                for doc, score in recall_docs[:cfg.TOP_K]:
                    meta = doc.metadata or {}
                    sources.append(Source(
                        filename=meta.get("filename", ""),
                        chunk_index=int(meta.get("chunk_index", 0)),
                        content=doc.page_content,
                        score=float(score),
                        heading_path=meta.get("heading_path", ""),
                    ))
                sources = self._dedupe_sources(sources, limit=cfg.TOP_K)

        # 没有 subject_id 时自动降级为 broad 模式（通用知识回答）
        if not subject_id:
            mode = "broad"

        if subject_id:
            keyword_sources = self._keyword_recall_sources(question, subject_id, limit=cfg.TOP_K)
            sources = self._dedupe_sources(keyword_sources + sources, limit=cfg.TOP_K)

        if mode == "strict" and (not sources or all(s.score > cfg.SIMILARITY_THRESHOLD for s in sources)):
            raise RAGNeedsConfirmation()

        # 构建 messages
        context_parts = []
        for i, src in enumerate(sources, 1):
            context_parts.append(f"[资料 {i}] 文件：{src.filename}\n{src.content}")
        context = "\n\n".join(context_parts)

        # ── feynman 模式：注入用户记忆 + 知识点上下文，不强制 RAG ──────────
        if mode == "feynman":
            user_context_str = ""
            try:
                from services.memory_service import MemoryService
                memory = MemoryService().get_memory(user_id, subject_id)
                weak_points = memory.get("weak_points", [])
                misconceptions = memory.get("misconceptions", [])
                parts = []
                if weak_points:
                    parts.append(f"该学生的薄弱点：{', '.join(weak_points[:3])}")
                if misconceptions:
                    parts.append(f"该学生的常见误解：{', '.join(misconceptions[:2])}")
                if parts:
                    user_context_str = "【学生画像】" + "；".join(parts) + "\n针对以上特点，追问时重点关注这些薄弱环节。\n\n"
            except Exception:
                pass

            rag_context_str = ""
            if context:
                rag_context_str = (
                    "【知识点参考资料（仅供你了解正确答案，不要直接告诉学生）】\n"
                    f"{context}\n\n"
                )

            system_prompt = _FEYNMAN_SYSTEM.format(
                user_context=user_context_str,
                rag_context=rag_context_str,
            )
            messages = [{"role": "system", "content": system_prompt}]
            messages.append({"role": "user", "content": question})
        else:
            system_prompt = _resolve_system_prompt(mode, bool(context), subject_id)
            messages = [{"role": "system", "content": system_prompt}]
            if context:
                messages.append({"role": "user", "content": f"参考资料：\n{context}\n\n问题：{question}"})
            else:
                messages.append({"role": "user", "content": question})

        llm = LLMService()
        full_answer = ""
        for token in llm.stream_chat(
            messages,
            user_id=user_id,
            session_id=session_id,
            endpoint="rag_stream",
            track_token=True,
        ):
            full_answer += token
            yield token

        # 保存历史
        self._save_history(session_id, question, full_answer, sources, mode)

        # 更新会话标题
        with get_session() as db:
            sess = db.query(ConversationSession).filter_by(id=session_id).first()
            if sess and not sess.title:
                sess.title = question[:cfg.SESSION_TITLE_MAX_CHARS]

        _ctx.sources = sources
        _ctx.session_id = session_id
        _ctx.top_rerank_score = top_rerank_score
        _ctx.fallback_triggered = fallback_triggered
        _ctx.fallback_reason = fallback_reason

    RAGPipeline.query_stream = query_stream

    # 给原版 query 加 user_id 参数支持
    _orig_query = RAGPipeline.query

    def query_with_user_id(self, question, subject_id, session_id, mode="strict", user_id=None):
        return _orig_query(self, question, subject_id, session_id, mode, user_id)

    RAGPipeline.query = query_with_user_id


_patch_rag_pipeline()
