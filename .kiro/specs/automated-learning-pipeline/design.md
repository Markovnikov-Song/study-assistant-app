# Design Document

## 自动化全链路学习规划 - 技术设计

### 1. 系统架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Flutter (Frontend)                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     Chat Page                                    │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌────────────────────────┐  │   │
│  │  │ Intent      │  │ Params      │  │ Planning               │  │   │
│  │  │ Detector    │→ │ Collector   │→ │ Flow Controller        │  │   │
│  │  └─────────────┘  └─────────────┘  └────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐   │
│  │ Study Plan       │   │ Calendar         │   │ Notification     │   │
│  │ Provider         │   │ Service          │   │ Service          │   │
│  └──────────────────┘   └──────────────────┘   └──────────────────┘   │
│                                                                          │
│  ┌──────────────────┐   ┌──────────────────┐                          │
│  │ Skill            │   │ Home             │                          │
│  │ Launcher         │   │ Dashboard        │                          │
│  └──────────────────┘   └──────────────────┘                          │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │ HTTP/WebSocket
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Backend (Python)                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  CAS Dispatch Pipeline (扩展)                                    │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │  │
│  │  │ Intent       │  │ Parameter    │  │ Multi-Turn           │  │  │
│  │  │ Mapper       │→ │ Extractor    │→ │ Collector            │  │  │
│  │  └──────────────┘  └──────────────┘  └──────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐   │
│  │ Knowledge        │   │ Study Plan       │   │ Skill            │   │
│  │ Navigator        │   │ Generator        │   │ Dispatcher       │   │
│  └──────────────────┘   └──────────────────┘   └──────────────────┘   │
│                                                                          │
│  ┌──────────────────┐   ┌──────────────────┐                          │
│  │ Adaptive         │   │ Notification     │                          │
│  │ Loop             │   │ Scheduler        │                          │
│  └──────────────────┘   └──────────────────┘                          │
│                                                                          │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Database                                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  study_plans                                                            │
│  ├─ id, user_id, subject_id, title, status (active/completed/adjusted)│
│  ├─ deadline, knowledge_navigation (JSON), daily_tasks (JSONB[])      │
│  ├─ created_at, updated_at                                             │
│                                                                          │
│  daily_tasks                                                            │
│  ├─ id, plan_id, date, title, node_id, skill_id, duration_minutes     │
│  ├─ status (pending/completed/skipped), calendar_event_id             │
│                                                                          │
│  plan_adjustments                                                       │
│  ├─ id, plan_id, adjustment_type, reason, old_value, new_value        │
│  ├─ triggered_by (user/auto), created_at                              │
│                                                                          │
│  node_skill_mapping                                                     │
│  ├─ id, node_id, skill_id, phase (learn/practice/review), weight      │
│                                                                          │
│  knowledge_navigations (缓存)                                           │
│  ├─ id, subject_id, scope, nodes (JSON), created_at                   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2. 核心数据模型

#### 2.1 PlanningParams (Backend)

```python
from dataclasses import dataclass
from typing import Optional
from datetime import date

@dataclass
class PlanningParams:
    subject_id: int
    subject_name: str
    exam_date: date
    exam_scope: str  # "全书" / "前五章"
    daily_hours: float = 2.0
    target_score: Optional[int] = None
    
    # 内部状态
    collected_params: dict = None  # 已收集的参数
    missing_params: list = None    # 缺失的参数
    
    def __post_init__(self):
        self.collected_params = {}
        self.missing_params = []
```

#### 2.2 StudyPlan (Backend)

```python
class StudyPlan(Base):
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'))
    subject_id = Column(Integer, ForeignKey('subjects.id'))
    
    title = Column(String(256))  # "材料力学 - 期末备考计划"
    status = Column(String(32))  # "pending_confirm" / "active" / "paused" / "completed" / "adjusted"
    
    deadline = Column(Date)  # 考试日期
    knowledge_navigation = Column(JSON)  # 知识导航节点列表
    
    # 每日任务 (JSONB 数组)
    # [
    #   {"date": "2026-06-01", "tasks": [
    #     {"nodeId": "L1_chap1", "title": "力的基本概念", "skill": "mindmap", "duration": 30}
    #   ]}
    # ]
    daily_tasks = Column(JSONB)
    
    created_at = Column(DateTime)
    updated_at = Column(DateTime)
```

