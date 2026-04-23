# 需求文档：受控动作空间（Controlled Action Space）框架

## 简介

受控动作空间（CAS）框架是学习助手 APP 的核心交互基础设施。其设计哲学来源于「崩铁帕姆一键配遗器」和「编程猫积木系统」：把系统所有合法行为预先枚举为一个有限、闭合、完备的集合，用户只能在这个集合内选择，系统永远不会因为用户输入而崩溃、报错或越界。

CAS 框架分三层：
- **Action 层**：枚举所有系统能力（make_quiz / make_plan / open_calendar 等），用户的任何输入最终都映射到这个集合内的某个 Action；
- **Param 层**：每个 Action 的参数类型只有 6 种（radio / checkbox / number / text / date / topic_tree），缺参时弹出补全卡片，永不越界；
- **Executor 层**：每个 Action 对应一个稳定的执行函数，必捕获异常、必返回固定结构、必有兜底响应。

LLM 在 CAS 框架中只承担一件事：把用户的自然语言输入映射到 Action + 参数，不生成逻辑，不执行逻辑。

---

## 词汇表

- **CAS_Framework**：受控动作空间框架，本文档描述的整体系统。
- **Action**：系统能力的最小可执行单元，由唯一 `action_id`（snake_case）标识，包含名称、描述、参数模式和执行器引用。
- **Action_Registry**：Action 的注册表，运行时唯一来源，后端以 YAML 文件定义，前端通过 API 同步。
- **Param_Schema**：单个 Action 的参数描述集合，每个参数有类型、标签、是否必填、默认值和校验规则。
- **Param_Type**：参数类型枚举，共 6 种：`radio`（单选）/ `checkbox`（多选）/ `number`（数字）/ `text`（文本）/ `date`（日期）/ `topic_tree`（知识点树）。
- **Param_Fill_Card**：当 Action 缺少必填参数时，前端弹出的参数补全卡片，每张卡片对应一个参数。
- **Intent_Mapper**：负责将用户自然语言输入映射到 Action + 参数的模块，后端由 LLM 驱动，前端有规则降级实现。
- **Executor**：Action 的执行函数，接收完整参数，返回固定结构的 `ActionResult`，必须捕获所有异常。
- **ActionResult**：Executor 的统一返回结构，包含 `success`、`action_id`、`data`、`error_code`、`error_message`、`fallback_used` 字段。
- **Fallback_Response**：当 Executor 执行失败时返回的兜底响应，保证前端永远收到合法的 `ActionResult`。
- **Dispatch_Pipeline**：从用户输入到 Action 执行的完整处理链路：输入 → Intent_Mapper → 参数校验 → Param_Fill_Card（可选）→ Executor → ActionResult → 前端渲染。
- **Rule_Mapper**：Intent_Mapper 的本地规则降级实现，不依赖 LLM，基于关键词匹配。
- **CAS_Router**：后端新增的 FastAPI 路由，挂载在 `/api/cas`，提供 Action 注册表查询和 Action 分发两个端点。

---

## 需求

### 需求 1：Action 注册表

**用户故事：** 作为开发者，我希望系统所有能力都以 Action 的形式注册在一个中央注册表中，以便在不修改主流程的情况下扩展新功能。

#### 验收标准

1. THE Action_Registry SHALL 以 YAML 文件形式定义所有 Action，每个 Action 包含 `action_id`、`name`、`description`、`param_schema`、`executor_ref` 五个字段。
2. THE Action_Registry SHALL 在后端服务启动时完成加载，加载失败时记录错误日志并以空注册表启动，不阻断服务启动。
3. WHEN 开发者新增一个 Action YAML 条目并重启服务，THE Action_Registry SHALL 自动包含该 Action，无需修改任何现有代码。
4. THE Action_Registry SHALL 提供按 `action_id` 精确查询单个 Action 的接口，查询不存在的 `action_id` 时返回 `None`，不抛出异常。
5. THE Action_Registry SHALL 提供列出所有已注册 Action 摘要（`action_id` + `name` + `description`）的接口，供 Intent_Mapper 构建提示词。
6. FOR ALL Action 定义，THE Action_Registry SHALL 校验每个 Action 的 `param_schema` 中所有参数类型均属于 6 种合法 Param_Type，校验失败的 Action 被跳过并记录警告日志。
7. THE CAS_Router SHALL 提供 `GET /api/cas/actions` 端点，返回所有已注册 Action 的摘要列表，供前端同步。

---

### 需求 2：参数模式（Param Schema）

**用户故事：** 作为系统设计者，我希望每个 Action 的参数类型被严格限定在 6 种之内，以便前端能够用统一的 UI 组件渲染任意 Action 的参数补全界面。

#### 验收标准

