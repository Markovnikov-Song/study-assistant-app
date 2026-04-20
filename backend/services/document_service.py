"""
文档服务：文件解析、文本分块、向量化存储，以及文档的列表与删除。
"""

from __future__ import annotations

import logging
import os
import tempfile
from typing import List
from uuid import uuid4

logger = logging.getLogger(__name__)


class DocumentService:
    """文档上传、解析、分块、向量化及管理服务。"""

    # ------------------------------------------------------------------
    # 6.1 文件解析器
    # ------------------------------------------------------------------

    def parse_file(self, tmp_path: str, filename: str) -> str:
        from services.file_parser import parse_file
        return parse_file(tmp_path, filename)

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
        from database import get_session, Document, Chunk
        from services.embedding_service import EmbeddingService

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
                )
                session.add(doc)
                session.flush()
                doc_id = doc.id

            # 2. 更新 status='processing'
            self._update_doc_status(doc_id, "processing")

            # 3. 解析文本
            text = self.parse_file(tmp_path, filename)

            # 4. 分块
            chunks = self.chunk_text(text)

            # 5. 生成向量
            embedding_service = EmbeddingService()
            vectors = embedding_service.embed_texts(chunks) if chunks else []

            # 6. 存入 PGVector
            if chunks:
                self._store_vectors(chunks, vectors, doc_id, subject_id, filename)

            # 7. 写 chunks 表
            with get_session() as session:
                for idx, chunk_content in enumerate(chunks):
                    chunk = Chunk(
                        document_id=doc_id,
                        subject_id=subject_id,
                        chunk_index=idx,
                        content=chunk_content,
                    )
                    session.add(chunk)

            # 8. 更新 status='completed'
            self._update_doc_status(doc_id, "completed")

            return {"success": True, "doc_id": doc_id, "error": ""}

        except Exception as e:
            logger.error("文档处理失败：%s", e)
            if doc_id is not None:
                self._update_doc_status(doc_id, "failed", str(e))
            return {"success": False, "doc_id": doc_id, "error": str(e)}

        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    def _store_vectors(
        self,
        chunks: List[str],
        vectors: List[List[float]],
        doc_id: int,
        subject_id: int,
        filename: str,
    ) -> None:
        """将文本块及向量存入 PGVector collection。"""
        from langchain_postgres import PGVector
        from langchain_openai import OpenAIEmbeddings
        from langchain_core.documents import Document as LCDocument
        from config import get_config

        cfg = get_config()
        embeddings = OpenAIEmbeddings(
            model=cfg.LLM_EMBEDDING_MODEL,
            openai_api_key=cfg.LLM_API_KEY,
            openai_api_base=cfg.LLM_BASE_URL,
        )

        vector_store = PGVector(
            embeddings=embeddings,
            collection_name=f"subject_{subject_id}",
            connection=cfg.DATABASE_URL,
        )

        docs = [
            LCDocument(
                page_content=chunk,
                metadata={
                    "doc_id": doc_id,
                    "subject_id": subject_id,
                    "filename": filename,
                    "chunk_index": idx,
                },
            )
            for idx, chunk in enumerate(chunks)
        ]

        # 分批写入，每批最多 64 条，避免超出 embedding API 限制
        batch_size = 64
        for i in range(0, len(docs), batch_size):
            vector_store.add_documents(docs[i:i + batch_size])

    def _update_doc_status(
        self, doc_id: int, status: str, error: str | None = None
    ) -> None:
        """更新 documents 表中的 status 和 error 字段。"""
        from database import get_session, Document

        with get_session() as session:
            doc = session.get(Document, doc_id)
            if doc:
                doc.status = status
                if error is not None:
                    doc.error = error

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
                self._delete_vectors(doc_id, subject_id)
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

            return {"success": True, "error": ""}

        except Exception as e:
            logger.error("删除文档失败：%s", e)
            return {"success": False, "error": str(e)}

    def _delete_vectors(self, doc_id: int, subject_id: int) -> None:
        """从 PGVector collection 中删除指定 doc_id 的所有向量。"""
        from langchain_postgres import PGVector
        from langchain_openai import OpenAIEmbeddings
        from config import get_config

        cfg = get_config()
        embeddings = OpenAIEmbeddings(
            model=cfg.LLM_EMBEDDING_MODEL,
            openai_api_key=cfg.LLM_API_KEY,
            openai_api_base=cfg.LLM_BASE_URL,
        )

        vector_store = PGVector(
            embeddings=embeddings,
            collection_name=f"subject_{subject_id}",
            connection=cfg.DATABASE_URL,
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
            )
            session.add(doc)
            session.flush()
            return doc.id

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
            self._update_doc_status(doc_id, "processing")
            text = self.parse_file(tmp_path, filename)
            chunks = self.chunk_text(text)
            from services.embedding_service import EmbeddingService
            vectors = EmbeddingService().embed_texts(chunks) if chunks else []
            if chunks:
                self._store_vectors(chunks, vectors, doc_id, subject_id, filename)
            from database import get_session, Chunk
            with get_session() as session:
                for idx, content in enumerate(chunks):
                    session.add(Chunk(
                        document_id=doc_id,
                        subject_id=subject_id,
                        chunk_index=idx,
                        content=content,
                    ))
            self._update_doc_status(doc_id, "completed")
        except Exception as e:
            self._update_doc_status(doc_id, "failed", str(e))
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
        from services.embedding_service import EmbeddingService

        self._update_doc_status(doc_id, "processing")
        try:
            with get_session() as db:
                doc = db.query(Document).filter_by(id=doc_id).first()
                filename = doc.filename if doc else ""
                old_chunks = (
                    db.query(Chunk).filter_by(document_id=doc_id)
                    .order_by(Chunk.chunk_index).all()
                )
                full_text = "\n".join(c.content for c in old_chunks)

            if not full_text.strip():
                self._update_doc_status(doc_id, "failed", "文档内容为空")
                return

            self._delete_vectors(doc_id, subject_id)
            new_chunks = self.chunk_text(full_text)
            vectors = EmbeddingService().embed_texts(new_chunks)
            self._store_vectors(new_chunks, vectors, doc_id, subject_id, filename)

            with get_session() as db:
                db.query(Chunk).filter_by(document_id=doc_id).delete()
                for idx, content in enumerate(new_chunks):
                    db.add(Chunk(document_id=doc_id, subject_id=subject_id,
                                 chunk_index=idx, content=content))
            self._update_doc_status(doc_id, "completed")
        except Exception as e:
            logger.error("reindex 失败 doc_id=%d: %s", doc_id, e)
            self._update_doc_status(doc_id, "failed", str(e))
