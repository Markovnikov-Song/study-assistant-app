"""
FastAPI 配置：从环境变量读取，接口与 Streamlit 版 config.py 完全一致，
services/ 里的 `from config import get_config` 会优先找到这个文件。

配置分组：
  - LLM 基础配置：模型、API 密钥、端点
  - RAG 参数：向量检索阈值、分块大小
  - LLM 调用参数：各场景的 temperature / max_tokens
  - 业务逻辑阈值：Agent 判断、采样限制、超时
  - 文件类型白名单
  - 功能默认值：默认模式、默认适配器
  - 认证配置
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import Optional

from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))

_REQUIRED = [
    "DATABASE_URL", "LLM_API_KEY", "LLM_BASE_URL",
    "LLM_CHAT_MODEL", "LLM_EMBEDDING_MODEL",
]


@dataclass
class AppConfig:
    # ── LLM 基础配置 ──────────────────────────────────────────────────────────
    DATABASE_URL: str
    LLM_API_KEY: str
    LLM_BASE_URL: str
    LLM_CHAT_MODEL: str
    LLM_EMBEDDING_MODEL: str
    LLM_VISION_MODEL: str = "Qwen/Qwen2.5-VL-7B-Instruct"
    # 场景化模型（不配置则回退到 LLM_CHAT_MODEL）
    LLM_FAST_MODEL: str = ""    # 轻量模型：简单问答、标题生成、hints
    LLM_HEAVY_MODEL: str = ""   # 大模型：解题、讲义生成、council

    # ── RAG 向量检索参数 ───────────────────────────────────────────────────────
    # PGVector cosine 距离阈值：距离 < 阈值才视为相关（0=完全相同，2=完全相反）
    # BGE-M3 实测：相关内容距离通常在 0.2~0.5，0.7 是合理上限
    SIMILARITY_THRESHOLD: float = 0.7
    CHUNK_SIZE: int = 800
    CHUNK_OVERLAP: int = 150
    TOP_K: int = 8

    # ── LLM 调用参数（各场景独立可调）────────────────────────────────────────
    # 记忆提取：低温度保证 JSON 格式稳定
    LLM_MEMORY_TEMPERATURE: float = 0.1
    LLM_MEMORY_MAX_TOKENS: int = 800

    # 讲义生成：低温度保证结构一致，大 token 支持长文
    LLM_LECTURE_TEMPERATURE: float = 0.3
    LLM_LECTURE_MAX_TOKENS: int = 4096

    # 笔记润色：低温度保持原意
    LLM_NOTES_POLISH_TEMPERATURE: float = 0.3
    LLM_NOTES_POLISH_MAX_TOKENS: int = 2000

    # 提问建议：高温度增加多样性
    LLM_HINTS_TEMPERATURE: float = 0.8
    LLM_HINTS_MAX_TOKENS: int = 200

    # Skill 解析：中等 token，结构化输出
    LLM_SKILL_PARSE_MAX_TOKENS: int = 1000

    # Council Agent（重型任务）
    LLM_COUNCIL_SUBJECT_TEACHER_MAX_TOKENS: int = 1500
    LLM_COUNCIL_PRINCIPAL_MAX_TOKENS: int = 800
    LLM_COUNCIL_ADVISOR_MAX_TOKENS: int = 800
    LLM_COUNCIL_DECISION_MAX_TOKENS: int = 200
    LLM_COUNCIL_FEEDBACK_MAX_TOKENS: int = 100

    # Skill 推荐（意图解析）
    LLM_SKILL_RECOMMEND_MAX_TOKENS: int = 500

    # PromptNode 执行
    LLM_EXECUTE_NODE_MAX_TOKENS: int = 2000

    # ── 业务逻辑阈值 ──────────────────────────────────────────────────────────
    # 同桌 Agent：触发快反馈的错题数阈值
    COMPANION_MISTAKE_THRESHOLD: int = 5
    # 同桌 Agent：触发中反馈的专注时长阈值（分钟）
    COMPANION_FOCUS_MINUTES_WARN: int = 30
    # 同桌 Agent：触发慢反馈的专注时长阈值（分钟）
    COMPANION_FOCUS_MINUTES_CRITICAL: int = 20

    # 校长 Agent：整体进度偏差超过此百分比时主动介入
    COUNCIL_DEVIATION_THRESHOLD_PERCENT: int = 20

    # ── 采样与限制参数 ────────────────────────────────────────────────────────
    # 思维导图生成：最多采样的 chunk 数（均匀采样覆盖全书）
    MINDMAP_MAX_CHUNKS: int = 60

    # 出题：预测试卷知识点提取的 chunk 数
    EXAM_KNOWLEDGE_CHUNK_LIMIT: int = 30
    # 出题：自定义出题的 chunk 数
    EXAM_CUSTOM_CHUNK_LIMIT: int = 20

    # 对话历史：注入 LLM 的最近消息数
    CHAT_HISTORY_WINDOW: int = 40

    # 用户记忆：薄弱点最大条数
    MEMORY_WEAK_POINTS_MAX: int = 8
    # 用户记忆：常问话题最大条数
    MEMORY_FREQUENT_TOPICS_MAX: int = 8
    # 用户记忆：误解最大条数
    MEMORY_MISCONCEPTIONS_MAX: int = 5

    # Hints：取最近 N 条用户消息作为上下文
    HINTS_HISTORY_LIMIT: int = 20
    # Hints：每次生成的建议数
    HINTS_COUNT: int = 3
    # Hints：建议最大字符数（过滤太长的）
    HINTS_MAX_CHARS: int = 40

    # 会话标题：最大字符数
    SESSION_TITLE_MAX_CHARS: int = 15

    # ── 超时配置（秒）────────────────────────────────────────────────────────
    # 讲义生成（流式）超时
    LECTURE_GENERATION_TIMEOUT_SECONDS: int = 120
    # PDF 导出超时
    PDF_GENERATION_TIMEOUT_SECONDS: int = 90
    # Library: 讲义生成超时
    LIBRARY_LECTURE_GENERATE_TIMEOUT_SECONDS: int = 120
    # Library: PDF 导出超时
    LIBRARY_PDF_EXPORT_TIMEOUT_SECONDS: int = 90
    # MCP 工具调用超时
    MCP_TOOL_CALL_TIMEOUT_SECONDS: float = 10.0
    # MCP 服务重连间隔
    MCP_RECONNECT_INTERVAL_SECONDS: int = 30
    # MCP 服务停止等待超时
    MCP_STOP_MONITOR_TIMEOUT_SECONDS: int = 5
    # Agent execute_node 超时
    AGENT_EXECUTE_NODE_TIMEOUT_SECONDS: float = 10.0

    # ── 文件类型白名单 ────────────────────────────────────────────────────────
    # 学科资料支持的文件格式
    DOCUMENT_ALLOWED_EXTENSIONS: str = ".pdf,.docx,.pptx,.txt,.md"
    # 历年题支持的文件格式
    PAST_EXAM_ALLOWED_EXTENSIONS: str = ".pdf,.jpg,.jpeg,.png,.docx"

    # ── 功能默认值 ────────────────────────────────────────────────────────────
    # 默认 RAG 模式（strict / broad / hybrid / solve）
    DEFAULT_RAG_MODE: str = "strict"
    # 默认 Skill 解析适配器（ai / rule_based）
    DEFAULT_SKILL_PARSER_ADAPTER: str = "ai"
    # 默认会话类型（qa / solve / mindmap / exam）
    DEFAULT_SESSION_TYPE: str = "qa"

    # ── 认证配置 ──────────────────────────────────────────────────────────────
    JWT_SECRET: str = "change-me-in-production"
    JWT_EXPIRE_HOURS: int = 24 * 7

    # ── 便捷属性 ──────────────────────────────────────────────────────────────
    @property
    def document_allowed_extensions_set(self) -> set[str]:
        """返回文档允许扩展名的集合，如 {'.pdf', '.docx'}"""
        return {ext.strip() for ext in self.DOCUMENT_ALLOWED_EXTENSIONS.split(",") if ext.strip()}

    @property
    def past_exam_allowed_extensions_set(self) -> set[str]:
        """返回历年题允许扩展名的集合"""
        return {ext.strip() for ext in self.PAST_EXAM_ALLOWED_EXTENSIONS.split(",") if ext.strip()}


_config: Optional[AppConfig] = None


def get_config() -> AppConfig:
    global _config
    if _config is None:
        missing = [k for k in _REQUIRED if not os.getenv(k)]
        if missing:
            raise RuntimeError(f"缺少环境变量：{', '.join(missing)}")
        _config = AppConfig(
            # LLM 基础
            DATABASE_URL=os.environ["DATABASE_URL"],
            LLM_API_KEY=os.environ["LLM_API_KEY"],
            LLM_BASE_URL=os.environ["LLM_BASE_URL"],
            LLM_CHAT_MODEL=os.environ["LLM_CHAT_MODEL"],
            LLM_EMBEDDING_MODEL=os.environ["LLM_EMBEDDING_MODEL"],
            LLM_VISION_MODEL=os.getenv("LLM_VISION_MODEL", "Qwen/Qwen2.5-VL-7B-Instruct"),
            LLM_FAST_MODEL=os.getenv("LLM_FAST_MODEL", ""),
            LLM_HEAVY_MODEL=os.getenv("LLM_HEAVY_MODEL", ""),
            # RAG
            SIMILARITY_THRESHOLD=float(os.getenv("SIMILARITY_THRESHOLD", "0.7")),
            CHUNK_SIZE=int(os.getenv("CHUNK_SIZE", "800")),
            CHUNK_OVERLAP=int(os.getenv("CHUNK_OVERLAP", "150")),
            TOP_K=int(os.getenv("TOP_K", "8")),
            # LLM 调用参数
            LLM_MEMORY_TEMPERATURE=float(os.getenv("LLM_MEMORY_TEMPERATURE", "0.1")),
            LLM_MEMORY_MAX_TOKENS=int(os.getenv("LLM_MEMORY_MAX_TOKENS", "800")),
            LLM_LECTURE_TEMPERATURE=float(os.getenv("LLM_LECTURE_TEMPERATURE", "0.3")),
            LLM_LECTURE_MAX_TOKENS=int(os.getenv("LLM_LECTURE_MAX_TOKENS", "4096")),
            LLM_NOTES_POLISH_TEMPERATURE=float(os.getenv("LLM_NOTES_POLISH_TEMPERATURE", "0.3")),
            LLM_NOTES_POLISH_MAX_TOKENS=int(os.getenv("LLM_NOTES_POLISH_MAX_TOKENS", "2000")),
            LLM_HINTS_TEMPERATURE=float(os.getenv("LLM_HINTS_TEMPERATURE", "0.8")),
            LLM_HINTS_MAX_TOKENS=int(os.getenv("LLM_HINTS_MAX_TOKENS", "200")),
            LLM_SKILL_PARSE_MAX_TOKENS=int(os.getenv("LLM_SKILL_PARSE_MAX_TOKENS", "1000")),
            LLM_COUNCIL_SUBJECT_TEACHER_MAX_TOKENS=int(os.getenv("LLM_COUNCIL_SUBJECT_TEACHER_MAX_TOKENS", "1500")),
            LLM_COUNCIL_PRINCIPAL_MAX_TOKENS=int(os.getenv("LLM_COUNCIL_PRINCIPAL_MAX_TOKENS", "800")),
            LLM_COUNCIL_ADVISOR_MAX_TOKENS=int(os.getenv("LLM_COUNCIL_ADVISOR_MAX_TOKENS", "800")),
            LLM_COUNCIL_DECISION_MAX_TOKENS=int(os.getenv("LLM_COUNCIL_DECISION_MAX_TOKENS", "200")),
            LLM_COUNCIL_FEEDBACK_MAX_TOKENS=int(os.getenv("LLM_COUNCIL_FEEDBACK_MAX_TOKENS", "100")),
            LLM_SKILL_RECOMMEND_MAX_TOKENS=int(os.getenv("LLM_SKILL_RECOMMEND_MAX_TOKENS", "500")),
            LLM_EXECUTE_NODE_MAX_TOKENS=int(os.getenv("LLM_EXECUTE_NODE_MAX_TOKENS", "2000")),
            # 业务阈值
            COMPANION_MISTAKE_THRESHOLD=int(os.getenv("COMPANION_MISTAKE_THRESHOLD", "5")),
            COMPANION_FOCUS_MINUTES_WARN=int(os.getenv("COMPANION_FOCUS_MINUTES_WARN", "30")),
            COMPANION_FOCUS_MINUTES_CRITICAL=int(os.getenv("COMPANION_FOCUS_MINUTES_CRITICAL", "20")),
            COUNCIL_DEVIATION_THRESHOLD_PERCENT=int(os.getenv("COUNCIL_DEVIATION_THRESHOLD_PERCENT", "20")),
            # 采样与限制
            MINDMAP_MAX_CHUNKS=int(os.getenv("MINDMAP_MAX_CHUNKS", "60")),
            EXAM_KNOWLEDGE_CHUNK_LIMIT=int(os.getenv("EXAM_KNOWLEDGE_CHUNK_LIMIT", "30")),
            EXAM_CUSTOM_CHUNK_LIMIT=int(os.getenv("EXAM_CUSTOM_CHUNK_LIMIT", "20")),
            CHAT_HISTORY_WINDOW=int(os.getenv("CHAT_HISTORY_WINDOW", "40")),
            MEMORY_WEAK_POINTS_MAX=int(os.getenv("MEMORY_WEAK_POINTS_MAX", "8")),
            MEMORY_FREQUENT_TOPICS_MAX=int(os.getenv("MEMORY_FREQUENT_TOPICS_MAX", "8")),
            MEMORY_MISCONCEPTIONS_MAX=int(os.getenv("MEMORY_MISCONCEPTIONS_MAX", "5")),
            HINTS_HISTORY_LIMIT=int(os.getenv("HINTS_HISTORY_LIMIT", "20")),
            HINTS_COUNT=int(os.getenv("HINTS_COUNT", "3")),
            HINTS_MAX_CHARS=int(os.getenv("HINTS_MAX_CHARS", "40")),
            SESSION_TITLE_MAX_CHARS=int(os.getenv("SESSION_TITLE_MAX_CHARS", "15")),
            # 超时
            LECTURE_GENERATION_TIMEOUT_SECONDS=int(os.getenv("LECTURE_GENERATION_TIMEOUT_SECONDS", "120")),
            PDF_GENERATION_TIMEOUT_SECONDS=int(os.getenv("PDF_GENERATION_TIMEOUT_SECONDS", "90")),
            LIBRARY_LECTURE_GENERATE_TIMEOUT_SECONDS=int(os.getenv("LIBRARY_LECTURE_GENERATE_TIMEOUT_SECONDS", "120")),
            LIBRARY_PDF_EXPORT_TIMEOUT_SECONDS=int(os.getenv("LIBRARY_PDF_EXPORT_TIMEOUT_SECONDS", "90")),
            MCP_TOOL_CALL_TIMEOUT_SECONDS=float(os.getenv("MCP_TOOL_CALL_TIMEOUT_SECONDS", "10.0")),
            MCP_RECONNECT_INTERVAL_SECONDS=int(os.getenv("MCP_RECONNECT_INTERVAL_SECONDS", "30")),
            MCP_STOP_MONITOR_TIMEOUT_SECONDS=int(os.getenv("MCP_STOP_MONITOR_TIMEOUT_SECONDS", "5")),
            AGENT_EXECUTE_NODE_TIMEOUT_SECONDS=float(os.getenv("AGENT_EXECUTE_NODE_TIMEOUT_SECONDS", "10.0")),
            # 文件类型
            DOCUMENT_ALLOWED_EXTENSIONS=os.getenv("DOCUMENT_ALLOWED_EXTENSIONS", ".pdf,.docx,.pptx,.txt,.md"),
            PAST_EXAM_ALLOWED_EXTENSIONS=os.getenv("PAST_EXAM_ALLOWED_EXTENSIONS", ".pdf,.jpg,.jpeg,.png,.docx"),
            # 功能默认值
            DEFAULT_RAG_MODE=os.getenv("DEFAULT_RAG_MODE", "strict"),
            DEFAULT_SKILL_PARSER_ADAPTER=os.getenv("DEFAULT_SKILL_PARSER_ADAPTER", "ai"),
            DEFAULT_SESSION_TYPE=os.getenv("DEFAULT_SESSION_TYPE", "qa"),
            # 认证
            JWT_SECRET=os.getenv("JWT_SECRET", "change-me-in-production"),
            JWT_EXPIRE_HOURS=int(os.getenv("JWT_EXPIRE_HOURS", str(24 * 7))),
        )
    return _config


def reset_config() -> None:
    global _config
    _config = None
