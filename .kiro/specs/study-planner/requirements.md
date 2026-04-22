# 需求文档：大型学习规划（Study Planner）

## 简介

Study Planner 是学习助手 App 的大型学习规划功能，基于 Multi-Agent 架构，帮助用户制定跨学科、有截止时间约束的结构化学习计划。

整体流程：用户在 `/spec` 路由的 Spec 规划页与同桌 Agent 进行多轮对话，收集学习目标；各科老师 Agent 并行读取思维导图节点点亮状态，筛选未掌握知识点并标注优先级；班主任 Agent 聚合各科输出，生成结构化计划表并持久化到数据库；同桌 Agent 兼任监控角色，在用户学习过程中提供两级行为监控与气泡提示。

---

## 词汇表

- **Study_Planner**：本功能整体，负责协调各 Agent 完成规划生成与监控
- **Companion_Agent**：同桌 Agent，负责多轮对话收集目标，以及 Level 1/2 监控
- **Subject_Agent**：各科老师 Agent，负责读取节点状态、筛选未掌握节点、标注学习参数
- **Advisor_Agent**：班主任 Agent，负责聚合各科输出、排期生成计划表、持久化、监控协调
- **Principal_Agent**：校长 Agent，战略层，本次不新增逻辑，仅占位
- **Spec_Page**：前端 `/spec` 路由对应的规划页，包含对话收集、规划进度、计划表三个视图阶段
- **mindmap_node_states**：后端数据库表，存储用户各思维导图节点的点亮状态（is_lit）
- **TreeNode**：思维导图中的原子知识点节点，对应一个学习单元
- **study_plan**：后端数据库表，存储一次规划的元信息（目标、截止时间、状态）
- **plan_items**：后端数据库表，存储规划中每个学习条目（节点、学科、时间、优先级、依赖）
- **Level_1_Monitor**：前端本地静默行为埋点，存储于 SharedPreferences，不上报后端
- **Level_2_Monitor**：App 内同桌气泡提示，触发后调用 companion_observe 端点生成文案
- **Level_3_Monitor**：推送通知占位接口，本次不实现
- **litNode**：mindmap_node_states 中 is_lit = 1 的节点，视为已掌握，跳过规划
- **unlitNode**：mindmap_node_states 中 is_lit = 0 或不存在记录的节点，视为未掌握，纳入规划

---

## 需求列表

---

### 需求 1：同桌多轮对话收集规划目标

**用户故事：** 作为学生，我希望通过与同桌的自然对话说明我的学习目标，以便系统能理解我的需求并启动规划流程。

#### 验收标准

1. WHEN 用户在答疑室输入大型学习目标（如"帮我制定期末复习计划"），THE Spec_Page SHALL 在对话流中弹出 Spec 模式确认卡片，提示用户启动规划模式。
2. WHEN 用户确认启动规划模式，THE Spec_Page SHALL 路由跳转至 `/spec`，并进入同桌对话收集阶段。
3. WHEN 用户进入 `/spec` 页面，THE Companion_Agent SHALL 通过多轮对话依次收集以下信息：目标学科列表、复习截止时间、每日可用学习时长（分钟）。
4. THE Companion_Agent SHALL 在每轮对话中仅追问一个维度的信息，不得在单条消息中同时追问多个问题。
5. IF 用户未提供截止时间，THEN THE Companion_Agent SHALL 提示用户输入截止日期，并拒绝进入规划生成阶段。
6. IF 用户未提供每日可用时长，THEN THE Companion_Agent SHALL 使用默认值 60 分钟/天，并在确认消息中告知用户。
7. WHEN 所有必要信息收集完毕，THE Companion_Agent SHALL 向用户展示收集摘要（学科列表、截止时间、每日时长），并请求用户确认后再触发规划生成。
8. WHEN 用户确认规划信息，THE Spec_Page SHALL 切换至规划进度视图，显示各 Agent 的执行状态。

---

### 需求 2：各科老师 Agent 并行读取节点状态

