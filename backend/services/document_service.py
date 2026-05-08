"""
文档服务：文件解析、文本分块、向量化存储，以及文档的列表与删除。
"""

from __future__ import annotations

import logging
import os
import tempfile
from dataclasses import dataclass
from typing import Any, List
from uuid import uuid4

logger = logging.getLogger(__name__)


@dataclass
class PreparedDocument:
    chunks: list[Any]
    outline: dict[str, Any]
    parser_backend: str


class DocumentService:
    """文档上传、解析、分块、向量化及管理服务。"""

    # ------------------------------------------------------------------
    # 6.1 文件解析器
    # ------------------------------------------------------------------

    def parse_file(self, tmp_path: str, filename: str) -> str:
        from services.file_parser import parse_file
        return parse_file(tmp_path, filename)

    def parse_source(self, tmp_path: str, filename: str) -> tuple[str, str]:
        ext = os.path.splitext(filename)[1].lower()
        if ext in (".txt", ".md"):
            with open(tmp_path, "r", encoding="utf-8") as f:
                return f.read(), ext.lstrip(".")
        if ext in (".pdf", ".docx", ".pptx", ".ppt"):
            from services.document_parser import DocumentParser

            result = DocumentParser().parse(tmp_path)
            return result.markdown, result.backend_used
        return self.parse_file(tmp_path, filename), "fallback"

    # ------------------------------------------------------------------
    # 6.2 文本分块
    # ------------------------------------------------------------------

    def chunk_text(self, text: str) -> List[str]:
        """
        按滑动窗口将文本分块。

        :param text: 待分块文本
        :return: 文本块列表
        """
        if not text:
            return []

        from config import get_config
        cfg = get_config()
        chunk_size = cfg.CHUNK_SIZE
        chunk_overlap = cfg.CHUNK_OVERLAP

        chunks: List[str] = []
        start = 0
        text_len = len(text)

        while start < text_len:
            end = start + chunk_size
            chunks.append(text[start:end])
            if end >= text_len:
                break
            start += chunk_size - chunk_overlap

        return chunks

    def parse_and_chunk(self, tmp_path: str, filename: str) -> list[Any]:
        """
        Parse a source file into structured Markdown and split it with the
        hierarchical chunker so downstream RAG/mindmap jobs keep chapter context.
        """
        return self.prepare_document(tmp_path, filename).chunks

    def prepare_document(self, tmp_path: str, filename: str) -> PreparedDocument:
        text, parser_backend = self.parse_source(tmp_path, filename)
        try:
            from services.chunker import HierarchicalChunker

            chunks = HierarchicalChunker().chunk(text, {"filename": filename})
        except Exception as exc:
            logger.warning("structured chunking failed for %s, falling back: %s", filename, exc)
            chunks = []

        if not chunks:
            chunks = [
                {
                    "content": content,
                    "heading_path": "",
                    "chunk_index": idx,
                    "filename": filename,
                    "is_secondary": False,
                    "token_count": len(content) // 4,
                }
                for idx, content in enumerate(self.chunk_text(text))
            ]

        return PreparedDocument(
            chunks=chunks,
            outline=self._build_outline(chunks),
            parser_backend=parser_backend,
        )

    def _chunk_attr(self, chunk: Any, name: str, default: Any = None) -> Any:
        if isinstance(chunk, dict):
            return chunk.get(name, default)
        return getattr(chunk, name, default)

    def _chunk_content(self, chunk: Any) -> str:
        return str(self._chunk_attr(chunk, "content", ""))

    def _chunk_heading_path(self, chunk: Any) -> str:
        return str(self._chunk_attr(chunk, "heading_path", "") or "")

    def _chunk_index(self, chunk: Any, fallback: int) -> int:
        value = self._chunk_attr(chunk, "chunk_index", fallback)
        return int(value if value is not None else fallback)

    def _chunk_for_storage(self, chunk: Any) -> str:
        content = self._chunk_content(chunk)
        heading_path = self._chunk_heading_path(chunk)
        if not heading_path:
            return content
        return f"[章节路径] {heading_path}\n\n{content}"

    def _build_outline(self, chunks: list[Any]) -> dict[str, Any]:
        contents = [self._chunk_for_storage(chunk) for chunk in chunks]
        try:
            from services.structure_extractor import StructureExtractor

            skeleton = StructureExtractor().extract(contents)
            headings = [
                {
                    "level": h.level,
                    "text": h.text,
                    "line_no": h.line_no,
                    "source_type": h.source_type,
                    "importance": round(float(h.importance or 0), 4),
                }
                for h in skeleton.headings
            ]
            return {
                "heading_count": len(headings),
                "headings": headings,
                "markdown": skeleton.to_markdown_outline(),
            }
        except Exception as exc:
            logger.warning("outline preprocessing failed: %s", exc)
            seen: set[str] = set()
            headings: list[dict[str, Any]] = []
            for chunk in chunks:
                path = self._chunk_heading_path(chunk)
                if path and path not in seen:
                    seen.add(path)
                    headings.append({
                        "level": min(path.count(">") + 1, 4),
                        "text": path,
                        "source_type": "heading_path",
                    })
            return {
                "heading_count": len(headings),
                "headings": headings,
                "markdown": "\n".join(
                    f"{'#' * int(h['level'])} {h['text']}" for h in headings
                ),
            }

    # ------------------------------------------------------------------
    # 6.4 完整上传流程
    # ------------------------------------------------------------------

    def upload_and_process(
        self,
        file_bytes: bytes,
        filename: str,
        subject_id: int,
        user_id: int,
    ) -> dict:
        """
        完整的文件上传与处理流程。

        :param file_bytes: 文件二进制内容
        :param filename: 原始文件名
        :param subject_id: 所属学科 ID
        :param user_id: 上传用户 ID
        :return: {"success": bool, "doc_id": int, "error": str}
        """
        from database import get_session, Document

        tmp_path = os.path.join(tempfile.gettempdir(), f"{uuid4()}_{filename}")
        doc_id: int | None = None

        try:
            # 写入临时文件
            with open(tmp_path, "wb") as f:
                f.write(file_bytes)

            # 1. 写 documents 记录（status='pending'）
            with get_session() as session:
                doc = Document(
                    subject_id=subject_id,
                    user_id=user_id,
                    filename=filename,
                    status="pending",
                    processing_stage="queued",
                    progress=0,
                )
                session.add(doc)
                session.flush()
                doc_id = doc.id

            # 2. 更新 status='processing'
            self._update_doc_status(doc_id, "processing", stage="parsing", progress=10)

            # 3/4. Parse to structured Markdown and keep chapter paths in chunks.
            prepared = self.prepare_document(tmp_path, filename)
            chunks = prepared.chunks
            self._update_doc_status(
                doc_id,
                "processing",
                stage="indexing",
                progress=60,
                parser_backend=prepared.parser_backend,
                chunk_count=len(chunks),
                outline=prepared.outline,
                mindmap_ready=False,
            )

            # 6. 存入 PGVector
            if chunks:
                self._store_vectors(chunks, doc_id, subject_id, filename, user_id=user_id)

            # 7. 写 chunks 表
            self._update_doc_status(doc_id, "processing", stage="preprocessing", progress=85)
            self._store_chunks(doc_id, subject_id, chunks)

            # 8. 更新 status='completed'
            self._update_doc_status(doc_id, "completed", stage="ready", progress=100, mindmap_ready=True)
            self._refresh_subject_knowledge_base(subject_id, user_id)

            return {"success": True, "doc_id": doc_id, "error": ""}

        except Exception as e:
            logger.error("文档处理失败：%s", e)
            if doc_id is not None:
                self._update_doc_status(doc_id, "failed", str(e), stage="failed", progress=0)
                self._refresh_subject_knowledge_base(subject_id, user_id)
            return {"success": False, "doc_id": doc_id, "error": str(e)}

        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    def _store_vectors(
        self,
        chunks: list[Any],
        doc_id: int,
        subject_id: int,
        filename: str,
        user_id: int | None = None,
    ) -> None:
        """将文本块及向量存入 PGVector collection。"""
        from langchain_postgres import PGVector
        from langchain_core.documents import Document as LCDocument
        from config import get_config
        from services.embedding_service import EmbeddingService

        cfg = get_config()
        embeddings = EmbeddingService.create_langchain_embeddings(user_id)

        vector_store = PGVector(
            embeddings=embeddings,
            collection_name=f"subject_{subject_id}",
            connection=cfg.DATABASE_URL,
            use_jsonb=True,
        )

        docs = [
            LCDocument(
                page_content=self._chunk_content(chunk),
                metadata={
                    "doc_id": doc_id,
                    "subject_id": subject_id,
                    "filename": filename,
                    "chunk_index": self._chunk_index(chunk, idx),
                    "heading_path": self._chunk_heading_path(chunk),
                    "is_secondary": bool(self._chunk_attr(chunk, "is_secondary", False)),
                    "token_count": int(self._chunk_attr(chunk, "token_count", 0) or 0),
                },
            )
            for idx, chunk in enumerate(chunks)
        ]

        # 分批写入，每批最多 64 条，避免超出 embedding API 限制
        batch_size = 64
        for i in range(0, len(docs), batch_size):
            vector_store.add_documents(docs[i:i + batch_size])

    def _store_chunks(self, doc_id: int, subject_id: int, chunks: list[Any]) -> None:
        from database import Chunk, get_session

        with get_session() as session:
            for idx, content in enumerate(chunks):
                session.add(Chunk(
                    document_id=doc_id,
                    subject_id=subject_id,
                    chunk_index=self._chunk_index(content, idx),
                    content=self._chunk_for_storage(content),
                    heading_path=self._chunk_heading_path(content),
                    token_count=int(self._chunk_attr(content, "token_count", 0) or 0),
                    is_secondary=bool(self._chunk_attr(content, "is_secondary", False)),
                ))

    def _update_doc_status(
        self,
        doc_id: int,
        status: str,
        error: str | None = None,
        *,
        stage: str | None = None,
        progress: int | None = None,
        parser_backend: str | None = None,
        chunk_count: int | None = None,
        outline: dict[str, Any] | None = None,
        mindmap_ready: bool | None = None,
    ) -> None:
        """更新 documents 表中的 status 和 error 字段。"""
        from database import get_session, Document

        with get_session() as session:
            doc = session.get(Document, doc_id)
            if doc:
                doc.status = status
                if stage is not None:
                    doc.processing_stage = stage
                if progress is not None:
                    doc.progress = max(0, min(int(progress), 100))
                if parser_backend is not None:
                    doc.parser_backend = parser_backend
                if chunk_count is not None:
                    doc.chunk_count = int(chunk_count)
                if outline is not None:
                    doc.outline = outline
                if mindmap_ready is not None:
                    doc.mindmap_ready = bool(mindmap_ready)
                if error is not None:
                    doc.error = error

    def _refresh_subject_knowledge_base(self, subject_id: int, user_id: int) -> dict:
        from database import Document, SubjectKnowledgeBase, get_session

        with get_session() as session:
            docs = (
                session.query(Document)
                .filter(Document.subject_id == subject_id, Document.user_id == user_id)
                .all()
            )
            completed = [d for d in docs if d.status == "completed"]
            processing = [d for d in docs if d.status in ("pending", "processing")]
            failed = [d for d in docs if d.status == "failed"]
            chunk_count = sum(int(d.chunk_count or 0) for d in completed)
            outlines = [
                {
                    "document_id": d.id,
                    "filename": d.filename,
                    "outline": d.outline or {},
                }
                for d in completed
                if d.outline
            ]
            outline = {
                "documents": outlines,
                "document_count": len(completed),
                "chunk_count": chunk_count,
            }
            if processing:
                status = "processing"
            elif completed:
                status = "ready"
            elif failed:
                status = "failed"
            else:
                status = "empty"

            kb = (
                session.query(SubjectKnowledgeBase)
                .filter_by(user_id=user_id, subject_id=subject_id)
                .first()
            )
            if kb is None:
                kb = SubjectKnowledgeBase(user_id=user_id, subject_id=subject_id)
                session.add(kb)
            kb.status = status
            kb.document_count = len(completed)
            kb.chunk_count = chunk_count
            kb.outline = outline
            kb.mindmap_ready = bool(completed and chunk_count > 0)

            return {
                "subject_id": subject_id,
                "status": kb.status,
                "document_count": kb.document_count,
                "chunk_count": kb.chunk_count,
                "outline": kb.outline,
                "mindmap_ready": kb.mindmap_ready,
                "updated_at": kb.updated_at,
            }

    def get_knowledge_base_status(self, subject_id: int, user_id: int) -> dict:
        return self._refresh_subject_knowledge_base(subject_id, user_id)

    # ------------------------------------------------------------------
    # 6.7 列表与删除
    # ------------------------------------------------------------------

    def list_documents(self, subject_id: int, user_id: int) -> List[dict]:
        """
        查询指定学科下当前用户的所有文档。

        :param subject_id: 学科 ID
        :param user_id: 用户 ID
        :return: 文档信息列表
        """
        from database import get_session, Document

        with get_session() as session:
            docs = (
                session.query(Document)
                .filter(
                    Document.subject_id == subject_id,
                    Document.user_id == user_id,
                )
                .order_by(Document.created_at.desc())
                .all()
            )
            return [
                {
                    "id": doc.id,
                    "filename": doc.filename,
                    "status": doc.status,
                    "processing_stage": doc.processing_stage,
                    "progress": doc.progress,
                    "parser_backend": doc.parser_backend,
                    "chunk_count": doc.chunk_count,
                    "outline": doc.outline,
                    "mindmap_ready": doc.mindmap_ready,
                    "error": doc.error,
                    "created_at": doc.created_at,
                }
                for doc in docs
            ]

    def delete_document(
        self, doc_id: int, subject_id: int, user_id: int
    ) -> dict:
        from database import get_session, Document

        try:
            # 先尝试删除 PGVector 向量（失败不影响数据库删除）
            try:
                self._delete_vectors(doc_id, subject_id, user_id=user_id)
            except Exception as e:
                logger.warning("删除向量失败（doc_id=%d），继续删除数据库记录：%s", doc_id, e)

            # 删除数据库记录
            with get_session() as session:
                doc = (
                    session.query(Document)
                    .filter(
                        Document.id == doc_id,
                        Document.subject_id == subject_id,
                        Document.user_id == user_id,
                    )
                    .first()
                )
                if doc is None:
                    return {"success": False, "error": "文档不存在或无权限删除"}
                session.delete(doc)

            self._refresh_subject_knowledge_base(subject_id, user_id)
            return {"success": True, "error": ""}

        except Exception as e:
            logger.error("删除文档失败：%s", e)
            return {"success": False, "error": str(e)}

    def _delete_vectors(self, doc_id: int, subject_id: int, user_id: int | None = None) -> None:
        """从 PGVector collection 中删除指定 doc_id 的所有向量。"""
        from langchain_postgres import PGVector
        from config import get_config
        from services.embedding_service import EmbeddingService

        cfg = get_config()
        embeddings = EmbeddingService.create_langchain_embeddings(user_id)

        vector_store = PGVector(
            embeddings=embeddings,
            collection_name=f"subject_{subject_id}",
            connection=cfg.DATABASE_URL,
            use_jsonb=True,
        )

        # 通过 metadata filter 删除该文档的所有向量
        try:
            vector_store.delete(filter={"doc_id": doc_id})
        except Exception as e:
            logger.warning("删除 PGVector 向量失败（doc_id=%d）：%s", doc_id, e)

    # ------------------------------------------------------------------
    # FastAPI 后端扩展：异步两阶段上传
    # ------------------------------------------------------------------

    def create_pending(self, filename: str, subject_id: int, user_id: int) -> int:
        """创建 pending 状态的文档记录，立即返回 doc_id。"""
        from database import get_session, Document
        with get_session() as session:
            doc = Document(
                subject_id=subject_id,
                user_id=user_id,
                filename=filename,
                status="pending",
                processing_stage="queued",
                progress=0,
            )
            session.add(doc)
            session.flush()
            doc_id = doc.id
        self._refresh_subject_knowledge_base(subject_id, user_id)
        return doc_id

    def process_existing(
        self,
        doc_id: int,
        file_bytes: bytes,
        filename: str,
        subject_id: int,
        user_id: int,
    ) -> None:
        """在后台线程中处理已创建的文档记录。"""
        import os, tempfile
        from uuid import uuid4
        tmp_path = os.path.join(tempfile.gettempdir(), f"{uuid4()}_{filename}")
        try:
            with open(tmp_path, "wb") as f:
                f.write(file_bytes)
            self._update_doc_status(doc_id, "processing", stage="parsing", progress=10)
            prepared = self.prepare_document(tmp_path, filename)
            chunks = prepared.chunks
            self._update_doc_status(
                doc_id,
                "processing",
                stage="indexing",
                progress=60,
                parser_backend=prepared.parser_backend,
                chunk_count=len(chunks),
                outline=prepared.outline,
                mindmap_ready=False,
            )
            if chunks:
                self._store_vectors(chunks, doc_id, subject_id, filename, user_id=user_id)
            self._update_doc_status(doc_id, "processing", stage="preprocessing", progress=85)
            self._store_chunks(doc_id, subject_id, chunks)
            self._update_doc_status(doc_id, "completed", stage="ready", progress=100, mindmap_ready=True)
            self._refresh_subject_knowledge_base(subject_id, user_id)
        except Exception as e:
            self._update_doc_status(doc_id, "failed", str(e), stage="failed", progress=0)
            self._refresh_subject_knowledge_base(subject_id, user_id)
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    def get_all_chunks(self, subject_id: int, doc_id=None) -> list:
        """获取学科下所有 chunk（用于思维导图/出题采样）。"""
        from database import get_session, Chunk
        with get_session() as session:
            q = session.query(Chunk).filter(Chunk.subject_id == subject_id)
            if doc_id is not None:
                q = q.filter(Chunk.document_id == doc_id)
            rows = q.order_by(Chunk.document_id, Chunk.chunk_index).all()
            return [{"content": r.content, "document_id": r.document_id, "chunk_index": r.chunk_index} for r in rows]

    def reindex(self, doc_id: int, subject_id: int) -> None:
        """从 Chunk 表重建文本并重新向量化，在后台线程中调用。"""
        from database import get_session, Chunk, Document

        self._update_doc_status(doc_id, "processing", stage="indexing", progress=30)
        try:
            with get_session() as db:
                doc = db.query(Document).filter_by(id=doc_id).first()
                filename = doc.filename if doc else ""
                user_id = doc.user_id if doc else 0
                old_chunks = (
                    db.query(Chunk).filter_by(document_id=doc_id)
                    .order_by(Chunk.chunk_index).all()
                )
                full_text = "\n".join(c.content for c in old_chunks)

            if not full_text.strip():
                self._update_doc_status(doc_id, "failed", "文档内容为空", stage="failed", progress=0)
                if user_id:
                    self._refresh_subject_knowledge_base(subject_id, user_id)
                return

            self._delete_vectors(doc_id, subject_id, user_id=user_id)
            try:
                from services.chunker import HierarchicalChunker
                new_chunks = HierarchicalChunker().chunk(full_text, {"filename": filename})
            except Exception as exc:
                logger.warning("structured reindex failed for doc_id=%d, falling back: %s", doc_id, exc)
                new_chunks = [
                    {
                        "content": content,
                        "heading_path": "",
                        "chunk_index": idx,
                        "filename": filename,
                        "is_secondary": False,
                        "token_count": len(content) // 4,
                    }
                    for idx, content in enumerate(self.chunk_text(full_text))
                ]
            self._store_vectors(new_chunks, doc_id, subject_id, filename, user_id=user_id)
            outline = self._build_outline(new_chunks)

            with get_session() as db:
                db.query(Chunk).filter_by(document_id=doc_id).delete()
                for idx, content in enumerate(new_chunks):
                    db.add(Chunk(
                        document_id=doc_id,
                        subject_id=subject_id,
                        chunk_index=self._chunk_index(content, idx),
                        content=self._chunk_for_storage(content),
                        heading_path=self._chunk_heading_path(content),
                        token_count=int(self._chunk_attr(content, "token_count", 0) or 0),
                        is_secondary=bool(self._chunk_attr(content, "is_secondary", False)),
                    ))
            self._update_doc_status(
                doc_id,
                "completed",
                stage="ready",
                progress=100,
                chunk_count=len(new_chunks),
                outline=outline,
                mindmap_ready=True,
            )
            if user_id:
                self._refresh_subject_knowledge_base(subject_id, user_id)
        except Exception as e:
            logger.error("reindex 失败 doc_id=%d: %s", doc_id, e)
            self._update_doc_status(doc_id, "failed", str(e), stage="failed", progress=0)
