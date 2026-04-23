# 实现计划：学习日历（Calendar Planner）

## 概述

按照「后端先行，前端基础设施，再到 UI 组件，最后联动」的顺序逐步实现。每个阶段都能独立验证，避免悬空代码。设计文档中的 18 条正确性属性通过属性测试（后端 Hypothesis、前端 fast_check）覆盖。

---

## 任务列表

- [x] 1. 后端数据库迁移
  - [x] 1.1 创建迁移文件 `backend/migrations/007_add_calendar_tables.sql`
    - 按设计文档第 4 节创建 `calendar_events` 表，含所有字段、CHECK 约束、DEFAULT 值
    - 创建 `calendar_routines` 表，含 `repeat_type` CHECK 约束
    - 创建 `study_sessions` 表
    - 创建索引：`idx_calendar_events_user_date`、`idx_calendar_events_countdown`、`idx_calendar_routines_user`、`idx_study_sessions_user_time`、`idx_study_sessions_event`
    - _需求：11.1、11.2_

  - [ ]* 1.2 属性测试：CountdownEvent 写入后可查询（属性 4）
    - **属性 4：CountdownEvent 写入后可查询**
    - **验证：需求 4.5、11.1**

- [x] 2. 后端 Calendar Router — 事件端点
  - [x] 2.1 创建 `backend/routers/calendar.py`，实现事件 CRUD 端点
    - `POST /api/calendar/events`：创建单次事件，返回 201 + 完整事件对象
    - `GET /api/calendar/events`：支持 `start_date`、`end_date`、`subject_id`、`is_completed` 过滤
    - `GET /api/calendar/events/today`：返回今日事件列表 + 完成率统计（total/completed/completion_rate/total_duration_minutes/actual_duration_minutes）
    - `PATCH /api/calendar/events/{id}`：部分字段更新（拖拽移动、打卡完成、更新实际时长）
    - `DELETE /api/calendar/events/{id}`：返回 204
    - 所有端点复用 `get_current_user` 依赖，访问他人数据返回 404
    - _需求：11.3、11.4_

  - [x] 2.2 实现批量写入端点 `POST /api/calendar/events/batch`
    - 接受最多 100 条事件数组，每条独立验证
    - 合法条目写入，非法条目记录错误，互不影响
    - 返回 `results`（每条 success/error）、`created_count`、`failed_count`
    - _需求：10.1、10.2_

  - [ ]* 2.3 属性测试：批量写入全量持久化（属性 15）
    - **属性 15：批量写入全量持久化**
    - **验证：需求 10.1**

  - [ ]* 2.4 属性测试：批量写入独立验证（属性 16）
    - **属性 16：批量写入独立验证**
    - **验证：需求 10.2**

- [x] 3. 后端 Calendar Router — 例程、Session、统计端点
  - [x] 3.1 实现例程端点
    - `POST /api/calendar/routines`：创建例程，在事务内为 `start_date`~`end_date` 范围批量生成 `calendar_events` 实例（`routine_id` 关联）
    - `GET /api/calendar/routines`：返回 `is_active=true` 的例程列表
    - `PATCH /api/calendar/routines/{id}`：更新例程，同步更新未来关联事件实例
    - `DELETE /api/calendar/routines/{id}`：软删除（`is_active=false`），保留历史事件
    - _需求：2.3、11.3_

  - [x] 3.2 实现学习 Session 端点和统计端点
    - `POST /api/calendar/sessions`：记录学习 session（event_id、subject_id、started_at、ended_at、duration_minutes、pomodoro_count）
    - `GET /api/calendar/stats?period=7d|30d`：聚合 `study_sessions` 返回每日时长、学科占比、打卡天数、连续打卡天数
    - _需求：8.3、11.3_

  - [ ]* 3.3 属性测试：统计数据来源于 study_sessions（属性 12）
    - **属性 12：统计数据来源于 study_sessions**
    - **验证：需求 8.3**

  - [x] 3.4 在 `backend/main.py` 中注册 `/api/calendar` 路由
    - `app.include_router(calendar_router, prefix="/api/calendar", tags=["calendar"])`
    - _需求：11.3_

