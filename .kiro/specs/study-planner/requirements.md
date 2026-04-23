# 需求文档：大型学习规划（Study Planner）

## 简介

Study Planner 是学习助手 App 的大型学习规划功能，基于 Multi-Agent 架构，融合**自由学习、系统规划、引导学习**三种模式，帮助用户制定跨学科、有截止时间约束的结构化学习计划。

**核心触发路径**：用户在答疑室（`/`）自由对话 → `RuleBasedIntentDetector` 识别到长远规划意图 → 对话流中插入 `SceneCard`（spec 类型）→ 用户确认启动 → 跳转 `/spec` → Multi-Agent 系统（助教收集目标 → 各科老师并行分析 → 教务排期生成计划表）→ 计划表驱动引导学习，答疑室首页出现今日任务入口，用户随时可回到自由对话。

**三种模式融合原则**：
- 自由学习是默认状态，任何时候都可以在答疑室随意提问
- 系统规划由助教在对话中识别触发，不强制，用户可选择「稍后再说」
- 引导学习是计划生成后的叠加层，以今日任务卡片形式出现，不替代自由对话
- 用户在自由对话中问到计划内的知识点时，助教静默同步进度，不打断对话

---

## 词汇表

- **Study_Planner**：本功能整体，协调各 Agent 完成规划生成与监控
- **Assistant_Agent（助教）**：原「同桌」，负责多轮对话收集目标、意图识别、Level 1/2 监控、今日任务推送
- **Subject_Agent（各科老师）**：读取节点状态、筛选未掌握节点、标注学习参数
- **Academic_Agent（教务）**：原「班主任」，聚合各科输出、排期生成计划表、持久化、监控协调
- **Principal_Agent（校长）**：战略层，本次不新增逻辑，仅占位
- **Spec_Page**：前端 `/spec` 路由对应的规划页（`lib/features/spec/spec_page.dart`），含三阶段视图
- **RuleBasedIntentDetector**：已实现的本地规则意图识别器（`lib/services/intent_detector.dart`）
- **SceneCard**：已实现的场景识别卡片组件（`lib/widgets/scene_card.dart`），在对话流中插入引导卡片
- **TodayTaskCard**：今日任务浮层卡片，在答疑室首页展示当日计划条目，引导进入对应学科对话
- **mindmap_node_states**：后端数据库表，存储用户各思维导图节点的点亮状态（is_lit）
- **TreeNode**：思维导图中的原子知识点节点，对应一个学习单元（15–45 分钟）
- **study_plan**：后端数据库表，存储一次规划的元信息
- **plan_items**：后端数据库表，存储规划中每个学习条目
- **Level_1_Monitor**：前端本地静默行为埋点，存储于 SharedPreferences，不上报后端
- **Level_2_Monitor**：App 内助教气泡提示，触发后调用 companion_observe 端点生成文案
- **Level_3_Monitor**：推送通知占位接口，本次不实现
- **litNode**：mindmap_node_states 中 is_lit = 1 的节点，视为已掌握，跳过规划
- **unlitNode**：mindmap_node_states 中 is_lit = 0 或无记录的节点，视为未掌握，纳入规划
- **R**：已重构的路由常量类（`lib/routes/app_router.dart`），`R.spec = '/spec'`

---

## 需求列表

---

### 需求 1：Spec 意图识别与入口触发

**用户故事：** 作为学生，我希望在答疑室自由对话时，系统能自动识别我的长远规划意图并引导我进入规划模式，而不需要手动找入口。

#### 验收标准

1. WHEN 用户在答疑室（`/`）发送消息，THE `RuleBasedIntentDetector` SHALL 检测消息是否包含 spec 关键词（系统学习、完整计划、从零开始、全面掌握、系统掌握、完整课程）。
2. WHEN spec 意图被识别，THE `ChatPage` SHALL 在对话流中插入一条 `SceneCard`（`SceneType.spec`），显示标题「检测到大型学习任务」、副标题「启动 Spec 规划模式，助教将协调各科老师为你制定系统计划」、确认按钮「启动规划」、取消按钮「继续自由对话」。
3. WHEN 用户点击「启动规划」，THE `ChatPage` SHALL 调用 `context.push(R.spec)` 跳转至 `/spec`，同时将当前对话中已识别的学科信息作为参数传入。
4. WHEN 用户点击「继续自由对话」，THE SceneCard SHALL 标记为 dismissed，对话继续正常进行，助教不再重复触发同一条消息的 spec 识别。
5. THE spec 意图识别 SHALL 仅在通用对话（`widget.subjectId == null && widget.taskId == null`）中触发，学科专属对话和任务对话中不触发。
6. IF 用户已有 active 状态的 study_plan，THEN THE SceneCard 确认按钮文案 SHALL 改为「查看当前计划」，点击后跳转至 `/spec` 直接展示计划表视图。

