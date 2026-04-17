# 设计文档：生态接入层（Ecosystem Integration）

## 概述

本文档描述在现有 Learning OS 三层架构（AgentKernel / SkillLibrary / ComponentRegistry）基础上，新增两个方向的生态扩展能力的技术设计：

**方向一：MCP 接入层** — 将外部 MCP（Model Context Protocol）服务器接入 AgentKernel，使 Agent 能调用外部工具（文件系统、OCR、日历、网页搜索等），同时保持教育专用工具（错题本、笔记本等）继续以 Component 形式运行，不做任何改动。

**方向二：Skill 生态扩展** — 为 SkillParser 接入可插拔外部 AI 模型，建立云端 Skill 市场（浏览、下载到本地、第三方提交），支持 Skill JSON 往返导入导出，并实现 SkillCreationAdapter 的对话式创建路径。

### 关键设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| MCP 实现语言 | Python FastAPI 后端 | 官方 `mcp` Python SDK 成熟，Flutter 端通过现有 HTTP API 间接调用 |
| MCP 传输协议 | 本地 Stdio / 远程 HTTP+SSE | 官方 SDK 原生支持，本地无需网络 |
| Skill 市场存储 | 现有 FastAPI 后端 + PostgreSQL | 复用现有基础设施，不引入独立服务 |
| SkillParser 降级 | 规则解析（提取编号列表） | AI 不可用时仍能生成最小可用草稿 |
| 对话式创建兜底 | 硬编码引导问题序列 | AI 不可用时仍能完成完整创建流程 |

### 约束（继承自需求文档）

- 不修改 `ComponentInterface`（open/write/read/close）
- 不修改 `AgentKernel` 接口
- 教育专用工具（Component）不通过 MCP 包装，保持原有调用路径
- 所有核心执行路径必须有硬编码兜底
- MCP 工具调用失败时必须有降级方案，不影响核心学习功能


---

## 架构

### 系统整体架构图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Flutter UI 层                                      │
│  底部导航 5 Tab：问答 / 解题 / 导图 / 出题 / 我的                             │
│  MCP 状态指示器（全部在线 / 仅本地 / 离线模式）                               │
│  Skill 市场浏览页 / 对话式 Skill 创建页                                       │
└──────────────────────────────┬──────────────────────────────────────────────┘
                               │ HTTP / Dio
┌──────────────────────────────▼──────────────────────────────────────────────┐
│                        FastAPI 后端（Python）                                │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      AgentKernel（扩展后）                           │   │
│  │                                                                     │   │
│  │  resolveIntent ──→ LLMService                                       │   │
│  │                                                                     │   │
│  │  dispatchSkill                                                      │   │
│  │    ├── requiredComponents ──→ ComponentRegistry ──→ Component       │   │
│  │    └── mcpTools ──────────→ MCP_Client ──→ MCP_Registry             │   │
│  │                                    │                                │   │
│  │                                    ├──→ Local MCP Server (Stdio)    │   │
│  │                                    │     ├── mcp-server-filesystem  │   │
│  │                                    │     ├── local-pdf-parser       │   │
│  │                                    │     └── local-calendar         │   │
│  │                                    │                                │   │
│  │                                    └──→ Remote MCP Server (HTTP/SSE)│   │
│  │                                          ├── cloud-ocr (可选)       │   │
│  │                                          └── web-search (可选)      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌──────────────────────────┐  ┌──────────────────────────────────────┐    │
│  │     SkillParser 层        │  │         Skill 市场层                  │    │
│  │  AI_Model_Adapter         │  │  /api/marketplace/ 路由               │    │
│  │    ├── LLMServiceAdapter  │  │  MarketplaceService                  │    │
│  │    └── RuleBasedAdapter   │  │  SkillValidator                      │    │
│  │  (降级: 规则解析)          │  │  DownloadService                     │    │
│  └──────────────────────────┘  └──────────────────────────────────────┘    │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                  对话式 Skill 创建层                                   │  │
│  │  DialogSessionManager                                                │  │
│  │    ├── AI 引导问题生成（LLMService）                                  │  │
│  │    └── 硬编码兜底问题序列（FALLBACK_QUESTIONS）                       │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  现有层（不修改）：LLMService / ComponentRegistry / SkillLibrary / Database  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 调用路由决策树

```
AgentKernel.dispatchSkill(skill, session)
│
├── 解析 skill.requiredComponents 中的每个引用
│     │
│     ├── 格式为 "notebook" / "mindmap" 等（无点号）
│     │     └──→ ComponentRegistry.get(id) ──→ Component.open/write/read
│     │
│     └── 格式为 "filesystem.read_file" 等（含点号）
│           └──→ MCP_Client.call(server_id, tool_name, args)
│                 │
│                 ├── 成功 ──→ 注入下一 PromptNode 输入
│                 └── 失败/超时 ──→ Fallback_Handler.handle(tool_ref)
│                                   └──→ 降级响应，标注 degraded=true
│
└── 执行 PromptNode 序列（顺序不变，继承自 learning-os-architecture）
```