- [ ] 4. 检查点 — 后端接口验证
  - 确保所有 REST 端点返回正确状态码（非 404/500），运行后端测试套件，如有问题请提出。

- [x] 5. 前端基础设施 — EventBus、MiniAppContract、数据模型
  - [x] 5.1 创建 `lib/core/event_bus/app_event_bus.dart`
    - 实现 `AppEventBus` 全局单例（`StreamController.broadcast()`）
    - 实现 `on<T extends AppEvent>()`、`fire()`、`dispose()` 方法
    - 定义 `abstract class AppEvent`
    - _需求：6.4、12.3_

  - [x] 5.2 创建 `lib/core/event_bus/calendar_events.dart`，定义所有 Calendar EventBus 事件类
    - `CalendarEventCreated`（eventId、eventDate、source）
    - `CalendarEventUpdated`（eventId、eventDate）
    - `CalendarEventCompleted`（eventId、subjectId、taskId、mindmapNodeId）
    - `CalendarEventUncompleted`（eventId）
    - `CalendarEventsBatchCreated`（createdCount、affectedMonths、source）
    - `PomodoroCompleted`（eventId、durationMinutes、sessionId）
    - _需求：6.2、6.4_

  - [x] 5.3 创建 `lib/core/mini_app/mini_app_contract.dart`
    - 定义 `MiniAppInput`（sceneSource、renderMode、params）
    - 定义 `MiniAppResult`（success、action、data）
    - 定义 `abstract class MiniAppContract`
    - 定义 `CalendarMiniAppInput`（subjectId、taskId、prefillDate、prefillTitle、prefillTime、prefillDuration）
    - _需求：1.4、1.5、1.6_

  - [x] 5.4 创建 `lib/features/calendar/models/calendar_models.dart`，定义前端数据模型
    - `CalendarEvent`（含 `fromJson`、`copyWith`）
    - `CalendarRoutine`（含 `fromJson`）
    - `StudySession`（含 `fromJson`）
    - `CalendarStats`、`TodayEventsResult`、`DateRange`
    - `PomodoroTimerState`（phase、currentEvent、durationMinutes、elapsedSeconds、completedPomodoros）
    - `enum PomodoroPhase { idle, focusing, resting, paused }`
    - `enum ViewMode { month, week, day }`
    - _需求：12.1_

- [x] 6. 前端 CalendarApiService
  - [x] 6.1 创建 `lib/features/calendar/services/calendar_api_service.dart`
    - 基于 `DioClient` 实现所有 REST 调用方法：`getEvents`、`getTodayEvents`、`createEvent`、`updateEvent`、`deleteEvent`、`batchCreateEvents`、`getRoutines`、`createRoutine`、`updateRoutine`、`deleteRoutine`、`createSession`、`getStats`
    - 定义 `calendarApiServiceProvider`（Riverpod Provider）
    - _需求：11.3、12.1_

