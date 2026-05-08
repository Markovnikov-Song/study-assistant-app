"""
重排序服务：封装 BGE-Reranker-v2-m3，支持本地推理和 HTTP API 两种模式。

支持的调用模式：
  - api：通过 HTTP API 调用（兼容 SiliconFlow / Jina Reranker API 格式）
  - local：通过 FlagEmbedding 本地推理（MIT 许可，直接 import）

配置项（来自 backend_config.py）：
  - RERANKER_MODE：api | local
  - RERANKER_API_URL：HTTP Reranker API 地址
  - RERANKER_API_KEY：Reranker API 密钥（可为空）
  - RERANK_MODEL：重排模型名称（默认 BAAI/bge-reranker-v2-m3）
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Any, Optional

logger = logging.getLogger(__name__)


class RerankUnavailableError(Exception):
    """Reranker 服务不可用时抛出"""
    pass


@dataclass
class RerankResult:
    index: int          # 原始文档索引
    content: str        # 文档内容
    score: float        # 相关度得分 0~1
    heading_path: str = ""   # 来自 Chunk 元数据
    chunk_index: int = 0
    filename: str = ""


class RerankService:
    """
    BGE-Reranker-v2-m3 重排序服务。

    支持两种调用模式：
    1. 本地推理（FlagEmbedding，MIT 许可，直接 import）
    2. HTTP API（兼容 SiliconFlow / Jina Reranker API）
    """

    def __init__(self) -> None:
        # 懒加载：首次调用时才读取配置和初始化模型
        self._mode: Optional[str] = None
        self._model_name: Optional[str] = None
        self._api_url: Optional[str] = None
        self._api_key: Optional[str] = None
        # 本地模型懒加载
        self._local_reranker: Any = None
        self._local_reranker_initialized: bool = False

    def _load_config(self) -> None:
        """懒加载配置，首次调用时初始化。"""
        if self._mode is not None:
            return
        from config import get_config
        cfg = get_config()
        self._mode = cfg.RERANKER_MODE
        self._model_name = cfg.RERANK_MODEL
        self._api_url = cfg.RERANKER_API_URL
        self._api_key = cfg.RERANKER_API_KEY

    def _load_config_for_user(self, user_id: int) -> None:
        """为指定用户加载配置（优先用户自定义，回退到系统配置）。"""
        from config import get_config
        cfg = get_config()
        self._mode = cfg.RERANKER_MODE
        self._model_name = cfg.RERANK_MODEL
        self._api_url = cfg.RERANKER_API_URL
        self._api_key = cfg.RERANKER_API_KEY

        try:
            from database import User, get_session

            with get_session() as db:
                user = db.query(User).filter_by(id=user_id).first()
                if user:
                    api_key = getattr(user, "custom_reranker_api_key", None) or getattr(user, "custom_llm_api_key", None)
                    if api_key:
                        self._api_key = api_key
                        self._api_url = (
                            getattr(user, "custom_reranker_base_url", None)
                            or getattr(user, "custom_llm_base_url", None)
                            or self._api_url
                        )
                        if self._api_url and not self._api_url.rstrip("/").endswith("/rerank"):
                            self._api_url = self._api_url.rstrip("/") + "/rerank"
                    self._model_name = getattr(user, "custom_reranker_model", None) or self._model_name
        except Exception:
            pass

        try:
            from services.llm_service import LLMService
            user_cfg = LLMService()._get_user_api_config(user_id)
            if user_cfg:
                # 用户自定义 Reranker 配置覆盖系统配置
                if user_cfg.get("reranker_api_key"):
                    self._api_key = user_cfg["reranker_api_key"]
                    self._api_url = user_cfg.get("reranker_base_url", cfg.RERANKER_API_URL)
                    # 拼接 /rerank 端点（如果 base_url 不以 /rerank 结尾）
                    if self._api_url and not self._api_url.rstrip("/").endswith("/rerank"):
                        self._api_url = self._api_url.rstrip("/") + "/rerank"
                if user_cfg.get("reranker_model"):
                    self._model_name = user_cfg["reranker_model"]
        except Exception:
            pass  # 读取用户配置失败时静默回退到系统配置

    def rerank(
        self,
        query: str,
        documents: list[str],
        top_n: int | None = None,
        metadata: list[dict] | None = None,
        user_id: int | None = None,
    ) -> list[RerankResult]:
        """
        对 documents 按 query 相关度重排序。

        :param query: 查询文本
        :param documents: 待排序的文档列表
        :param top_n: 返回前 top_n 个结果，None 时返回全部
        :param metadata: 可选，每个元素对应 documents 中同索引文档的元数据
        :param user_id: 可选，用于读取用户自定义 Reranker 配置
        :returns: 按 score 降序排列的 RerankResult 列表
        :raises RerankUnavailableError: Reranker 服务不可用时
        """
        if user_id:
            self._load_config_for_user(user_id)
        else:
            self._load_config()

        if not documents:
            return []

        # 根据模式选择调用方式
        if self._mode == "local":
            raw_results = self._rerank_local(query, documents)
        else:
            # 默认 api 模式
            raw_results = self._rerank_via_api(query, documents)

        # 构建 RerankResult 列表，附加元数据
        results: list[RerankResult] = []
        for idx, score in raw_results:
            meta: dict = {}
            if metadata is not None and 0 <= idx < len(metadata):
                meta = metadata[idx]

            result = RerankResult(
                index=idx,
                content=documents[idx] if 0 <= idx < len(documents) else "",
                score=score,
                heading_path=meta.get("heading_path", ""),
                chunk_index=meta.get("chunk_index", 0),
                filename=meta.get("filename", ""),
            )
            results.append(result)

        # 按 score 降序排列
        results.sort(key=lambda r: r.score, reverse=True)

        # 截断到 top_n
        if top_n is not None:
            results = results[:top_n]

        return results

    def is_available(self, user_id: int | None = None) -> bool:
        """
        检查 Reranker 服务是否可用。

        :returns: True 表示可用，False 表示不可用（不抛异常）
        """
        try:
            if user_id:
                self._load_config_for_user(user_id)
            else:
                self._load_config()
            if self._mode == "local":
                return self._check_local_available()
            else:
                return self._check_api_available()
        except Exception as e:
            logger.debug("检查 Reranker 可用性时出错：%s", e)
            return False

    def _check_api_available(self) -> bool:
        """检查 API 模式是否可用。"""
        if not self._api_url:
            logger.debug("RERANKER_API_URL 未配置，API 模式不可用")
            return False
        try:
            import httpx  # noqa: F401
            return True
        except ImportError:
            logger.debug("httpx 未安装，API 模式不可用")
            return False

    def _check_local_available(self) -> bool:
        """检查本地模式是否可用。"""
        try:
            from FlagEmbedding import FlagReranker  # noqa: F401
            return True
        except ImportError:
            logger.debug("FlagEmbedding 未安装，本地模式不可用")
            return False

    def _rerank_via_api(
        self,
        query: str,
        documents: list[str],
    ) -> list[tuple[int, float]]:
        """
        通过 HTTP API 调用 Reranker（兼容 SiliconFlow / Jina Reranker API 格式）。

        请求格式：POST {model, query, documents}
        响应格式：{"results": [{"index": int, "relevance_score": float}, ...]}

        :param query: 查询文本
        :param documents: 待排序的文档列表
        :returns: [(index, score), ...] 列表
        :raises RerankUnavailableError: httpx 未安装或 API 调用失败时
        """
        try:
            import httpx
        except ImportError:
            raise RerankUnavailableError(
                "httpx 未安装，无法使用 API 模式。请运行：pip install httpx"
            )

        if not self._api_url:
            raise RerankUnavailableError(
                "RERANKER_API_URL 未配置，无法使用 API 模式"
            )

        headers: dict[str, str] = {"Content-Type": "application/json"}
        if self._api_key:
            headers["Authorization"] = f"Bearer {self._api_key}"

        payload = {
            "model": self._model_name,
            "query": query,
            "documents": documents,
        }

        try:
            with httpx.Client(timeout=10.0) as client:
                response = client.post(
                    self._api_url,
                    json=payload,
                    headers=headers,
                )
                response.raise_for_status()
                data = response.json()
        except httpx.TimeoutException as e:
            raise RerankUnavailableError(f"Reranker API 调用超时：{e}") from e
        except httpx.HTTPStatusError as e:
            raise RerankUnavailableError(
                f"Reranker API 返回错误状态码 {e.response.status_code}：{e}"
            ) from e
        except Exception as e:
            raise RerankUnavailableError(f"Reranker API 调用失败：{e}") from e

        # 解析响应：兼容 SiliconFlow 格式
        # {"results": [{"index": 0, "relevance_score": 0.95}, ...]}
        results: list[tuple[int, float]] = []
        try:
            for item in data.get("results", []):
                idx = int(item["index"])
                score = float(item.get("relevance_score", item.get("score", 0.0)))
                results.append((idx, score))
        except (KeyError, TypeError, ValueError) as e:
            raise RerankUnavailableError(
                f"Reranker API 响应格式解析失败：{e}，响应内容：{data}"
            ) from e

        logger.debug("API Rerank 完成，共 %d 个结果", len(results))
        return results

    def _rerank_local(
        self,
        query: str,
        documents: list[str],
    ) -> list[tuple[int, float]]:
        """
        通过 FlagEmbedding 本地推理进行重排序（MIT 许可，直接 import）。

        懒加载模型，首次调用时初始化。

        :param query: 查询文本
        :param documents: 待排序的文档列表
        :returns: [(index, score), ...] 列表
        :raises RerankUnavailableError: FlagEmbedding 未安装或模型加载失败时
        """
        # 懒加载本地模型
        if not self._local_reranker_initialized:
            try:
                from FlagEmbedding import FlagReranker
                logger.info("正在加载本地 Reranker 模型：%s", self._model_name)
                self._local_reranker = FlagReranker(
                    self._model_name,
                    use_fp16=True,
                )
                self._local_reranker_initialized = True
                logger.info("本地 Reranker 模型加载完成")
            except ImportError as e:
                raise RerankUnavailableError(
                    "FlagEmbedding 未安装，无法使用本地模式。"
                    "请运行：pip install FlagEmbedding"
                ) from e
            except Exception as e:
                raise RerankUnavailableError(
                    f"本地 Reranker 模型加载失败：{e}"
                ) from e

        try:
            # FlagReranker.compute_score 接受 [(query, doc), ...] 格式
            pairs = [(query, doc) for doc in documents]
            scores = self._local_reranker.compute_score(pairs, normalize=True)

            # compute_score 对单个 pair 返回 float，对多个返回 list
            if isinstance(scores, float):
                scores = [scores]

            results = [(idx, float(score)) for idx, score in enumerate(scores)]
            logger.debug("本地 Rerank 完成，共 %d 个结果", len(results))
            return results
        except Exception as e:
            raise RerankUnavailableError(f"本地 Reranker 推理失败：{e}") from e
