# 需求文档：生态接入层（Ecosystem Integration）

## 简介

在现有 Learning OS 三层架构（AgentKernel / SkillLibrary / ComponentRegistry）基础上，
新增两个方向的生态扩展能力：

**方向一：MCP 接入层**
将外部 MCP（Model Context Protocol）服务器接入 AgentKernel，
使 Agent 能调用外部工具（文件系统、OCR、日历、浏览器等），
同时保持教育专用工具（错题本、笔记本等）继续以 Component 形式运行，不做任何改动。

> **架构说明**：Component 是系统内置的"应用"（有 UI、有状态、有完整业务逻辑），
> MCP Tool 是外部"工具驱动"（无 UI，只有功能调用）。两者是不同层级的概念，
> MCP 不替代 Component，而是补充 Agent 调用外部能力的通道。

**方向二：Skill 生态扩展**
为 SkillParser 接入可插拔外部 AI 模型，
建立云端 Skill 市场（浏览、下载到本地、第三方提交），
支持 Skill JSON 往返导入导出，
并实现 SkillCreationAdapter 的对话式创建路径。

本功能严格遵守以下约束：
- 不修改现有 ComponentInterface（open/write/read/close）
- 不修改现有 AgentKernel 接口
- 教育专用工具（Component）不通过 MCP 包装，保持原有调用路径
- 所有核心执行路径必须有硬编码兜底，不允许 AI 完全决定执行结果
- MCP 工具调用失败时必须有降级方案，不影响核心学习功能

---

## 词汇表

- **MCP**：Model Context Protocol，Anthropic 推出的工具调用标准协议，已成为事实标准
- **MCP_Server**：实现 MCP 协议的服务进程，可以是本地进程或远程服务
- **MCP_Tool**：MCP_Server 暴露的单个可调用工具，具有名称、描述和输入 Schema。与 Component 的区别：MCP_Tool 是无状态的外部工具驱动，Component 是有 UI 和完整业务逻辑的内置应用
- **MCP_Client**：AgentKernel 内部的 MCP 客户端，负责连接 MCP_Server 并调用 MCP_Tool
- **Local_MCP_Server**：运行在本地设备上的 MCP_Server，无需网络即可调用（如本地文件系统）
- **Remote_MCP_Server**：运行在远程服务器上的 MCP_Server，需要网络连接（如云端 OCR、日历同步）
- **MCP_Registry**：管理所有已连接 MCP_Server 的注册表，由 AgentKernel 持有
- **Fallback_Handler**：当 MCP 工具不可用时执行的硬编码兜底逻辑
- **SkillParser**：将非结构化文本解析为 Skill 草稿的可插拔接口（已在 learning-os-architecture 中定义）
- **AI_Model_Adapter**：将外部 AI 模型接入 SkillParser 的适配器，支持多模型切换
- **Skill_Marketplace**：云端 Skill 共创市场，存储社区贡献的 Skill，用户可浏览并下载到本地
- **Skill_Download**：用户将云端 Skill 市场中的 Skill 下载到本地 Skill_Library 的操作，下载后可离线执行
- **SkillCreationAdapter**：统一 Skill 创建适配器（已在 learning-os-architecture 中定义），本 spec 实现其对话式路径
- **Dialog_Session**：对话式 Skill 创建过程中的一次引导对话会话，可中断后恢复
- **ComponentInterface**：现有标准接口（open/write/read/close），本 spec 不修改
- **AgentKernel**：现有内核接口，本 spec 不修改
- **ComponentRegistry**：现有组件注册表，本 spec 不修改

---

## 需求

### 需求 1：MCP 客户端——AgentKernel 调用外部工具

**用户故事：** 作为开发者，我希望 AgentKernel 能通过 MCP 协议调用外部工具（文件系统、OCR、日历等），以便 Skill 执行时能使用外部能力，而无需自己实现这些工具驱动。

#### 验收标准

1. THE AgentKernel SHALL 持有一个 MCP_Client，能够连接 MCP_Server 并调用其暴露的 MCP_Tool，调用结果以结构化数据返回给 Skill 执行上下文。
2. WHEN Skill 的 PromptNode 执行结果中包含工具调用指令时，THE AgentKernel SHALL 通过 MCP_Client 调用对应的 MCP_Tool，并将工具返回值注入下一个 PromptNode 的输入。
3. THE MCP_Client SHALL 支持同时连接多个 MCP_Server，每个服务器的工具以 `{server_id}.{tool_name}` 格式在 Skill 中引用，避免命名冲突。
4. WHEN MCP_Client 连接 MCP_Server 时，THE MCP_Client SHALL 自动发现该服务器暴露的所有工具，并将工具列表缓存供 AgentKernel 查询。
5. IF MCP_Tool 调用返回错误或超时（超过 10 秒），THEN THE AgentKernel SHALL 调用对应的 Fallback_Handler，Skill 执行继续而非中断，并在执行上下文中标注该工具调用已降级。
6. THE MCP_Client SHALL 对 Component（内置应用）的调用路径完全透明——Component 仍通过 ComponentRegistry 调用，不经过 MCP_Client。