---

## 组件与接口

### MCP 接入层

#### MCP_Client

后端 Python 类，封装官方 `mcp` SDK，负责连接 MCP_Server 并调用工具。

```python
# backend/mcp_layer/mcp_client.py

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
from mcp.client.sse import sse_client
from typing import Any

class MCPClient:
    """
    封装 MCP 官方 SDK，支持 Stdio（本地）和 HTTP/SSE（远程）两种传输。
    由 AgentKernel 持有，对 Skill 执行层透明。
    """

    async def call_tool(
        self,
        server_id: str,
        tool_name: str,
        arguments: dict[str, Any],
        timeout_seconds: float = 10.0,
    ) -> MCPToolResult:
        """
        调用指定服务器的工具。
        超时或错误时返回 MCPToolResult(success=False, fallback_triggered=True)，
        不抛出异常，由调用方决定是否触发 Fallback_Handler。
        """
        ...

    async def discover_tools(self, server_id: str) -> list[MCPToolDef]:
        """
        调用服务器的工具发现接口，返回工具定义列表。
        结果缓存在 MCP_Registry 中。
        """
        ...
```

#### MCP_Registry

管理所有已连接 MCP_Server 的注册表，维护工具缓存和连接状态。

```python
# backend/mcp_layer/mcp_registry.py

class MCPRegistry:
    """
    统一管理多个 MCP_Server 的连接状态和工具缓存。
    工具全局引用名格式：{server_id}.{tool_name}
    """

    def register_server(self, config: MCPServerConfig) -> None:
        """
        注册服务器并自动触发工具发现。
        发现失败时标记为 discovery_failed，不中断其他服务器。
        """
        ...

    def unregister_server(self, server_id: str) -> None:
        """注销服务器，清除该服务器的所有工具缓存。"""
        ...

    def get_tool(self, tool_ref: str) -> MCPToolDef | None:
        """
        按 {server_id}.{tool_name} 格式查找工具定义。
        优先返回本地服务器的同名工具（本地优先策略）。
        """
        ...

    def list_tools(
        self,
        server_id: str | None = None,
        tool_name: str | None = None,
        status: MCPServerStatus | None = None,
    ) -> list[MCPToolDef]:
        """支持按服务器 ID、工具名称、连接状态过滤。"""
        ...

    def get_connection_summary(self) -> MCPConnectionSummary:
        """返回全部在线 / 仅本地 / 离线模式三种状态之一。"""
        ...
```

#### Fallback_Handler

为核心操作提供硬编码兜底实现，MCP 工具不可用时自动触发。

```python
# backend/mcp_layer/fallback_handler.py

class FallbackHandler:
    """
    硬编码兜底实现。
    每个工具引用对应一个 fallback 函数，AI 完全不参与兜底逻辑。
    """

    FALLBACK_MAP: dict[str, Callable] = {
        "filesystem.read_file":  _fallback_read_file,   # 直接读本地文件
        "filesystem.write_file": _fallback_write_file,  # 直接写本地文件
        "calendar.get_events":   _fallback_calendar,    # 返回空列表 + 提示
        "calendar.create_event": _fallback_calendar_create,
    }

    def handle(self, tool_ref: str, arguments: dict) -> MCPToolResult:
        """
        执行兜底逻辑。若无对应兜底，返回空结果并标注 degraded=True。
        """
        ...
```

### Skill 生态扩展层

#### AI_Model_Adapter（SkillParser 实现）

```python
# backend/skill_ecosystem/ai_model_adapter.py

class AIModelAdapter:
    """
    实现 SkillParser 接口，将 LLMService 封装为可插拔的解析适配器。
    AI 失败时自动降级为 RuleBasedAdapter。
    """

    PARSE_PROMPT_TEMPLATE = """
    你是一个学习方法结构化专家。请将以下学习经验文本解析为结构化的 Skill 定义。

    要求：
    1. 提取学习步骤，每个步骤生成一个 PromptNode
    2. 识别适用学科标签
    3. 生成简洁的名称和描述
    4. 以 JSON 格式返回，结构见下方 Schema

    输入文本：
    {text}

    返回 JSON Schema：
    {
      "name": "string",
      "description": "string",
      "tags": ["string"],
      "steps": [{"id": "string", "prompt": "string", "input_mapping": {}}]
    }
    """

    def parse(self, text: str) -> SkillDraftSchema:
        """
        调用 LLMService 解析文本。
        失败时降级为 RuleBasedAdapter.parse(text)。
        记录：模型名称、耗时、输入字符数、输出节点数。
        """
        ...


class RuleBasedAdapter:
    """
    基于规则的降级解析器。
    提取编号列表（1. 2. 3. 或 一、二、三）作为 PromptNode。
    保证在 AI 不可用时仍能生成最小可用草稿。
    """

    def parse(self, text: str) -> SkillDraftSchema:
        ...
```