- [-] 7. 前端 Riverpod Providers
  - [ ] 7.1 创建 `lib/features/calendar/providers/calendar_providers.dart`
    - 实现 `calendarEventsProvider(DateRange)` — 按日期范围加载事件
    - 实现 `todayEventsProvider` — 今日事件 + 完成率
    - 实现 `calendarRoutinesProvider` — 活跃例程列表
    - 实现 `calendarStatsProvider(String period)` — 统计数据
    - 实现 `calendarViewModeProvider`（`CalendarViewMode` Notifier，默认 `ViewMode.month`）
    - 实现 `calendarFocusedDateProvider`（`CalendarFocusedDate` Notifier，默认今日）
    - _需求：12.1、12.4_

  - [ ] 7.2 实现 `PomodoroTimerNotifier`（全局单例 Provider）
    - 状态机：idle → focusing → resting → paused → idle
    - `start(event, durationMinutes)`、`pause()`、`resume()`、`stop(markCompleted)`
    - `_onPomodoroComplete()`：自动调用 `POST /api/calendar/sessions`，更新 `actual_duration_minutes`，发布 `PomodoroCompleted`
    - 当 `actual_duration_minutes >= duration_minutes` 时自动 PATCH `is_completed: true` 并发布 `CalendarEventCompleted`
    - _需求：5.1–5.6_

  - [ ]* 7.3 属性测试：番茄钟完成写入 StudySession（属性 5）
    - **属性 5：番茄钟完成写入 StudySession**
    - **验证：需求 5.3**

  - [ ]* 7.4 属性测试：手动停止写入实际时长（属性 6）
    - **属性 6：手动停止写入实际时长（ceil(elapsed_seconds / 60)）**
    - **验证：需求 5.4**

  - [ ]* 7.5 属性测试：累计时长达标自动完成（属性 7）
    - **属性 7：累计时长达标自动完成**
    - **验证：需求 5.5**

  - [ ] 7.6 在 `CalendarPage` 初始化时接入 EventBus 缓存失效逻辑
    - 监听 `CalendarEventCreated` → invalidate `calendarEventsProvider` + `todayEventsProvider`
    - 监听 `CalendarEventUpdated` → invalidate 受影响月份的 `calendarEventsProvider` + `todayEventsProvider`
    - 监听 `CalendarEventCompleted` → invalidate `todayEventsProvider` + `calendarStatsProvider('7d')`
    - 监听 `CalendarEventsBatchCreated` → invalidate 所有受影响月份的 `calendarEventsProvider`
    - _需求：12.3_

  - [ ]* 7.7 属性测试：EventBus 触发缓存失效（属性 18）
    - **属性 18：EventBus 触发缓存失效**
    - **验证：需求 12.3**

- [ ] 8. 工具箱入口注册 + 路由配置
  - [ ] 8.1 在 `lib/features/toolkit/toolkit_page.dart` 的 `kDefaultTools` 末尾追加 Calendar ToolItem
    - `id: 'calendar'`，图标 `Icons.calendar_today_outlined` / `Icons.calendar_today_rounded`
    - 渐变色 `[Color(0xFF6366F1), Color(0xFF818CF8)]`
    - `label: '学习日历'`，`description: '计划、打卡、复盘，学习闭环'`
    - `route: '/toolkit/calendar'`
    - _需求：1.1_

  - [ ] 8.2 在 `lib/routes/app_router.dart` 的 `R` 类中新增路由常量
    - `toolkitCalendar = '/toolkit/calendar'`
    - `toolkitCalendarTask(String id)` → `/toolkit/calendar/task/$id`
    - `toolkitCalendarCountdown = '/toolkit/calendar/countdown'`
    - `toolkitCalendarStats = '/toolkit/calendar/stats'`
    - _需求：1.2_

  - [ ] 8.3 在 `routerProvider` 中注册 Calendar 路由树
    - 主路由 `/toolkit/calendar`：构建 `CalendarPage`，从 query params 读取 `mode`、`source`、`subject`、`date`
    - 子路由 `task/:taskId` → `CalendarTaskDetailPage`（占位页，后续扩展）
    - 子路由 `countdown` → `CountdownListPage`
    - 子路由 `stats` → `StatsPanel`
    - _需求：1.2、4.4、8.4_

