# 设计文档：大型学习规划（Study Planner）

## 概述

Study Planner 基于现有 Multi-Agent Council 框架，在 Flutter + FastAPI 项目上叠加一套「规划生成 → 引导学习 → 静默同步 → 行为监控」的完整闭环。

核心设计原则：
- **最小侵入**：复用现有 `StudyPlan`/`PlanItem` ORM 模型、`council` 路由、`MindmapNodeState` 表、`MemoryService`
- **渐进增强**：自由学习是默认状态，规划是叠加层，不替代现有对话流
- **前后端分离**：后端负责 Multi-Agent 规划逻辑，前端负责三阶段视图和本地监控

---

## 架构总览

```
前端 (Flutter + Riverpod)
├── lib/features/spec/
│   ├── spec_page.dart              # 三阶段视图主页面
│   ├── models/study_plan_models.dart
│   ├── providers/study_planner_providers.dart
│   ├── services/study_planner_api_service.dart
│   └── widgets/
│       ├── phase_chat_view.dart    # 阶段1：对话收集
│       ├── phase_progress_view.dart # 阶段2：规划进度
│       ├── phase_plan_view.dart    # 阶段3：计划表
│       └── today_task_card.dart    # 答疑室今日任务卡片
├── lib/features/chat/
│   └── chat_page.dart              # 新增：意图识别 + TodayTaskCard 插入
└── lib/services/
    ├── intent_detector.dart        # 新增 spec 关键词
    └── level1_monitor.dart         # Level 1 本地埋点

后端 (FastAPI + SQLAlchemy)
├── backend/routers/
│   ├── study_planner.py            # 新增：/api/study-planner/* 端点
│   └── council.py                  # 新增：/api/council/subject/node-analysis
└── backend/services/
    └── study_planner_service.py    # Multi-Agent 规划逻辑
```

---

## 数据库设计

### 现有表（无需修改）

`study_plans` 和 `plan_items` 已在 `database.py` 中定义为 `StudyPlan` 和 `PlanItem` ORM 模型，字段完全满足需求：

**study_plans**
```
id, user_id, name, target_subjects (JSONB), deadline, daily_minutes,
status (draft/active/completed/abandoned), created_at, updated_at
```

**plan_items**
```
id, plan_id, subject_id, node_id, node_text, estimated_minutes,
priority (high/medium/low), dependency_node_ids (JSONB),
planned_date, status (pending/done/skipped), completed_at
```

**mindmap_node_states**（已有，只读）
```
id, user_id, session_id, node_id, is_lit, updated_at
```

### 无需新增迁移

所有需要的表已在 `database.py` 中通过 `init_db()` 自动创建。

---

## 后端设计

### 1. 新增路由：`backend/routers/study_planner.py`

挂载在 `/api/study-planner`，所有端点复用 `get_current_user` 依赖。

#### 端点列表

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/plans` | 触发 Multi-Agent 规划，返回 study_plan |
| GET | `/plans/active` | 获取当前 active 计划及所有 plan_items |
| GET | `/plans/today` | 获取今日 plan_items |
| PATCH | `/plans/{plan_id}/items/{item_id}` | 更新单个 plan_item 状态 |
| PATCH | `/plans/{plan_id}/status` | 更新计划状态（abandoned） |
| GET | `/plans/{plan_id}/summary` | 获取计划摘要 |
| GET | `/plans/{plan_id}/progress` | 轮询规划进度（异步场景） |
| POST | `/notify/register` | Level 3 占位端点 |
| POST | `/notify/send` | Level 3 占位端点 |

#### POST /plans 流程

```
1. 验证用户无 active 计划（否则 409）
2. 创建 study_plan（status=draft）
3. 同步调用 StudyPlannerService.generate_plan()
   - 超时 60s → 返回 202 + plan_id，前端轮询 /progress
   - 成功 → 返回完整 study_plan（status=active）
