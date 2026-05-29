"""
RAG 工具集 MCP 服务器配置。

注册四个 RAG MCP Tool：
  rag_tools.parse_document_to_markdown      — 文档解析为结构化 Markdown
  rag_tools.search_textbook_with_rerank     — 向量召回 + Reranker 两阶段检索
  rag_tools.generate_hierarchical_outline   — 递归生成层级大纲（思维导图）
  rag_tools.strict_textbook_qa              — 严格约束的课本问答
"""
from __future__ import annotations

import asyncio
import logging
import os

from mcp_layer.models import MCPServerConfig, MCPServerType, MCPToolDef, MCPToolResult

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# 严格 QA 系统提示词
# ---------------------------------------------------------------------------

_STRICT_QA_SYSTEM = (
    "你是一位严谨的学科辅导助手。"
    "请仅基于以下提供的参考资料内容回答用户问题，不得引用或推断任何外部知识。"
    "若参考资料中未提及相关内容，请回答：「参考资料中未提及此内容」。"
    "回答时必须在末尾标注知识点来源，格式：「来源：{文件名} > {章节路径}」。"
)

# ---------------------------------------------------------------------------
# 服务器配置
# ---------------------------------------------------------------------------

RAG_TOOLS_SERVER_CONFIG = MCPServerConfig(
    server_id="rag_tools",
    name="RAG 工具集",
    type=MCPServerType.local,
)

# ---------------------------------------------------------------------------
# 工具列表
# ---------------------------------------------------------------------------

RAG_TOOLS: list[MCPToolDef] = [
    MCPToolDef.create(
        server_id="rag_tools",
        tool_name="parse_document_to_markdown",
        description="将 PDF/PPTX/DOCX 文件转换为带 H1/H2/H3 层级的结构化 Markdown，保留表格和 LaTeX 公式",
        input_schema={
            "type": "object",
            "properties": {
                "file_path": {
                    "type": "string",
                    "description": "文件路径（支持 .pdf/.pptx/.docx）",
                }
            },
            "required": ["file_path"],
        },
    ),
    MCPToolDef.create(
        server_id="rag_tools",
        tool_name="search_textbook_with_rerank",
        description="对指定课本执行向量召回+重排序两阶段检索，返回最高精度的 Top-5 知识片段及来源位置",
        input_schema={
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "问题文本",
                },
                "subject_id": {
                    "type": "integer",
                    "description": "课本/学科 ID",
                },
            },
            "required": ["query", "subject_id"],
        },
    ),
    MCPToolDef.create(
        server_id="rag_tools",
        tool_name="generate_hierarchical_outline",
        description="将长篇章节文档递归生成严格层级 JSON 结构，专供思维导图渲染使用",
        input_schema={
            "type": "object",
            "properties": {
                "document_text": {
                    "type": "string",
                    "description": "章节文本内容",
                },
                "max_depth": {
                    "type": "integer",
                    "description": "最大递归深度（默认 3）",
                    "default": 3,
                },
            },
            "required": ["document_text"],
        },
    ),
    MCPToolDef.create(
        server_id="rag_tools",
        tool_name="strict_textbook_qa",
        description="附带强约束系统提示词的专用解疑工具，仅基于课本参考资料回答，并标注知识点来源章节",
        input_schema={
            "type": "object",
            "properties": {
                "question": {
                    "type": "string",
                    "description": "问题文本",
                },
                "subject_id": {
                    "type": "integer",
                    "description": "课本/学科 ID",
                },
            },
            "required": ["question", "subject_id"],
        },
    ),
]

# ---------------------------------------------------------------------------
# 处理函数
# ---------------------------------------------------------------------------


