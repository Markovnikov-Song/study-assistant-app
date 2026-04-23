# 需求文档：学习日历（Calendar Planner）

## 简介

Calendar Planner 是学习助手 App 工具箱（`/toolkit`）中的独立日程管理 miniapp，融合以下参考来源的核心优点：

- **[flutter_planner](https://github.com/IvanHerreraCasas/flutter_planner)**：事件/例程/任务三类型分离的数据模型，时间轴视图架构
- **[timetable](https://github.com/JonasWanke/timetable)**：拖拽移动事件、时间段遮罩、动画切换的日/周视图
- **[study_calendar](https://github.com/chuckinSpace/study_calendar)**：根据目标自动生成学习 session 的核心思路
- **Studyplus**：学习时长可视化、学科占比图表、打卡正向反馈
- **School Planner**：学科颜色编码，日历一眼识别学科分布
- **Notion Exam Planner**：Pomodoro 计时器内嵌任务，完成番茄钟自动更新进度

**双模式唤起**：
- 用户主动模式：工具箱 → 「学习日历」→ `/toolkit/calendar` 全屏
- Agent 场景化模式：对话识别到日程需求 → 半屏弹窗唤起，关闭后回到原对话

**生态融合定位**：日历是整个学习闭环的执行层。study-planner 生成的计划、思维导图节点学习、错题订正、讲义学习等任务均可写入日历；日历的完成打卡通过 EventBus 反向同步到各模块进度。

---

## 技术选型

| 依赖库 | 版本 | 用途 |
|--------|------|------|
| `table_calendar` | ^3.2.0 | 月视图底座，事件标记点，考试倒计时高亮 |
| `timetable` | latest | 日/周时间轴视图，拖拽移动，时间遮罩 |
| `flutter_local_notifications` | latest | 本地提醒通知（参考 flutter_planner） |

> 用 `timetable` 替代 `calendar_view`，拖拽和时间遮罩能力更强。

---

## 词汇表

- **CalendarEvent**：单次学习事件（一次性，有具体日期和时间）
- **CalendarRoutine**：重复例程（每日背单词、每周模考等，独立存储，参考 flutter_planner 的 routines 表）
- **CalendarTask**：轻量待办任务（无具体时间，只有截止日期）
- **CountdownEvent**：考试/重要日期倒计时，在月视图高亮，顶部横幅展示剩余天数
- **StudySession**：一次实际学习记录，记录开始时间、结束时间、实际学习时长（区别于预估时长）
- **PomodoroTimer**：内嵌于事件的番茄钟计时器，完成一个番茄钟自动更新事件进度
- **SubjectColor**：学科颜色，事件默认继承所绑定学科的颜色（参考 School Planner）
- **CalendarPage**：前端 `/toolkit/calendar` 路由对应的日历主页
- **MonthView**：基于 `table_calendar` 的月视图
- **WeekView / DayView**：基于 `timetable` 的周/日时间轴视图，支持拖拽
- **TodayPanel**：今日事件快速查看面板，含完成率进度条
- **StatsPanel**：学习数据统计面板，展示学科占比、每日时长趋势（参考 Studyplus）
- **EventBus**：全局事件总线，日历打卡事件实时通知各 Agent 和模块
- **MiniAppContract**：miniapp 标准化契约，定义入参/出参/生命周期钩子
- **calendar_events**：后端数据库表，存储单次事件
- **calendar_routines**：后端数据库表，存储重复例程定义（参考 flutter_planner）
- **study_sessions**：后端数据库表，存储实际学习时长记录

---

## 需求列表

---

### 需求 1：工具箱入口注册与双模式唤起

**用户故事：** 作为学生，我希望能从工具箱主动打开日历，也希望在对话中被 Agent 引导时以弹窗形式唤起日历，两种方式都能流畅使用。

#### 验收标准

1. THE `kDefaultTools` 列表 SHALL 新增 `ToolItem`，`id: 'calendar'`，`label: '学习日历'`，`description: '计划、打卡、复盘，学习闭环'`，`route: '/toolkit/calendar'`，渐变色 `[Color(0xFF6366F1), Color(0xFF818CF8)]`。
2. THE `R` 类 SHALL 新增 `toolkitCalendar = '/toolkit/calendar'`，子路由 `toolkitCalendarTask(String id)`、`toolkitCalendarCountdown`、`toolkitCalendarStats`。
3. WHEN `renderMode == 'full'`（默认），THE `CalendarPage` SHALL 以全屏页面展示。
4. WHEN `renderMode == 'modal'`，THE `CalendarPage` SHALL 以底部半屏弹窗展示，关闭后通过 `MiniAppContract.onResult` 回调返回操作结果，不破坏导航栈。
5. THE `CalendarPage` 接受标准化入参：`sceneSource`（user_active/agent）、`subjectId`（预选学科）、`taskId`（关联任务）、`renderMode`（full/modal）、`prefillDate`（预填日期）。
6. WHEN Agent 场景化调用（`sceneSource: 'agent'`），THE `CalendarPage` SHALL 根据传入参数预填事件表单，用户确认后写入日历并通过 `onResult` 回调通知调用方。

---

### 需求 2：三类事件管理（事件/例程/任务）

**用户故事：** 作为学生，我希望能区分「单次学习事件」「重复例程」「轻量待办」三种类型，以便更灵活地管理不同性质的学习安排。

#### 验收标准

1. THE `EventFormSheet` SHALL 在顶部提供类型切换标签：「事件」「例程」「任务」，默认为「事件」。
2. WHEN 类型为「事件」，THE 表单 SHALL 显示：标题（必填）、日期（必填）、开始时间（必填）、时长（必填，15–480 分钟，步进 15）、学科标签（选填）、颜色（默认继承学科颜色）、备注（选填）、是否为考试倒计时（开关）、优先级（高/中/低）。
3. WHEN 类型为「例程」，THE 表单 SHALL 显示：标题（必填）、重复周期（每日/每周/每月，必填）、执行时间（必填）、时长（必填）、学科标签（选填）、生效日期范围（开始日期–结束日期）。例程数据写入 `calendar_routines` 表，每次执行时自动生成对应的 `calendar_events` 实例。
4. WHEN 类型为「任务」，THE 表单 SHALL 显示：标题（必填）、截止日期（必填）、学科标签（选填）、优先级（高/中/低）。任务无具体开始时间，在月视图截止日期格内以小标签展示。
5. THE 颜色字段 SHALL 默认继承所选学科的 `SubjectColor`；IF 用户未选学科或手动修改颜色，THEN 使用用户选择的颜色（参考 School Planner 的学科颜色编码设计）。
6. WHEN 用户保存事件/例程/任务，THE `EventFormSheet` SHALL 调用对应端点，成功后通过 `EventBus` 发布对应创建事件，刷新当前视图。

---

### 需求 3：月/周/日三视图切换

**用户故事：** 作为学生，我希望能在月/周/日三种视图之间自由切换，以便从不同粒度查看我的学习安排。

#### 验收标准

1. THE `CalendarPage` SHALL 在顶部提供视图切换控件（月/周/日），默认展示月视图。
2. WHEN 用户选择「月」，THE `CalendarPage` SHALL 使用 `TableCalendar` 渲染月视图，每个日期格内显示学科颜色标记点（最多 3 个，超出显示「+N」），`CountdownEvent` 日期以红色边框高亮。
3. WHEN 用户选择「周」或「日」，THE `CalendarPage` SHALL 使用 `timetable` 库的 `MultiDateTimetable` 渲染时间轴视图，事件以色块形式按时间段展示，支持拖拽移动事件到新时间段。
4. WHEN 用户在周/日视图中拖拽事件到新时间段，THE `CalendarPage` SHALL 调用 `PATCH /api/calendar/events/{id}` 更新事件时间，并通过 `EventBus` 发布 `CalendarEventUpdated`。
5. THE 周/日视图 SHALL 支持时间遮罩（`timetable` 的 `TimeOverlay`）：已有课程表的时间段显示灰色遮罩，提示时间冲突（后续课程表导入功能接入）。
6. THE `CalendarPage` SHALL 提供「今天」按钮，点击后定位至包含今日的时间单元并高亮今日。
7. THE `CalendarPage` 视觉风格 SHALL 与 `ToolkitPage` 保持一致，使用 `AppColors` 主题色，支持深色/浅色模式。

---

### 需求 4：考试倒计时

**用户故事：** 作为学生，我希望能在日历上标记重要考试日期，并在首页醒目看到倒计时，以便合理安排复习节奏。

#### 验收标准

1. WHEN 用户在 `EventFormSheet` 中开启「标记为考试/重要日期」，THE 事件 SHALL 被标记为 `CountdownEvent`，在月视图以红色边框高亮，在周/日视图以特殊图标标注。
2. THE `CalendarPage` 顶部 SHALL 展示距离最近 `CountdownEvent` 的倒计时横幅：「距 {标题} 还有 X 天」，颜色随剩余天数变化（>30天绿色，10–30天橙色，<10天红色）。
3. IF 今日即为 `CountdownEvent` 日期，THEN 横幅 SHALL 显示「今天是 {标题}，加油！」。
4. THE `/toolkit/calendar/countdown` 路由 SHALL 展示所有 `CountdownEvent` 列表，按日期升序排列，每条显示标题、日期、剩余天数进度条。
5. THE `CountdownEvent` SHALL 同时写入 `calendar_events` 表的 `is_countdown` 字段，供 study-planner 在排期时识别并预留复习缓冲时间。

---

### 需求 5：内嵌番茄钟计时器

**用户故事：** 作为学生，我希望在开始学习某个事件时能直接启动番茄钟，完成后自动记录实际学习时长，不需要切换到其他 APP。

#### 验收标准

1. WHEN 用户点击某个 `CalendarEvent` 详情面板，THE 面板 SHALL 显示「开始学习」按钮，点击后启动内嵌 `PomodoroTimer`（默认 25 分钟专注 + 5 分钟休息）。
2. WHEN `PomodoroTimer` 运行中，THE `CalendarPage` SHALL 在底部显示悬浮计时条，显示当前番茄钟剩余时间和已完成番茄数，用户可切换到其他页面，计时条保持显示。
3. WHEN 一个番茄钟（25 分钟）完成，THE `PomodoroTimer` SHALL 自动将 25 分钟写入该事件的 `StudySession` 记录，并更新事件的实际学习时长。
4. WHEN 用户手动停止计时，THE `PomodoroTimer` SHALL 将已计时的时长（不足 25 分钟也记录）写入 `StudySession`，并询问用户「是否标记事件为已完成？」。
5. WHEN 事件的实际学习时长 ≥ 预估时长，THE `CalendarPage` SHALL 自动将该事件标记为已完成，并通过 `EventBus` 发布 `CalendarEventCompleted`。
6. THE `PomodoroTimer` 时长 SHALL 可在事件详情中自定义（15/25/45/60 分钟），默认 25 分钟。

---

### 需求 6：事件完成打卡与正向反馈

**用户故事：** 作为学生，我希望完成学习任务后能一键打卡，获得正向反馈，并看到今日完成率，以便保持学习动力。

#### 验收标准

1. THE 事件卡片 SHALL 在左侧显示完成状态指示器（圆形复选框），颜色与事件/学科颜色一致，未完成为空心，已完成为填充勾选。
2. WHEN 用户点击完成状态指示器，THE `CalendarPage` SHALL 调用 `PATCH /api/calendar/events/{id}`，将 `is_completed` 取反，并通过 `EventBus` 发布 `CalendarEventCompleted` 或 `CalendarEventUncompleted`。
3. WHEN 事件被标记为已完成，THE 事件卡片 SHALL 以删除线 + 降低透明度展示，不从视图中移除。
4. WHEN `CalendarEventCompleted` 被发布，THE `EventBus` 监听方 SHALL 自动同步：study-planner 对应 plan_item 状态更新为 done，思维导图对应节点 is_lit 更新为 1（如有关联）。
5. WHEN 今日所有事件均完成，THE `CalendarPage` SHALL 展示全部完成动画（撒花效果，参考 editable_mindmap_page 的 confetti 实现），并在 TodayPanel 显示「今日全部完成！」。
6. THE `MonthView` 中每个日期格 SHALL 以颜色区分完成情况：全部完成绿色，部分完成橙色，全部未完成灰色（参考 School Planner）。

---

### 需求 7：今日事件快速查看（TodayPanel）

**用户故事：** 作为学生，我希望能快速查看今天的所有学习事件和完成率，以便在不切换视图的情况下了解当日安排。

#### 验收标准

1. THE `CalendarPage` SHALL 在月视图下方提供可展开/收起的 `TodayPanel`，默认展开。
2. THE `TodayPanel` SHALL 按开始时间升序排列今日所有事件（含例程实例和任务），每条显示：学科颜色标记、标题、时间段、预估时长、完成状态指示器。
3. THE `TodayPanel` 标题区域 SHALL 显示今日完成率进度条，格式「今日进度 X/Y（Z%）」。
4. WHEN 今日无任何事件，THE `TodayPanel` SHALL 显示空状态「今天还没有学习安排，点击 + 新建」。
5. WHEN 用户点击 `TodayPanel` 中某条事件，THE `CalendarPage` SHALL 弹出该事件详情面板（含「开始学习」番茄钟入口）。
6. THE `TodayPanel` SHALL 提供「查看完整计划」入口，点击跳转至 `/spec`（study-planner 计划表）。

---

### 需求 8：学习数据统计（StatsPanel）

**用户故事：** 作为学生，我希望能看到我的学习时长趋势和学科占比，以便了解自己的学习分布是否合理。

#### 验收标准

1. THE `/toolkit/calendar/stats` 路由 SHALL 展示 `StatsPanel`，包含：近 7 天每日实际学习时长柱状图、近 30 天学科占比饼图、本月总学习时长、本月打卡天数（参考 Studyplus 的可视化设计）。
2. THE 学科占比饼图 SHALL 使用各学科的 `SubjectColor` 着色，与日历视图颜色一致。
3. THE 每日学习时长数据 SHALL 来源于 `study_sessions` 表的实际记录，而非预估时长。
4. THE `StatsPanel` SHALL 在 `CalendarPage` 顶部 AppBar 提供「统计」入口按钮，点击跳转至 `/toolkit/calendar/stats`。
5. WHEN 用户连续打卡 7 天，THE `StatsPanel` SHALL 展示连续打卡徽章，并在 `TodayPanel` 顶部显示「已连续学习 X 天」激励文案。

---

### 需求 9：对话中自然语言添加计划（Agent 联动）

**用户故事：** 作为学生，我希望在答疑室对话中说「帮我把高数复习加到下周一」，助教能自动识别并调用日历完成添加。

#### 验收标准

1. THE `RuleBasedIntentDetector` SHALL 新增 `IntentType.calendar`，关键词包含：「加到日历」「添加计划」「安排学习」「记到日历」「下周X」「明天X点」「提醒我」。
2. WHEN `IntentType.calendar` 被识别，THE `ChatPage` SHALL 在对话流中插入 `SceneCard`（新增 `SceneType.calendar`），显示提取的事件信息摘要，确认按钮「添加到日历」。
3. WHEN 用户点击「添加到日历」，THE `ChatPage` SHALL 以 `renderMode: 'modal'` 唤起 `CalendarPage`，预填提取的事件信息，用户确认后写入日历。
4. WHEN 日历事件成功创建，THE `ChatPage` SHALL 在对话流中插入助教消息「已添加到日历 ✓」，消息中包含跳转至 `/toolkit/calendar` 的快捷入口。
5. THE `SceneCard` 的 `SceneType.calendar` SHALL 使用靛蓝色（`Color(0xFF6366F1)`）作为强调色，与日历工具卡片颜色一致。

---

### 需求 10：接收外部批量写入事件

**用户故事：** 作为系统，我希望 Calendar Planner 提供标准 API 供外部功能批量写入事件，以便 study-planner 等生成的计划能自动出现在日历中。

#### 验收标准

1. THE 后端 SHALL 提供 `POST /api/calendar/events/batch` 端点，接受事件数组（最多 100 条），每个事件包含：`title`（必填）、`event_date`（必填）、`start_time`（必填）、`duration_minutes`（必填）、`subject_id`（选填）、`color`（选填）、`notes`（选填）、`source`（选填，如 `"study-planner"`）、`is_countdown`（选填）、`priority`（选填）。
2. THE 端点 SHALL 对每个事件独立验证，验证通过的写入 `calendar_events` 表，响应中分别报告每条的写入结果。
3. WHEN 批量写入成功，THE 后端 SHALL 通过 `EventBus` 发布 `CalendarEventsBatchCreated`，前端日历视图自动刷新受影响日期范围。
4. THE `calendar_events` 表 SHALL 存储 `source` 字段，前端通过小图标区分来源（手动创建无图标，study-planner 显示「📋」，助教 Agent 显示「🤖」）。

---

### 需求 11：后端数据模型与 REST API

**用户故事：** 作为前端，我希望后端提供完整的 Calendar Planner REST API 和数据库表。

#### 验收标准

1. THE 后端 SHALL 创建以下数据库表（迁移文件 `007_add_calendar_tables.sql`）：

   **`calendar_events`**：`id`、`user_id`（FK users）、`title`（VARCHAR 50）、`event_date`（DATE）、`start_time`（TIME）、`duration_minutes`（SMALLINT，15–480）、`actual_duration_minutes`（SMALLINT，实际学习时长，可为 NULL）、`subject_id`（FK subjects，可为 NULL）、`color`（VARCHAR 7）、`notes`（VARCHAR 200）、`is_completed`（BOOLEAN，DEFAULT FALSE）、`is_countdown`（BOOLEAN，DEFAULT FALSE）、`priority`（VARCHAR 10，DEFAULT 'medium'）、`source`（VARCHAR 50，DEFAULT 'manual'）、`routine_id`（FK calendar_routines，可为 NULL，例程生成的实例关联原例程）、`created_at`、`updated_at`。

   **`calendar_routines`**（参考 flutter_planner 的 routines 表）：`id`、`user_id`（FK users）、`title`（VARCHAR 50）、`repeat_type`（VARCHAR 10，daily/weekly/monthly）、`day_of_week`（SMALLINT，1–7，weekly 时使用）、`start_time`（TIME）、`duration_minutes`（SMALLINT）、`subject_id`（FK subjects，可为 NULL）、`color`（VARCHAR 7）、`start_date`（DATE）、`end_date`（DATE，可为 NULL）、`is_active`（BOOLEAN，DEFAULT TRUE）、`created_at`。

   **`study_sessions`**（参考 Studyplus 的学习记录）：`id`、`user_id`（FK users）、`event_id`（FK calendar_events，可为 NULL）、`subject_id`（FK subjects，可为 NULL）、`started_at`（TIMESTAMPTZ）、`ended_at`（TIMESTAMPTZ）、`duration_minutes`（SMALLINT，实际时长）、`pomodoro_count`（SMALLINT，完成的番茄钟数）、`created_at`。

2. THE 后端 SHALL 在 `calendar_events` 上创建索引 `idx_calendar_events_user_date`（`user_id, event_date`）。

3. THE 后端 SHALL 提供以下 REST 端点，全部复用 `get_current_user` 依赖进行身份验证：
   - `POST /api/calendar/events` — 创建单次事件
   - `GET /api/calendar/events?start_date=&end_date=&subject_id=&is_completed=` — 查询事件列表
   - `GET /api/calendar/events/today` — 今日事件列表 + 完成率统计
   - `PATCH /api/calendar/events/{id}` — 更新事件（支持部分字段）
   - `DELETE /api/calendar/events/{id}` — 删除事件（HTTP 204）
   - `POST /api/calendar/events/batch` — 批量写入事件
   - `POST /api/calendar/routines` — 创建例程
   - `GET /api/calendar/routines` — 查询例程列表
   - `PATCH /api/calendar/routines/{id}` — 更新例程
   - `DELETE /api/calendar/routines/{id}` — 删除例程
   - `POST /api/calendar/sessions` — 记录学习 session
   - `GET /api/calendar/stats?period=7d|30d` — 学习统计数据（时长趋势 + 学科占比）

4. IF 用户尝试访问或修改不属于自己的资源，THEN THE 端点 SHALL 返回 HTTP 404。

---

### 需求 12：前端状态管理与数据加载

**用户故事：** 作为前端，我希望日历页面使用 Riverpod 管理事件数据，视图切换时高效加载并缓存，避免重复请求。

#### 验收标准

1. THE 前端 SHALL 使用 Riverpod 定义以下 Provider：
   - `calendarEventsProvider(DateRange)` — 按日期范围加载并缓存事件列表
   - `calendarRoutinesProvider` — 加载所有活跃例程
   - `calendarStatsProvider(String period)` — 加载统计数据
   - `pomodoroTimerProvider` — 管理当前运行中的番茄钟状态（全局单例）

2. THE `calendarEventsProvider` SHALL 预加载当前视图相邻时间单元的数据（当前月则预加载上月和下月），减少滑动延迟。

3. WHEN `EventBus` 收到任何 `CalendarEvent*` 类事件，THE `calendarEventsProvider` SHALL 使受影响日期范围的缓存失效，触发重新加载。

4. WHILE 数据加载中，THE `CalendarPage` SHALL 显示骨架屏占位，不显示空状态。

5. THE `pubspec.yaml` SHALL 新增依赖：`table_calendar: ^3.2.0`、`timetable: latest`、`flutter_local_notifications: latest`。