- [ ] 9. CalendarPage 主页面骨架
  - [ ] 9.1 创建 `lib/features/calendar/calendar_page.dart`
    - 定义 `CalendarPage` 构造参数：`renderMode`、`sceneSource`、`subjectId`、`taskId`、`prefillDate`、`onResult`
    - 实现顶部视图切换控件（月/周/日 SegmentedButton）
    - 实现「今天」按钮（定位至今日）
    - 实现 AppBar 右侧「统计」入口按钮（跳转 `R.toolkitCalendarStats`）
    - 实现悬浮 FAB（点击弹出 `EventFormSheet`）
    - 实现 `_prefetchAdjacentMonths()` 预加载上月/下月
    - 在 `initState` 中调用 EventBus 缓存失效监听（任务 7.6）
    - 加载中显示骨架屏，不显示空状态
    - _需求：1.3、3.1、3.6、3.7、8.4、12.2、12.4_

  - [ ]* 9.2 属性测试：calendarEventsProvider 预加载相邻月份（属性 17）
    - **属性 17：calendarEventsProvider 预加载相邻月份**
    - **验证：需求 12.2**

- [ ] 10. MonthView 月视图组件
  - [ ] 10.1 创建 `lib/features/calendar/widgets/month_view.dart`
    - 基于 `table_calendar` 实现 `MonthView`
    - 每个日期格显示学科颜色标记点（最多 3 个，超出显示「+N」）
    - `CountdownEvent` 日期以红色边框高亮
    - 日期格颜色区分完成情况：全完成绿色、部分完成橙色、全未完成灰色、无事件无标记
    - 点击日期格弹出当日事件列表
    - _需求：3.2、6.6_

  - [ ]* 10.2 属性测试：月视图日期格颜色规则（属性 9）
    - **属性 9：月视图日期格颜色规则**
    - **验证：需求 6.6**

- [ ] 11. WeekView / DayView 时间轴视图组件
  - [ ] 11.1 创建 `lib/features/calendar/widgets/timetable_view.dart`
    - 基于 `timetable` 库的 `MultiDateTimetable` 实现 `TimetableView`
    - 周视图传 7 天，日视图传 1 天
    - 事件以色块形式按时间段展示
    - 支持拖拽移动事件：拖拽结束后调用 `PATCH /api/calendar/events/{id}`（更新 event_date + start_time），发布 `CalendarEventUpdated`
    - 时间遮罩（`TimeOverlay`）：已有课程表时间段显示灰色遮罩
    - 长按事件弹出详情面板
    - _需求：3.3、3.4、3.5_

  - [ ]* 11.2 属性测试：拖拽后事件时间更新（属性 2）
    - **属性 2：拖拽后事件时间更新**
    - **验证：需求 3.4**

- [ ] 12. EventFormSheet 事件表单
  - [ ] 12.1 创建 `lib/features/calendar/widgets/event_form_sheet.dart`
    - 顶部类型切换标签：「事件」「例程」「任务」，默认「事件」
    - 「事件」类型字段：标题、日期、开始时间、时长（15–480 分钟步进 15 的 Slider/Picker）、学科标签、颜色、备注、是否考试倒计时开关、优先级
    - 「例程」类型字段：标题、重复周期（每日/每周/每月）、执行时间、时长、学科标签、生效日期范围
    - 「任务」类型字段：标题、截止日期、学科标签、优先级
    - 颜色继承逻辑：`_resolveColor()` — 用户选色 > 学科颜色 > AppColors.primary
    - 保存时调用对应端点，成功后发布 `CalendarEventCreated`，关闭弹窗
    - 支持编辑模式（传入 `initialEvent`）和预填模式（传入 `prefillDate`、`prefillSubjectId`）
    - 表单验证失败时在字段下方显示红色提示，禁用「保存」按钮
    - _需求：2.1–2.6_

  - [ ]* 12.2 属性测试：事件颜色继承学科颜色（属性 1）
    - **属性 1：事件颜色继承学科颜色**
    - **验证：需求 2.5**