---

### 需求 2：MCP 注册表——管理多个 MCP 服务器

**用户故事：** 作为开发者，我希望系统能统一管理多个 MCP 服务器的连接状态，以便在运行时动态发现和注册 MCP 工具。

#### 验收标准

1. THE MCP_Registry SHALL 支持注册 Local_MCP_Server 和 Remote_MCP_Server 两种类型，并为每个服务器存储：服务器 ID、名称、类型（本地/远程）、连接地址、连接状态、已发现工具列表。
2. WHEN 一个 MCP_Server 被注册时，THE MCP_Registry SHALL 自动调用该服务器的工具发现接口，缓存返回的所有 MCP_Tool 定义（名称、描述、输入 Schema）。
3. WHEN MCP_Registry 完成工具发现后，THE MCP_Registry SHALL 为每个工具分配格式为 `{server_id}.{tool_name}` 的全局唯一引用名，供 Skill 的 PromptNode 引用。
4. THE MCP_Registry SHALL 支持注销 MCP_Server，注销时清除该服务器的所有工具缓存。
5. IF 工具发现过程中 MCP_Server 返回错误，THEN THE MCP_Registry SHALL 记录错误日志，将该服务器标记为 `discovery_failed` 状态，并继续处理其他已注册服务器，不中断整体启动流程。
6. THE MCP_Registry SHALL 提供查询接口，支持按服务器 ID、工具名称、连接状态过滤已注册的工具列表。

---

### 需求 3：离线降级——MCP 工具不可用时的兜底策略

**用户故事：** 作为用户，我希望在 MCP 工具不可用（网络断开、服务器故障）时，核心学习功能仍能正常使用，以便不因外部工具故障而中断学习。

#### 验收标准

1. THE MCP_Registry SHALL 在工具调用时优先选择 Local_MCP_Server 提供的同名工具，仅当本地工具不可用时才尝试 Remote_MCP_Server。
2. WHEN 设备网络不可用时，THE MCP_Client SHALL 对所有 Remote_MCP_Server 的调用立即返回降级响应，不等待网络超时。
3. THE Fallback_Handler SHALL 为以下核心操作提供硬编码兜底实现：文件读写（本地文件系统直接操作）、日历查询（返回空结果并提示用户手动查看）。
4. WHEN 网络恢复时，THE MCP_Registry SHALL 自动重新连接之前标记为不可用的 Remote_MCP_Server。
5. THE Learning_OS SHALL 在 UI 层展示当前 MCP 连接状态指示器，区分"全部在线"、"仅本地"、"离线模式"三种状态。
6. WHILE MCP 工具不可用，THE Learning_OS SHALL 保证以下功能不受影响：笔记本读写（Component 直接调用）、错题本读写（Component 直接调用）、思维导图生成（Component 直接调用）、不依赖外部工具的 Skill 执行。


---

### 需求 4：教育专用工具保持 Component 路径

**用户故事：** 作为开发者，我希望明确教育专用工具（笔记本、错题本、思维导图等）继续以 Component 形式运行，不通过 MCP 包装，以便保持对这些核心工具的完全控制权和最低调用延迟。

#### 验收标准

1. THE Learning_OS SHALL 保持笔记本（Notebook）、错题本（MistakeBook）、思维导图（MindMap）、问答（Chat）、解题（Solve）、出题（Quiz）六个 Component 通过 ComponentRegistry 调用，不引入 MCP 中间层。
2. WHEN AgentKernel 调度 Skill 时，THE AgentKernel SHALL 根据 requiredComponents 字段区分调用路径：Component ID 通过 ComponentRegistry 调用，MCP 工具引用（格式 `{server_id}.{tool_name}`）通过 MCP_Client 调用。
3. THE Skill 定义 SHALL 在 requiredComponents 字段中同时支持 Component ID（如 `notebook`）和 MCP 工具引用（如 `filesystem.read_file`），两种引用格式在同一 Skill 中可共存。
4. IF 一个 Skill 同时引用了 Component 和 MCP 工具，THEN THE AgentKernel SHALL 在执行前验证两者均可用，任一不可用时按各自的降级策略处理（Component 不可用返回错误，MCP 工具不可用调用 Fallback_Handler）。

---

### 需求 5：可插拔 AI 模型接入 SkillParser

