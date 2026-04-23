# 设计文档：学习日历（Calendar Planner）

## 1. 系统架构概览

Calendar Planner 是工具箱（`/toolkit`）中的独立 miniapp，定位为整个学习闭环的**执行层**。它通过 EventBus 与 study-planner、思维导图、错题本等模块双向联动，同时支持 Agent 对话场景化唤起。

### 1.1 整体分层

```
┌─────────────────────────────────────────────────────────────┐
│                        Flutter 前端                          │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  CalendarPage │  │ EventFormSheet│  │  PomodoroTimer   │  │
│  │  (月/周/日视图)│  │ (事件/例程/任务)│  │  (悬浮计时条)    │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘  │
│         │                 │                    │            │
│  ┌──────▼─────────────────▼────────────────────▼─────────┐  │
│  │              Riverpod Providers 层                     │  │
│  │  calendarEventsProvider / calendarRoutinesProvider     │  │
│  │  calendarStatsProvider / pomodoroTimerProvider         │  │
│  └──────────────────────────┬──────────────────────────┘  │
│                             │                              │
│  ┌──────────────────────────▼──────────────────────────┐  │
│  │                  CalendarApiService                  │  │
│  │              (Dio + JWT Bearer Token)                │  │
│  └──────────────────────────┬──────────────────────────┘  │
│                             │                              │
│  ┌──────────────────────────▼──────────────────────────┐  │
│  │                    AppEventBus                       │  │
│  │  (全局单例，StreamController，跨模块事件广播)          │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                             │ HTTP REST
┌─────────────────────────────▼───────────────────────────────┐
│                    Python FastAPI 后端                        │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │           /api/calendar  路由模块                    │   │
│  │  events / routines / sessions / stats               │   │
│  └──────────────────────────┬──────────────────────────┘   │
│                             │                               │
│  ┌──────────────────────────▼──────────────────────────┐   │
│  │                  PostgreSQL                          │   │
│  │  calendar_events / calendar_routines / study_sessions│   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 双模式唤起架构

```
用户主动模式：
  工具箱 (/toolkit)
    → 点击「学习日历」卡片
    → context.push(R.toolkitCalendar)
    → CalendarPage(renderMode: 'full')

Agent 场景化模式：
  ChatPage 意图识别
    → IntentType.calendar 触发
    → 插入 SceneCard(SceneType.calendar)
    → 用户点击「添加到日历」
    → showModalBottomSheet → CalendarPage(renderMode: 'modal')
    → 用户确认 → MiniAppContract.onResult 回调
    → ChatPage 插入确认消息
```

### 1.3 与生态模块的联动关系

| 来源模块 | 写入日历方式 | 触发事件 |
|---------|------------|---------|
| study-planner | `POST /api/calendar/events/batch`，source='study-planner' | `CalendarEventsBatchCreated` |
| 对话 Agent | modal 模式唤起，用户确认后写入 | `CalendarEventCreated` |
| 用户手动 | EventFormSheet 直接创建 | `CalendarEventCreated` |

| 日历打卡 | 通知目标模块 | 同步内容 |
|---------|------------|---------|
| `CalendarEventCompleted` | study-planner | plan_item.status → done |
| `CalendarEventCompleted` | 思维导图 | mindmap_node_states.is_lit → 1（如有关联） |
| `CalendarEventsBatchCreated` | CalendarPage | 刷新受影响日期范围 |


## 2. 前端组件结构

### 2.1 核心页面组件

#### CalendarPage (`lib/features/calendar/calendar_page.dart`)

```dart
class CalendarPage extends ConsumerStatefulWidget {
  final String renderMode;      // 'full' | 'modal'
  final String sceneSource;     // 'user_active' | 'agent'
  final int? subjectId;         // 预选学科
  final String? taskId;         // 关联任务
  final DateTime? prefillDate;  // 预填日期
  
