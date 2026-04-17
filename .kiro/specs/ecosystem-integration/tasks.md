# 实现计划：生态接入层（Ecosystem Integration）

## 概述

基于设计文档的四个阶段，将 MCP 接入层和 Skill 生态扩展能力逐步集成到现有 Learning OS 三层架构中。
实现语言：Python（后端）+ Dart/Flutter（前端）。

---

## 任务列表

### 第一阶段：MCP 接入层骨架

- [x] 1. 安装依赖并创建 MCP 层目录结构
  - 在 `backend/require
  ments.txt` 中添加 `mcp` Python SDK 依赖（固定版本）
  - 创建 `backend/mcp_layer/` 目录及 `__init__.py`
  - 创建 `backend/mcp_layer/server_configs/` 子目录及 `__init__.py`
  - _需求：1.1、2.1、10.1_

- [x] 2. 实现 MCP 数据模型
  - 创建 `backend/mcp_layer/models.py`，定义 `MCPServerType`、`MCPServerStatus`、`MCPServerConfig`、`MCPToolDef`、`MCPToolResult`、`MCPConnectionSummary` Pydantic 模型
  - 确保 `MCPToolDef.global_ref` 字段格式为 `{server_id}.{tool_name}`
  - _需求：1.3、2.1、2.3_

- [x] 3. 实现 MCPClient 骨架
  - 创建 `backend/mcp_layer/mcp_client.py`，实现 `MCPClient` 类
  - 实现 `call_tool(server_id, tool_name, arguments, timeout_seconds=10.0)` 方法，封装官方 `mcp` SDK 的 Stdio 传输
  - 实现 `discover_tools(server_id)` 方法，调用服务器工具发现接口
  - 超时或错误时返回 `MCPToolResult(success=False, fallback_triggered=True)`，不抛出异常
  - _需求：1.1、1.4、1.5_

- [x] 4. 实现 MCPRegistry
  - 创建 `backend/mcp_layer/mcp_registry.py`，实现 `MCPRegistry` 类
  - 实现 `register_server(config)` 方法：注册服务器并自动触发工具发现，发现失败时标记为 `discovery_failed`，不中断其他服务器
  - 实现 `unregister_server(server_id)` 方法：注销服务器并清除该服务器所有工具缓存
  - 实现 `get_tool(tool_ref)` 方法：按 `{server_id}.{tool_name}` 格式查找，本地优先策略
  - 实现 `list_tools(server_id, tool_name, status)` 过滤查询方法
  - 实现 `get_connection_summary()` 方法：返回全部在线/仅本地/离线三种状态
  - _需求：1.3、1.4、2.1–2.6、3.1_

  - [ ]* 4.1 属性测试：全局引用名格式与唯一性（属性 1）
    - **属性 1：MCP 工具全局引用名格式**
    - 生成随机 `server_id` 和 `tool_name`，注册后验证 `global_ref == f"{server_id}.{tool_name}"` 且在注册表中唯一
    - **验证：需求 1.3、2.3**

  - [ ]* 4.2 属性测试：工具发现缓存完整性（属性 2）
    - **属性 2：工具发现缓存完整性**
    - 用 mock MCP_Server 暴露随机工具列表，注册后验证缓存工具集合与暴露工具集合完全一致（不多不少）
    - **验证：需求 1.4、2.2**

  - [ ]* 4.3 属性测试：服务器注销清除工具缓存（属性 4）
    - **属性 4：服务器注销清除工具缓存**
    - 注册任意服务器后注销，验证 `list_tools(server_id=id)` 返回空列表
    - **验证：需求 2.4**

  - [ ]* 4.4 属性测试：工具发现失败不影响其他服务器（属性 5）
    - **属性 5：工具发现失败不影响其他服务器**
    - 注册 N 个服务器，令其中 K 个发现失败，验证其余 N-K 个服务器工具正常可用，失败服务器状态为 `discovery_failed`
    - **验证：需求 2.5**

  - [ ]* 4.5 属性测试：过滤查询结果一致性（属性 6，MCP 工具部分）
    - **属性 6：过滤查询结果一致性**
    - 生成随机工具集合和过滤条件（server_id / tool_name / status），验证返回结果中所有条目均满足过滤条件
    - **验证：需求 2.6**