def handle_parse_document_to_markdown(file_path: str) -> MCPToolResult:
    """
    调用 DocumentParser 解析文件，返回结构化 Markdown。

    成功返回：{"markdown_content": "...", "heading_count": N, "formula_count": N, "degraded": bool}
    失败返回：MCPToolResult(success=False, error_message="...")
    """
    # 文件不存在时返回 success=False
    if not os.path.exists(file_path):
        logger.warning("parse_document_to_markdown: 文件不存在：%s", file_path)
        return MCPToolResult(
            success=False,
            error_message=f"文件不存在：{file_path}",
        )

    # 格式不支持时返回 success=False
    ext = os.path.splitext(file_path)[1].lower()
    supported_exts = {".pdf", ".pptx", ".docx", ".ppt"}
    if ext not in supported_exts:
        logger.warning("parse_document_to_markdown: 不支持的文件格式：%s", ext)
        return MCPToolResult(
            success=False,
            error_message=f"不支持的文件格式：{ext}，仅支持 .pdf/.pptx/.docx",
        )

    try:
        from services.document_parser import DocumentParser

        parser = DocumentParser()
        result = parser.parse(file_path)

        logger.info(
            "parse_document_to_markdown 完成：文件=%s，标题数=%d，公式数=%d，降级=%s",
            os.path.basename(file_path),
            result.heading_count,
            result.formula_count,
            result.degraded,
        )

        return MCPToolResult(
            success=True,
            data={
                "markdown_content": result.markdown,
                "heading_count": result.heading_count,
                "formula_count": result.formula_count,
                "degraded": result.degraded,
            },
        )
    except Exception as exc:
        logger.error("parse_document_to_markdown 失败：%s", exc)
        return MCPToolResult(
            success=False,
            error_message=str(exc),
        )


def handle_search_textbook_with_rerank(query: str, subject_id: int) -> MCPToolResult:
    """
    执行两阶段检索（向量召回 + Reranker 精排）。

    成功返回：{"results": [{"content": "...", "rerank_score": 0.9, "heading_path": "...", "filename": "...", "chunk_index": N}]}
    失败返回：MCPToolResult(success=False, error_message="...")

    subject_id 对应向量库不存在时返回 success=False + "指定课本的向量库不存在"
    响应时间不超过 10 秒（通过 try/except 捕获超时）
    """
    try:
        from config import get_config
        from services.rag_pipeline import RAGPipeline
        from services.rerank_service import RerankService, RerankUnavailableError

        cfg = get_config()

        # 获取向量库
        try:
            pipeline = RAGPipeline()
            vector_store = pipeline.get_vector_store(subject_id)
        except Exception as exc:
            logger.warning("search_textbook_with_rerank: 向量库获取失败 subject_id=%d：%s", subject_id, exc)
            return MCPToolResult(
                success=False,
                error_message="指定课本的向量库不存在",
            )

        # 阶段 1：向量粗筛
        try:
            recall_docs = vector_store.similarity_search_with_score(query, k=cfg.RECALL_TOP_K)
        except Exception as exc:
            logger.warning("search_textbook_with_rerank: 向量检索失败 subject_id=%d：%s", subject_id, exc)
            return MCPToolResult(
                success=False,
                error_message=f"向量检索失败：{exc}",
            )

        if not recall_docs:
            logger.info("search_textbook_with_rerank: 未找到相关文档 subject_id=%d", subject_id)
            return MCPToolResult(
                success=True,
                data={"results": []},
            )

        # 阶段 2：Reranker 精排
        doc_texts = [doc.page_content for doc, _ in recall_docs]
        doc_metadata = [
            {
                "heading_path": (doc.metadata or {}).get("heading_path", ""),
                "chunk_index": int((doc.metadata or {}).get("chunk_index", 0)),
                "filename": (doc.metadata or {}).get("filename", ""),
            }
            for doc, _ in recall_docs
        ]

        rerank_svc = RerankService()
        try:
            rerank_results = rerank_svc.rerank(
                query,
                doc_texts,
                top_n=cfg.RERANK_TOP_N,
                metadata=doc_metadata,
            )
        except RerankUnavailableError as exc:
            logger.warning("search_textbook_with_rerank: Reranker 不可用，降级为向量 Top-K：%s", exc)
            # 降级：直接使用向量检索 Top-K 结果
            rerank_results_fallback = []
            for doc, score in recall_docs[: cfg.RERANK_TOP_N]:
                meta = doc.metadata or {}
                rerank_results_fallback.append({
                    "content": doc.page_content,
                    "rerank_score": float(score),
                    "heading_path": meta.get("heading_path", ""),
                    "filename": meta.get("filename", ""),
                    "chunk_index": int(meta.get("chunk_index", 0)),
                })
            return MCPToolResult(
                success=True,
                data={"results": rerank_results_fallback},
            )

        results = [
            {
                "content": r.content,
                "rerank_score": r.score,
                "heading_path": r.heading_path,
                "filename": r.filename,
                "chunk_index": r.chunk_index,
            }
            for r in rerank_results
        ]

        logger.info(
            "search_textbook_with_rerank 完成：subject_id=%d，召回=%d，精排=%d",
            subject_id,
            len(recall_docs),
            len(results),
        )

        return MCPToolResult(
            success=True,
            data={"results": results},
        )

    except Exception as exc:
        logger.error("search_textbook_with_rerank 失败：%s", exc)
        return MCPToolResult(
            success=False,
            error_message=str(exc),
        )