```

#### 节点分析端点（新增到 council.py）

`GET /api/council/subject/node-analysis?subject_id={id}`

```python
# 查询逻辑：
# 1. 获取该学科所有 mindmap session（session_type='mindmap'）
# 2. 从 conversation_history 解析节点树
# 3. 与 mindmap_node_states 对比，筛选 is_lit=0 或无记录的节点
# 4. 从 MemoryService 获取 weak_points，提升对应节点优先级
# 5. 调用 LLM 为每个节点标注预估时长和优先级
# 返回：{has_mindmap: bool, nodes: [{node_id, text, depth, parent_id, estimated_minutes, priority}]}
```

### 2. StudyPlannerService（`backend/services/study_planner_service.py`）

```python
class StudyPlannerService:
    def generate_plan(
        self,
        plan_id: int,
        user_id: int,
        subject_ids: list[int],
        deadline: datetime,
        daily_minutes: int,
    ) -> StudyPlan:
        """
        Multi-Agent 规划流程：
        1. 并行调用 SubjectAgent（每个学科一个线程）
           - 调用 node-analysis 端点获取 unlitNode 列表
           - 超时 30s 标记失败
        2. 聚合各科输出
        3. 调用 AcademicAgent 排期
           - 遵守依赖关系（拓扑排序）
           - 均衡分配（单科 ≤ 60% 每日时长）
           - 时间不足时优先排 high 优先级节点
        4. 批量写入 plan_items
        5. 更新 study_plan.status = 'active'
        """

    def sync_node_completion(
        self,
        user_id: int,
        node_id: str,
        session_id: int,
    ) -> None:
        """
        静默同步：节点点亮时自动更新对应 plan_item。
        在 library.py 的 upsert_node_states 端点中调用。
        """

    def check_plan_completion(self, plan_id: int) -> bool:
        """检查计划是否全部完成，触发 completed 状态变更。"""
```

#### SubjectAgent 逻辑

```python
def _run_subject_agent(subject_id: int, user_id: int) -> SubjectAnalysis:
    """
    1. 查询 mindmap_node_states（is_lit=0 或无记录）
    2. 从 MemoryService 获取 weak_points
    3. 调用 LLM 标注优先级和预估时长
    4. 构建依赖关系（基于节点树的父子关系）
    """
```

#### AcademicAgent 排期算法

```python
def _schedule_items(
    nodes: list[AnnotatedNode],
    deadline: datetime,
    daily_minutes: int,
) -> list[ScheduledItem]:
    """
    1. 拓扑排序（依赖关系）
    2. 贪心分配：
       - 按日期从今天到 deadline 遍历
       - 每日剩余时长 = daily_minutes
       - 单科占比 ≤ 60%（即 ≤ daily_minutes * 0.6）
       - 优先填入 high 优先级节点
    3. 时间不足时记录 gap_minutes
    """
```

### 3. 静默同步钩子

在 `backend/routers/library.py` 的 `upsert_node_states` 端点末尾添加：

```python
# 静默同步：如果节点被点亮，检查是否有对应 plan_item
for item in body.states:
    if item.is_lit:
        StudyPlannerService().sync_node_completion(
            user_id=user["id"],
            node_id=item.node_id,
            session_id=session_id,
        )
```

---

## 前端设计

### 1. 数据模型（`lib/features/spec/models/study_plan_models.dart`）

```dart
class StudyPlan {
  final int id;
  final String name;
  final List<TargetSubject> targetSubjects;
  final DateTime deadline;
  final int dailyMinutes;
  final String status; // draft/active/completed/abandoned
  final List<PlanItem> items;
  final DateTime createdAt;
}

class PlanItem {
  final int id;
  final int planId;
  final int? subjectId;
  final String? subjectName;
  final String nodeId;
  final String nodeText;
  final int estimatedMinutes;
  final String priority; // high/medium/low
  final List<String> dependencyNodeIds;
  final DateTime? plannedDate;
  final String status; // pending/done/skipped
  final DateTime? completedAt;
}