  const CalendarPage({
    this.renderMode = 'full',
    this.sceneSource = 'user_active',
    this.subjectId,
    this.taskId,
    this.prefillDate,
  });
}
```

**职责**：
- 顶部视图切换控件（月/周/日）
- 倒计时横幅（距最近考试 X 天）
- 主视图区域（MonthView / WeekView / DayView）
- TodayPanel（今日事件快速查看）
- 悬浮 FAB（新建事件）

**状态管理**：
- `currentViewMode`：当前视图模式（month/week/day）
- `selectedDate`：当前选中日期
- `focusedDate`：当前聚焦日期（月视图用）

---

#### MonthView (`lib/features/calendar/widgets/month_view.dart`)

基于 `table_calendar` 库实现。

```dart
class MonthView extends ConsumerWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onPageChanged;
}
```

**特性**：
- 每个日期格显示学科颜色标记点（最多 3 个，超出显示「+N」）
- CountdownEvent 日期以红色边框高亮
- 日期格颜色区分完成情况（全完成绿色，部分完成橙色，全未完成灰色）
- 点击日期格弹出当日事件列表

---

#### WeekView / DayView (`lib/features/calendar/widgets/timetable_view.dart`)

基于 `timetable` 库的 `MultiDateTimetable` 实现。

```dart
class TimetableView extends ConsumerWidget {
  final List<DateTime> visibleDates;  // 周视图传 7 天，日视图传 1 天
  final ValueChanged<CalendarEvent> onEventTap;
  final ValueChanged<(CalendarEvent, DateTime)> onEventDragged;
}
```

**特性**：
- 事件以色块形式按时间段展示
- 支持拖拽移动事件到新时间段（触发 `PATCH /api/calendar/events/{id}`）
- 时间遮罩（`TimeOverlay`）：已有课程表的时间段显示灰色遮罩
- 长按事件弹出详情面板

---

#### EventFormSheet (`lib/features/calendar/widgets/event_form_sheet.dart`)

底部弹窗表单，支持三种类型切换。

```dart
class EventFormSheet extends ConsumerStatefulWidget {
  final CalendarEvent? initialEvent;  // 编辑模式传入
  final DateTime? prefillDate;
  final int? prefillSubjectId;
}
```

**表单字段**（根据类型动态显示）：

| 类型 | 字段 |
|------|------|
| 事件 | 标题、日期、开始时间、时长（15–480分钟，步进15）、学科、颜色、备注、是否考试倒计时、优先级 |
| 例程 | 标题、重复周期（每日/每周/每月）、执行时间、时长、学科、生效日期范围 |
| 任务 | 标题、截止日期、学科、优先级 |

**颜色继承逻辑**：
```dart
Color _resolveColor() {
  if (userSelectedColor != null) return userSelectedColor!;
  if (selectedSubject != null) return selectedSubject!.color;
  return AppColors.primary;
}
```

---

#### TodayPanel (`lib/features/calendar/widgets/today_panel.dart`)

可展开/收起的今日事件面板。

```dart
class TodayPanel extends ConsumerWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
}
```

**内容**：
- 标题区域：「今日进度 X/Y（Z%）」+ 进度条
- 事件列表：按 start_time 升序排列，每条显示学科颜色标记、标题、时间段、完成状态指示器
- 空状态：「今天还没有学习安排，点击 + 新建」
- 底部入口：「查看完整计划」→ `/spec`

---

#### PomodoroTimer (`lib/features/calendar/widgets/pomodoro_timer.dart`)

内嵌番茄钟计时器，全局单例（通过 `pomodoroTimerProvider` 管理）。

```dart
class PomodoroTimer extends ConsumerStatefulWidget {
  final CalendarEvent event;
  final int durationMinutes;  // 15/25/45/60
}
```

**UI 形态**：
- 运行中：底部悬浮计时条，显示剩余时间和已完成番茄数
- 完成一个番茄钟：自动写入 `study_sessions`，更新事件 `actual_duration_minutes`
- 手动停止：询问「是否标记事件为已完成？」

---

### 2.2 工具箱入口注册

在 `lib/features/toolkit/toolkit_page.dart` 的 `kDefaultTools` 列表中新增：

```dart
const ToolItem(
  id: 'calendar',
  icon: Icons.calendar_today_outlined,
  filledIcon: Icons.calendar_today_rounded,
  gradientColors: [Color(0xFF6366F1), Color(0xFF818CF8)],
  label: '学习日历',
  description: '计划、打卡、复盘，学习闭环',
  route: '/toolkit/calendar',
),
```

---

### 2.3 路由定义

在 `lib/routes/app_router.dart` 的 `R` 类中新增：

```dart
class R {
  // ... 现有路由 ...
  