**用户故事：** 作为系统，我希望各科老师 Agent 能并行读取用户的思维导图节点点亮状态，以便准确识别用户尚未掌握的知识点。

#### 验收标准

1. WHEN 规划生成被触发，THE Study_Planner SHALL 为用户选定的每个学科并行启动一个 Subject_Agent 实例。
2. THE Subject_Agent SHALL 查询 mindmap_node_states 表，筛选出属于该学科且 is_lit = 0 或无记录的 unlitNode 列表。
3. THE Subject_Agent SHALL 跳过所有 litNode（is_lit = 1），不将已掌握节点纳入规划。
4. THE Subject_Agent SHALL 为每个 unlitNode 标注以下属性：预估学习时长（15–45 分钟/节点）、优先级（高/中/低）、前置依赖节点列表。
5. IF 某学科在 mindmap_node_states 中无任何节点记录，THEN THE Subject_Agent SHALL 将该学科标记为"无节点数据"，并在规划进度视图中提示用户先生成该学科的思维导图。
6. WHEN 所有 Subject_Agent 完成节点分析，THE Study_Planner SHALL 将各科输出汇总后传递给 Advisor_Agent。
7. THE Subject_Agent SHALL 在 30 秒内完成单学科节点分析，IF 超时，THEN THE Study_Planner SHALL 标记该学科为分析失败，并允许用户选择跳过或重试。

---

### 需求 3：班主任 Agent 生成结构化计划表

**用户故事：** 作为学生，我希望班主任 Agent 能将各科老师的分析结果整合成一份按日期排期的学习计划，以便我知道每天该学什么。

#### 验收标准

1. WHEN 班主任 Agent 收到所有 Subject_Agent 的输出，THE Advisor_Agent SHALL 根据截止时间和每日可用时长，将所有 unlitNode 排入日历时间槽。
2. THE Advisor_Agent SHALL 在排期时遵守节点依赖关系，确保前置节点的学习日期早于后置节点。
3. THE Advisor_Agent SHALL 在排期时均衡分配各学科的学习时间，避免单日内同一学科占用超过每日可用时长的 60%。
4. IF 所有 unlitNode 的总预估时长超过截止时间前的可用总时长，THEN THE Advisor_Agent SHALL 优先排入高优先级节点，并在计划摘要中告知用户存在时间缺口及缺口时长。
5. WHEN 排期完成，THE Advisor_Agent SHALL 将计划元信息持久化到 study_plan 表，将每个计划条目持久化到 plan_items 表。
6. THE study_plan 表 SHALL 存储以下字段：用户 ID、计划名称、目标学科列表（JSON）、截止时间、每日可用时长、计划状态（draft/active/completed/abandoned）、创建时间、更新时间。
7. THE plan_items 表 SHALL 存储以下字段：计划 ID、学科 ID、节点 ID（node_id）、节点文本、预估时长（分钟）、优先级、依赖节点 ID 列表（JSON）、计划日期、完成状态（pending/done/skipped）、实际完成时间。
8. WHEN 计划持久化成功，THE Spec_Page SHALL 切换至计划表视图，展示按日期分组的学习条目列表。

---

### 需求 4：Spec 规划页前端视图

**用户故事：** 作为学生，我希望 `/spec` 页面提供清晰的三阶段视图，以便我能跟踪规划进度并查看最终计划。

#### 验收标准

1. THE Spec_Page SHALL 包含三个顺序阶段的视图：对话收集视图、规划进度视图、计划表视图，阶段间单向流转，不可回退。
2. WHILE 处于对话收集视图，THE Spec_Page SHALL 展示同桌对话气泡列表和底部输入框，交互样式与答疑室对话页保持一致。
3. WHILE 处于规划进度视图，THE Spec_Page SHALL 为每个参与规划的学科显示一个状态卡片，状态包括：等待中、分析中、已完成、失败。
4. WHILE 处于规划进度视图，THE Spec_Page SHALL 显示整体进度条，反映已完成 Subject_Agent 数量占总数的百分比。
5. WHILE 处于计划表视图，THE Spec_Page SHALL 按日期分组展示 plan_items，每个条目显示：节点文本、所属学科、预估时长、优先级、完成状态。
6. WHILE 处于计划表视图，THE Spec_Page SHALL 支持用户将单个 plan_item 标记为"已完成"或"跳过"，并实时更新后端 plan_items 表中的完成状态。
7. WHERE 用户已有 active 状态的 study_plan，THE Spec_Page SHALL 在进入 `/spec` 时直接展示计划表视图，而非重新进入对话收集阶段。
8. THE Spec_Page SHALL 在计划表视图顶部展示计划摘要：总节点数、已完成节点数、距截止时间剩余天数、今日计划完成率。