#### 2.3 DailyTask (Backend)

```python
class DailyTask(Base):
    id = Column(Integer, primary_key=True)
    plan_id = Column(Integer, ForeignKey('study_plans.id'))
    
    task_date = Column(Date)
    title = Column(String(256))
    node_id = Column(String(128))  # 关联知识节点
    skill_id = Column(String(64))  # 推荐使用的 Skill
    duration_minutes = Column(Integer)
    
    status = Column(String(32))  # "pending" / "completed" / "skipped"
    calendar_event_id = Column(String(128))  # 日历事件 ID
    
    completed_at = Column(DateTime)
    wrong_answer_count = Column(Integer, default=0)
```

### 3. 核心流程设计

#### 3.1 意图识别与参数提取流程

```python
async def handle_planning_input(text: str, user_id: int) -> PlanningResult:
    # Step 1: 基础意图检测
    intent = await intent_detector.detect(text)
    if intent.type != 'planning':
        return PlanningResult(type='not_planning', ...)
    
    # Step 2: 参数提取
    params = await param_extractor.extract(text)
    
    # Step 3: 检查缺失参数
    missing = []
    if not params.subject_id:
        missing.append('subject')
    if not params.exam_date:
        missing.append('exam_date')
    if not params.exam_scope:
        missing.append('exam_scope')
    
    # Step 4: 返回结果
    if missing:
        return PlanningResult(
            type='need_params',
            missing_params=missing,
            collected_params=params
        )
    else:
        return PlanningResult(
            type='ready_to_plan',
            params=params
        )
```

#### 3.2 多轮对话状态机

```dart
enum MultiTurnState {
  initial,           // 初始状态，等待用户输入
  collectingSubject, // 收集学科
  collectingDate,    // 收集考试日期
  collectingScope,   // 收集考试范围
  collectingHours,   // 收集每日时长（可选）
  confirmed,         // 用户确认
  cancelled          // 用户取消
}

class ParamsCollector {
  MultiTurnState state = MultiTurnState.initial;
  PlanningParams params = PlanningParams();
  
  String getNextPrompt() {
    switch (state) {
      case MultiTurnState.initial:
        return "好的，您想备考哪门科目？";
      case MultiTurnState.collectingSubject:
        return "请问您计划什么时间考试？";
      case MultiTurnState.collectingDate:
        return "考试范围是全书还是特定章节？";
      case MultiTurnState.collectingScope:
        return "每天能投入多少时间学习？（可选，默认 2 小时）";
      default:
        return "好的，我已了解您的学习目标，正在生成计划...";
    }
  }
}
```

#### 3.3 知识导航生成

```python
async def generate_knowledge_navigation(
    subject_id: int,
    exam_scope: str,
    deadline: date
) -> KnowledgeNavigation:
    # 尝试获取预设路径
    preset_path = await learning_path_service.get_preset_path(subject_id)
    
    if preset_path and matches_scope(preset_path, exam_scope):
        # 使用预设路径，过滤考试范围外的节点
        return filter_by_scope(preset_path, exam_scope)
    else:
        # 调用 LLM 生成
        return await llm.generate_navigation(
            subject_id=subject_id,
            exam_scope=exam_scope,
            days_left=(deadline - date.today()).days
        )
```

#### 3.4 学习计划生成