- [x] 5. 配置预置本地 MCP_Server
  - 创建 `backend/mcp_layer/server_configs/filesystem_server.py`：配置 `mcp-server-filesystem` Stdio 传输参数
  - 创建 `backend/mcp_layer/server_configs/calendar_server.py`：配置本地日历服务参数
  - 创建 `backend/mcp_layer/server_configs/pdf_parser_server.py`：配置本地 PDF 解析服务参数
  - _需求：1.1、3.3_

- [x] 6. 新增 MCP 管理 API 路由
  - 创建 `backend/routers/mcp.py`，实现以下端点：
    - `GET /api/mcp/status`：返回 `MCPConnectionSummary`
    - `GET /api/mcp/servers`：列出所有已注册服务器及状态
    - `POST /api/mcp/servers`：注册新服务器（触发工具发现）
    - `DELETE /api/mcp/servers/{server_id}`：注销服务器
    - `GET /api/mcp/tools`：查询工具列表，支持 `server_id`、`tool_name`、`status` 过滤
    - `POST /api/mcp/tools/call`：直接调用工具（调试用，需认证）
  - 在 `backend/main.py` 注册 mcp 路由
  - _需求：2.6、3.5_

- [x] 7. 第一阶段检查点
  - 确保所有测试通过，属性 1、2、4、5 的属性测试全部绿灯，ask the user if questions arise.

---

### 第二阶段：AgentKernel 双路由 + Fallback

- [x] 8. 实现 FallbackHandler
  - 创建 `backend/mcp_layer/fallback_handler.py`，实现 `FallbackHandler` 类
  - 实现 `_fallback_read_file`：直接读取本地文件系统
  - 实现 `_fallback_write_file`：直接写入本地文件系统
  - 实现 `_fallback_calendar`：返回空列表并附带提示信息
  - 实现 `_fallback_calendar_create`：返回降级响应
  - 实现 `handle(tool_ref, arguments)` 方法：无对应兜底时返回空结果并标注 `degraded=True`
  - _需求：1.5、3.3_

- [x] 9. 扩展 AgentKernel 路由逻辑（后端）
  - 修改 `backend/routers/agent.py` 的 `execute-node` 端点，解析 `requiredComponents` 中的工具引用
  - 实现路由判断：含点号（`{server_id}.{tool_name}`）→ `MCP_Client.call_tool()`；不含点号 → `ComponentRegistry.get()`
  - MCP 工具调用失败/超时时自动触发 `FallbackHandler.handle()`，在执行上下文中标注 `degraded=True`
  - 实现本地优先路由策略：同名工具优先选择 Local_MCP_Server
  - 网络不可用时对 Remote_MCP_Server 调用立即返回降级响应，不等待超时
  - _需求：1.2、1.5、1.6、3.1、3.2、4.2、4.4_

  - [ ]* 9.1 属性测试：MCP 工具失败时 Skill 执行继续（属性 3）
    - **属性 3：MCP 工具失败时 Skill 执行继续**
    - 生成随机 Skill（含 MCP 工具调用），注入失败响应，验证 AgentKernel 继续执行后续 PromptNode，不抛出 SkillExecutionError，且上下文包含 `degraded=True`
    - **验证：需求 1.5**

  - [ ]* 9.2 属性测试：本地优先路由（属性 7）
    - **属性 7：本地优先路由**
    - 同时注册同名工具的本地和远程版本，验证 `get_tool()` 始终返回本地版本；仅当本地不可用时返回远程版本
    - **验证：需求 3.1**

  - [ ]* 9.3 属性测试：Component 隔离性（属性 8）
    - **属性 8：Component 隔离性**
    - 注入 MCP 层全部失败状态，验证通过 ComponentRegistry 调用的六个内置 Component（Notebook、MistakeBook、MindMap、Chat、Solve、Quiz）读写操作不受影响
    - **验证：需求 3.6、10.4**

- [x] 10. Flutter 端 MCP 工具引用解析
  - 创建 `lib/core/mcp/mcp_models.dart`，定义 `MCPConnectionState` 枚举和 `MCPToolRef` 类
  - 实现 `MCPToolRef.isMCPRef(String ref)` 静态方法：含点号返回 true
  - 实现 `MCPToolRef.fromString(String ref)` 工厂构造函数
  - _需求：4.2、4.3_

- [x] 11. Flutter 端 MCP 状态 Provider
  - 创建 `lib/core/mcp/mcp_status_provider.dart`，实现 Riverpod Provider
  - 轮询后端 `/api/mcp/status` 端点，提供 `MCPConnectionState` 给 UI 层
  - _需求：3.5_