---

### 需求 2：助教多轮对话收集规划目标

**用户故事：** 作为学生，我希望通过与助教的自然对话说明我的学习目标，以便系统能理解我的需求并启动规划流程，而不需要填写复杂的表单。

#### 验收标准

1. WHEN 用户进入 `/spec` 页面且无 active 计划，THE Spec_Page SHALL 进入对话收集阶段，展示助教对话气泡列表和底部输入框，交互样式与 `ChatPage` 保持一致。
2. WHEN 对话收集阶段开始，THE Assistant_Agent SHALL 主动发送第一条消息，基于从答疑室传入的上下文（如已识别的学科）直接确认，而非从零开始询问。
3. THE Assistant_Agent SHALL 通过多轮对话依次收集：目标学科列表、复习截止时间、每日可用学习时长（分钟）。
4. THE Assistant_Agent SHALL 在每轮对话中仅追问一个维度的信息，不得在单条消息中同时追问多个问题。
5. IF 用户未提供截止时间，THEN THE Assistant_Agent SHALL 提示用户输入截止日期，并拒绝进入规划生成阶段。
6. IF 用户未提供每日可用时长，THEN THE Assistant_Agent SHALL 使用默认值 60 分钟/天，并在确认消息中告知用户。
7. WHEN 所有必要信息收集完毕，THE Assistant_Agent SHALL 向用户展示收集摘要（学科列表、截止时间、每日时长），并请求用户确认后再触发规划生成。
8. WHEN 用户确认规划信息，THE Spec_Page SHALL 切换至规划进度视图，显示各 Agent 的执行状态。

---

### 需求 3：各科老师 Agent 并行读取节点状态

**用户故事：** 作为系统，我希望各科老师 Agent 能并行读取用户的思维导图节点点亮状态，以便准确识别用户尚未掌握的知识点，避免重复规划已掌握内容。

#### 验收标准

1. WHEN 规划生成被触发，THE Study_Planner SHALL 为用户选定的每个学科并行启动一个 Subject_Agent 实例。
2. THE Subject_Agent SHALL 调用 `GET /api/council/subject/node-analysis` 端点，查询 mindmap_node_states 表，筛选出属于该学科且 is_lit = 0 或无记录的 unlitNode 列表。
3. THE Subject_Agent SHALL 跳过所有 litNode（is_lit = 1），不将已掌握节点纳入规划。
4. THE Subject_Agent SHALL 为每个 unlitNode 标注：预估学习时长（15–45 分钟/节点）、优先级（high/medium/low）、前置依赖节点列表。
5. THE Subject_Agent SHALL 在标注优先级时，将 `MemoryService` 中 `weak_points` 出现的节点优先级提升为 high。
6. IF 某学科在 mindmap_node_states 中无任何节点记录（`has_mindmap: false`），THEN THE Subject_Agent SHALL 将该学科标记为「无导图数据」，并在规划进度视图中提示用户先去「图书馆」生成该学科的思维导图。
7. WHEN 所有 Subject_Agent 完成节点分析，THE Study_Planner SHALL 将各科输出汇总后传递给 Academic_Agent。
8. THE Subject_Agent SHALL 在 30 秒内完成单学科节点分析；IF 超时，THEN THE Study_Planner SHALL 标记该学科为分析失败，并允许用户选择跳过或重试。

---

### 需求 4：教务 Agent 生成结构化计划表

**用户故事：** 作为学生，我希望教务 Agent 能将各科老师的分析结果整合成一份按日期排期的学习计划，以便我知道每天该学什么。

#### 验收标准