class PlanSummary {
  final int totalItems;
  final int completedItems;
  final int daysRemaining;
  final double todayCompletionRate;
  final List<PlanItem> todayItems;
}
```

### 2. API 服务（`lib/features/spec/services/study_planner_api_service.dart`）

```dart
class StudyPlannerApiService {
  Future<StudyPlan> createPlan({...});
  Future<StudyPlan?> getActivePlan();
  Future<List<PlanItem>> getTodayItems();
  Future<void> updateItemStatus(int planId, int itemId, String status);
  Future<void> updatePlanStatus(int planId, String status);
  Future<PlanSummary> getPlanSummary(int planId);
  Future<Map<String, dynamic>> getPlanProgress(int planId);
}
```

### 3. Riverpod Providers（`lib/features/spec/providers/study_planner_providers.dart`）

```dart
// 当前 active 计划（全局单例，多处复用）
final activePlanProvider = FutureProvider<StudyPlan?>(...);

// 今日任务（供 TodayTaskCard 使用）
final todayPlanItemsProvider = FutureProvider<List<PlanItem>>(...);

// 计划摘要
final planSummaryProvider = FutureProvider.family<PlanSummary, int>(...);

// 规划进度（轮询，仅在 draft 状态时激活）
final planProgressProvider = StreamProvider.family<Map<String, dynamic>, int>(...);

// Spec 页面阶段状态
enum SpecPhase { chat, progress, plan }
final specPhaseProvider = StateProvider<SpecPhase>(...);

// 对话收集状态
final specChatMessagesProvider = StateNotifierProvider<SpecChatNotifier, List<ChatMessage>>(...);
```

### 4. SpecPage 三阶段视图（`lib/features/spec/spec_page.dart`）

```dart
class SpecPage extends ConsumerStatefulWidget {
  // 从 ChatPage 传入的上下文（已识别的学科信息）
  final List<int>? prefilledSubjectIds;
  final String? prefilledContext;
}
```

**阶段切换逻辑：**
```
进入 /spec
  ├── 有 active 计划 → 直接进入 Phase.plan
  └── 无 active 计划 → Phase.chat
        ↓ 用户确认规划信息
      Phase.progress（显示 Agent 执行状态）
        ↓ 规划完成
      Phase.plan（计划表视图）
```

**Phase 1 - 对话收集视图（`phase_chat_view.dart`）：**
- 复用 `ChatPage` 的气泡列表样式（`ListView` + 气泡 Widget）
- 底部 `_InputBar` 组件（与 ChatPage 保持一致）
- 助教消息通过本地状态管理（不调用后端 chat 端点）
- 收集完成后展示摘要确认卡片

**Phase 2 - 规划进度视图（`phase_progress_view.dart`）：**
- 每个学科一个状态卡片（等待中/分析中/已完成/失败）
- 整体进度条（已完成 Subject_Agent 数 / 总数）
- 失败学科显示重试按钮
- 通过 `planProgressProvider` 轮询后端进度

**Phase 3 - 计划表视图（`phase_plan_view.dart`）：**
- 顶部摘要卡片（总节点数、已完成、剩余天数、今日完成率）
- 按日期分组的 `SliverList`
- 每个 `PlanItemTile`：节点文本、学科色标、预估时长、优先级标签、完成状态
- 滑动操作：标记完成 / 跳过
- 底部「放弃计划」按钮（二次确认）

**视觉风格：**
- 与 `ToolkitPage` 保持一致：`AppColors` 主题色、圆角卡片（`BorderRadius.circular(12)`）
- 优先级色标：high=红色、medium=橙色、low=绿色
- 学科色标复用 `CalendarEvent.color` 的颜色体系

### 5. TodayTaskCard（`lib/features/spec/widgets/today_task_card.dart`）

```dart
class TodayTaskCard extends ConsumerWidget {
  // 插入到 ChatPage 空状态区域（默认提示词上方）
  // 条件：有 active 计划 && 今日有 pending items && 用户未关闭
}
```

**展示逻辑：**
- 今日前 3 条 pending items
- 每条：节点文本 + 学科色标 + 预估时长
- 点击任务 → `context.push(R.chatSubject(newChatId, subjectId))`，预填节点文本
- 「查看完整计划」→ `context.push(R.spec)`
- 关闭按钮 → 写入 SharedPreferences（`today_task_card_dismissed_date`），当日不再展示

**关闭状态持久化：**
```dart
// SharedPreferences key: 'today_task_card_dismissed_date'
// 值：ISO 日期字符串（如 '2025-01-15'）
// 判断：dismissed_date == today → 不展示
```

### 6. 意图识别扩展（`lib/services/intent_detector.dart`）

在现有 `RuleBasedIntentDetector` 中新增 spec 关键词检测：

```dart
// 新增 spec 关键词列表
static const _specKeywords = [
  '系统学习', '完整计划', '从零开始', '全面掌握', '系统掌握', '完整课程',
];