- [x] 12. MCP 连接状态指示器 Widget
  - 创建 `lib/widgets/mcp_status_indicator.dart`
  - 根据 `MCPConnectionState` 展示三种状态：全部在线 / 仅本地 / 离线模式
  - 集成到应用顶部 AppBar 区域
  - _需求：3.5_

- [x] 13. 第二阶段检查点
  - 确保所有测试通过，属性 3、5、7、8 的属性测试全部绿灯，ask the user if questions arise.

---

### 第三阶段：Skill 生态扩展

- [x] 14. 实现 Skill 生态数据模型
  - 创建 `backend/skill_ecosystem/__init__.py` 和 `backend/skill_ecosystem/models.py`
  - 定义 `SkillSourceEnum`、`PromptNodeSchema`、`SkillSchema`、`MarketplaceSkillSchema`、`SkillDraftSchema`、`DialogSession`、`DialogTurn`、`ParseLog`、`SkillSubmitRequest`、`PaginatedSkillList`、`SkillImportResult` Pydantic 模型
  - 确保 `SkillSchema` 包含 `schema_version` 字段
  - _需求：6.1、7.2、8.1、8.6_

- [x] 15. 实现 AIModelAdapter 和 RuleBasedAdapter
  - 创建 `backend/skill_ecosystem/ai_model_adapter.py`
  - 实现 `AIModelAdapter.parse(text)` 方法：调用 `LLMService`，注入 `PARSE_PROMPT_TEMPLATE`，记录 `ParseLog`（模型名称、耗时、输入字符数、输出节点数）
  - 实现 `RuleBasedAdapter.parse(text)` 方法：提取编号列表（`1. 2. 3.` 或 `一、二、三`）作为 PromptNode
  - `AIModelAdapter` 调用失败时自动降级为 `RuleBasedAdapter`
  - 实现运行时切换适配器的配置接口
  - _需求：5.1–5.6_

  - [ ]* 15.1 属性测试：AI 解析 Prompt 模板注入（属性 9）
    - **属性 9：AI 解析 Prompt 模板注入**
    - 生成任意输入文本，验证 `AIModelAdapter` 发送给 LLMService 的请求始终包含 `PARSE_PROMPT_TEMPLATE` 结构，仅 `{text}` 占位符被替换
    - **验证：需求 5.3**

  - [ ]* 15.2 属性测试：AI 失败时降级解析生成有效草稿（属性 10）
    - **属性 10：AI 失败时降级解析生成有效草稿**
    - 生成包含有效步骤结构（至少一个编号步骤）的随机文本，注入 AI 失败，验证 `RuleBasedAdapter` 生成的 `SkillDraft` 包含至少一个 `PromptNode`
    - **验证：需求 5.4、5.6**

- [x] 16. 实现 SkillParser 配置端点
  - 在 `backend/routers/agent.py` 新增子路由：
    - `GET /api/agent/parser/config`：获取当前适配器配置
    - `PUT /api/agent/parser/config`：运行时切换 `AI_Model_Adapter` 实现
  - _需求：5.2_

- [x] 17. 实现 Skill JSON 导入导出
  - 创建 `backend/skill_ecosystem/skill_io.py`
  - 实现 `export_skill(skill_id) -> str`：序列化为 JSON 字符串，包含所有字段（含 `schema_version`）
  - 实现 `import_skill(json_str) -> SkillImportResult`：反序列化并执行结构验证，检测缺失 Component，格式不合法时返回错误不保存
  - _需求：8.1–8.6_

  - [ ]* 17.1 属性测试：Skill JSON 往返一致性（属性 13）
    - **属性 13：Skill JSON 往返一致性**
    - 生成随机合法 Skill 对象，调用 `export_skill` 后再 `import_skill`，验证除 `id` 外所有字段（含 `prompt_chain` 顺序、`schema_version`）完全一致
    - **验证：需求 8.3**

  - [ ]* 17.2 属性测试：缺失 Component 检测完整性（属性 14）
    - **属性 14：缺失 Component 检测完整性**
    - 生成引用 K 个未注册 Component ID 的 Skill JSON，验证 `SkillImportResult.missing_components` 恰好包含这 K 个 ID，不多不少
    - **验证：需求 8.5**

- [x] 18. 实现 Skill JSON 导入导出 API 端点
  - 在 `backend/routers/agent.py` 新增：
    - `GET /api/agent/skills/{skill_id}/export`：导出 Skill 为 JSON
    - `POST /api/agent/skills/import`：导入 Skill JSON，返回 `SkillImportResult`
  - _需求：8.1、8.2、8.4、8.5_