```python
async def generate_study_plan(
    params: PlanningParams,
    knowledge_nav: KnowledgeNavigation
) -> StudyPlan:
    days_left = (params.exam_date - date.today()).days
    
    # 计算每日任务分配
    daily_tasks = []
    current_week = 1
    
    for node in knowledge_nav.nodes:
        # 阶段 1-2: 基础阶段 (前 60% 时间)
        # 阶段 3: 强化阶段 (30% 时间)
        # 阶段 4: 冲刺阶段 (10% 时间)
        
        phase = get_phase(current_week, days_left)
        task = DailyTask(
            node_id=node.id,
            title=node.title,
            skill=get_recommended_skill(node.id, phase),
            duration=calculate_duration(node, params.daily_hours),
            phase=phase
        )
        daily_tasks.append(task)
    
    # 创建计划
    plan = StudyPlan(
        user_id=params.user_id,
        subject_id=params.subject_id,
        title=f"{params.subject_name} - 备考计划",
        deadline=params.exam_date,
        knowledge_navigation=knowledge_nav.to_json(),
        daily_tasks=daily_tasks_to_json(daily_tasks),
        status='pending_confirm'
    )
    
    return plan
```

#### 3.5 自适应调整算法

```python
async def adaptive_adjustment(
    plan_id: int,
    wrong_answers: List[WrongAnswer]
) -> AdjustedPlan:
    plan = await get_plan(plan_id)
    
    # Step 1: 分析错题涉及的知识点
    weak_nodes = []
    for wa in wrong_answers:
        nodes = await map_question_to_nodes(wa.question_id)
        for node in nodes:
            # 标记为薄弱点
            node.mastery_level = max(0, node.mastery_level - 10)
            weak_nodes.append(node.id)
    
    # Step 2: 调整后续任务
    adjustments = []
    for task in plan.daily_tasks:
        if task.node_id in weak_nodes:
            # 延长该知识点的学习时间
            task.duration_minutes *= 1.5
            adjustments.append({
                'type': 'extend_duration',
                'node_id': task.node_id,
                'old_duration': task.duration_minutes / 1.5,
                'new_duration': task.duration_minutes
            })
            
            # 插入复习任务（如果还没有）
            if not has_review_task(plan, task.node_id):
                review_task = create_review_task(task.node_id, after_days=3)
                plan.daily_tasks.append(review_task)
                adjustments.append({
                    'type': 'add_review',
                    'node_id': task.node_id
                })
    
    # Step 3: 记录调整历史
    await record_adjustments(plan_id, adjustments)
    
    # Step 4: 更新计划状态
    plan.status = 'adjusted'
    plan.updated_at = datetime.now()
    
    return AdjustedPlan(plan=plan, adjustments=adjustments)
```

### 4. API 接口设计

#### 4.1 意图检测与参数提取

```
POST /api/cas/dispatch
Body: {"text": "我要备考材料力学，下个月期末考试"}

Response:
{
  "action_id": "make_plan",
  "params": {
    "subject_name": "材料力学",
    "exam_date": null,  // 需要提取
    "exam_scope": null,
    "daily_hours": 2.0
  },
  "missing_params": ["exam_date", "exam_scope"],
  "render_type": "param_fill"
}
```

#### 4.2 补充参数

```
POST /api/planning/params
Body: {
  "session_id": "abc123",
  "params": {"exam_date": "2026-06-15", "exam_scope": "前五章"}
}

Response:
{
  "status": "complete",
  "ready_for_plan": true
}
```

#### 4.3 生成知识导航

```
POST /api/planning/knowledge-navigation
Body: {
  "subject_id": 1,
  "exam_scope": "前五章",
  "deadline": "2026-06-15"
}

Response:
{
  "navigation_id": 1,
  "nodes": [
    {"nodeId": "L1_chap1", "title": "力的基本概念", "priority": "core", "prerequisites": [], "hours": 2},
    {"nodeId": "L1_chap1_sec1", "title": "力的平衡条件", "priority": "core", "prerequisites": ["L1_chap1"], "hours": 1.5}
  ]
}
```

#### 4.4 生成学习计划