**用户故事：** 作为开发者，我希望 SkillParser 能接入不同的外部 AI 模型，以便在不修改上层代码的前提下切换或升级底层解析能力。

#### 验收标准

1. THE AI_Model_Adapter SHALL 实现 SkillParser 接口（`parse(String text): SkillDraft`），将外部 AI 模型的调用封装在适配器内部，上层代码无感知。
2. THE SkillParser SHALL 支持在运行时通过配置切换 AI_Model_Adapter 实现，切换后新的解析请求使用新模型，不影响进行中的解析任务。
3. WHEN AI_Model_Adapter 调用外部 AI 模型时，THE AI_Model_Adapter SHALL 在请求中注入标准化的 Skill 解析 Prompt 模板，确保不同模型返回结构一致的草稿数据。
4. IF 外部 AI 模型调用失败或返回无法解析的响应，THEN THE AI_Model_Adapter SHALL 降级为基于规则的文本解析（提取编号列表、关键词匹配），生成最小可用的 SkillDraft。
5. THE AI_Model_Adapter SHALL 记录每次解析调用的模型名称、耗时、输入字符数、输出节点数，供调试和性能分析使用。
6. FOR ALL 包含有效步骤结构的学习经验文本，AI_Model_Adapter 解析后生成的 SkillDraft SHALL 包含至少一个 PromptNode，满足 Skill 最低结构要求（继承自 learning-os-architecture 需求 8.2.6）。

---

### 需求 6：Skill 市场——浏览与下载

**用户故事：** 作为用户，我希望能浏览云端社区贡献的 Skill，并将感兴趣的 Skill 下载到本地 Skill 库，以便获取他人总结的优质学习方法，下载后离线也能使用。

#### 验收标准

1. THE Skill_Marketplace SHALL 提供 Skill 列表浏览界面，展示每个 Skill 的名称、描述、学科标签、来源（内置/用户创建/第三方）、下载次数、创建时间。
2. THE Skill_Marketplace SHALL 支持按学科标签、关键词、来源类型、下载次数排序对 Skill 列表进行过滤和排序。
3. WHEN 用户点击"下载"一个云端 Skill 时，THE Skill_Marketplace SHALL 将该 Skill 的完整定义（含 Prompt_Chain）下载并保存到用户本地的 Skill_Library，在元数据中标注来源为 `marketplace_download`，记录原始云端 Skill ID 和下载时间。
4. WHEN 用户删除一个已下载的 Skill 时，THE Skill_Library SHALL 从本地移除该 Skill 副本，若该 Skill 当前正在 Session 中使用则拒绝删除并提示用户。
5. THE Skill_Marketplace SHALL 对展示的每个 Skill 执行与需求 1（learning-os-architecture）相同的结构验证，验证不通过的 Skill 不得展示给用户。
6. THE Skill_Marketplace SHALL 支持用户对已下载的 Skill 进行本地修改，本地修改不影响云端原始版本，修改后的 Skill 来源标注为 `marketplace_fork`。

---

### 需求 7：Skill 市场——第三方提交

**用户故事：** 作为第三方开发者，我希望通过 API 向 Skill 市场提交 Skill，以便将我设计的学习方法分享给社区用户。

#### 验收标准

1. THE Skill_Marketplace SHALL 提供 `POST /api/marketplace/skills` 端点，接受符合 Skill JSON Schema 的提交请求，并对提交内容执行结构验证（与 learning-os-architecture 需求 1 相同）。
2. WHEN 第三方提交 Skill 时，THE Skill_Marketplace SHALL 为提交的 Skill 分配新的唯一标识符，在元数据中记录提交者标识和提交时间，并将来源标注为 `third_party_api`。
3. IF 提交的 Skill 结构验证失败，THEN THE Skill_Marketplace SHALL 返回包含字段级错误描述的 422 响应，不保存该 Skill。
4. THE Skill_Marketplace SHALL 提供 `GET /api/marketplace/skills` 端点，支持按标签、关键词、来源类型过滤，返回分页结果（每页最多 20 条）。
5. THE Skill_Marketplace SHALL 提供 `GET /api/marketplace/skills/{id}` 端点，返回单个 Skill 的完整定义，包含 Prompt_Chain 和 requiredComponents。
6. THE Skill_Marketplace SHALL 对所有提交 API 进行身份验证，未认证的请求返回 401 响应。

---

### 需求 8：Skill JSON 往返导入导出

**用户故事：** 作为用户，我希望将自定义 Skill 导出为 JSON 文件并在其他设备或账号上导入，以便备份和迁移我的学习方法。

#### 验收标准