- [x] 19. 实现 MarketplaceService 和市场 API 路由
  - 创建 `backend/skill_ecosystem/marketplace_service.py`，实现 `MarketplaceService` 类
  - 实现 `list_skills(tag, keyword, source, sort_by, page, page_size)`：只返回通过结构验证的 Skill，分页每页最多 20 条
  - 实现 `download_skill(marketplace_skill_id, user_id)`：下载到本地库，来源标注 `marketplace_download`，记录 `original_marketplace_id` 和 `downloaded_at`
  - 实现 `submit_skill(skill_data, submitter_id)`：分配新 UUID，来源标注 `third_party_api`，验证失败返回 422 + 字段级错误
  - 创建 `backend/routers/marketplace.py`，实现四个端点（GET/POST `/api/marketplace/skills`，GET `/api/marketplace/skills/{id}`，POST `/api/marketplace/skills/{id}/download`）
  - 在 `backend/main.py` 注册 marketplace 路由
  - 对提交 API 添加身份验证，未认证返回 401
  - _需求：6.1–6.6、7.1–7.6、10.3、10.6_

  - [ ]* 19.1 属性测试：Skill 下载往返一致性（属性 11）
    - **属性 11：Skill 下载往返一致性**
    - 对任意合法云端 Skill 执行下载，验证本地库可通过 `get(id)` 查到完整副本，来源为 `marketplace_download`，`original_marketplace_id` 正确记录
    - **验证：需求 6.3**

  - [ ]* 19.2 属性测试：无效 Skill 不进入市场展示（属性 12）
    - **属性 12：无效 Skill 不进入市场展示**
    - 向数据库写入结构验证失败的 Skill（空 `prompt_chain`、缺失必填字段），验证市场列表接口不返回该 Skill
    - **验证：需求 6.5、7.3**

  - [ ]* 19.3 属性测试：过滤查询结果一致性（属性 6，Skill 市场部分）
    - **属性 6：过滤查询结果一致性（Skill 市场）**
    - 生成随机 Skill 集合和过滤条件（tag / keyword / source），验证返回结果中所有条目均满足过滤条件
    - **验证：需求 6.2**

- [x] 20. 实现 DialogSessionManager（对话式 Skill 创建）
  - 创建 `backend/skill_ecosystem/dialog_session_manager.py`
  - 定义 `FALLBACK_QUESTIONS` 硬编码问题序列（6 个问题）
  - 实现 `start_session(user_id)` 方法：启动会话，返回第一个问题（用户友好表述，无技术术语）
  - 实现 `process_answer(session_id, answer)` 方法：处理回答，收集到至少一个步骤后自动生成草稿预览
  - 实现 `save_draft(session_id)` 方法：保存当前进度为草稿，支持中断恢复
  - 实现 `confirm_and_publish(session_id, user_id)` 方法：调用 SkillLibrary 保存并发布
  - AI 不可用时自动切换到 `FALLBACK_QUESTIONS` 序列，用户无感知
  - _需求：9.1–9.7_

  - [ ]* 20.1 属性测试：对话式创建状态保持（属性 15）
    - **属性 15：对话式创建状态保持**
    - 在随机对话步骤中断（调用 `save_draft`），验证保存的草稿包含中断前所有已收集信息（步骤列表、标签、名称），恢复后不丢失数据
    - **验证：需求 9.5**

  - [ ]* 20.2 属性测试：AI 不可用时硬编码兜底完成创建（属性 16）
    - **属性 16：AI 不可用时硬编码兜底完成创建**
    - 注入 AI 不可用状态，验证 `DialogSessionManager` 使用 `FALLBACK_QUESTIONS` 完成完整创建流程，最终生成包含至少一个 PromptNode 的有效 SkillDraft
    - **验证：需求 9.7**

- [x] 21. 新增对话式 Skill 创建 API 端点
  - 在 `backend/routers/agent.py` 新增 `/api/agent/dialog-skill/` 子路由：
    - `POST /api/agent/dialog-skill/start`
    - `POST /api/agent/dialog-skill/{session_id}/answer`
    - `GET /api/agent/dialog-skill/{session_id}/draft`
    - `POST /api/agent/dialog-skill/{session_id}/confirm`
    - `DELETE /api/agent/dialog-skill/{session_id}`
  - _需求：9.1–9.6_