// 新增检测方法
bool detectSpecIntent(String message) {
  return _specKeywords.any((kw) => message.contains(kw));
}
```

**ChatPage 集成：**
- 仅在 `widget.subjectId == null && widget.taskId == null` 时触发
- 已有 active 计划时，SceneCard 按钮文案改为「查看当前计划」
- 同一条消息只触发一次（通过消息 ID 去重）

### 7. Level 1 本地监控（`lib/services/level1_monitor.dart`）

```dart
class Level1Monitor {
  static const _prefs_prefix = 'l1_monitor_';

  // 记录行为事件
  Future<void> recordNodeClick(String nodeId);
  Future<void> recordNodeClickWithoutCompletion(String nodeId);
  Future<void> recordSpecPageDuration(int seconds);

  // 计算今日完成率
  Future<double> calcTodayCompletionRate(List<PlanItem> todayItems);

  // 记录无学习行为的连续时长
  Future<void> updateIdleMinutes(int minutes);

  // 读取数据（供 Level 2 Monitor 使用）
  Future<Map<String, dynamic>> getTodayStats();

  // 每日重置（App 启动时调用）
  Future<void> resetDailyCounters();

  // 清理 7 天前的历史数据
  Future<void> pruneOldData();
}
```

**SharedPreferences 键设计：**
```
l1_monitor_node_clicks_{date}          → int（今日节点点击次数）
l1_monitor_incomplete_clicks_{date}    → int（点击未完成次数）
l1_monitor_spec_duration_{date}        → int（Spec 页停留秒数）
l1_monitor_completion_rate_{date}      → double（今日完成率）
l1_monitor_idle_minutes_{date}         → int（无学习行为连续分钟）
l1_monitor_last_activity_{date}        → ISO 时间戳（最后活跃时间）
```

### 8. Level 2 监控（集成到 SpecPage / ChatPage）

```dart
class Level2Monitor {
  // 触发条件检查（在 App 前台时定时检查，每 5 分钟一次）
  Future<void> checkAndTrigger(BuildContext context, WidgetRef ref);

  // 触发助教气泡
  Future<void> _showCompanionBubble(BuildContext context, String message);

  // 防抖：同一条件 30 分钟内最多触发一次
  // SharedPreferences key: 'l2_last_trigger_{condition_type}'
}
```

**触发条件：**
1. 今日完成率 < 50% && 当前时间 > 今日计划结束时间
2. 无学习行为连续时长 > 15 分钟

**气泡 UI：**
- 浮层组件，显示在当前页面右下角
- 助教头像 + 提示文案 + 关闭按钮
- 视觉风格与 `SceneCard` 保持一致

---

## 关键流程时序

### 规划生成流程

```
用户确认规划信息
  → SpecPage 切换到 Phase.progress
  → POST /api/study-planner/plans
      → 后端创建 study_plan (draft)
      → StudyPlannerService.generate_plan() (async)
          → 并行 SubjectAgent × N
              → GET /api/council/subject/node-analysis?subject_id=X
              → 返回 unlitNode 列表 + 优先级标注
          → AcademicAgent 排期
          → 批量写入 plan_items
          → study_plan.status = 'active'
      → 60s 内完成 → 200 + study_plan
      → 超时 → 202 + plan_id
  → 前端收到 202 → 开始轮询 GET /plans/{id}/progress
  → 规划完成 → SpecPage 切换到 Phase.plan