1. WHEN 教务 Agent 收到所有 Subject_Agent 的输出，THE Academic_Agent SHALL 根据截止时间和每日可用时长，将所有 unlitNode 排入日历时间槽。
2. THE Academic_Agent SHALL 在排期时遵守节点依赖关系，确保前置节点的学习日期早于后置节点。
3. THE Academic_Agent SHALL 在排期时均衡分配各学科的学习时间，避免单日内同一学科占用超过每日可用时长的 60%。
4. IF 所有 unlitNode 的总预估时长超过截止时间前的可用总时长，THEN THE Academic_Agent SHALL 优先排入 high 优先级节点，并在计划摘要中告知用户存在时间缺口及缺口时长。
5. WHEN 排期完成，THE Academic_Agent SHALL 将计划元信息持久化到 study_plan 表，将每个计划条目持久化到 plan_items 表。
6. THE study_plan 表 SHALL 存储：用户 ID、计划名称、目标学科列表（JSON）、截止时间、每日可用时长（分钟）、计划状态（draft/active/completed/abandoned）、创建时间、更新时间。
7. THE plan_items 表 SHALL 存储：计划 ID、学科 ID、节点 ID（node_id）、节点文本、预估时长（分钟）、优先级、依赖节点 ID 列表（JSON）、计划日期、完成状态（pending/done/skipped）、实际完成时间。
8. WHEN 计划持久化成功，THE Spec_Page SHALL 切换至计划表视图，展示按日期分组的学习条目列表。

---

### 需求 5：Spec 规划页三阶段视图

**用户故事：** 作为学生，我希望 `/spec` 页面提供清晰的三阶段视图，以便我能跟踪规划进度并查看最终计划。

#### 验收标准

1. THE Spec_Page（`lib/features/spec/spec_page.dart`）SHALL 包含三个顺序阶段：对话收集视图 → 规划进度视图 → 计划表视图，阶段间单向流转，不可回退。
2. WHILE 处于对话收集视图，THE Spec_Page SHALL 复用 `ChatPage` 的气泡列表和 `_InputBar` 组件，保持视觉一致性。
3. WHILE 处于规划进度视图，THE Spec_Page SHALL 为每个参与规划的学科显示状态卡片，状态包括：等待中、分析中、已完成、失败（含重试按钮）。
4. WHILE 处于规划进度视图，THE Spec_Page SHALL 显示整体进度条，反映已完成 Subject_Agent 数量占总数的百分比。
5. WHILE 处于计划表视图，THE Spec_Page SHALL 按日期分组展示 plan_items，每个条目显示：节点文本、所属学科、预估时长、优先级标签、完成状态。
6. WHILE 处于计划表视图，THE Spec_Page SHALL 支持用户将单个 plan_item 标记为「已完成」或「跳过」，并实时调用 `PATCH /api/study-planner/plans/{plan_id}/items/{item_id}` 更新后端状态。
7. WHERE 用户已有 active 状态的 study_plan，THE Spec_Page SHALL 在进入 `/spec` 时直接展示计划表视图，跳过对话收集阶段。
8. THE Spec_Page SHALL 在计划表视图顶部展示计划摘要：总节点数、已完成节点数、距截止时间剩余天数、今日计划完成率。
9. THE Spec_Page 的视觉风格 SHALL 与 `ToolkitPage` 保持一致，使用 `AppColors` 主题色和圆角卡片设计。

---

### 需求 6：引导学习——今日任务卡片

**用户故事：** 作为学生，我希望在答疑室首页看到今日的学习任务，以便在自由对话的同时不忘系统计划，随时可以一键进入对应知识点的学习。

#### 验收标准

1. WHEN 用户有 active 状态的 study_plan 且今日有 pending 状态的 plan_items，THE 答疑室首页（`ChatPage` 空状态区域）SHALL 在默认提示词上方展示 `TodayTaskCard`，显示今日任务数量和完成率。
2. THE `TodayTaskCard` SHALL 展示今日前 3 条 pending plan_items，每条显示：节点文本、所属学科色标、预估时长。
3. WHEN 用户点击 `TodayTaskCard` 中的某条任务，THE `ChatPage` SHALL 跳转至对应学科的专属对话（`/chat/:chatId/subject/:subjectId`），并在对话中预填入该节点文本作为学习起点。
4. WHEN 用户在学科专属对话中完成学习并手动标记节点为已学（mindmap_node_states 更新），THE Study_Planner SHALL 自动将对应 plan_item 状态更新为 done，无需用户在 Spec_Page 重复操作。
5. WHEN 今日所有 plan_items 均为 done 或 skipped，THE `TodayTaskCard` SHALL 显示完成祝贺状态，不再展示任务列表。
6. THE `TodayTaskCard` SHALL 提供「查看完整计划」入口，点击跳转至 `/spec` 计划表视图。
7. IF 用户关闭 `TodayTaskCard`，THE 卡片 SHALL 在当日内不再自动展示，但「查看完整计划」入口仍可通过 `/spec` 访问。

