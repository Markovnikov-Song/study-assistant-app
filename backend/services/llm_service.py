"""
LLM 服务增强版：集成 Token 统计

在原有功能基础上新增：
- Token 使用统计
- 配额检查
- 限流检查
"""

from __future__ import annotations

import base64
import uuid
from typing import Generator, List, Optional, Tuple

from openai import OpenAI


class LLMService:
    """封装 OpenAI 兼容 API 的 LLM 服务。"""

    def __init__(self) -> None:
        self._default_client: Optional[OpenAI] = None
        # 延迟导入，避免循环依赖
        self._token_service = None

    def _get_client(self, user_id: Optional[int] = None) -> OpenAI:
        """懒加载：首次调用时初始化 OpenAI 客户端。"""
        from config import get_config
        cfg = get_config()
        
        # 如果提供了 user_id，尝试使用用户配置
        if user_id:
            user_config = self._get_user_api_config(user_id)
            if user_config:
                # 为每个用户创建独立的客户端（不缓存）
                return OpenAI(
                    api_key=user_config["llm_api_key"],
                    base_url=user_config["llm_base_url"],
                )
        
        # 使用默认配置（可以缓存）
        if self._default_client is None:
            self._default_client = OpenAI(
                api_key=cfg.LLM_API_KEY,
                base_url=cfg.LLM_BASE_URL,
            )
        return self._default_client

    def _get_model(self) -> str:
        from config import get_config
        return get_config().LLM_CHAT_MODEL

    def get_model_for_scene(self, scene: str) -> str:
        """
        按场景返回模型名称。
        - "fast"：轻量任务（意图解析、标题生成、hints），使用 LLM_FAST_MODEL
        - "heavy"：重型任务（解题、讲义生成、council），使用 LLM_HEAVY_MODEL
        - 未配置对应模型时回退到 LLM_CHAT_MODEL
        """
        from config import get_config
        cfg = get_config()
        if scene == "fast":
            return cfg.LLM_FAST_MODEL or cfg.LLM_CHAT_MODEL
        if scene == "heavy":
            return cfg.LLM_HEAVY_MODEL or cfg.LLM_CHAT_MODEL
        return cfg.LLM_CHAT_MODEL

    def _get_token_service(self):
        """懒加载 Token 服务"""
        if self._token_service is None:
            from services.token_service import get_token_service
            self._token_service = get_token_service()
        return self._token_service

    def _get_user_api_config(self, user_id: int) -> Optional[dict]:
        """
        获取用户的 API 配置
        返回 None 表示使用默认配置
        """
        import os
        from database import get_session, User
        
        with get_session() as db:
            user = db.query(User).filter_by(id=user_id).first()
            if not user:
                return None
            
            # 如果用户使用共享配置
            if getattr(user, 'use_shared_config', False):
                config_type = getattr(user, 'shared_config_type', 'developer')
                return {
                    "llm_base_url": os.getenv("DEV_LLM_BASE_URL", "https://api.openai.com/v1"),
                    "llm_api_key": os.getenv("DEV_LLM_API_KEY", ""),
                    "vision_base_url": os.getenv("DEV_VISION_BASE_URL", "https://api.openai.com/v1"),
                    "vision_api_key": os.getenv("DEV_VISION_API_KEY", ""),
                }
            
            # 如果用户有自定义配置
            if getattr(user, 'custom_llm_api_key', None):
                return {
                    "llm_base_url": user.custom_llm_base_url or "https://api.openai.com/v1",
                    "llm_api_key": user.custom_llm_api_key,
                    "vision_base_url": getattr(user, 'custom_vision_base_url', None) or "https://api.openai.com/v1",
                    "vision_api_key": getattr(user, 'custom_vision_api_key', None) or "",
                }
            
            return None

    def _estimate_tokens(self, text: str) -> int:
        """估算 token 数量"""
        if not text:
            return 0
        chinese_chars = sum(1 for c in text if '\u4e00' <= c <= '\u9fff')
        other_chars = len(text) - chinese_chars
        return int(chinese_chars / 1.5 + other_chars / 4)

    def _estimate_from_messages(self, messages: List[dict], response: str = "") -> Tuple[int, int]:
        """估算消息列表的 token 数"""
        input_parts = []
        for msg in messages:
            content = msg.get("content", "")
            if isinstance(content, str):
                input_parts.append(content)
            elif isinstance(content, list):
                for item in content:
                    if isinstance(item, dict) and item.get("type") == "text":
                        input_parts.append(item.get("text", ""))
        
        input_text = " ".join(input_parts)
        input_tokens = self._estimate_tokens(input_text)
        output_tokens = self._estimate_tokens(response)
        
        return input_tokens, output_tokens

    def chat(
        self,
        messages: List[dict],
        user_id: Optional[int] = None,
        session_id: Optional[int] = None,
        endpoint: str = "chat",
        track_token: bool = True,
        **kwargs
    ) -> str:
        """
        带 Token 统计的 chat
        
        Args:
            messages: 消息列表
            user_id: 用户ID（用于统计）
            session_id: 会话ID
            endpoint: 端点类型
            track_token: 是否统计 token
            **kwargs: 其他参数
        """
        from config import get_config
        from services.token_service import UserBlockedException, RateLimitExceeded

        # 1. 限流检查
        if user_id and track_token:
            token_service = self._get_token_service()
            allowed, _ = token_service.check_rate_limit(user_id)
            if not allowed:
                raise RateLimitExceeded("minute", 0, 60)

        try:
            client = self._get_client(user_id)
            kwargs.setdefault("timeout", get_config().LECTURE_GENERATION_TIMEOUT_SECONDS)
            kwargs.pop("heavy", None)  # heavy 仅用于内部调度，不传给 OpenAI
            
            # 记录请求ID
            request_id = str(uuid.uuid4())
            
            # 优先使用调用方传入的 model，否则使用默认模型
            model = kwargs.pop("model", None) or self._get_model()

            response = client.chat.completions.create(
                model=model,
                messages=messages,
                **kwargs,
            )
            
            answer = response.choices[0].message.content or ""
            
            # 2. Token 统计
            if user_id and track_token:
                input_tokens, output_tokens = self._estimate_from_messages(messages, answer)
                
                # 获取实际 token 数（如果 API 返回了 usage）
                usage = getattr(response, 'usage', None)
                if usage:
                    input_tokens = getattr(usage, 'prompt_tokens', input_tokens)
                    output_tokens = getattr(usage, 'completion_tokens', output_tokens)
                
                # 记录使用
                self._get_token_service().record_usage(
                    user_id=user_id,
                    input_tokens=input_tokens,
                    output_tokens=output_tokens,
                    endpoint=endpoint,
                    model_name=self._get_model(),
                    session_id=session_id,
                    request_id=request_id,
                )
            
            return answer
            
        except Exception as e:
            raise RuntimeError(f"AI 服务暂时不可用，请稍后重试。（{e}）") from e

    def chat_with_vision(self, messages: List[dict], image_b64: str, user_id: Optional[int] = None, **kwargs) -> str:
        """
        将 base64 图片嵌入消息，调用支持视觉的模型（用于 OCR）。
        优先使用 LLM_VISION_MODEL 配置，未配置则使用 Qwen2.5-VL-7B-Instruct。
        """
        try:
            from config import get_config
            cfg = get_config()
            
            # 获取用户配置
            user_config = self._get_user_api_config(user_id) if user_id else None
            
            if user_config and user_config.get("vision_api_key"):
                # 使用用户的视觉模型配置
                vision_client = OpenAI(
                    api_key=user_config["vision_api_key"],
                    base_url=user_config["vision_base_url"],
                )
                vision_model = getattr(cfg, "LLM_VISION_MODEL", None) or "PaddlePaddle/PaddleOCR-VL-1.5"
            else:
                # 使用默认配置
                vision_model = getattr(cfg, "LLM_VISION_MODEL", None) or "PaddlePaddle/PaddleOCR-VL-1.5"
                vision_client = self._get_client(user_id)
            
            vision_messages = list(messages) + [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:image/png;base64,{image_b64}"},
                        },
                        {
                            "type": "text",
                            "text": "请识别并提取图片中的所有文字内容。",
                        },
                    ],
                }
            ]
            response = vision_client.chat.completions.create(
                model=vision_model,
                messages=vision_messages,
            )
            return response.choices[0].message.content or ""
        except Exception as e:
            raise RuntimeError(f"AI 视觉服务暂时不可用，请稍后重试。（模型：{vision_model}，错误：{e}）") from e

    def stream_chat(
        self,
        messages: List[dict],
        user_id: Optional[int] = None,
        session_id: Optional[int] = None,
        endpoint: str = "stream",
        track_token: bool = True,
        **kwargs,
    ) -> Generator[str, None, None]:
        """
        带 Token 统计的流式 chat
        
        Args:
            messages: 消息列表
            user_id: 用户ID（用于统计）
            session_id: 会话ID
            endpoint: 端点类型
            track_token: 是否统计 token
            **kwargs: 其他参数（如 temperature, max_tokens 等）
        """
        from config import get_config
        from services.token_service import RateLimitExceeded

        # 1. 限流检查
        if user_id and track_token:
            allowed, _ = self._get_token_service().check_rate_limit(user_id)
            if not allowed:
                raise RateLimitExceeded("minute", 0, 60)

        try:
            client = self._get_client(user_id)
            request_id = str(uuid.uuid4())
            
            # 移除内部调度参数，不传给 OpenAI
            kwargs.pop("heavy", None)
            
            # 优先使用调用方传入的 model，否则使用默认模型
            model = kwargs.pop("model", None) or self._get_model()

            stream = client.chat.completions.create(
                model=model,
                messages=messages,
                stream=True,
                timeout=kwargs.pop("timeout", get_config().LECTURE_GENERATION_TIMEOUT_SECONDS),
                **kwargs,
            )
            
            full_response = ""
            output_token_count = 0
            
            for chunk in stream:
                delta = chunk.choices[0].delta
                if delta.content:
                    full_response += delta.content
                    output_token_count += 1
                    yield delta.content
            
            # 2. Token 统计
            if user_id and track_token:
                input_tokens, _ = self._estimate_from_messages(messages, full_response)
                # 流式输出 token 用词数估算
                output_tokens = output_token_count * 2  # 简化估算
                
                self._get_token_service().record_usage(
                    user_id=user_id,
                    input_tokens=input_tokens,
                    output_tokens=output_tokens,
                    endpoint=endpoint,
                    model_name=self._get_model(),
                    session_id=session_id,
                    request_id=request_id,
                )
                
        except Exception as e:
            raise RuntimeError(f"AI 流式服务暂时不可用，请稍后重试。（{e}）") from e

    def chat_stream(self, messages, **kwargs):
        """stream_chat 的别名，兼容 FastAPI 后端调用。"""
        return self.stream_chat(messages, **kwargs)