1. THE Param_Schema SHALL 支持且仅支持以下 6 种 Param_Type：`radio`、`checkbox`、`number`、`text`、`date`、`topic_tree`。
2. WHEN Param_Type 为 `radio` 或 `checkbox`，THE Param_Schema SHALL 包含 `options` 字段，`options` 为非空字符串列表。
3. WHEN Param_Type 为 `number`，THE Param_Schema SHALL 支持可选的 `min`、`max`、`step` 字段，前端渲染为数字步进器。
4. WHEN Param_Type 为 `date`，THE Param_Schema SHALL 支持可选的 `min_date`、`max_date` 字段，前端渲染为日期选择器。
5. WHEN Param_Type 为 `topic_tree`，THE Param_Schema SHALL 引用当前用户已有的知识点树，前端渲染为可折叠的多选树形列表。
6. WHEN Param_Type 为 `text`，THE Param_Schema SHALL 支持可选的 `max_length` 字段，默认值为 200。
7. FOR ALL Param_Schema 定义，THE CAS_Framework SHALL 拒绝接受任何不在上述 6 种类型之外的参数类型，并在 Action 加载时记录警告日志跳过该 Action。

---

### 需求 3：Intent Mapper（意图映射）

**用户故事：** 作为用户，我希望无论我用什么方式描述需求，系统都能把我的意图准确映射到一个合法的 Action，而不是返回错误或空白响应。

#### 验收标准

1. THE Intent_Mapper SHALL 接收用户自然语言输入，返回一个包含 `action_id` 和已提取参数的映射结果，映射结果中的 `action_id` 必须存在于 Action_Registry 中。
2. WHEN LLM 服务不可用，THE Intent_Mapper SHALL 自动降级为 Rule_Mapper，Rule_Mapper 基于关键词匹配返回映射结果，整个降级过程对用户透明。
3. WHEN LLM 返回的 `action_id` 不存在于 Action_Registry 中，THE Intent_Mapper SHALL 丢弃该结果并返回 `action_id` 为 `unknown_intent` 的兜底映射，不抛出异常。
4. WHEN LLM 返回格式无法解析为合法 JSON，THE Intent_Mapper SHALL 捕获解析异常，降级为 Rule_Mapper 重新映射，不向调用方传播异常。
5. THE Intent_Mapper SHALL 在映射结果中包含 `confidence` 字段（0.0–1.0），LLM 映射时由模型提供，Rule_Mapper 降级时固定为 0.5。
6. THE CAS_Router SHALL 提供 `POST /api/cas/dispatch` 端点，接收 `{ "text": string, "session_id": string? }` 请求体，调用 Intent_Mapper 并返回映射结果。
7. WHEN 用户输入为空字符串，THE CAS_Router SHALL 返回 HTTP 400，不调用 Intent_Mapper。

---

### 需求 4：参数补全卡片（Param Fill Card）

**用户故事：** 作为用户，当我的请求缺少必要参数时，我希望系统以友好的卡片形式引导我补全，而不是报错或静默失败。

#### 验收标准

1. WHEN Intent_Mapper 返回的映射结果中存在必填参数未被提取，THE CAS_Framework SHALL 触发 Param_Fill_Card 流程，不直接调用 Executor。
2. THE Param_Fill_Card SHALL 每次只展示一个未填参数，按 Param_Schema 中参数的定义顺序依次展示，直到所有必填参数补全。
3. WHEN Param_Type 为 `radio`，THE Param_Fill_Card SHALL 渲染为单选按钮组，用户只能选择 `options` 中的值，不能自由输入。
4. WHEN Param_Type 为 `checkbox`，THE Param_Fill_Card SHALL 渲染为多选复选框组，用户只能选择 `options` 中的值，不能自由输入。
5. WHEN Param_Type 为 `number`，THE Param_Fill_Card SHALL 渲染为带加减按钮的数字步进器，输入值被限制在 `min`–`max` 范围内。
6. WHEN Param_Type 为 `date`，THE Param_Fill_Card SHALL 渲染为日历日期选择器，可选日期范围由 `min_date`、`max_date` 限定。
7. WHEN Param_Type 为 `topic_tree`，THE Param_Fill_Card SHALL 渲染为可折叠的知识点多选树，树数据来自当前用户的学科知识点。
8. WHEN Param_Type 为 `text`，THE Param_Fill_Card SHALL 渲染为单行或多行文本输入框，输入长度不超过 `max_length`。
9. WHEN 用户完成所有必填参数的补全，THE Param_Fill_Card SHALL 自动关闭并触发 Executor 执行，无需用户额外确认。
10. IF 用户关闭 Param_Fill_Card 而未完成补全，THEN THE CAS_Framework SHALL 取消本次 Action 执行，在对话流中显示「已取消」提示消息，不报错。