---

### 需求 7：自由学习与计划进度的静默同步

**用户故事：** 作为学生，我希望在答疑室自由提问时，系统能自动识别我学习的知识点并同步到计划进度，而不需要我手动在两个地方分别标记。

#### 验收标准

1. WHEN 用户在学科专属对话中将某个思维导图节点标记为已学（mindmap_node_states 中 is_lit 更新为 1），THE Study_Planner SHALL 检查该节点是否存在于 active study_plan 的 plan_items 中。
2. IF 该节点存在于 plan_items 中且状态为 pending，THEN THE Study_Planner SHALL 自动将该 plan_item 状态更新为 done，并记录实际完成时间。
3. THE 静默同步 SHALL 不向用户展示任何弹窗或提示，仅在后台静默执行，不打断当前对话。
4. WHEN 静默同步导致今日计划完成率达到 100%，THE Assistant_Agent SHALL 在当前对话中插入一条助教气泡，显示今日任务完成的祝贺文案。
5. THE 静默同步 SHALL 仅在用户有 active study_plan 时生效，无计划时不执行任何同步逻辑。

---

### 需求 8：Level 1 本地行为埋点监控

**用户故事：** 作为系统，我希望在前端静默记录用户的学习行为数据，以便为 Level 2 监控提供触发依据，同时不干扰用户体验。

#### 验收标准

1. THE Level_1_Monitor SHALL 在前端本地记录以下行为事件：Spec_Page 停留时长（秒）、plan_item 节点点击次数、节点点击后未标记完成的次数。
2. THE Level_1_Monitor SHALL 将行为数据存储于设备本地 SharedPreferences（复用现有 `sharedPreferencesProvider`），不向后端上报任何数据。
3. THE Level_1_Monitor SHALL 每次 App 启动时重置当日行为计数，保留历史数据不超过 7 天。
4. THE Level_1_Monitor SHALL 在每次行为事件发生后，同步计算今日计划完成率（已完成 plan_items 数 / 今日计划 plan_items 总数），并将结果写入 SharedPreferences。
5. THE Level_1_Monitor SHALL 记录用户在 App 内活跃但无学习行为（无节点点击、无对话输入）的连续时长（分钟），并将结果写入 SharedPreferences。

---

### 需求 9：Level 2 助教气泡提示监控

**用户故事：** 作为学生，我希望当我的学习状态出现异常时，助教能以气泡形式友好地提醒我，以便我及时调整学习节奏。

#### 验收标准

1. WHEN 今日计划完成率低于 50% 且当前时间已过今日计划结束时间，THE Level_2_Monitor SHALL 触发助教气泡提示。
2. WHEN 用户在 App 内活跃但无学习行为的连续时长超过 15 分钟，THE Level_2_Monitor SHALL 触发助教气泡提示。
3. WHEN Level_2_Monitor 触发，THE Assistant_Agent SHALL 调用现有 `POST /api/council/companion/observe` 端点，传入当前行为数据，获取 AI 生成的提示文案。
4. THE Level_2_Monitor SHALL 将助教气泡渲染为浮层组件，显示在当前页面右下角，包含助教头像、提示文案、关闭按钮，视觉风格与 `SceneCard` 保持一致。
5. THE Level_2_Monitor SHALL 在同一触发条件下，每 30 分钟内最多触发一次气泡提示，避免频繁打扰用户。
6. IF companion_observe 端点调用失败，THEN THE Level_2_Monitor SHALL 展示本地兜底文案（如「今天的计划还没完成，要继续加油哦～」），不阻塞用户操作。
7. THE Level_2_Monitor SHALL 仅在用户已有 active 状态的 study_plan 时生效，无计划时不触发任何气泡提示。

---

### 需求 10：Level 3 推送通知占位接口

**用户故事：** 作为系统，我希望预留推送通知的接口骨架，以便后续版本可以扩展 App 外的学习提醒能力。

#### 验收标准

1. THE Study_Planner 后端 SHALL 提供 `POST /api/study-planner/notify/register` 占位端点，当前实现仅返回 `{"status": "not_implemented"}`，不执行任何推送逻辑。
2. THE Study_Planner 后端 SHALL 提供 `POST /api/study-planner/notify/send` 占位端点，当前实现仅返回 `{"status": "not_implemented"}`，不执行任何推送逻辑。
3. THE Level_3_Monitor 占位接口 SHALL 不影响 Level 1 和 Level 2 监控的正常运行。