```
POST /api/planning/plans
Body: {
  "subject_id": 1,
  "deadline": "2026-06-15",
  "daily_hours": 2.0,
  "knowledge_navigation_id": 1
}

Response:
{
  "plan_id": 1,
  "title": "材料力学 - 期末备考计划",
  "stages": [
    {"name": "基础阶段", "week": "第1-2周", "tasks_count": 8},
    {"name": "强化阶段", "week": "第3-4周", "tasks_count": 10},
    {"name": "冲刺阶段", "week": "第5周", "tasks_count": 5}
  ],
  "daily_tasks_preview": [
    {"date": "2026-05-12", "tasks": [{"title": "力的基本概念", "skill": "mindmap", "duration": 30}]}
  ]
}
```

#### 4.5 确认并执行计划

```
POST /api/planning/plans/{plan_id}/confirm

Response:
{
  "status": "active",
  "calendar_synced": true,
  "notifications_scheduled": true,
  "first_task": {
    "date": "2026-05-12",
    "title": "力的基本概念",
    "skill_id": "mindmap_learning"
  }
}
```

#### 4.6 错题反馈与调整

```
POST /api/planning/plans/{plan_id}/feedback
Body: {
  "question_id": 123,
  "is_correct": false,
  "wrong_answer": "B"
}

Response:
{
  "adjustments": [
    {"type": "extend_duration", "node_id": "L1_chap1", "old": 30, "new": 45},
    {"type": "add_review", "node_id": "L1_chap1", "scheduled_date": "2026-05-15"}
  ],
  "message": "根据您的练习情况，我们已为您调整了学习计划，重点加强「力的基本概念」"
}
```

### 5. 前端状态管理

```dart
// 学习流程状态
class PlanningFlowState {
  PlanningPhase phase;  // collecting, generating, confirming, executing, adjusting
  PlanningParams? params;
  KnowledgeNavigation? navigation;
  StudyPlan? plan;
  List<DailyTask> todayTasks;
  List<WeakNode> weakPoints;
  
  double get progress {
    switch (phase) {
      case PlanningPhase.collecting: return 0.1;
      case PlanningPhase.generating: return 0.3;
      case PlanningPhase.confirming: return 0.5;
      case PlanningPhase.executing: return 0.7;
      case PlanningPhase.adjusting: return 0.9;
    }
  }
}
```

### 6. Skill 推荐策略

```python
def recommend_skill(phase: str, node_id: str, user_level: str) -> str:
    """根据学习阶段和节点推荐合适的 Skill"""
    
    # 学习阶段映射
    phase_skill_map = {
        'learn': ['mindmap_learning', 'feynman_technique', 'lecture'],
        'practice': ['quiz', 'mistake_review', 'drill'],
        'review': ['mindmap', 'comprehensive_test']
    }
    
    # 获取该节点关联的 Skill
    node_skills = get_node_skills(node_id)
    
    # 根据用户水平过滤
    if user_level == 'beginner':
        # 新手推荐讲义+思维导图
        return 'mindmap_learning'
    elif user_level == 'intermediate':
        # 中级推荐练习题
        return 'quiz'
    else:
        # 高级推荐综合测试
        return 'comprehensive_test'
    
    return node_skills[0] if node_skills else 'mindmap_learning'
```

### 7. 通知策略

| 场景 | 通知类型 | 时间 | 内容 |
|------|----------|------|------|
| 计划确认 | 欢迎通知 | 即时 | "欢迎开始备考之旅！" |
| 每日提醒 | 学习提醒 | 前一天 20:00 | "明天有 3 个学习任务" |
| 任务开始 | 任务提醒 | 任务前 15 分钟 | "「力的基本概念」即将开始" |
| 任务未完成 | 督促通知 | 当天 21:00 | "今日任务进度 2/3，加油！" |
| 计划调整 | 变更通知 | 即时 | "根据练习情况，计划已调整" |
| 薄弱点 | 强化通知 | 每日 9:00 | "今日重点：复习 2 个薄弱点" |

### 8. 性能考虑

- 参数提取使用本地缓存，避免重复调用 LLM
- 学习计划生成结果缓存 24 小时
- 知识导航使用预设路径 + LLM fallback
- 自适应调整使用乐观更新，先显示调整结果，后台同步
- 日历同步使用批量操作，减少 API 调用