#### DialogSessionManager（对话式 Skill 创建）

```python
# backend/skill_ecosystem/dialog_session_manager.py

FALLBACK_QUESTIONS = [
    "你想创建一个什么类型的学习方法？（例如：复习、解题、记忆）",
    "这个学习方法的第一步是什么？",
    "第一步完成后，下一步做什么？",
    "还有其他步骤吗？如果没有，请回复「完成」",
    "这个方法适合哪些学科？（例如：数学、物理、通用）",
    "给这个学习方法起一个名字吧",
]

class DialogSessionManager:
    """
    管理对话式 Skill 创建的会话状态。
    后端维护 Dialog_Session 状态，支持中断后恢复。
    AI 不可用时使用 FALLBACK_QUESTIONS 硬编码序列。
    """

    def start_session(self, user_id: str) -> DialogSession:
        """启动新的对话会话，返回第一个问题。"""
        ...

    def process_answer(
        self, session_id: str, answer: str
    ) -> DialogTurn:
        """
        处理用户回答，返回下一个问题或草稿预览。
        收集到至少一个步骤后自动生成草稿。
        """
        ...

    def save_draft(self, session_id: str) -> SkillDraftSchema:
        """将当前对话进度保存为草稿，支持中断恢复。"""
        ...

    def confirm_and_publish(
        self, session_id: str, user_id: str
    ) -> SkillSchema:
        """用户确认草稿后，调用 SkillLibrary 保存并发布。"""
        ...
```

#### MarketplaceService（Skill 市场）

```python
# backend/skill_ecosystem/marketplace_service.py

class MarketplaceService:
    """
    Skill 市场核心服务。
    复用现有 SkillLibrary 的 save/get/list/delete 接口，
    不引入新的本地存储层。
    """

    def list_skills(
        self,
        tag: str | None = None,
        keyword: str | None = None,
        source: SkillSourceEnum | None = None,
        sort_by: str = "download_count",
        page: int = 1,
        page_size: int = 20,
    ) -> PaginatedSkillList:
        """只返回通过结构验证的 Skill。"""
        ...

    def download_skill(
        self, marketplace_skill_id: str, user_id: str
    ) -> LocalSkillSchema:
        """
        下载云端 Skill 到用户本地库。
        来源标注为 marketplace_download，记录原始云端 ID 和下载时间。
        """
        ...

    def submit_skill(
        self, skill_data: SkillSubmitRequest, submitter_id: str
    ) -> MarketplaceSkillSchema:
        """
        第三方提交 Skill。
        分配新 UUID，记录提交者和时间，来源标注为 third_party_api。
        验证失败返回 422 + 字段级错误。
        """
        ...
```

### Flutter 端新增接口

Flutter 端不直接连接 MCP，通过现有 HTTP API 间接调用。新增以下 Dart 接口：

```dart
// lib/core/mcp/mcp_status_provider.dart
// 轮询后端 /api/mcp/status，提供 MCPConnectionState 给 UI 层

enum MCPConnectionState { allOnline, localOnly, offline }

// lib/core/skill/skill_marketplace_service.dart
// 封装 /api/marketplace/ 系列 API 调用

abstract class SkillMarketplaceService {
  Future<PaginatedSkillList> listSkills({String? tag, String? keyword, SkillSource? source});
  Future<LocalSkill> downloadSkill(String marketplaceSkillId);
  Future<MarketplaceSkill> submitSkill(SkillSubmitRequest request);
}

// lib/core/skill/dialog_skill_creation_service.dart
// 封装 /api/agent/dialog-skill/ 系列 API 调用

abstract class DialogSkillCreationService {
  Future<DialogTurn> startSession();
  Future<DialogTurn> sendAnswer(String sessionId, String answer);
  Future<SkillDraft> saveDraft(String sessionId);
  Future<Skill> confirmAndPublish(String sessionId);
}
```


---

## 数据模型

### Python Pydantic 模型（后端）

```python
# backend/mcp_layer/models.py

from enum import Enum
from pydantic import BaseModel
from typing import Any

class MCPServerType(str, Enum):
    local = "local"    # Stdio 传输
    remote = "remote"  # HTTP/SSE 传输

class MCPServerStatus(str, Enum):
    connected = "connected"
    disconnected = "disconnected"
    discovery_failed = "discovery_failed"
    connecting = "connecting"

class MCPServerConfig(BaseModel):
    server_id: str                    # 唯一标识，用于工具引用前缀
    name: str
    type: MCPServerType
    # Stdio 传输：command + args；HTTP/SSE 传输：url
    command: str | None = None        # 本地服务器启动命令
    args: list[str] = []
    url: str | None = None            # 远程服务器地址
    env: dict[str, str] = {}

class MCPToolDef(BaseModel):
    server_id: str
    tool_name: str
    global_ref: str                   # "{server_id}.{tool_name}"
    description: str
    input_schema: dict[str, Any]      # JSON Schema

class MCPToolResult(BaseModel):
    success: bool
    data: dict[str, Any] = {}
    error_message: str | None = None
    fallback_triggered: bool = False
    degraded: bool = False            # 标注该工具调用已降级

class MCPConnectionSummary(BaseModel):
    state: str                        # "all_online" | "local_only" | "offline"
    connected_servers: list[str]
    failed_servers: list[str]
```