---

### 需求 5：Executor 层（执行器）

**用户故事：** 作为系统设计者，我希望每个 Action 的执行逻辑被封装在独立的 Executor 函数中，并且无论发生什么异常，Executor 都能返回一个合法的结构化结果。

#### 验收标准

1. THE Executor SHALL 接收完整的参数字典，返回 `ActionResult` 结构，`ActionResult` 包含 `success`（bool）、`action_id`（str）、`data`（dict）、`error_code`（str?）、`error_message`（str?）、`fallback_used`（bool）六个字段。
2. THE Executor SHALL 捕获所有异常（包括网络超时、数据库错误、LLM 服务不可用），在捕获异常时返回 `success=False` 的 `ActionResult`，不向调用方传播异常。
3. WHEN Executor 执行失败，THE Executor SHALL 返回包含 `fallback_used=True` 的 Fallback_Response，`data` 字段包含对用户友好的兜底文本。
4. THE Executor SHALL 在 `ActionResult.data` 中包含 `render_type` 字段，取值为 `text`、`card`、`navigate`、`modal` 之一，前端根据此字段决定渲染方式。
5. FOR ALL Executor 实现，THE CAS_Framework SHALL 保证每个 `action_id` 有且仅有一个对应的 Executor，`executor_ref` 字段在 Action YAML 中指定。
6. WHEN 新增 Action 时，IF 对应的 Executor 函数不存在，THEN THE Action_Registry SHALL 在加载时记录错误日志并跳过该 Action，不影响其他 Action 的正常加载。

---

### 需求 6：Dispatch Pipeline（分发管道）

**用户故事：** 作为用户，我希望从输入到得到响应的整个过程是流畅且可预期的，任何环节的失败都不会导致 APP 崩溃或白屏。

#### 验收标准

1. THE Dispatch_Pipeline SHALL 按以下顺序处理用户输入：用户输入 → Intent_Mapper → 参数完整性校验 → （缺参时）Param_Fill_Card → Executor → ActionResult → 前端渲染。
2. WHEN Dispatch_Pipeline 中任意环节抛出未捕获异常，THE CAS_Framework SHALL 捕获该异常，返回 `action_id` 为 `system_error` 的 Fallback_Response，在对话流中显示「系统繁忙，请稍后再试」。
3. THE Dispatch_Pipeline SHALL 在 3 秒内完成 Intent_Mapper 阶段（不含 Param_Fill_Card 用户交互时间），超时时自动降级为 Rule_Mapper。
4. WHEN ActionResult 的 `render_type` 为 `navigate`，THE CAS_Framework SHALL 触发前端路由跳转，跳转目标路径由 `ActionResult.data.route` 指定，路径必须存在于 `AppRoutes` 中。
5. WHEN ActionResult 的 `render_type` 为 `modal`，THE CAS_Framework SHALL 以底部弹出层（Bottom Sheet）形式展示 `ActionResult.data.content`。
6. WHEN ActionResult 的 `render_type` 为 `card`，THE CAS_Framework SHALL 在对话流中插入一条结构化卡片消息，卡片内容由 `ActionResult.data` 渲染。
7. WHEN ActionResult 的 `render_type` 为 `text`，THE CAS_Framework SHALL 在对话流中插入一条普通文本消息，内容为 `ActionResult.data.text`。
8. THE Dispatch_Pipeline SHALL 保证后端 `POST /api/cas/dispatch` 端点在任何情况下均返回 HTTP 200，错误信息通过 `ActionResult` 的 `success=False` 字段传递，不返回 HTTP 4xx/5xx（用户输入为空除外）。

---

### 需求 7：内置 Action 集合

**用户故事：** 作为用户，我希望系统预置一组覆盖常见学习场景的 Action，让我开箱即用，无需手动配置。

#### 验收标准

1. THE Action_Registry SHALL 预置以下 Action：`make_quiz`（出题）、`make_plan`（生成学习计划）、`open_calendar`（打开日历）、`add_calendar_event`（添加日历事件）、`recommend_mistake_practice`（推荐错题练习）、`open_notebook`（打开笔记本）、`explain_concept`（解释概念）、`solve_problem`（解题）、`unknown_intent`（兜底 Action）。
2. THE Action `unknown_intent` SHALL 不包含任何必填参数，其 Executor 返回引导用户澄清意图的文本消息，`render_type` 为 `text`。
3. WHEN 用户请求出题（`make_quiz`），THE Param_Schema SHALL 要求用户通过 Param_Fill_Card 补全以下参数：`subject`（radio，从用户已有学科中选择）、`question_type`（checkbox，选项为「选择题/填空题/解答题」）、`count`（number，范围 1–20）。
4. WHEN 用户请求生成学习计划（`make_plan`），THE Param_Schema SHALL 要求用户补全：`subject`（radio）、`exam_date`（date）、`daily_hours`（number，范围 0.5–8，步长 0.5）。
5. WHEN 用户请求添加日历事件（`add_calendar_event`），THE Param_Schema SHALL 要求用户补全：`title`（text，max_length=50）、`date`（date）。
6. WHEN 用户请求推荐错题练习（`recommend_mistake_practice`），THE Param_Schema SHALL 要求用户补全：`subject`（radio）、`topic`（topic_tree，从该学科知识点树中选择）。