- [ ] 13. 考试倒计时功能
  - [ ] 13.1 实现 `CalendarPage` 顶部倒计时横幅
    - 查询最近的 `is_countdown=true` 事件，计算剩余天数
    - 实现 `_countdownBannerColor(int daysLeft)` 纯函数：`d > 30` 绿色，`10 ≤ d ≤ 30` 橙色，`d < 10` 红色，`d = 0` 返回 null（显示特殊文案「今天是 {标题}，加油！」）
    - _需求：4.1、4.2、4.3_

  - [ ]* 13.2 属性测试：倒计时横幅颜色分段规则（属性 3）
    - **属性 3：倒计时横幅颜色分段规则**
    - **验证：需求 4.2、4.3**

  - [ ] 13.3 创建 `lib/features/calendar/widgets/countdown_list_page.dart`
    - 展示所有 `is_countdown=true` 事件，按日期升序排列
    - 每条显示标题、日期、剩余天数进度条
    - _需求：4.4_

- [ ] 14. TodayPanel 今日事件面板
  - [ ] 14.1 创建 `lib/features/calendar/widgets/today_panel.dart`
    - 可展开/收起，默认展开
    - 标题区域：「今日进度 X/Y（Z%）」+ 进度条，实现 `_completionRate(int completed, int total)` 纯函数
    - 事件列表：按 `start_time` 升序排列，每条显示学科颜色标记、标题、时间段、预估时长、完成状态指示器
    - 空状态：「今天还没有学习安排，点击 + 新建」
    - 底部「查看完整计划」入口 → `R.spec`
    - 点击事件弹出详情面板（含「开始学习」番茄钟入口）
    - _需求：7.1–7.6_

  - [ ]* 14.2 属性测试：TodayPanel 事件排序（属性 10）
    - **属性 10：TodayPanel 事件排序**
    - **验证：需求 7.2**

  - [ ]* 14.3 属性测试：TodayPanel 完成率计算（属性 11）
    - **属性 11：TodayPanel 完成率计算**
    - **验证：需求 7.3、7.4**

- [ ] 15. 事件完成打卡与正向反馈
  - [ ] 15.1 实现事件卡片完成状态指示器
    - 圆形复选框，颜色与事件/学科颜色一致，未完成空心，已完成填充勾选
    - 点击调用 `PATCH /api/calendar/events/{id}`（`is_completed` 取反）
    - 已完成事件以删除线 + 降低透明度展示，不从视图移除
    - 发布 `CalendarEventCompleted` 或 `CalendarEventUncompleted`
    - _需求：6.1–6.3_

  - [ ]* 15.2 属性测试：完成状态切换幂等性（属性 8）
    - **属性 8：完成状态切换幂等性**
    - **验证：需求 6.2**

  - [ ] 15.3 实现今日全部完成动画与跨模块 EventBus 同步
    - 当今日所有事件均完成时，触发撒花动画（参考 `editable_mindmap_page` 的 confetti 实现），TodayPanel 显示「今日全部完成！」
    - `CalendarEventCompleted` 监听方：若 `taskId != null` → `PATCH /api/study-planner/tasks/{taskId}`（status: done）；若 `mindmapNodeId != null` → `PATCH /api/mindmap/nodes/{nodeId}`（is_lit: 1）
    - _需求：6.4、6.5_

- [ ] 16. 检查点 — 核心功能验证
  - 确保月视图、TodayPanel、打卡、倒计时横幅均正常工作，运行所有已实现的属性测试，如有问题请提出。

- [ ] 17. PomodoroTimer 番茄钟计时器
  - [ ] 17.1 创建 `lib/features/calendar/widgets/pomodoro_timer.dart`
    - 底部悬浮计时条 UI：显示剩余时间、已完成番茄数、暂停/继续/停止按钮
    - 全局单例（通过 `pomodoroTimerProvider` 管理），切换页面后计时条保持显示
    - 时长可在事件详情中自定义（15/25/45/60 分钟），默认 25 分钟
    - 手动停止时弹出 Dialog「是否标记事件为已完成？」
    - _需求：5.1–5.6_