```python
# backend/skill_ecosystem/models.py

from enum import Enum
from datetime import datetime
from pydantic import BaseModel, Field
import uuid

class SkillSourceEnum(str, Enum):
    builtin = "builtin"
    user_created = "user_created"
    third_party_api = "third_party_api"
    experience_import = "experience_import"
    marketplace_download = "marketplace_download"
    marketplace_fork = "marketplace_fork"

class PromptNodeSchema(BaseModel):
    id: str
    prompt: str
    input_mapping: dict[str, str] = {}

class SkillSchema(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    name: str
    description: str
    tags: list[str]
    prompt_chain: list[PromptNodeSchema]
    required_components: list[str] = []
    version: str = "1.0.0"
    created_at: datetime = Field(default_factory=datetime.utcnow)
    type: str                         # "builtin" | "custom"
    source: SkillSourceEnum
    created_by: str | None = None
    schema_version: str = "1.0"       # Skill JSON Schema 版本号

class MarketplaceSkillSchema(SkillSchema):
    download_count: int = 0
    submitter_id: str | None = None
    submitted_at: datetime | None = None
    original_marketplace_id: str | None = None  # 下载时记录云端原始 ID
    downloaded_at: datetime | None = None

class SkillDraftSchema(BaseModel):
    session_id: str | None = None
    name: str | None = None
    description: str | None = None
    tags: list[str] = []
    steps: list[PromptNodeSchema] = []
    required_components: list[str] = []
    is_draft: bool = True
    source_text_length: int | None = None

class DialogSession(BaseModel):
    session_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    user_id: str
    current_step: int = 0
    collected_data: dict[str, Any] = {}
    draft: SkillDraftSchema = Field(default_factory=SkillDraftSchema)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    is_ai_available: bool = True

class DialogTurn(BaseModel):
    session_id: str
    question: str                     # 下一个问题（用户友好表述，无技术术语）
    draft_preview: SkillDraftSchema | None = None  # 收集到足够信息后展示
    is_complete: bool = False         # True 时展示确认界面

class ParseLog(BaseModel):
    model_name: str
    duration_ms: float
    input_char_count: int
    output_node_count: int
    success: bool
    error: str | None = None

class SkillSubmitRequest(BaseModel):
    name: str
    description: str
    tags: list[str]
    prompt_chain: list[PromptNodeSchema]
    required_components: list[str] = []
    version: str = "1.0.0"

class PaginatedSkillList(BaseModel):
    skills: list[MarketplaceSkillSchema]
    total: int
    page: int
    page_size: int

class SkillImportResult(BaseModel):
    success: bool
    skill: SkillSchema | None = None
    missing_components: list[str] = []  # 缺失的 Component ID 列表
    errors: list[str] = []
```

### Dart 数据模型（Flutter 端）

```dart
// lib/core/mcp/mcp_models.dart

enum MCPConnectionState { allOnline, localOnly, offline }

class MCPToolRef {
  final String serverId;
  final String toolName;
  String get globalRef => '$serverId.$toolName';

  const MCPToolRef({required this.serverId, required this.toolName});

  /// 从 "server_id.tool_name" 格式解析
  factory MCPToolRef.fromString(String ref) {
    final parts = ref.split('.');
    assert(parts.length == 2, 'Invalid MCP tool ref: $ref');
    return MCPToolRef(serverId: parts[0], toolName: parts[1]);
  }

  /// 判断一个 requiredComponents 条目是否为 MCP 工具引用（含点号）
  static bool isMCPRef(String ref) => ref.contains('.');
}

// lib/core/skill/marketplace_models.dart

enum SkillSourceExtended {
  builtin,
  userCreated,
  thirdPartyApi,
  experienceImport,
  marketplaceDownload,
  marketplaceFork,
}

class MarketplaceSkill extends Skill {
  final int downloadCount;
  final String? submitterId;
  final DateTime? submittedAt;
  final String? originalMarketplaceId;
  final DateTime? downloadedAt;

  const MarketplaceSkill({
    required super.id,
    required super.name,
    required super.description,
    required super.tags,
    required super.promptChain,
    required super.requiredComponents,
    required super.version,
    required super.createdAt,
    required super.type,
    super.createdBy,
    super.source,
    this.downloadCount = 0,
    this.submitterId,
    this.submittedAt,
    this.originalMarketplaceId,
    this.downloadedAt,
  });
}

class DialogTurn {
  final String sessionId;
  final String question;
  final SkillDraft? draftPreview;
  final bool isComplete;

  const DialogTurn({
    required this.sessionId,
    required this.question,
    this.draftPreview,
    this.isComplete = false,
  });
}

class SkillImportResult {
  final bool success;
  final Skill? skill;
  final List<String> missingComponents;
  final List<String> errors;

  const SkillImportResult({
    required this.success,
    this.skill,
    this.missingComponents = const [],
    this.errors = const [],
  });
}
```