---

### 需求 11：计划状态管理与生命周期

**用户故事：** 作为学生，我希望系统能管理我的学习计划状态，以便我可以放弃计划或完成计划，而不会丢失历史数据。

#### 验收标准

1. THE study_plan SHALL 支持以下状态流转：draft → active（用户确认计划后）、active → completed（所有 plan_items 均为 done 或 skipped）、active → abandoned（用户主动放弃）。
2. WHEN 用户在计划表视图点击「放弃计划」，THE Spec_Page SHALL 弹出二次确认对话框，确认后调用 `PATCH /api/study-planner/plans/{plan_id}/status` 将状态更新为 abandoned。
3. THE Study_Planner SHALL 保证同一用户同一时刻最多只有一个 active 状态的 study_plan；IF 用户尝试创建新计划时已有 active 计划，THEN THE Spec_Page SHALL 提示用户先完成或放弃当前计划。
4. WHEN study_plan 状态变更为 completed，THE Academic_Agent SHALL 通过 companion_observe 端点生成完成祝贺文案，并在 Spec_Page 展示助教气泡庆祝提示。
5. THE Study_Planner SHALL 为每个 study_plan 保留完整的 plan_items 历史记录，即使计划状态为 completed 或 abandoned，数据不得删除。

---

### 需求 12：后端 API 端点

**用户故事：** 作为前端，我希望后端提供完整的 Study Planner REST API，以便前端能够创建、查询和更新学习计划。

#### 验收标准

1. THE Study_Planner 后端 SHALL 提供 `POST /api/study-planner/plans` 端点，接受目标学科列表、截止时间、每日可用时长，触发 Multi-Agent 规划流程，返回新建的 study_plan 对象（含 plan_id）。
2. THE Study_Planner 后端 SHALL 提供 `GET /api/study-planner/plans/active` 端点，返回当前用户的 active study_plan 及其所有 plan_items（按计划日期排序）。
3. THE Study_Planner 后端 SHALL 提供 `GET /api/study-planner/plans/today` 端点，返回今日的 plan_items 列表（含完成状态），供 `TodayTaskCard` 使用。
4. THE Study_Planner 后端 SHALL 提供 `PATCH /api/study-planner/plans/{plan_id}/items/{item_id}` 端点，接受 `status`（done/skipped）字段，更新单个 plan_item 的完成状态。
5. THE Study_Planner 后端 SHALL 提供 `PATCH /api/study-planner/plans/{plan_id}/status` 端点，接受 `status`（abandoned）字段，更新 study_plan 状态。
6. THE Study_Planner 后端 SHALL 提供 `GET /api/study-planner/plans/{plan_id}/summary` 端点，返回计划摘要：总节点数、已完成数、今日计划条目列表、今日完成率、距截止时间剩余天数。
7. WHEN `POST /api/study-planner/plans` 被调用，THE Study_Planner 后端 SHALL 在 60 秒内完成 Multi-Agent 规划流程并返回响应；IF 超时，THEN 后端 SHALL 返回 HTTP 202 Accepted，并提供 `GET /api/study-planner/plans/{plan_id}/progress` 轮询端点供前端查询规划进度。
8. THE Study_Planner 后端 SHALL 对所有端点进行用户身份验证（复用现有 `get_current_user` 依赖），未认证请求 SHALL 返回 HTTP 401。

---

### 需求 13：各科老师节点分析端点

**用户故事：** 作为系统，我希望后端提供节点分析端点，使各科老师 Agent 能读取思维导图节点状态并标注学习参数。

#### 验收标准

1. THE Study_Planner 后端 SHALL 新增 `GET /api/council/subject/node-analysis` 端点，接受 `subject_id` 参数，查询 mindmap_node_states 表，返回该学科下所有 unlitNode 列表（含 node_id、节点文本、depth、parent_id）。
2. THE 端点 SHALL 在返回的 unlitNode 列表中，为每个节点附加 AI 标注的预估学习时长（15–45 分钟）和优先级（high/medium/low）。
3. IF mindmap_node_states 表中该学科无任何节点记录，THEN THE 端点 SHALL 返回空列表，并在响应中附加 `"has_mindmap": false` 标志。
4. THE 端点 SHALL 复用现有 `MemoryService` 中的 `weak_points` 数据，将 weak_points 中出现的节点优先级提升为 high。
5. THE 端点 SHALL 复用现有 `get_current_user` 依赖进行身份验证，仅返回当前用户的节点状态数据。
