"""
RAG 流水线：向量检索 + LLM 问答/解题，支持 strict / broad / solve 三种模式。
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import List, Optional

from langchain_openai import OpenAIEmbeddings
from langchain_postgres import PGVector


# ---------------------------------------------------------------------------
# 数据类
# ---------------------------------------------------------------------------


@dataclass
class Source:
    filename: str
    chunk_index: int
    content: str
    score: float


@dataclass
class RAGResult:
    answer: str = ""
    sources: List[Source] = field(default_factory=list)
    needs_confirmation: bool = False  # 相关性不足，需用户确认
    top_score: float = 0.0
    mode: str = "strict"  # strict | broad | solve


# ---------------------------------------------------------------------------
# System Prompts
# ---------------------------------------------------------------------------

_STRICT_SYSTEM = (
    "你是一位严谨的学科辅导助手。"
    "请仅基于以下提供的资料内容回答用户问题，不得引用或推断任何外部知识。"
    "回答要求：用流畅的自然语言，段落清晰；"
    "仅在有多个并列要点时才用列表，仅在有公式时才用 LaTeX（行内 $...$，块级 $$...$$）；"
    "不要滥用加粗，只对最关键的术语或结论加粗；不要用标题层级（##）拆分简短回答。"
    "若资料中没有相关信息，请如实告知用户。"
)

_BROAD_SYSTEM = (
    "你是一位学科辅导助手。"
    "请结合以下提供的资料内容以及你自身的通用知识回答用户问题。"
    "回答要求：用流畅的自然语言，段落清晰；"
    "仅在有多个并列要点时才用列表，仅在有公式时才用 LaTeX（行内 $...$，块级 $$...$$）；"
    "不要滥用加粗，只对最关键的术语或结论加粗；不要用标题层级（##）拆分简短回答。"
    "在回答中，必须明确区分每段内容的来源：\n"
    "- 来自上传资料的内容，请在段落前标注【来自上传资料】\n"
    "- 来自通用知识的内容，请在段落前标注【来自通用知识】"
)

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

_SYSTEM_PROMPTS = {
    "strict": _STRICT_SYSTEM,
    "broad": _BROAD_SYSTEM,
    "solve": _SOLVE_SYSTEM,
}


# ---------------------------------------------------------------------------
# RAGPipeline
# ---------------------------------------------------------------------------


class RAGPipeline:
    """RAG 检索增强生成流水线。"""

    def __init__(self) -> None:
        self._embeddings: Optional[OpenAIEmbeddings] = None

    # ------------------------------------------------------------------
    # 内部辅助
    # ------------------------------------------------------------------

    def _get_embeddings(self) -> OpenAIEmbeddings:
        """懒加载 OpenAIEmbeddings 实例。"""
        if self._embeddings is None:
            from config import get_config
            cfg = get_config()
            self._embeddings = OpenAIEmbeddings(
                model=cfg.LLM_EMBEDDING_MODEL,
                openai_api_key=cfg.LLM_API_KEY,
                openai_api_base=cfg.LLM_BASE_URL,
            )
        return self._embeddings

    def get_vector_store(self, subject_id: int) -> PGVector:
        """
        返回指定学科的 PGVector 实例。

        :param subject_id: 学科 ID
        :return: PGVector 实例，collection 名为 subject_{subject_id}
        """
        from config import get_config
        cfg = get_config()
        return PGVector(
            embeddings=self._get_embeddings(),
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
        if subject_id:
            vector_store = self.get_vector_store(subject_id)
            docs_with_scores = vector_store.similarity_search_with_score(question, k=top_k)
            for doc, score in docs_with_scores:
                metadata = doc.metadata or {}
                sources.append(
                    Source(
                        filename=metadata.get("filename", ""),
                        chunk_index=int(metadata.get("chunk_index", 0)),
                        content=doc.page_content,
                        score=float(score),
                    )
                )
        else:
            mode = "broad"  # 无学科上下文，自动切换通用知识模式

        # 2. 构建 Source 列表（已在上方完成）

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

        system_prompt = _SYSTEM_PROMPTS.get(mode, _BROAD_SYSTEM if not subject_id else _STRICT_SYSTEM)
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
        if mode in ("strict", "hybrid", "solve") and subject_id:
            vector_store = self.get_vector_store(subject_id)
            docs_with_scores = vector_store.similarity_search_with_score(question, k=cfg.TOP_K)
            for doc, score in docs_with_scores:
                meta = doc.metadata or {}
                sources.append(Source(
                    filename=meta.get("filename", ""),
                    chunk_index=int(meta.get("chunk_index", 0)),
                    content=doc.page_content,
                    score=float(score),
                ))

        # 没有 subject_id 时自动降级为 broad 模式（通用知识回答）
        if not subject_id:
            mode = "broad"

        if mode == "strict" and (not sources or all(s.score > cfg.SIMILARITY_THRESHOLD for s in sources)):
            raise RAGNeedsConfirmation()

        # 构建 messages
        context_parts = []
        for i, src in enumerate(sources, 1):
            context_parts.append(f"[资料 {i}] 文件：{src.filename}\n{src.content}")
        context = "\n\n".join(context_parts)

        system_prompt = _SYSTEM_PROMPTS.get(mode, _STRICT_SYSTEM)
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

    RAGPipeline.query_stream = query_stream

    # 给原版 query 加 user_id 参数支持
    _orig_query = RAGPipeline.query

    def query_with_user_id(self, question, subject_id, session_id, mode="strict", user_id=None):
        return _orig_query(self, question, subject_id, session_id, mode, user_id)

    RAGPipeline.query = query_with_user_id


_patch_rag_pipeline()