---

## 新增文件目录结构

```
backend/
├── mcp_layer/                          # 新增：MCP 接入层
│   ├── __init__.py
│   ├── models.py                       # MCPServerConfig / MCPToolDef / MCPToolResult 等
│   ├── mcp_client.py                   # MCPClient（封装官方 mcp SDK）
│   ├── mcp_registry.py                 # MCPRegistry（服务器注册表 + 工具缓存）
│   ├── fallback_handler.py             # FallbackHandler（硬编码兜底实现）
│   └── server_configs/                 # 预置服务器配置
│       ├── filesystem_server.py        # mcp-server-filesystem 配置
│       ├── calendar_server.py          # 本地日历服务配置
│       └── pdf_parser_server.py        # 本地 PDF 解析服务配置
│
├── skill_ecosystem/                    # 新增：Skill 生态扩展层
│   ├── __init__.py
│   ├── models.py                       # SkillSchema / MarketplaceSkillSchema / DialogSession 等
│   ├── ai_model_adapter.py             # AIModelAdapter + RuleBasedAdapter
│   ├── dialog_session_manager.py       # DialogSessionManager（对话式创建）
│   ├── marketplace_service.py          # MarketplaceService（Skill 市场）
│   └── skill_io.py                     # exportSkill / importSkill（JSON 往返）
│
├── routers/
│   ├── agent.py                        # 已有，新增 /dialog-skill/ 子路由
│   └── marketplace.py                  # 新增：/api/marketplace/ 路由
│
└── main.py                             # 新增注册 marketplace 路由

lib/
├── core/
│   ├── mcp/                            # 新增：MCP 状态感知层
│   │   ├── mcp_models.dart             # MCPToolRef / MCPConnectionState
│   │   └── mcp_status_provider.dart    # Riverpod Provider，轮询后端状态
│   │
│   └── skill/
│       ├── skill_marketplace_service.dart   # 新增：Skill 市场 API 封装
│       ├── dialog_skill_creation_service.dart  # 新增：对话式创建 API 封装
│       └── skill_io_service.dart            # 新增：exportSkill / importSkill
│
├── features/
│   ├── skill_marketplace/              # 新增：Skill 市场 UI
│   │   ├── marketplace_page.dart       # 浏览 / 搜索 / 下载
│   │   └── skill_detail_page.dart      # Skill 详情 + 下载按钮
│   │
│   └── skill_creation/                 # 新增：Skill 创建 UI
│       ├── dialog_creation_page.dart   # 对话式创建页面
│       └── skill_draft_preview.dart    # 草稿预览 + 确认
│
└── widgets/
    └── mcp_status_indicator.dart       # 新增：MCP 连接状态指示器
```


---

## API 端点清单（新增）

### MCP 管理端点（`/api/mcp/`）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/mcp/status` | 返回 MCPConnectionSummary（全部在线/仅本地/离线） |
| GET | `/api/mcp/servers` | 列出所有已注册 MCP_Server 及其状态 |
| POST | `/api/mcp/servers` | 注册新 MCP_Server（触发工具发现） |
| DELETE | `/api/mcp/servers/{server_id}` | 注销 MCP_Server，清除工具缓存 |
| GET | `/api/mcp/tools` | 查询工具列表，支持 `server_id`、`tool_name`、`status` 过滤 |
| POST | `/api/mcp/tools/call` | 直接调用 MCP 工具（调试用，需认证） |

### Skill 市场端点（`/api/marketplace/`）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/marketplace/skills` | 浏览 Skill 列表，支持 `tag`、`keyword`、`source`、`sort_by`、`page` 过滤，每页最多 20 条 |
| GET | `/api/marketplace/skills/{id}` | 获取单个 Skill 完整定义（含 prompt_chain） |
| POST | `/api/marketplace/skills` | 第三方提交 Skill（需认证），验证失败返回 422 + 字段级错误 |
| POST | `/api/marketplace/skills/{id}/download` | 下载云端 Skill 到用户本地库，来源标注 `marketplace_download` |

### 对话式 Skill 创建端点（`/api/agent/dialog-skill/`）

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/agent/dialog-skill/start` | 启动 Dialog_Session，返回第一个引导问题 |
| POST | `/api/agent/dialog-skill/{session_id}/answer` | 提交用户回答，返回下一个问题或草稿预览 |
| GET | `/api/agent/dialog-skill/{session_id}/draft` | 获取当前草稿（支持中断恢复） |
| POST | `/api/agent/dialog-skill/{session_id}/confirm` | 确认草稿，调用 SkillLibrary 保存并发布 |
| DELETE | `/api/agent/dialog-skill/{session_id}` | 放弃当前 Dialog_Session |

### Skill JSON 导入导出端点（`/api/agent/skills/`，扩展现有路由）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/agent/skills/{skill_id}/export` | 导出 Skill 为 JSON 字符串（含 schema_version） |
| POST | `/api/agent/skills/import` | 导入 Skill JSON，返回 SkillImportResult（含缺失 Component 列表） |