1. THE Skill_Library SHALL 提供 `exportSkill(String skillId): String` 方法，将指定 Skill 序列化为标准 JSON 字符串，包含所有字段（id、name、description、tags、promptChain、requiredComponents、version、createdAt、type、source）。
2. THE Skill_Library SHALL 提供 `importSkill(String json): Skill` 方法，将 JSON 字符串反序列化为 Skill 对象，并执行与需求 1（learning-os-architecture）相同的结构验证。
3. FOR ALL 合法的自定义 Skill 对象，导出为 JSON 后再导入，所得 Skill 对象的所有字段（id 除外，导入时重新分配）SHALL 与原 Skill 完全一致（往返属性）。
4. IF 导入的 JSON 格式不合法或结构验证失败，THEN THE Skill_Library SHALL 返回包含具体失败原因的导入错误，不保存任何数据。
5. WHEN 导入的 Skill 引用了当前 ComponentRegistry 中不存在的 Component 时，THE Skill_Library SHALL 在导入结果中列出缺失的 Component ID，并询问用户是否仍要保存（保存后该 Skill 在缺失 Component 补齐前不可执行）。
6. THE Skill_Library SHALL 在导出的 JSON 中包含 `schema_version` 字段，标注当前 Skill JSON Schema 的版本号，供未来版本兼容性检查使用。

---

### 需求 9：对话式 Skill 创建路径实现

**用户故事：** 作为用户，我希望通过与 AI 对话的方式创建 Skill，以便在不了解任何技术概念的情况下将自己的学习方法固化为可复用的 Skill。

#### 验收标准

1. WHEN 用户选择"对话式创建 Skill"入口时，THE SkillCreationAdapter SHALL 启动 Dialog_Session，由 Agent 依次向用户提问以收集 Skill 的步骤、条件和工具信息，每次提问聚焦单一信息点，不同时提问多个问题。
2. THE SkillCreationAdapter SHALL 在对话过程中不向用户展示任何技术术语（如 PromptNode、ComponentInterface、requiredComponents 等内部概念），使用用户友好的表述替代。
3. WHEN Agent 在引导对话中收集到足够信息（至少一个学习步骤）时，THE SkillCreationAdapter SHALL 自动生成 Skill 草稿，以可读形式呈现给用户确认，草稿包含名称、描述、学科标签和步骤列表。
4. WHEN 用户对 Skill 草稿提出修改意见时，THE SkillCreationAdapter SHALL 根据用户的自然语言反馈更新草稿内容，并重新呈现修改后的版本，每次修改不超过 5 秒响应。
5. IF 用户在 Dialog_Session 进行中退出，THEN THE SkillCreationAdapter SHALL 将当前对话进度保存为草稿状态，用户下次进入时可选择继续该草稿或放弃并重新开始。
6. WHEN 用户确认 Skill 草稿时，THE SkillCreationAdapter SHALL 调用 Skill_Library 的保存接口，执行结构验证后完成发布，发布成功后该 Skill 立即出现在用户的 Skill 列表中。
7. THE SkillCreationAdapter SHALL 在整个对话式创建流程中提供硬编码的引导问题序列作为兜底，当 AI 模型不可用时仍能通过固定问题引导用户完成 Skill 创建。

---

### 需求 10：生态接入层与现有架构的兼容性

**用户故事：** 作为开发者，我希望生态接入层在不破坏现有接口的前提下扩展系统能力，以便现有 Skill 和 Component 代码无需修改即可继续运行。

#### 验收标准

1. THE MCP_Client 和 MCP_Registry SHALL 作为 AgentKernel 的内部扩展存在，不修改 ComponentRegistry 和 ComponentInterface，两套调用路径（Component 和 MCP Tool）在 AgentKernel 内部路由，对 Skill 定义透明。
2. THE AI_Model_Adapter SHALL 实现现有 SkillParser 接口，SkillCreationAdapter 无需修改即可使用不同的 AI_Model_Adapter 实现。
3. THE Skill_Marketplace 的下载功能 SHALL 复用现有 Skill_Library 的 save/get/list/delete 接口，不引入新的本地存储层。
4. IF 生态接入层的任意组件初始化失败（MCP_Server 连接失败、AI 模型不可用、Skill 市场网络不可达等），THEN THE Learning_OS SHALL 降级运行，现有内置 Component 和内置 Skill 的功能不受影响。
5. WHEN MCP_Registry 向 AgentKernel 注册新工具时，THE AgentKernel SHALL 不需要重启即可感知新工具，已在执行中的 Skill 不受影响。
6. THE Skill_Marketplace 的云端 API SHALL 与现有后端（FastAPI）部署在同一服务中，通过 `/api/marketplace/` 前缀路由，不引入独立的云端服务。