---

### 需求 5：Level 1 本地行为埋点监控

**用户故事：** 作为系统，我希望在前端静默记录用户的学习行为数据，以便为 Level 2 监控提供触发依据，同时不干扰用户体验。

#### 验收标准

1. THE Level_1_Monitor SHALL 在前端本地记录以下行为事件：Spec_Page 停留时长（秒）、plan_item 节点点击次数、节点点击后未点亮（is_lit 未变化）的次数。
2. THE Level_1_Monitor SHALL 将行为数据存储于设备本地 SharedPreferences，不向后端上报任何数据。
3. THE Level_1_Monitor SHALL 每次 App 启动时重置当日行为计数，保留历史数据不超过 7 天。
4. THE Level_1_Monitor SHALL 在每次行为事件发生后，同步计算今日计划完成率（已完成 plan_items 数 / 今日计划 plan_items 总数），并将结果写入 SharedPreferences。
5. THE Level_1_Monitor SHALL 记录用户在 App 内活跃但无学习行为（无节点点击、无对话输入）的连续时长（分钟），并将结果写入 SharedPreferences。

---

### 需求 6：Level 2 同桌气泡提示监控

**用户故事：** 作为学生，我希望当我的学习状态出现异常时，同桌能以气泡形式友好地提醒我，以便我及时调整学习节奏。

#### 验收标准

1. WHEN 今日计划完成率低于 50% 且当前时间已过今日计划结束时间，THE Level_2_Monitor SHALL 触发同桌气泡提示。
2. WHEN 用户在 App 内活跃但无学习行为的连续时长超过 15 分钟，THE Level_2_Monitor SHALL 触发同桌气泡提示。
3. WHEN Level_2_Monitor 触发，THE Companion_Agent SHALL 调用现有 `/api/council/companion/observe` 端点，传入当前行为数据，获取 AI 生成的提示文案。
4. THE Level_2_Monitor SHALL 将同桌气泡渲染为浮层气泡组件，显示在当前页面右下角，包含同桌头像、提示文案、关闭按钮。
5. THE Level_2_Monitor SHALL 在同一触发条件下，每 30 分钟内最多触发一次气泡提示，避免频繁打扰用户。
6. IF companion_observe 端点调用失败，THEN THE Level_2_Monitor SHALL 展示本地兜底文案（如"今天的计划还没完成，要继续加油哦～"），不阻塞用户操作。
7. THE Level_2_Monitor SHALL 仅在用户已有 active 状态的 study_plan 时生效，无计划时不触发任何气泡提示。

---

### 需求 7：Level 3 推送通知占位接口

**用户故事：** 作为系统，我希望预留推送通知的接口骨架，以便后续版本可以扩展 App 外的学习提醒能力。

#### 验收标准

1. THE Study_Planner SHALL 在后端提供 `/api/study-planner/notify/register` 占位端点，接受设备推送 token 注册请求，当前实现仅返回 `{"status": "not_implemented"}`，不执行任何推送逻辑。
2. THE Study_Planner SHALL 在后端提供 `/api/study-planner/notify/send` 占位端点，接受推送消息请求，当前实现仅返回 `{"status": "not_implemented"}`，不执行任何推送逻辑。
3. THE Level_3_Monitor 占位接口 SHALL 不影响 Level 1 和 Level 2 监控的正常运行。

---

### 需求 8：计划状态管理与生命周期