### SkillParser 配置端点（`/api/agent/parser/`）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/agent/parser/config` | 获取当前 SkillParser 适配器配置 |
| PUT | `/api/agent/parser/config` | 运行时切换 AI_Model_Adapter 实现 |


---

## 正确性属性

*属性（Property）是在系统所有合法执行中都应成立的特征或行为——本质上是对系统应做什么的形式化陈述。属性是人类可读规范与机器可验证正确性保证之间的桥梁。*

### 属性 1：MCP 工具全局引用名格式

*对于任意* 已注册的 MCP_Server（server_id）和该服务器暴露的任意工具（tool_name），MCP_Registry 为该工具分配的全局引用名应严格等于字符串 `"{server_id}.{tool_name}"`，且该引用名在整个注册表中唯一。

**验证：需求 1.3、2.3**

---

### 属性 2：工具发现缓存完整性

*对于任意* 成功连接的 MCP_Server，MCP_Registry 缓存的工具列表应与该服务器实际暴露的工具列表完全一致——不多（无幻觉工具）、不少（无遗漏工具）。

**验证：需求 1.4、2.2**

---

### 属性 3：MCP 工具失败时 Skill 执行继续

*对于任意* 包含 MCP 工具调用的 Skill，当该工具调用返回错误或超时时，AgentKernel 应继续执行后续 PromptNode，不抛出 SkillExecutionError，且执行上下文中应包含 `degraded=true` 标注。

**验证：需求 1.5**

---

### 属性 4：服务器注销清除工具缓存

*对于任意* 已注册的 MCP_Server，注销该服务器后，MCP_Registry 的工具列表中不应再包含该服务器的任何工具，且按该服务器 ID 查询应返回空列表。

**验证：需求 2.4**

---

### 属性 5：工具发现失败不影响其他服务器

*对于任意* 包含 N 个 MCP_Server 的注册表，当其中 K 个服务器（K < N）工具发现失败时，其余 N-K 个服务器的工具应正常可用，失败服务器被标记为 `discovery_failed` 状态，不影响整体启动流程。

**验证：需求 2.5**

---

### 属性 6：过滤查询结果一致性

*对于任意* 工具列表或 Skill 市场列表的过滤查询（按服务器 ID、工具名称、连接状态、学科标签、关键词、来源类型），返回的所有条目都应满足该过滤条件，不应包含不匹配的结果。

**验证：需求 2.6、6.2**

---

### 属性 7：本地优先路由

*对于任意* 同时存在本地（Local_MCP_Server）和远程（Remote_MCP_Server）版本的同名工具，MCP_Registry 的工具查找应始终优先返回本地版本，仅当本地版本不可用时才返回远程版本。

**验证：需求 3.1**

---

### 属性 8：Component 隔离性

*对于任意* MCP 层组件（MCP_Client、MCP_Registry、远程服务器）的失败状态，通过 ComponentRegistry 调用的内置 Component（Notebook、MistakeBook、MindMap、Chat、Solve、Quiz）的读写操作应始终成功，不受 MCP 层状态影响。

**验证：需求 3.6、10.4**

---

### 属性 9：AI 解析 Prompt 模板注入

*对于任意* 输入文本，AI_Model_Adapter 发送给 LLMService 的请求应始终包含标准化的 Skill 解析 Prompt 模板（`PARSE_PROMPT_TEMPLATE`），不同输入文本只替换模板中的 `{text}` 占位符，模板结构保持不变。

**验证：需求 5.3**

---

### 属性 10：AI 失败时降级解析生成有效草稿

*对于任意* 包含有效步骤结构（至少一个编号步骤或分点内容）的学习经验文本，当 AI 模型调用失败时，RuleBasedAdapter 降级解析应生成包含至少一个 PromptNode 的 SkillDraft，满足 Skill 最低结构要求。

**验证：需求 5.4、5.6**

---

### 属性 11：Skill 下载往返一致性

*对于任意* 云端 Skill 市场中的合法 Skill，执行下载操作后，用户本地 SkillLibrary 中应能通过 `get(id)` 查询到该 Skill 的完整副本，且来源标注为 `marketplace_download`，原始云端 Skill ID 记录在 `original_marketplace_id` 字段中。

**验证：需求 6.3**

---

### 属性 12：无效 Skill 不进入市场展示

*对于任意* 结构验证失败的 Skill（空 prompt_chain、缺失必填字段等），Skill 市场的列表接口不应返回该 Skill，无论其是否已存储在数据库中。

**验证：需求 6.5、7.3**