```

### 静默同步流程

```
用户在学科对话中点亮节点
  → POST /api/library/sessions/{id}/node-states
      → upsert_node_states()
      → 钩子：StudyPlannerService.sync_node_completion()
          → 查询 active plan_items WHERE node_id = X AND status = 'pending'
          → 更新 status = 'done', completed_at = now()
          → check_plan_completion() → 如果全完成，status = 'completed'
  → 前端 invalidate todayPlanItemsProvider
  → TodayTaskCard 自动刷新
```

### 今日任务卡片展示流程

```
ChatPage 加载（通用对话模式）
  → ref.watch(activePlanProvider)
  → 有 active 计划 → ref.watch(todayPlanItemsProvider)
  → 有 pending items → 检查 SharedPreferences dismissed_date
  → 未关闭 → 展示 TodayTaskCard
```

---

## 路由参数传递

`/spec` 路由需要支持从 ChatPage 传入上下文参数：

```dart
// app_router.dart 修改
GoRoute(
  path: R.spec,
  builder: (_, state) => SpecPage(
    prefilledSubjectIds: (state.uri.queryParameters['subjects'] ?? '')
        .split(',')
        .where((s) => s.isNotEmpty)
        .map(int.tryParse)
        .whereType<int>()
        .toList(),
    prefilledContext: state.uri.queryParameters['context'],
  ),
),
```

---

## 错误处理策略

| 场景 | 处理方式 |
|------|---------|
| 某学科无导图数据 | Subject_Agent 标记 `has_mindmap: false`，进度视图提示用户先生成导图 |
| Subject_Agent 超时（>30s） | 标记失败，显示重试按钮，允许跳过该学科继续规划 |
| 规划整体超时（>60s） | 返回 202，前端轮询 `/progress` 端点 |
| companion_observe 失败 | Level 2 Monitor 展示本地兜底文案 |
| 创建计划时已有 active 计划 | 返回 409，前端提示用户先完成或放弃当前计划 |
| 网络请求失败 | Riverpod AsyncValue.error 状态，展示重试按钮 |

---

## 正确性属性

### 属性 1：计划状态机不变量（不变量）

对于任意 `study_plan`，以下状态转换不变量必须成立：
- `draft → active`：仅在 `generate_plan()` 成功后
- `active → completed`：仅在所有 `plan_items.status ∈ {done, skipped}` 时
- `active → abandoned`：仅在用户主动触发时
- 同一用户同一时刻最多一个 `active` 计划

**测试方式**：集成测试（示例），验证状态转换的前置条件和后置条件。

### 属性 2：静默同步幂等性（幂等性）

对于同一个 `node_id`，多次调用 `sync_node_completion()` 的结果与调用一次相同：
- `plan_item.status` 最终为 `done`
- `completed_at` 记录第一次完成时间，不被覆盖

**测试方式**：单元测试（示例），调用两次验证结果一致。

### 属性 3：排期时间约束（不变量）

对于任意生成的 `plan_items`：
- 所有 `planned_date ≤ deadline`
- 同一天内同一学科的 `estimated_minutes` 之和 ≤ `daily_minutes × 0.6`
- 同一天内所有学科的 `estimated_minutes` 之和 ≤ `daily_minutes`

**测试方式**：属性测试（property-based），对随机输入验证排期约束。

### 属性 4：节点依赖顺序（不变量）

对于任意有依赖关系的节点对 `(A, B)`，若 `B.dependency_node_ids` 包含 `A.node_id`，则 `A.planned_date ≤ B.planned_date`。

**测试方式**：属性测试（property-based），对随机节点图验证拓扑排序正确性。

### 属性 5：Level 1 监控数据完整性（不变量）

`l1_monitor_completion_rate_{date}` 的值 = `done_items_count / total_today_items_count`，且始终在 `[0.0, 1.0]` 范围内。

**测试方式**：单元测试（示例），验证计算逻辑。

### 属性 6：TodayTaskCard 关闭状态持久化（轮次属性）

关闭 `TodayTaskCard` 后，当日内重新进入 ChatPage，卡片不再展示；次日进入，卡片重新展示（若有 pending items）。

**测试方式**：集成测试（示例），模拟日期变化验证展示逻辑。