- [ ] 18. StatsPanel 学习数据统计
  - [ ] 18.1 创建 `lib/features/calendar/widgets/stats_panel.dart`
    - 近 7 天每日实际学习时长柱状图（数据来自 `study_sessions`）
    - 近 30 天学科占比饼图（使用各学科 `SubjectColor` 着色）
    - 本月总学习时长、本月打卡天数
    - 连续打卡 ≥ 7 天时显示连续打卡徽章，TodayPanel 顶部显示「已连续学习 X 天」
    - _需求：8.1–8.5_

  - [ ]* 18.2 属性测试：连续打卡徽章阈值（属性 13）
    - **属性 13：连续打卡徽章阈值（n ≥ 7 显示，n < 7 不显示）**
    - **验证：需求 8.5**

- [ ] 19. Agent 联动 — IntentType.calendar + SceneType.calendar
  - [ ] 19.1 在 `lib/services/intent_detector.dart` 中新增 `IntentType.calendar`
    - 在 `IntentType` 枚举中追加 `calendar`
    - 在 `RuleBasedIntentDetector` 中新增 `_calendarKeywords`：「加到日历」「添加计划」「安排学习」「记到日历」「下周」「明天」「提醒我」
    - 优先级：spec > planning > calendar > subject > tool > none
    - 提取参数：title、date（DateTime）、time（String "HH:mm"）、subjectId
    - _需求：9.1_

  - [ ]* 19.2 属性测试：日历关键词意图识别（属性 14）
    - **属性 14：日历关键词意图识别**
    - **验证：需求 9.1**

  - [ ] 19.3 在 `lib/models/chat_message.dart` 中新增 `SceneType.calendar`
    - 在 `SceneType` 枚举中追加 `calendar`
    - _需求：9.5_

  - [ ] 19.4 在 `lib/widgets/scene_card.dart` 中处理 `SceneType.calendar`
    - `_accentColor`：返回 `Color(0xFF6366F1)`（靛蓝色）
    - `_icon`：返回 `Icons.calendar_today_outlined`
    - _需求：9.5_

  - [ ] 19.5 在 `lib/features/chat/chat_page.dart` 中接入 Calendar 场景化调用
    - 当 `IntentType.calendar` 被识别时，在对话流中插入 `SceneCard(SceneType.calendar)`，显示提取的事件信息摘要，确认按钮「添加到日历」
    - 用户点击「添加到日历」时，以 `renderMode: 'modal'` 唤起 `CalendarPage`，预填提取的事件信息
    - 日历事件成功创建后，在对话流中插入助教消息「已添加到日历 ✓ [查看日历](/toolkit/calendar)」，发布 `CalendarEventCreated`
    - _需求：9.2–9.4_

- [ ] 20. pubspec.yaml 依赖更新
  - [ ] 20.1 在 `pubspec.yaml` 中新增前端依赖
    - `table_calendar: ^3.2.0`
    - `timetable: latest`（或当前最新稳定版）
    - `flutter_local_notifications: latest`
    - `fast_check`（Dart 属性测试库，dev_dependencies）
    - _需求：12.5_

- [ ] 21. 最终检查点 — 全链路验证
  - 确保所有测试通过（属性测试 + 单元测试），工具箱入口可见，Agent 联动正常，如有问题请提出。

---

## 备注

- 标有 `*` 的子任务为可选测试任务，可跳过以加快 MVP 进度
- 每个任务均引用具体需求条款，便于追溯
- 属性测试覆盖设计文档第 9 节的 18 条正确性属性（属性 2、4、5、6、7、8、9、10、11、12、13、14、15、16、17、18）
- 后端属性测试使用 `hypothesis`（`backend/tests/test_calendar_properties.py`）
- 前端属性测试使用 `fast_check`（`test/features/calendar/`）
- 检查点任务确保每个阶段可独立验证，不产生悬空代码