---

### 属性 13：Skill JSON 往返一致性

*对于任意* 合法的自定义 Skill 对象，调用 `exportSkill` 序列化为 JSON 后再调用 `importSkill` 反序列化，所得 Skill 对象的所有字段（`id` 除外，导入时重新分配）应与原 Skill 完全一致，包括 `name`、`description`、`tags`、`prompt_chain`（含顺序）、`required_components`、`version`、`type`、`source`、`schema_version`。

**验证：需求 8.3**

---

### 属性 14：缺失 Component 检测完整性

*对于任意* 引用了 K 个未在 ComponentRegistry 中注册的 Component ID 的 Skill JSON，`importSkill` 返回的 `SkillImportResult.missing_components` 列表应恰好包含这 K 个 ID，不多不少。

**验证：需求 8.5**

---

### 属性 15：对话式创建状态保持

*对于任意* Dialog_Session，在任意对话步骤中断（用户退出）后，保存的草稿应包含中断前所有已收集的信息（步骤列表、标签、名称等），用户恢复后继续的对话不应丢失已收集的数据。

**验证：需求 9.5**

---

### 属性 16：AI 不可用时硬编码兜底完成创建

*对于任意* AI 模型不可用的状态，DialogSessionManager 应使用 `FALLBACK_QUESTIONS` 硬编码问题序列引导用户完成完整的 Skill 创建流程，最终生成包含至少一个 PromptNode 的有效 SkillDraft，不因 AI 不可用而中断流程。

**验证：需求 9.7**


---

## 错误处理

### MCP 层错误处理

| 错误场景 | 处理方式 | 返回给调用方 |
|---------|---------|------------|
| MCP_Server 连接失败（启动时） | 标记为 `disconnected`，记录日志，不中断启动 | 服务器状态 = `disconnected` |
| 工具发现失败 | 标记为 `discovery_failed`，其他服务器继续 | 服务器状态 = `discovery_failed` |
| MCP 工具调用超时（> 10 秒） | 触发 Fallback_Handler，标注 `degraded=true` | `MCPToolResult(success=False, fallback_triggered=True)` |
| MCP 工具调用返回错误 | 触发 Fallback_Handler，Skill 执行继续 | `MCPToolResult(success=False, degraded=True)` |
| 无对应 Fallback 的工具失败 | 返回空结果，标注 `degraded=True`，记录警告日志 | 空 data，`degraded=True` |
| 网络不可用时调用远程工具 | 立即返回降级响应，不等待超时 | `MCPToolResult(success=False, fallback_triggered=True)` |
| 工具引用格式错误（无点号） | 返回 400 错误，提示正确格式 | `{"error": "Invalid tool ref format, expected {server_id}.{tool_name}"}` |

### Skill 生态层错误处理

| 错误场景 | 处理方式 | 返回给调用方 |
|---------|---------|------------|
| AI 模型调用失败（SkillParser） | 降级为 RuleBasedAdapter，记录 ParseLog | 规则解析结果，`model_name="rule_based"` |
| 规则解析无法提取步骤 | 返回空草稿，提示用户补充内容 | `ParseError("无法从文本中提取步骤，请补充编号列表或分点内容")` |
| Skill 结构验证失败（提交/导入） | 返回字段级错误列表，不保存 | `422 + {"field_errors": [...]}` |
| 导入 JSON 格式不合法 | 返回解析错误，不保存任何数据 | `SkillImportResult(success=False, errors=["JSON 格式错误: ..."])` |
| 导入 Skill 引用缺失 Component | 列出缺失 ID，询问用户是否仍要保存 | `SkillImportResult(missing_components=["calendar", ...])` |
| 下载 Skill 时网络不可达 | 返回 503，提示用户稍后重试 | `{"error": "Skill 市场暂时不可达，请检查网络连接"}` |
| Dialog_Session 不存在 | 返回 404 | `{"error": "Dialog session not found"}` |
| AI 不可用时对话式创建 | 切换到硬编码问题序列，用户无感知 | 正常 DialogTurn 响应，问题来自 FALLBACK_QUESTIONS |
| 生态接入层初始化失败 | 降级运行，内置 Component 和 Skill 不受影响 | 系统正常启动，MCP 状态显示"离线模式" |

### 降级策略优先级

```
工具调用请求
    │
    ▼
1. 本地 MCP_Server（优先）
    │ 失败
    ▼
2. 远程 MCP_Server（网络可用时）
    │ 失败/超时
    ▼
3. Fallback_Handler 硬编码兜底
    │ 无对应兜底
    ▼
4. 返回空结果 + degraded=True 标注，Skill 执行继续
```

---

## 测试策略

### 单元测试

针对具体示例和边界条件：

- MCPToolRef 格式解析（含点号 vs 不含点号）
- MCP_Registry 注册/注销/查询逻辑
- Fallback_Handler 各工具的兜底实现
- RuleBasedAdapter 规则解析（编号列表、分点内容）
- SkillImportResult 缺失 Component 检测
- DialogSessionManager 硬编码问题序列完整性
- Skill JSON 序列化/反序列化字段完整性