- [x] 22. Flutter 端 Skill 生态数据模型
  - 创建 `lib/core/skill/marketplace_models.dart`，定义 `SkillSourceExtended` 枚举、`MarketplaceSkill`、`DialogTurn`、`SkillImportResult` Dart 类
  - _需求：6.1、8.1、9.3_

- [x] 23. Flutter 端 Skill 市场 Service
  - 创建 `lib/core/skill/skill_marketplace_service.dart`，封装 `/api/marketplace/` 系列 API 调用
  - 实现 `listSkills`、`downloadSkill`、`submitSkill` 方法
  - _需求：6.1–6.6、7.1–7.6_

- [x] 24. Flutter 端对话式创建 Service
  - 创建 `lib/core/skill/dialog_skill_creation_service.dart`，封装 `/api/agent/dialog-skill/` 系列 API 调用
  - 实现 `startSession`、`sendAnswer`、`saveDraft`、`confirmAndPublish` 方法
  - _需求：9.1–9.6_

- [x] 25. Flutter 端 Skill JSON 导入导出 Service
  - 创建 `lib/core/skill/skill_io_service.dart`，封装 `/api/agent/skills/export` 和 `/api/agent/skills/import` API 调用
  - _需求：8.1–8.6_

- [x] 26. Skill 市场 UI 页面
  - 创建 `lib/features/skill_marketplace/marketplace_page.dart`：展示 Skill 列表，支持按标签/关键词/来源过滤和排序，下载按钮
  - 创建 `lib/features/skill_marketplace/skill_detail_page.dart`：展示 Skill 完整信息（名称、描述、标签、来源、下载次数），下载按钮
  - _需求：6.1、6.2、6.3_

- [x] 27. 对话式 Skill 创建 UI 页面
  - 创建 `lib/features/skill_creation/dialog_creation_page.dart`：对话气泡式交互界面，每次展示单一问题，无技术术语
  - 创建 `lib/features/skill_creation/skill_draft_preview.dart`：草稿预览组件，展示名称/描述/标签/步骤列表，支持用户确认或提出修改
  - _需求：9.1–9.6_

- [x] 28. 第三阶段检查点
  - 确保所有测试通过，属性 9–16 的属性测试全部绿灯，集成测试（Skill 市场端到端、对话式创建双路径）通过，ask the user if questions arise.

---

### 第四阶段：远程 MCP_Server + 网络恢复

- [x] 29. 实现远程 MCP_Server 连接（HTTP/SSE 传输）
  - 在 `backend/mcp_layer/mcp_client.py` 中扩展 `MCPClient`，支持 HTTP/SSE 传输（使用官方 SDK `sse_client`）
  - 创建 `backend/mcp_layer/server_configs/` 中的远程服务器配置（云端 OCR、网页搜索）
  - _需求：1.1、2.1_

- [x] 30. 实现网络状态监听与自动重连
  - 在 `backend/mcp_layer/mcp_registry.py` 中实现网络状态监听逻辑
  - 网络恢复时自动重新连接之前标记为不可用的 Remote_MCP_Server
  - 网络不可用时对所有 Remote_MCP_Server 调用立即返回降级响应，不等待超时
  - _需求：3.2、3.4_

- [x] 31. Flutter 端三态连接状态 UI 完善
  - 完善 `lib/widgets/mcp_status_indicator.dart`，确保全部在线 / 仅本地 / 离线模式三种状态切换流畅
  - 在所有功能页（问答/解题/导图/出题）的 SubjectBar 区域集成状态指示器
  - _需求：3.5_

- [x] 32. 离线降级与网络恢复集成测试
  - 编写集成测试：模拟网络断开 → 验证 Remote_MCP_Server 立即降级 → 模拟网络恢复 → 验证自动重连成功
  - 编写集成测试：MCP 层全部失败时，内置 Component 功能（笔记本/错题本/思维导图）不受影响
  - _需求：3.2、3.4、3.6、10.4_

- [x] 33. 最终检查点
  - 确保所有阶段的测试通过，离线降级和网络恢复集成测试通过，ask the user if questions arise.

---

## 说明

- 标注 `*` 的子任务为可选任务（属性测试 / 集成测试），可跳过以加快 MVP 进度
- 每个任务引用了具体的需求条款，确保需求可追溯
- 属性测试使用 [Hypothesis](https://hypothesis.readthedocs.io/) 库，每个属性最少运行 100 次迭代
- 测试标签格式：`# Feature: ecosystem-integration, Property {N}: {属性描述}`
- 实现时不修改 `ComponentInterface`（open/write/read/close）和 `AgentKernel` 接口
