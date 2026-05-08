"""
嵌入服务：封装 OpenAI 兼容 Embedding API，支持批量和单条向量生成。
客户端懒加载，首次调用时才初始化。
"""

from __future__ import annotations

from typing import List, Optional

from openai import OpenAI
from langchain_openai import OpenAIEmbeddings


def resolve_embedding_config(user_id: Optional[int] = None) -> dict:
    from config import get_config
    cfg = get_config()
    resolved = {
        "api_key": cfg.LLM_API_KEY,
        "base_url": cfg.LLM_BASE_URL,
        "model": cfg.LLM_EMBEDDING_MODEL,
    }
    if not user_id:
        return resolved

    try:
        import os
        from database import User, get_session

        with get_session() as db:
            user = db.query(User).filter_by(id=user_id).first()
            if not user:
                return resolved
            if getattr(user, "use_shared_config", False):
                resolved["api_key"] = os.getenv("DEV_LLM_API_KEY", resolved["api_key"])
                resolved["base_url"] = os.getenv("DEV_LLM_BASE_URL", resolved["base_url"])
                return resolved

            api_key = getattr(user, "custom_embedding_api_key", None) or getattr(user, "custom_llm_api_key", None)
            if api_key:
                resolved["api_key"] = api_key
                resolved["base_url"] = (
                    getattr(user, "custom_embedding_base_url", None)
                    or getattr(user, "custom_llm_base_url", None)
                    or resolved["base_url"]
                )
                resolved["model"] = getattr(user, "custom_embedding_model", None) or resolved["model"]
    except Exception:
        return resolved
    return resolved


class EmbeddingService:
    """封装 OpenAI 兼容 API 的 Embedding 服务。"""

    def __init__(self, user_id: Optional[int] = None) -> None:
        self._client: Optional[OpenAI] = None
        self._user_id = user_id

    def _get_client(self) -> OpenAI:
        """懒加载：首次调用时初始化 OpenAI 客户端。"""
        if self._client is None:
            cfg = resolve_embedding_config(self._user_id)
            self._client = OpenAI(
                api_key=cfg["api_key"],
                base_url=cfg["base_url"],
            )
        return self._client

    def _get_model(self) -> str:
        return resolve_embedding_config(self._user_id)["model"]

    @staticmethod
    def create_langchain_embeddings(user_id: Optional[int] = None) -> OpenAIEmbeddings:
        cfg = resolve_embedding_config(user_id)
        return OpenAIEmbeddings(
            model=cfg["model"],
            openai_api_key=cfg["api_key"],
            openai_api_base=cfg["base_url"],
        )

    def embed_texts(self, texts: List[str]) -> List[List[float]]:
        """
        批量生成文本向量，自动分批处理（每批最多 64 条）。
        """
        try:
            client = self._get_client()
            model = self._get_model()
            batch_size = 64
            all_embeddings: List[List[float]] = []
            for i in range(0, len(texts), batch_size):
                batch = texts[i:i + batch_size]
                response = client.embeddings.create(model=model, input=batch)
                batch_embeddings = [item.embedding for item in sorted(response.data, key=lambda x: x.index)]
                all_embeddings.extend(batch_embeddings)
            return all_embeddings
        except Exception as e:
            raise RuntimeError(f"向量化服务暂时不可用，请稍后重试。（{e}）") from e

    def embed_query(self, text: str) -> List[float]:
        """
        生成单条查询文本的向量。

        :param text: 查询文本
        :raises RuntimeError: Embedding 调用失败时
        :return: 查询向量
        """
        results = self.embed_texts([text])
        return results[0]