**用户故事：** 作为学生，我希望系统能管理我的学习计划状态，以便我可以暂停、重启或放弃计划，而不会丢失历史数据。

#### 验收标准

1. THE study_plan SHALL 支持以下状态流转：draft → active（用户确认计划后）、active → completed（所有 plan_items 均为 done 或 skipped）、active → abandoned（用户主动放弃）。
2. WHEN 用户在计划表视图点击"放弃计划"，THE Spec_Page SHALL 弹出二次确认对话框，确认后将 study_plan 状态更新为 abandoned。
3. THE Study_Planner SHALL 保证同一用户同一时刻最多只有一个 active 状态的 study_plan；IF 用户尝试创建新计划时已有 active 计划，THEN THE Spec_Page SHALL 提示用户先完成或放弃当前计划。
4. WHEN study_plan 状态变更为 completed，THE Advisor_Agent SHALL 通过 companion_observe 端点生成完成祝贺文案，并在 Spec_Page 展示同桌气泡庆祝提示。
5. THE Study_Planner SHALL 为每个 study_plan 保留完整的 plan_items 历史记录，即使计划状态为 completed 或 abandoned，数据不得删除。

---

### 需求 9：后端 API 端点

**用户故事：** 作为前端，我希望后端提供完整的 Study Planner REST API，以便前端能够创建、查询和更新学习计划。

#### 验收标准

1. THE Study_Planner 后端 SHALL 提供 `POST /api/study-planner/plans` 端点，接受目标学科列表、截止时间、每日可用时长，触发 Multi-Agent 规划流程，返回新建的 study_plan 对象（含 plan_id）。
2. THE Study_Planner 后端 SHALL 提供 `GET /api/study-planner/plans/active` 端点，返回当前用户的 active study_plan 及其所有 plan_items（按计划日期排序）。
3. THE Study_Planner 后端 SHALL 提供 `PATCH /api/study-planner/plans/{plan_id}/items/{item_id}` 端点，接受 `status`（done/skipped）字段，更新单个 plan_item 的完成状态。
4. THE Study_Planner 后端 SHALL 提供 `PATCH /api/study-planner/plans/{plan_id}/status` 端点，接受 `status`（abandoned）字段，更新 study_plan 状态。
5. THE Study_Planner 后端 SHALL 提供 `GET /api/study-planner/plans/{plan_id}/summary` 端点，返回计划摘要：总节点数、已完成数、今日计划条目列表、今日完成率、距截止时间剩余天数。
6. WHEN `POST /api/study-planner/plans` 被调用，THE Study_Planner 后端 SHALL 在 60 秒内完成 Multi-Agent 规划流程并返回响应；IF 超时，THEN 后端 SHALL 返回 HTTP 202 Accepted，并提供轮询端点供前端查询规划进度。
7. THE Study_Planner 后端 SHALL 对所有端点进行用户身份验证，未认证请求 SHALL 返回 HTTP 401。

---

### 需求 10：各科老师端点扩展（读取节点状态）

**用户故事：** 作为系统，我希望扩展现有的 `/api/council/subject/execute` 端点，使各科老师 Agent 能够读取思维导图节点状态，以便规划时使用真实的掌握情况数据。

#### 验收标准

1. THE Subject_Agent 后端端点 SHALL 新增 `GET /api/council/subject/node-analysis` 端点，接受 `subject_id` 和 `user_id` 参数，查询 mindmap_node_states 表，返回该学科下所有 unlitNode 的列表（含 node_id、节点文本、depth、parent_id）。
2. THE Subject_Agent 后端端点 SHALL 在返回的 unlitNode 列表中，为每个节点附加 AI 标注的预估学习时长（15–45 分钟）和优先级（high/medium/low）。
3. IF mindmap_node_states 表中该学科无任何节点记录，THEN THE Subject_Agent 后端端点 SHALL 返回空列表，并在响应中附加 `"has_mindmap": false` 标志。
4. THE Subject_Agent 后端端点 SHALL 复用现有 MemoryService 中的 weak_points 和 misconceptions 数据，在标注优先级时将 weak_points 中出现的节点优先级提升为 high。