---

### 需求 8：前端 CAS 集成

**用户故事：** 作为前端开发者，我希望 CAS 框架以 Provider + Widget 的形式无缝集成到现有 Flutter + Riverpod 架构中，不破坏现有的 ChatPage 和 SceneCard 逻辑。

#### 验收标准

1. THE CAS_Framework SHALL 提供 `CasDispatchProvider`（Riverpod StateNotifierProvider），封装 `POST /api/cas/dispatch` 的调用，状态包含 `isLoading`、`lastResult`、`pendingParams` 三个字段。
2. WHEN `CasDispatchProvider.pendingParams` 非空，THE CAS_Framework SHALL 在对话流中自动插入 `Param_Fill_Card` Widget，阻止用户发送新消息直到参数补全或取消。
3. THE `Param_Fill_Card` Widget SHALL 复用现有 `SceneCard` 的视觉样式（圆角卡片、主题色按钮），保持 UI 一致性。
4. THE CAS_Framework SHALL 在现有 `IntentDetector` 之上新增 `CasIntentDetector`，优先调用后端 `/api/cas/dispatch`，后端不可用时降级为现有 `RuleBasedIntentDetector`。
5. WHEN `CasIntentDetector` 降级为 `RuleBasedIntentDetector`，THE CAS_Framework SHALL 将规则匹配结果转换为合法的 `ActionResult` 结构，保持下游处理逻辑不变。
6. THE CAS_Framework SHALL 不修改现有 `ChatPage`、`SceneCard`、`chatProvider` 的公开接口，新增逻辑通过组合而非修改实现。

---

### 需求 9：错误隔离与兜底

**用户故事：** 作为用户，我希望无论发生什么错误，APP 都不会崩溃、不会白屏、不会显示技术性错误信息。

#### 验收标准

1. THE CAS_Framework SHALL 保证前端在任何情况下都能收到合法的 `ActionResult` 结构，不存在 `null` 返回值或未处理异常传播到 UI 层的情况。
2. IF 后端返回 HTTP 5xx，THEN THE CAS_Framework SHALL 在前端捕获该错误，构造 `success=False`、`fallback_used=True` 的本地 `ActionResult`，在对话流中显示「服务暂时不可用，请稍后再试」。
3. IF 后端返回的 `ActionResult` 缺少必要字段，THEN THE CAS_Framework SHALL 用默认值填充缺失字段，不抛出解析异常。
4. THE Executor SHALL 为每个 Action 定义 `fallback_text` 字段，当 Executor 执行失败时，`Fallback_Response.data.text` 使用该字段的值。
5. WHEN 网络请求超时（超过 10 秒），THE CAS_Framework SHALL 取消请求，返回本地构造的 Fallback_Response，超时阈值可通过配置文件调整。
6. THE CAS_Framework SHALL 在后端记录每次 Dispatch_Pipeline 的执行日志，包含 `action_id`、`success`、`duration_ms`、`fallback_used`、`error_code` 字段，日志保留最近 1000 条。

---

### 需求 10：可扩展性

**用户故事：** 作为开发者，我希望新增一个 Action 只需要三步：写 YAML 定义、写 Executor 函数、重启服务，不需要修改任何现有代码。

#### 验收标准

1. THE Action_Registry SHALL 支持通过新增 YAML 条目注册新 Action，新 Action 在服务重启后自动生效，无需修改 `CAS_Router`、`Intent_Mapper`、`Dispatch_Pipeline` 的任何现有代码。
2. THE CAS_Framework SHALL 提供 Executor 注册装饰器（Python `@register_executor("action_id")`），开发者只需在新 Executor 函数上添加该装饰器即可完成注册。
3. WHEN 新增 Action 的 `param_schema` 只使用已有的 6 种 Param_Type，THE CAS_Framework SHALL 自动为该 Action 生成对应的 Param_Fill_Card UI，无需编写任何前端代码。
4. THE Action_Registry SHALL 支持 Action 版本字段（`version`，语义化版本号），同名 Action 的新版本注册时，旧版本被替换，版本变更记录在启动日志中。