  // Calendar Planner
  static const toolkitCalendar = '/toolkit/calendar';
  static String toolkitCalendarTask(String id) => '/toolkit/calendar/task/$id';
  static const toolkitCalendarCountdown = '/toolkit/calendar/countdown';
  static const toolkitCalendarStats = '/toolkit/calendar/stats';
}
```

在 `routerProvider` 中注册路由：

```dart
GoRoute(
  path: R.toolkitCalendar,
  builder: (_, state) => CalendarPage(
    renderMode: state.uri.queryParameters['mode'] ?? 'full',
    sceneSource: state.uri.queryParameters['source'] ?? 'user_active',
    subjectId: int.tryParse(state.uri.queryParameters['subject'] ?? ''),
    prefillDate: state.uri.queryParameters['date'] != null
        ? DateTime.tryParse(state.uri.queryParameters['date']!)
        : null,
  ),
  routes: [
    GoRoute(
      path: 'task/:taskId',
      builder: (_, state) => CalendarTaskDetailPage(
        taskId: state.pathParameters['taskId']!,
      ),
    ),
    GoRoute(
      path: 'countdown',
      builder: (_, __) => CountdownListPage(),
    ),
    GoRoute(
      path: 'stats',
      builder: (_, __) => StatsPanel(),
    ),
  ],
),
```


## 3. 后端 API 设计

所有端点挂载在 `/api/calendar`，统一使用 `get_current_user` 依赖进行身份验证，用户只能访问自己的数据（否则返回 HTTP 404）。

### 3.1 事件端点

#### `POST /api/calendar/events` — 创建单次事件

**请求体**：
```json
{
  "title": "高数复习",
  "event_date": "2025-06-10",
  "start_time": "09:00",
  "duration_minutes": 90,
  "subject_id": 3,
  "color": "#6366F1",
  "notes": "重点复习极限章节",
  "is_countdown": false,
  "priority": "high",
  "source": "manual"
}
```

**响应**：`201 Created`，返回完整事件对象。

---

#### `GET /api/calendar/events` — 查询事件列表

**查询参数**：`start_date`、`end_date`、`subject_id`（可选）、`is_completed`（可选）

**响应**：
```json
{
  "events": [
    {
      "id": 1,
      "title": "高数复习",
      "event_date": "2025-06-10",
      "start_time": "09:00",
      "duration_minutes": 90,
      "actual_duration_minutes": 75,
      "subject_id": 3,
      "subject_name": "高等数学",
      "subject_color": "#6366F1",
      "color": "#6366F1",
      "is_completed": false,
      "is_countdown": false,
      "priority": "high",
      "source": "manual",
      "routine_id": null,
      "created_at": "2025-06-01T10:00:00Z"
    }
  ],
  "total": 1
}
```

---

#### `GET /api/calendar/events/today` — 今日事件 + 完成率

**响应**：
```json
{
  "events": [...],
  "stats": {
    "total": 5,
    "completed": 2,
    "completion_rate": 0.4,
    "total_duration_minutes": 240,
    "actual_duration_minutes": 90
  }
}
```

---

#### `PATCH /api/calendar/events/{id}` — 更新事件（部分字段）

支持更新任意字段组合，常见场景：
- 拖拽移动：`{"event_date": "...", "start_time": "..."}`
- 打卡完成：`{"is_completed": true}`
- 更新实际时长：`{"actual_duration_minutes": 75}`

**响应**：`200 OK`，返回更新后的完整事件对象。

---

#### `DELETE /api/calendar/events/{id}` — 删除事件

**响应**：`204 No Content`

---

#### `POST /api/calendar/events/batch` — 批量写入事件

**请求体**：
```json
{
  "events": [
    {
      "title": "高数复习 Day 1",
      "event_date": "2025-06-10",
      "start_time": "09:00",
      "duration_minutes": 90,
      "subject_id": 3,
      "source": "study-planner"
    }
  ]
}
```

**响应**：
```json
{
  "results": [
    {"index": 0, "success": true, "id": 42},
    {"index": 1, "success": false, "error": "title 不能为空"}
  ],
  "created_count": 1,
  "failed_count": 1
}
```

---

### 3.2 例程端点

#### `POST /api/calendar/routines` — 创建例程

**请求体**：
```json
{
  "title": "每日背单词",
  "repeat_type": "daily",
  "start_time": "07:00",
  "duration_minutes": 30,
  "subject_id": 5,
  "start_date": "2025-06-01",
  "end_date": "2025-08-31"
}
```

创建例程后，后端自动为 `start_date` 到 `end_date` 范围内的每个匹配日期生成 `calendar_events` 实例（`routine_id` 关联原例程）。

---

#### `GET /api/calendar/routines` — 查询活跃例程列表

**响应**：返回 `is_active=true` 的所有例程。

---

#### `PATCH /api/calendar/routines/{id}` — 更新例程

支持更新标题、时间、颜色等字段，同时更新未来的关联事件实例。

---

#### `DELETE /api/calendar/routines/{id}` — 删除例程

软删除（`is_active=false`），保留历史事件实例。

---

### 3.3 学习 Session 端点

#### `POST /api/calendar/sessions` — 记录学习 Session

**请求体**：
```json
{
  "event_id": 42,
  "subject_id": 3,
  "started_at": "2025-06-10T09:00:00Z",
  "ended_at": "2025-06-10T09:25:00Z",
  "duration_minutes": 25,
  "pomodoro_count": 1
}
```

---

### 3.4 统计端点

#### `GET /api/calendar/stats?period=7d|30d` — 学习统计

**响应**：
```json
{
  "period": "7d",
  "total_duration_minutes": 840,
  "checkin_days": 6,
  "streak_days": 4,
  "daily_stats": [
    {"date": "2025-06-04", "duration_minutes": 120},
    {"date": "2025-06-05", "duration_minutes": 90}
  ],
  "subject_stats": [
    {"subject_id": 3, "subject_name": "高等数学", "color": "#6366F1", "duration_minutes": 360, "percentage": 0.43},
    {"subject_id": 5, "subject_name": "英语", "color": "#10B981", "duration_minutes": 480, "percentage": 0.57}
  ]
}
```


## 4. 数据库表结构

迁移文件：`backend/migrations/007_add_calendar_tables.sql`

### 4.1 `calendar_events` 表

```sql
CREATE TABLE IF NOT EXISTS calendar_events (
    id                      SERIAL PRIMARY KEY,
    user_id                 INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title                   VARCHAR(50) NOT NULL,
    event_date              DATE NOT NULL,
    start_time              TIME NOT NULL,
    duration_minutes        SMALLINT NOT NULL CHECK (duration_minutes BETWEEN 15 AND 480),
    actual_duration_minutes SMALLINT,                          -- 实际学习时长，番茄钟累计
    subject_id              INTEGER REFERENCES subjects(id) ON DELETE SET NULL,
    color                   VARCHAR(7) NOT NULL DEFAULT '#6366F1',
    notes                   VARCHAR(200),
    is_completed            BOOLEAN NOT NULL DEFAULT FALSE,
    is_countdown            BOOLEAN NOT NULL DEFAULT FALSE,    -- 考试/重要日期倒计时
    priority                VARCHAR(10) NOT NULL DEFAULT 'medium'
                                CHECK (priority IN ('high', 'medium', 'low')),
    source                  VARCHAR(50) NOT NULL DEFAULT 'manual',  -- manual/study-planner/agent
    routine_id              INTEGER REFERENCES calendar_routines(id) ON DELETE SET NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 主查询索引：按用户+日期范围查询
CREATE INDEX IF NOT EXISTS idx_calendar_events_user_date
    ON calendar_events (user_id, event_date);

-- 倒计时查询索引
CREATE INDEX IF NOT EXISTS idx_calendar_events_countdown
    ON calendar_events (user_id, is_countdown, event_date)
    WHERE is_countdown = TRUE;
```

---

### 4.2 `calendar_routines` 表

```sql
CREATE TABLE IF NOT EXISTS calendar_routines (
    id               SERIAL PRIMARY KEY,
    user_id          INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title            VARCHAR(50) NOT NULL,
    repeat_type      VARCHAR(10) NOT NULL CHECK (repeat_type IN ('daily', 'weekly', 'monthly')),
    day_of_week      SMALLINT CHECK (day_of_week BETWEEN 1 AND 7),  -- weekly 时使用，1=周一
    start_time       TIME NOT NULL,
    duration_minutes SMALLINT NOT NULL CHECK (duration_minutes BETWEEN 15 AND 480),
    subject_id       INTEGER REFERENCES subjects(id) ON DELETE SET NULL,
    color            VARCHAR(7) NOT NULL DEFAULT '#6366F1',
    start_date       DATE NOT NULL,
    end_date         DATE,                                           -- NULL 表示无限期
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_calendar_routines_user
    ON calendar_routines (user_id, is_active);
```

---

### 4.3 `study_sessions` 表

```sql
CREATE TABLE IF NOT EXISTS study_sessions (
    id               SERIAL PRIMARY KEY,
    user_id          INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_id         INTEGER REFERENCES calendar_events(id) ON DELETE SET NULL,
    subject_id       INTEGER REFERENCES subjects(id) ON DELETE SET NULL,
    started_at       TIMESTAMPTZ NOT NULL,
    ended_at         TIMESTAMPTZ NOT NULL,
    duration_minutes SMALLINT NOT NULL,                             -- 实际时长（含不足25分钟的记录）
    pomodoro_count   SMALLINT NOT NULL DEFAULT 0,                   -- 完成的完整番茄钟数
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 统计查询索引：按用户+时间范围聚合
CREATE INDEX IF NOT EXISTS idx_study_sessions_user_time
    ON study_sessions (user_id, started_at);

-- 按事件查询索引
CREATE INDEX IF NOT EXISTS idx_study_sessions_event
    ON study_sessions (event_id)
    WHERE event_id IS NOT NULL;
```

---

### 4.4 表关系图

```
users
  │
  ├── calendar_routines (user_id FK)
  │       │
  │       └── calendar_events (routine_id FK, 例程生成的实例)
  │
  ├── calendar_events (user_id FK)
  │       │
  │       └── study_sessions (event_id FK)
  │
  └── study_sessions (user_id FK)

subjects
  ├── calendar_events (subject_id FK)
  ├── calendar_routines (subject_id FK)
  └── study_sessions (subject_id FK)
```


## 5. 状态管理设计（Riverpod Providers）

### 5.1 Provider 总览

```dart
// lib/features/calendar/providers/calendar_providers.dart

// ── 事件列表（按日期范围，带预加载）────────────────────────────────────────
@riverpod
Future<List<CalendarEvent>> calendarEvents(
  CalendarEventsRef ref,
  DateRange range,
) async {
  final api = ref.watch(calendarApiServiceProvider);
  return api.getEvents(startDate: range.start, endDate: range.end);
}

// ── 今日事件 + 完成率统计 ────────────────────────────────────────────────
@riverpod
Future<TodayEventsResult> todayEvents(TodayEventsRef ref) async {
  final api = ref.watch(calendarApiServiceProvider);
  return api.getTodayEvents();
}

// ── 活跃例程列表 ─────────────────────────────────────────────────────────
@riverpod
Future<List<CalendarRoutine>> calendarRoutines(CalendarRoutinesRef ref) async {
  final api = ref.watch(calendarApiServiceProvider);
  return api.getRoutines();
}

// ── 统计数据 ─────────────────────────────────────────────────────────────
@riverpod
Future<CalendarStats> calendarStats(
  CalendarStatsRef ref,
  String period,  // '7d' | '30d'
) async {
  final api = ref.watch(calendarApiServiceProvider);
  return api.getStats(period: period);
}

// ── 番茄钟状态（全局单例）────────────────────────────────────────────────
@riverpod
class PomodoroTimerNotifier extends _$PomodoroTimerNotifier {
  @override
  PomodoroTimerState build() => PomodoroTimerState.idle();

  void start(CalendarEvent event, {int durationMinutes = 25}) { ... }
  void pause() { ... }
  void resume() { ... }
  void stop({bool markCompleted = false}) { ... }
  void _onPomodoroComplete() { ... }  // 自动写入 study_sessions
}

// ── 当前视图模式 ─────────────────────────────────────────────────────────
@riverpod
class CalendarViewMode extends _$CalendarViewMode {
  @override
  ViewMode build() => ViewMode.month;
  
  void switchTo(ViewMode mode) => state = mode;
}

// ── 当前聚焦日期 ─────────────────────────────────────────────────────────
@riverpod
class CalendarFocusedDate extends _$CalendarFocusedDate {
  @override
  DateTime build() => DateTime.now();
  
  void jumpToToday() => state = DateTime.now();
  void jumpTo(DateTime date) => state = date;
}
```

---

### 5.2 预加载策略

`calendarEventsProvider` 在加载当前月份时，同时预加载上月和下月：

```dart
// 在 CalendarPage 的 initState 中触发预加载
void _prefetchAdjacentMonths() {
  final focused = ref.read(calendarFocusedDateProvider);
  
  // 预加载上月
  ref.prefetch(calendarEventsProvider(DateRange.month(
    DateTime(focused.year, focused.month - 1),
  )));
  
  // 预加载下月
  ref.prefetch(calendarEventsProvider(DateRange.month(
    DateTime(focused.year, focused.month + 1),
  )));
}
```

---

### 5.3 EventBus 触发缓存失效

```dart
// 在 CalendarPage 的 initState 中监听 EventBus
void _listenEventBus() {
  AppEventBus.instance.on<CalendarEventCreated>().listen((_) {
    ref.invalidate(calendarEventsProvider);
    ref.invalidate(todayEventsProvider);
  });
  
  AppEventBus.instance.on<CalendarEventUpdated>().listen((e) {
    // 只失效受影响的日期范围
    ref.invalidate(calendarEventsProvider(DateRange.month(e.eventDate)));
    ref.invalidate(todayEventsProvider);
  });
  
  AppEventBus.instance.on<CalendarEventCompleted>().listen((_) {
    ref.invalidate(todayEventsProvider);
    ref.invalidate(calendarStatsProvider('7d'));
  });
  
  AppEventBus.instance.on<CalendarEventsBatchCreated>().listen((e) {
    // 失效批量写入涉及的所有月份
    for (final month in e.affectedMonths) {
      ref.invalidate(calendarEventsProvider(DateRange.month(month)));
    }
  });
}
```

---

### 5.4 PomodoroTimerState 数据模型

```dart
enum PomodoroPhase { idle, focusing, resting, paused }

class PomodoroTimerState {
  final PomodoroPhase phase;
  final CalendarEvent? currentEvent;
  final int durationMinutes;       // 本次番茄钟时长
  final int elapsedSeconds;        // 已计时秒数
  final int completedPomodoros;    // 已完成番茄钟数
  
  factory PomodoroTimerState.idle() => PomodoroTimerState(
    phase: PomodoroPhase.idle,
    currentEvent: null,
    durationMinutes: 25,
    elapsedSeconds: 0,
    completedPomodoros: 0,
  );
  
  int get remainingSeconds => durationMinutes * 60 - elapsedSeconds;
  bool get isRunning => phase == PomodoroPhase.focusing || phase == PomodoroPhase.resting;
}
```


## 6. EventBus 事件定义

项目中 EventBus 采用全局单例 `AppEventBus`，基于 Dart `StreamController` 实现。

### 6.1 AppEventBus 实现

```dart
// lib/core/event_bus/app_event_bus.dart

class AppEventBus {
  AppEventBus._();
  static final instance = AppEventBus._();
  
  final _controller = StreamController<AppEvent>.broadcast();
  
  Stream<T> on<T extends AppEvent>() =>
      _controller.stream.whereType<T>();
  
  void fire(AppEvent event) => _controller.add(event);
  
  void dispose() => _controller.close();
}

abstract class AppEvent {
  const AppEvent();
}
```

---

### 6.2 Calendar Planner 事件定义

```dart
// lib/core/event_bus/calendar_events.dart

/// 单个事件创建完成
class CalendarEventCreated extends AppEvent {
  final int eventId;
  final DateTime eventDate;
  final String? source;
  const CalendarEventCreated({
    required this.eventId,
    required this.eventDate,
    this.source,
  });
}

/// 事件更新（含拖拽移动、字段修改）
class CalendarEventUpdated extends AppEvent {
  final int eventId;
  final DateTime eventDate;
  const CalendarEventUpdated({
    required this.eventId,
    required this.eventDate,
  });
}

/// 事件标记为已完成
class CalendarEventCompleted extends AppEvent {
  final int eventId;
  final int? subjectId;
  final String? taskId;       // 关联的 study-planner task id
  final String? mindmapNodeId; // 关联的思维导图节点 id
  const CalendarEventCompleted({
    required this.eventId,
    this.subjectId,
    this.taskId,
    this.mindmapNodeId,
  });
}

/// 事件取消完成（反向打卡）
class CalendarEventUncompleted extends AppEvent {
  final int eventId;
  const CalendarEventUncompleted({required this.eventId});
}

/// 批量事件创建完成（study-planner 等外部写入）
class CalendarEventsBatchCreated extends AppEvent {
  final int createdCount;
  final List<DateTime> affectedMonths;  // 受影响的月份列表
  final String source;
  const CalendarEventsBatchCreated({
    required this.createdCount,
    required this.affectedMonths,
    required this.source,
  });
}

/// 番茄钟完成一个周期
class PomodoroCompleted extends AppEvent {
  final int eventId;
  final int durationMinutes;
  final int sessionId;  // 写入的 study_sessions.id
  const PomodoroCompleted({
    required this.eventId,
    required this.durationMinutes,
    required this.sessionId,
  });
}
```

---

### 6.3 跨模块监听关系

| 事件 | 发布方 | 监听方 | 处理逻辑 |
|------|--------|--------|---------|
| `CalendarEventCompleted` | CalendarPage | study-planner | 更新 plan_item.status → done |
| `CalendarEventCompleted` | CalendarPage | 思维导图 | 更新 mindmap_node_states.is_lit → 1 |
| `CalendarEventsBatchCreated` | 后端 webhook / 前端 API 回调 | CalendarPage | 失效受影响月份缓存，刷新视图 |
| `PomodoroCompleted` | PomodoroTimerNotifier | CalendarPage | 更新事件 actual_duration_minutes |
| `CalendarEventCreated` | EventFormSheet | CalendarPage | 刷新当前视图 |


## 7. MiniApp 契约设计

Calendar Planner 遵循 MiniApp 标准化契约，支持全屏和弹窗两种模式。

### 7.1 MiniAppContract 接口

```dart
// lib/core/mini_app/mini_app_contract.dart

/// MiniApp 标准化入参
class MiniAppInput {
  final String sceneSource;    // 'user_active' | 'agent'
  final String renderMode;     // 'full' | 'modal'
  final Map<String, dynamic> params;
  
  const MiniAppInput({
    required this.sceneSource,
    this.renderMode = 'full',
    this.params = const {},
  });
}

/// MiniApp 标准化出参
class MiniAppResult {
  final bool success;
  final String? action;        // 'created' | 'updated' | 'cancelled'
  final Map<String, dynamic> data;
  
  const MiniAppResult({
    required this.success,
    this.action,
    this.data = const {},
  });
}

/// MiniApp 契约
abstract class MiniAppContract {
  MiniAppInput get input;
  void Function(MiniAppResult)? get onResult;
}
```

---

### 7.2 Calendar Planner 入参规范

```dart
// Calendar Planner 专用入参
class CalendarMiniAppInput extends MiniAppInput {
  final int? subjectId;        // 预选学科 ID
  final String? taskId;        // 关联的 study-planner 任务 ID
  final DateTime? prefillDate; // 预填日期
  final String? prefillTitle;  // 预填标题（Agent 提取）
  final String? prefillTime;   // 预填时间（Agent 提取，格式 "HH:mm"）
  final int? prefillDuration;  // 预填时长（分钟）
  
  const CalendarMiniAppInput({
    required super.sceneSource,
    super.renderMode = 'full',
    this.subjectId,
    this.taskId,
    this.prefillDate,
    this.prefillTitle,
    this.prefillTime,
    this.prefillDuration,
  });
}
```

---

### 7.3 modal 模式调用示例

```dart
// ChatPage 中 Agent 场景化调用
void _openCalendarModal(DetectedIntent intent) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CalendarPage(
      renderMode: 'modal',
      sceneSource: 'agent',
      prefillTitle: intent.params['title'] as String?,
      prefillDate: intent.params['date'] as DateTime?,
      prefillTime: intent.params['time'] as String?,
      subjectId: intent.params['subjectId'] as int?,
      onResult: (result) {
        if (result.success && result.action == 'created') {
          // 在对话流中插入确认消息
          final eventId = result.data['eventId'] as int;
          ref.read(chatProvider(_key).notifier).appendMessage(
            ChatMessage.local(
              role: MessageRole.assistant,
              content: '已添加到日历 ✓ [查看日历](/toolkit/calendar)',
            ),
          );
          // 发布 EventBus 事件
          AppEventBus.instance.fire(CalendarEventCreated(
            eventId: eventId,
            eventDate: result.data['eventDate'] as DateTime,
            source: 'agent',
          ));
        }
      },
    ),
  );
}
```

---

### 7.4 生命周期钩子

| 钩子 | 触发时机 | 说明 |
|------|---------|------|
| `onInit` | CalendarPage 初始化 | 加载入参，预填表单 |
| `onResult` | 用户确认/取消操作 | 回调调用方，传递操作结果 |
| `onDispose` | CalendarPage 销毁 | 清理计时器，保存草稿 |


## 8. 关键流程图

### 8.1 用户主动创建事件流程

```
用户点击工具箱「学习日历」卡片
  → context.push('/toolkit/calendar')
  → CalendarPage 初始化（renderMode: 'full'）
  → calendarEventsProvider 加载当前月事件
  → 同时预加载上月/下月数据
  → 渲染月视图（TableCalendar）
  → 用户点击 FAB「+」
  → EventFormSheet 弹出（默认「事件」类型）
  → 用户填写表单（标题、日期、时间、时长、学科）
  → 颜色自动继承学科颜色
  → 用户点击「保存」
  → POST /api/calendar/events
  → 成功 → AppEventBus.fire(CalendarEventCreated)
  → calendarEventsProvider 缓存失效
  → 视图自动刷新，新事件出现在对应日期格
```

---

### 8.2 Agent 场景化唤起流程

```
用户在答疑室输入「帮我把高数复习加到下周一」
  → RuleBasedIntentDetector.detect() 识别 IntentType.calendar
  → 提取参数：title='高数复习', date=下周一, subjectId=高数ID
  → ChatPage 插入 SceneCard(SceneType.calendar)
  → 显示「检测到日程需求，添加到日历？」
  → 用户点击「添加到日历」
  → showModalBottomSheet → CalendarPage(renderMode: 'modal', 预填参数)
  → 用户确认表单内容
  → POST /api/calendar/events（source: 'agent'）
  → 成功 → MiniAppContract.onResult(success: true, action: 'created')
  → 弹窗关闭，回到对话页
  → ChatPage 插入助教消息「已添加到日历 ✓」
  → AppEventBus.fire(CalendarEventCreated)
```

---

### 8.3 番茄钟学习流程

```
用户在 TodayPanel 点击某事件
  → 弹出事件详情面板
  → 用户点击「开始学习」
  → PomodoroTimerNotifier.start(event, durationMinutes: 25)
  → 底部悬浮计时条出现（显示剩余时间）
  → 用户可切换到其他页面，计时条保持显示
  
  [25分钟后]
  → PomodoroTimerNotifier._onPomodoroComplete()
  → POST /api/calendar/sessions（duration: 25, pomodoro_count: 1）
  → PATCH /api/calendar/events/{id}（actual_duration_minutes += 25）
  → AppEventBus.fire(PomodoroCompleted)
  → 检查 actual_duration >= duration_minutes？
    → 是 → PATCH is_completed: true
         → AppEventBus.fire(CalendarEventCompleted)
         → 检查今日所有事件是否全部完成？
           → 是 → 触发撒花动画，TodayPanel 显示「今日全部完成！」
    → 否 → 继续下一个番茄钟（5分钟休息）
```

---

### 8.4 study-planner 批量写入流程

```
study-planner 生成学习计划
  → 调用 POST /api/calendar/events/batch
  → 传入事件数组（source: 'study-planner'）
  → 后端逐条验证，写入 calendar_events
  → 返回写入结果（成功/失败各条）
  → 前端收到响应
  → AppEventBus.fire(CalendarEventsBatchCreated(affectedMonths: [...]))
  → calendarEventsProvider 失效受影响月份缓存
  → CalendarPage 自动刷新，新事件以「📋」图标标注来源
```

---

### 8.5 打卡完成跨模块同步流程

```
用户点击事件完成状态指示器
  → PATCH /api/calendar/events/{id}（is_completed: true）
  → AppEventBus.fire(CalendarEventCompleted(
      eventId: id,
      taskId: event.taskId,
      mindmapNodeId: event.mindmapNodeId,
    ))
  
  [study-planner 监听方]
  → 收到 CalendarEventCompleted
  → 若 taskId != null → PATCH /api/study-planner/tasks/{taskId}（status: done）
  
  [思维导图监听方]
  → 收到 CalendarEventCompleted
  → 若 mindmapNodeId != null → PATCH /api/mindmap/nodes/{nodeId}（is_lit: 1）
  
  [CalendarPage 本地]
  → 事件卡片更新为删除线 + 降低透明度样式
  → TodayPanel 完成率进度条更新
  → 月视图日期格颜色更新
```


## 9. 正确性属性

*属性（Property）是在系统所有合法执行中都应成立的特征或行为——本质上是对系统应做什么的形式化陈述。属性是人类可读规范与机器可验证正确性保证之间的桥梁。*

---

### 属性 1：事件颜色继承学科颜色

*对任意*学科，当创建关联该学科的事件且用户未手动修改颜色时，事件的 `color` 字段应等于该学科的 `SubjectColor`。

**验证：需求 2.5**

---

### 属性 2：拖拽后事件时间更新

*对任意*日历事件和任意合法目标时间段，将事件拖拽到目标时间段后，事件的 `event_date` 和 `start_time` 应等于目标时间段的日期和时间。

**验证：需求 3.4**

---

### 属性 3：倒计时横幅颜色分段规则

*对任意*剩余天数值 `d`，倒计时横幅的颜色应满足：`d > 30` 时为绿色，`10 ≤ d ≤ 30` 时为橙色，`d < 10` 时为红色，`d = 0` 时显示特殊文案而非颜色横幅。

**验证：需求 4.2、4.3**

---

### 属性 4：CountdownEvent 写入后可查询

*对任意*标记了 `is_countdown: true` 的事件，写入数据库后通过 `GET /api/calendar/events` 查询，返回结果中该事件的 `is_countdown` 字段应为 `true`。

**验证：需求 4.5**

---

### 属性 5：番茄钟完成写入 StudySession

*对任意*日历事件，完成一个完整番茄钟（25分钟）后，`study_sessions` 表中应新增一条记录，其 `event_id` 等于该事件 ID，`duration_minutes` 等于番茄钟时长，`pomodoro_count` 等于 1。

**验证：需求 5.3**

---

### 属性 6：手动停止写入实际时长

*对任意*已计时时长 `elapsed_seconds`，手动停止番茄钟后，写入 `study_sessions` 的 `duration_minutes` 应等于 `ceil(elapsed_seconds / 60)`（不足 1 分钟按 1 分钟计）。

**验证：需求 5.4**

---

### 属性 7：累计时长达标自动完成

*对任意*日历事件，当其 `actual_duration_minutes` 累计达到或超过 `duration_minutes` 时，事件的 `is_completed` 应自动变为 `true`，并触发 `CalendarEventCompleted` 事件。

**验证：需求 5.5**

---

### 属性 8：完成状态切换幂等性

*对任意*日历事件，连续两次点击完成状态指示器后，事件的 `is_completed` 应回到初始值（即两次取反等于不变）。

**验证：需求 6.2**

---

### 属性 9：月视图日期格颜色规则

*对任意*日期的事件集合，月视图日期格的颜色应满足：所有事件均已完成时为绿色，部分完成时为橙色，全部未完成时为灰色，无事件时无颜色标记。

**验证：需求 6.6**

---

### 属性 10：TodayPanel 事件排序

*对任意*今日事件集合，TodayPanel 中展示的事件顺序应与按 `start_time` 升序排列的结果完全一致。

**验证：需求 7.2**

---

### 属性 11：TodayPanel 完成率计算

*对任意*今日事件集合（总数 `total`，已完成数 `completed`），TodayPanel 进度条显示的百分比应等于 `completed / total`（total > 0 时），total = 0 时显示空状态。

**验证：需求 7.3、7.4**

---

### 属性 12：统计数据来源于 study_sessions

*对任意* `study_sessions` 记录集合，`GET /api/calendar/stats` 返回的每日学习时长应等于该日所有 session 的 `duration_minutes` 之和，学科占比应等于各学科 session 时长之和除以总时长。

**验证：需求 8.3**

---

### 属性 13：连续打卡徽章阈值

*对任意*连续打卡天数 `n`，当 `n ≥ 7` 时 StatsPanel 应显示连续打卡徽章，当 `n < 7` 时不显示。

**验证：需求 8.5**

---

### 属性 14：日历关键词意图识别

*对任意*包含关键词列表（「加到日历」「添加计划」「安排学习」「记到日历」「下周X」「明天X点」「提醒我」）中至少一个词语的输入字符串，`RuleBasedIntentDetector.detect()` 应返回 `IntentType.calendar`。

**验证：需求 9.1**

---

### 属性 15：批量写入全量持久化

*对任意*合法事件数组（1 到 100 条），调用 `POST /api/calendar/events/batch` 后，所有合法事件应写入 `calendar_events` 表，后续通过 `GET /api/calendar/events` 查询应能检索到所有写入的事件。

**验证：需求 10.1**

---

### 属性 16：批量写入独立验证

*对任意*包含部分非法事件（如 title 为空）的事件数组，批量写入后响应中合法事件的 `success` 应为 `true`，非法事件的 `success` 应为 `false` 并包含错误信息，且合法事件的写入不受非法事件影响。

**验证：需求 10.2**

---

### 属性 17：calendarEventsProvider 预加载相邻月份

*对任意*当前聚焦月份，`calendarEventsProvider` 在加载当前月数据时，应同时发起对上月和下月数据的请求（可通过检查 API 调用次数验证）。

**验证：需求 12.2**

---

### 属性 18：EventBus 触发缓存失效

*对任意* `CalendarEvent*` 类事件（Created/Updated/Completed/BatchCreated），发布后受影响日期范围的 `calendarEventsProvider` 缓存应失效，下次访问时触发重新加载。

**验证：需求 12.3**


## 10. 错误处理

### 10.1 前端错误处理

| 场景 | 处理策略 |
|------|---------|
| API 请求失败（网络错误） | 显示 SnackBar 提示「网络连接失败，请稍后重试」，保留用户输入数据，提供「重试」按钮 |
| 表单验证失败 | 在对应字段下方显示红色错误提示，禁用「保存」按钮直到验证通过 |
| 拖拽事件时间冲突 | 显示 SnackBar 提示「该时间段已有其他事件」，事件回弹到原位置 |
| 番茄钟运行中切换页面 | 计时器继续运行，悬浮计时条保持显示，用户可随时返回 |
| 批量写入部分失败 | 显示 Dialog 列出失败条目和原因，成功条目正常写入 |
| EventBus 监听方处理失败 | 记录错误日志，不影响主流程，后续通过后台同步任务补偿 |

---

### 10.2 后端错误处理

| 场景 | HTTP 状态码 | 响应体 |
|------|------------|--------|
| 未登录 | 401 | `{"detail": "未授权"}` |
| 访问他人数据 | 404 | `{"detail": "资源不存在"}` |
| 表单验证失败 | 422 | `{"detail": [{"loc": ["body", "title"], "msg": "不能为空"}]}` |
| 时长超出范围 | 422 | `{"detail": "duration_minutes 必须在 15-480 之间"}` |
| 数据库约束冲突 | 409 | `{"detail": "该时间段已有事件"}` |
| 服务器内部错误 | 500 | `{"detail": "服务器错误，请稍后重试"}` |

---

### 10.3 数据一致性保证

| 场景 | 保证机制 |
|------|---------|
| 例程生成事件实例 | 事务内批量插入，失败则全部回滚 |
| 番茄钟写入 session + 更新事件 | 事务内执行，确保原子性 |
| 批量写入事件 | 独立事务，单条失败不影响其他条目 |
| EventBus 跨模块同步 | 最终一致性，通过后台定时任务补偿失败的同步 |


## 11. 测试策略

### 11.1 单元测试

重点覆盖以下纯函数和业务逻辑：

- `_resolveColor()`：颜色继承逻辑（学科颜色 > 用户选择 > 默认色）
- `_countdownBannerColor(int daysLeft)`：倒计时颜色分段逻辑
- `_completionRate(int completed, int total)`：完成率计算
- `_sortEventsByStartTime(List<CalendarEvent>)`：事件排序
- `PomodoroTimerState` 状态转换：idle → focusing → resting → idle
- `CalendarStats` 聚合计算：每日时长求和、学科占比计算

---

### 11.2 属性测试（Property-Based Testing）

使用 `fast_check`（Dart）或 `hypothesis`（Python 后端）进行属性测试。每个属性测试最少运行 100 次迭代。

**前端属性测试**（`test/features/calendar/`）：

```dart
// 属性 3：倒计时横幅颜色分段规则
// Feature: calendar-planner, Property 3: 倒计时横幅颜色分段规则
test('countdown banner color follows segmentation rule', () {
  fc.assert(
    fc.property(fc.integer(min: 0, max: 365), (daysLeft) {
      final color = countdownBannerColor(daysLeft);
      if (daysLeft > 30) expect(color, equals(AppColors.success));
      else if (daysLeft >= 10) expect(color, equals(AppColors.warning));
      else if (daysLeft > 0) expect(color, equals(AppColors.error));
      else expect(color, isNull); // 今日显示特殊文案，无颜色
    }),
  );
});

// 属性 8：完成状态切换幂等性
// Feature: calendar-planner, Property 8: 完成状态切换幂等性
test('double toggle is_completed returns to original', () {
  fc.assert(
    fc.property(fc.boolean(), (initialCompleted) {
      final event = CalendarEvent(isCompleted: initialCompleted);
      final toggled = event.copyWith(isCompleted: !event.isCompleted);
      final doubleToggled = toggled.copyWith(isCompleted: !toggled.isCompleted);
      expect(doubleToggled.isCompleted, equals(initialCompleted));
    }),
  );
});

// 属性 10：TodayPanel 事件排序
// Feature: calendar-planner, Property 10: TodayPanel 事件排序
test('today panel events are sorted by start_time ascending', () {
  fc.assert(
    fc.property(fc.list(fc.calendarEventArb()), (events) {
      final sorted = sortEventsByStartTime(events);
      for (int i = 0; i < sorted.length - 1; i++) {
        expect(
          sorted[i].startTime.compareTo(sorted[i + 1].startTime),
          lessThanOrEqualTo(0),
        );
      }
    }),
  );
});
```

**后端属性测试**（`backend/tests/test_calendar_properties.py`）：

```python
# 属性 15：批量写入全量持久化
# Feature: calendar-planner, Property 15: 批量写入全量持久化
@given(st.lists(valid_event_strategy(), min_size=1, max_size=100))
@settings(max_examples=100)
def test_batch_create_all_persisted(events):
    response = client.post("/api/calendar/events/batch", json={"events": events})
    assert response.status_code == 200
    result = response.json()
    assert result["created_count"] == len(events)
    # 验证所有事件可查询
    for event in events:
        query = client.get(f"/api/calendar/events?start_date={event['event_date']}")
        titles = [e["title"] for e in query.json()["events"]]
        assert event["title"] in titles

# 属性 16：批量写入独立验证
# Feature: calendar-planner, Property 16: 批量写入独立验证
@given(
    st.lists(valid_event_strategy(), min_size=1, max_size=50),
    st.lists(invalid_event_strategy(), min_size=1, max_size=50),
)
@settings(max_examples=100)
def test_batch_create_independent_validation(valid_events, invalid_events):
    mixed = valid_events + invalid_events
    random.shuffle(mixed)
    response = client.post("/api/calendar/events/batch", json={"events": mixed})
    result = response.json()
    assert result["created_count"] == len(valid_events)
    assert result["failed_count"] == len(invalid_events)
```

---

### 11.3 集成测试

- `GET /api/calendar/events` 端点可访问，返回正确结构
- `POST /api/calendar/sessions` 写入后 `GET /api/calendar/stats` 数据更新
- EventBus `CalendarEventCompleted` 发布后 study-planner 状态同步（端到端）
- 例程创建后自动生成对应日期的事件实例

---

### 11.4 Smoke 测试

- `kDefaultTools` 中存在 `id='calendar'` 的 ToolItem
- `R.toolkitCalendar` 路由常量已定义
- `SceneType.calendar` 枚举值已定义，颜色为 `Color(0xFF6366F1)`
- 数据库表 `calendar_events`、`calendar_routines`、`study_sessions` 已创建
- 所有 REST 端点返回 200/201/204（非 404/500）

---

### 11.5 依赖库

| 库 | 用途 |
|----|------|
| `table_calendar: ^3.2.0` | 月视图底座 |
| `timetable: latest` | 日/周时间轴视图，拖拽支持 |
| `flutter_local_notifications: latest` | 本地提醒通知 |
| `fast_check` (Dart) | 前端属性测试 |
| `hypothesis` (Python) | 后端属性测试 |