### 属性测试

使用 [Hypothesis](https://hypothesis.readthedocs.io/)（Python PBT 库）验证上述 16 个正确性属性，每个属性测试运行最少 100 次迭代。

测试标签格式：`# Feature: ecosystem-integration, Property {N}: {属性描述}`

重点属性测试：

- **属性 1**：生成随机 server_id 和 tool_name，验证全局引用名格式和唯一性
- **属性 2**：用 mock MCP_Server 暴露随机工具列表，验证缓存完整性（不多不少）
- **属性 3**：生成随机 Skill（含 MCP 工具调用），注入失败响应，验证执行继续且有 degraded 标注
- **属性 6**：生成随机工具集合和过滤条件，验证过滤结果的完整性和准确性
- **属性 8**：注入 MCP 全部失败，验证 Component 操作不受影响
- **属性 10**：生成包含步骤结构的随机文本，注入 AI 失败，验证规则解析生成有效草稿
- **属性 13**：生成随机合法 Skill，验证 JSON 往返一致性（round-trip）
- **属性 14**：生成引用随机未注册 Component 的 Skill，验证缺失检测完整性
- **属性 15**：在随机对话步骤中断，验证草稿保存完整性

### 集成测试

- MCP_Client 连接本地 `mcp-server-filesystem`，调用文件读写工具（1-3 个示例）
- Skill 市场 API 端到端流程（提交 → 列表 → 下载 → 本地查询）
- 对话式 Skill 创建完整流程（AI 可用 + AI 不可用两种路径）
- Skill JSON 导入导出跨设备兼容性（含 schema_version 检查）

### 冒烟测试

- MCP_Registry 初始化时预置服务器配置加载成功
- AI_Model_Adapter 实现了 SkillParser 接口的所有方法
- `/api/marketplace/skills` 端点返回 200
- `/api/mcp/status` 端点返回有效的连接状态

---

## 实现阶段划分

### 第一阶段：MCP 接入层骨架（后端）

**目标**：建立 MCP 层基础设施，实现本地 MCP_Server 连接。

**工作内容**：

1. 安装 `mcp` Python SDK（`pip install mcp`），添加到 `requirements.txt`
2. 创建 `backend/mcp_layer/` 目录，实现 `MCPRegistry`、`MCPClient`、`FallbackHandler` 骨架
3. 配置 `mcp-server-filesystem` 本地服务器（Stdio 传输）
4. 新增 `/api/mcp/status` 和 `/api/mcp/tools` 端点
5. 在 `backend/main.py` 注册 mcp 路由
6. 验证：属性 1、2、4 的测试通过

**约束**：不修改现有 `agent.py` 路由，MCP 层作为独立模块存在。

---

### 第二阶段：AgentKernel 路由扩展 + Fallback

**目标**：在 AgentKernel 内部实现 Component/MCP 双路由，接入 Fallback_Handler。

**工作内容**：

1. 扩展 `backend/routers/agent.py` 的 `execute-node` 端点，支持解析 `{server_id}.{tool_name}` 格式的工具引用
2. 实现 `FallbackHandler` 的文件读写和日历查询兜底逻辑
3. 实现本地优先路由策略（属性 7）
4. 在 Flutter 端添加 `MCPToolRef.isMCPRef()` 工具引用格式判断
5. 添加 `mcp_status_indicator.dart` UI 组件
6. 验证：属性 3、5、7、8 的测试通过

---

### 第三阶段：Skill 生态扩展

**目标**：实现 AI_Model_Adapter、Skill 市场、对话式创建、JSON 导入导出。

**工作内容**：

1. 实现 `AIModelAdapter` 和 `RuleBasedAdapter`，接入现有 `LLMService`
2. 实现 `DialogSessionManager`，包含硬编码 `FALLBACK_QUESTIONS` 序列
3. 创建 `backend/skill_ecosystem/marketplace_service.py` 和 `backend/routers/marketplace.py`
4. 实现 `skill_io.py` 的 `exportSkill` / `importSkill`（含 `schema_version` 字段）
5. 在 Flutter 端实现 `SkillMarketplaceService`、`DialogSkillCreationService`、`SkillIOService`
6. 新增 Skill 市场 UI 页面和对话式创建页面
7. 验证：属性 9-16 的测试通过，集成测试通过

---

### 第四阶段：远程 MCP_Server + 网络恢复

**目标**：接入可选的远程 MCP_Server，实现网络状态感知和自动重连。

**工作内容**：

1. 实现 HTTP/SSE 传输的远程 MCP_Server 连接（云端 OCR、网页搜索）
2. 实现网络状态监听和自动重连逻辑
3. 实现 UI 层三种连接状态的切换展示（全部在线/仅本地/离线模式）
4. 验证：离线降级和网络恢复的集成测试通过