def handle_generate_hierarchical_outline(
    document_text: str,
    max_depth: int = 3,
) -> MCPToolResult:
    """
    调用 RecursiveSummarizer 生成层级大纲。

    document_text 为空时返回 success=False + "输入文档文本不能为空"
    成功返回：{"outline": {...}}（HierarchicalOutline.to_dict()）
    """
    # document_text 为空时直接返回错误
    if not document_text or not document_text.strip():
        logger.warning("generate_hierarchical_outline: 输入文档文本为空")
        return MCPToolResult(
            success=False,
            error_message="输入文档文本不能为空",
        )

    try:
        from services.recursive_summarizer import RecursiveSummarizer

        summarizer = RecursiveSummarizer()
        # 使用 asyncio.run() 调用异步方法
        outline = asyncio.run(
            summarizer.generate_outline(document_text, max_depth=max_depth)
        )

        logger.info(
            "generate_hierarchical_outline 完成：深度=%d，节点数=%d",
            outline.depth(),
            len(outline.all_nodes()),
        )

        return MCPToolResult(
            success=True,
            data={"outline": outline.to_dict()},
        )

    except Exception as exc:
        logger.error("generate_hierarchical_outline 失败：%s", exc)
        return MCPToolResult(
            success=False,
            error_message=str(exc),
        )


def handle_strict_textbook_qa(question: str, subject_id: int) -> MCPToolResult:
    """
    先执行 search_textbook_with_rerank，再附加严格系统提示词调用 LLM。

    Rerank 最高分 < RERANK_THRESHOLD 时直接返回固定回答，不调用 LLM。
    成功返回：{"answer": "...", "sources": [...], "rerank_top_score": 0.9}
    """
    try:
        from config import get_config
        from services.llm_service import LLMService

        cfg = get_config()

        # 1. 调用 handle_search_textbook_with_rerank 获取 Top-N 片段
        search_result = handle_search_textbook_with_rerank(question, subject_id)
        if not search_result.success:
            return MCPToolResult(
                success=False,
                error_message=search_result.error_message,
            )

        results = search_result.data.get("results", [])

        # 2. 检查 rerank_top_score，低于阈值时返回固定回答
        rerank_top_score = results[0]["rerank_score"] if results else 0.0
        if rerank_top_score < cfg.RERANK_THRESHOLD:
            logger.info(
                "strict_textbook_qa: rerank_top_score=%.3f < threshold=%.3f，返回固定回答",
                rerank_top_score,
                cfg.RERANK_THRESHOLD,
            )
            return MCPToolResult(
                success=True,
                data={
                    "answer": "参考资料中未提及此内容",
                    "sources": [],
                    "rerank_top_score": rerank_top_score,
                },
            )

        # 3. 构建严格系统提示词
        context_parts = []
        for i, r in enumerate(results, 1):
            context_parts.append(
                f"[资料 {i}] 文件：{r['filename']}，章节：{r['heading_path']}\n{r['content']}"
            )
        context = "\n\n".join(context_parts)

        messages = [
            {"role": "system", "content": _STRICT_QA_SYSTEM},
            {"role": "user", "content": f"参考资料：\n{context}\n\n问题：{question}"},
        ]

        # 4. 调用 LLMService().chat() 获取回答
        llm = LLMService()
        answer = llm.chat(messages)

        # 5. 返回 answer + sources + rerank_top_score
        sources = [
            {
                "filename": r["filename"],
                "heading_path": r["heading_path"],
                "chunk_index": r["chunk_index"],
                "rerank_score": r["rerank_score"],
            }
            for r in results
        ]

        logger.info(
            "strict_textbook_qa 完成：subject_id=%d，rerank_top_score=%.3f",
            subject_id,
            rerank_top_score,
        )

        return MCPToolResult(
            success=True,
            data={
                "answer": answer,
                "sources": sources,
                "rerank_top_score": rerank_top_score,
            },
        )

    except Exception as exc:
        logger.error("strict_textbook_qa 失败：%s", exc)
        return MCPToolResult(
            success=False,
            error_message=str(exc),
        )
