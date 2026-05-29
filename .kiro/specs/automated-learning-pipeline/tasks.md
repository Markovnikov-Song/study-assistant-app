# 实现计划：自动化全链路学习规划系统

## 概述

实现从用户自然语言输入「我要备考材料力学」到完整学习闭环的自动化。

**核心流程**：
意图识别 → 参数提取 → 多轮对话 → 知识导航 → 计划生成 → 日历写入 → 通知调度 → Skill执行 → 错题反馈 → 计划调整

## 任务

### 阶段一：意图识别与参数提取增强

- [ ] 1. 后端：扩展 CAS 参数提取能力
  - [ ] 1.1 修改 `backend/cas/intent_mapper.py`
    - 新增 `extract_planning_params(text)` 方法
    - 使用 LLM 从文本中提取：subject, examDate, examScope, dailyHours, targetScore
  - [ ] 1.2 在 `backend/cas/models.py` 中新增 `PlanningParams` 数据模型
  - [ ] 1.3 新增 `backend/services/param_extractor_service.py`
    - 实现语义日期解析（「下个月」「期末」→「2026-06-15」）
    - 实现学科标准化（「材料力学」→ 匹配已有学科 ID）

- [ ] 2. Flutter：意图识别前端集成
  - [ ] 2.1 修改 `lib/features/cas/cas_intent_detector.dart`
    - 新增 `detectPlanningIntent(text)` 方法
    - 返回提取的参数和缺失参数列表
  - [ ] 2.2 在 `lib/services/intent_detector.dart` 中新增 `extractParams` 方法
  - [ ] 2.3 创建 `lib/features/cas/params_collector_dialog.dart`
    - 多轮对话参数收集 UI
    - 支持选项快捷输入 + 文本输入

### 阶段二：知识导航生成

- [ ] 3. 后端：知识导航服务
  - [ ] 3.1 创建 `backend/services/knowledge_navigator.py`
    - `generate_navigation(subject_id, exam_scope, days_left)` → 返回节点列表
    - 调用 LLM 生成结构化知识导航
    - 优先使用预设学习路径（来自 knowledge-graph-evolution）
  - [ ] 3.2 在 `backend/routers/` 中新增 `/api/planning/knowledge-navigation` 接口
    - 参数：subjectId, examScope, deadline
    - 返回：知识节点列表（nodeId, title, prerequisites, priority, estimatedHours）
  - [ ] 3.3 在 `database.py` 中新增 `knowledge_navigations` 表（可选缓存）

- [ ] 4. Flutter：知识导航展示
  - [ ] 4.1 创建 `lib/components/planning/knowledge_navigator_card.dart`
    - 以简化版思维导图或列表形式展示知识节点
    - 节点显示：名称、优先级、预估时长
  - [ ] 4.2 在计划确认页面集成知识导航预览
  - [ ] 4.3 与现有 MindMap 数据模型对接

### 阶段三：学习计划生成

- [ ] 5. 后端：学习计划生成服务
  - [ ] 5.1 重构 `backend/cas/executors/make_plan.py`
    - 改为接收完整参数（subject, examDate, examScope, dailyHours, knowledgeNodes）
    - 生成更结构化的学习计划（不是纯文本）
  - [ ] 5.2 创建 `backend/services/study_plan_generator.py`
    - 输入：学科、考试日期、知识导航节点、每日时长
    - 输出：结构化计划（阶段划分 + 每日任务）
    - 遵循约束：每日≤3任务、最后一周冲刺、周末弹性
  - [ ] 5.3 在 `database.py` 中新增 `study_plans` 表
    - 字段：id, user_id, subject_id, title, status, deadline, created_at, updated_at
    - 字段：daily_tasks（JSONB 数组）
  - [ ] 5.4 在 `backend/routers/` 中新增 REST 接口
    - `POST /api/planning/plans` - 创建计划
    - `GET /api/planning/plans/{plan_id}` - 获取计划
    - `PUT /api/planning/plans/{plan_id}` - 更新计划

- [ ] 6. Flutter：学习计划展示与确认
  - [ ] 6.1 创建 `lib/components/planning/study_plan_card.dart`
    - 展示阶段划分（基础/强化/冲刺）
    - 展示每日任务列表
  - [ ] 6.2 创建 `lib/screens/planning/plan_confirm_page.dart`
    - 展示生成的计划
    - 「确认执行」和「调整」按钮
    - 调整功能：拖拽修改任务顺序/时长
  - [ ] 6.3 在 `lib/providers/` 中新增 `study_plan_provider.dart`
    - `currentPlanProvider` - 当前进行中的计划
    - `createPlan(params)` - 创建计划

### 阶段四：日历写入

- [ ] 7. 日历集成服务
  - [ ] 7.1 修改 `lib/services/calendar_service.dart`
    - 新增 `importPlanToCalendar(planId)` 方法
    - 遍历计划的每日任务，创建日历事件
  - [ ] 7.2 在任务数据模型中新增日历关联字段
    - `calendarEventId` - 关联的日历事件 ID
    - `linkedNodeId` - 关联的知识节点（用于掌握度追踪）
  - [ ] 7.3 实现「弹性日历」功能
    - 支持拖拽调整任务时间
    - 自动重新平衡后续任务时间

- [ ] 8. Flutter：日历视图集成
  - [ ] 8.1 在日历页面高亮显示学习计划任务
    - 使用特殊颜色/图标区分
  - [ ] 8.2 点击日历任务 → 启动对应 Skill
  - [ ] 8.3 日历任务支持「已完成」标记

### 阶段五：通知调度

- [ ] 9. 通知服务增强
  - [ ] 9.1 修改 `lib/services/notification_service.dart`
    - 新增 `scheduleStudyReminder(planId)` 方法
    - 基于计划设置每日提醒
  - [ ] 9.2 在 `lib/models/` 中新增 `StudyReminder` 模型
    - 字段：planId, reminderTime, taskTitle, linkedNodeId
  - [ ] 9.3 实现多种提醒策略
    - 固定时间提醒
    - 任务前提醒
    - 未完成累积提醒（当天 21:00 检查）
  - [ ] 9.4 Web 端支持
    - 使用 Web Push API（`web_push` 包）
    - 后端新增 `web_push_service.py`

- [ ] 10. 前端通知 UI
  - [ ] 10.1 在首页增加「学习仪表盘」组件
    - 显示今日任务
    - 显示完成进度
    - 快捷开始按钮
  - [ ] 10.2 创建通知偏好设置页面
    - 提醒时间设置
    - 勿扰模式设置

### 阶段六：Skill 调度

- [ ] 11. Skill 智能调度服务
  - [ ] 11.1 创建 `backend/services/skill_dispatcher.py`
    - 维护「知识点-Skill 映射表」
    - `dispatch_skill(phase, nodeId, userLevel)` → 推荐 Skill
  - [ ] 11.2 在数据库中创建 `node_skill_mapping` 表
    - 字段：node_id, skill_id, weight, phase（learn/practice/review）
  - [ ] 11.3 在 `backend/routers/` 中新增 `/api/planning/recommend-skill` 接口
    - 参数：planId, currentNodeId
    - 返回：推荐 Skill 列表及理由

- [ ] 12. Flutter：Skill 启动集成
  - [ ] 12.1 修改日历任务点击行为
    - 点击任务 → 根据 nodeId 启动对应 Skill
  - [ ] 12.2 创建 `lib/components/planning/skill_launcher.dart`
    - 根据当前学习阶段推荐 Skill
    - 「学习新知」「巩固练习」「阶段复盘」三种模式
  - [ ] 12.3 实现学习闭环
    - Skill 执行完成后更新节点掌握度
    - 触发 Adaptive Loop 检查

### 阶段七：自适应循环（错题反馈与计划调整）

- [ ] 13. 错题分析与薄弱点检测
  - [ ] 13.1 复用 `knowledge-graph-evolution` 中的 `skill_diagnostic_service`
    - 分析错题 → 标记薄弱节点
  - [ ] 13.2 创建 `backend/services/adaptive_loop_service.py`
    - `analyze_and_adjust(planId, wrongAnswers)` → 调整后的计划
    - 调整策略：
      - 插入薄弱点复习任务
      - 调整优先级
      - 延长相关任务时间
  - [ ] 13.3 在 `database.py` 中新增 `plan_adjustments` 表
    - 记录每次调整的原因、内容、时间

- [ ] 14. 前端：自适应调整 UI
  - [ ] 14.1 创建调整通知组件
    - 显示：「根据您的练习情况，计划已调整」
    - 展示具体变更内容
  - [ ] 14.2 计划调整历史页面
    - 显示每次调整的时间、原因、变更内容
  - [ ] 14.3 手动调整支持
    - 允许用户覆盖自动调整
    - 记住用户偏好

### 阶段八：全链路状态管理与前端展示

- [ ] 15. 学习流程状态页
  - [ ] 15.1 创建 `lib/screens/planning/learning_flow_page.dart`
    - ���示各阶段状态：参数收集中 → 计划生成中 → 执行中 → 调整中
    - 阶段进度可视化
  - [ ] 15.2 集成到导航系统
    - 从 Chat 页面可进入
    - 从首页仪表盘可进入

- [ ] 16. Chat 页面全链路集成
  - [ ] 16.1 修改 `lib/features/chat/chat_page.dart`
    - 检测到 planning 意图后，引导完成参数收集
    - 在确认阶段展示计划预览卡片
  - [ ] 16.2 创建 `lib/components/planning/planning_chat_components.dart`
    - 参数收集对话气泡
    - 计划确认卡片
    - 执行中状态卡片

- [ ] 17. 首页学习仪表盘
  - [ ] 17.1 修改 `lib/features/home/`
    - 新增「学习计划」小部件
    - 显示当前计划、进度、薄弱点提醒
  - [ ] 17.2 快捷操作按钮
    - 「继续学习」
    - 「查看计划」
    - 「薄弱点强化」

---

## 里程碑

| 里程碑 | 交付物 | 预计完成 |
|--------|--------|----------|
| M1: 意图与参数 | 参数提取、多轮对话 UI | - |
| M2: 知识导航 | 导航生成服务 + 展示 | - |
| M3: 计划生成 | 结构化计划 + 确认页 | - |
| M4: 日历集成 | 任务写入日历 | - |
| M5: 通知 | 学习提醒系统 | - |
| M6: Skill 调度 | 智能推荐 + 启动 | - |
| M7: 自适应 | 错题分析 + 计划调整 | - |
| M8: 前端集成 | 状态页 + 仪表盘 | - |

---

## 技术架构

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter (Frontend)                      │
├─────────────────────────────────────────────────────────────┤
│  Chat Page ←→ Planning Flow ←→ Home Dashboard              │
│       ↓                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────┐    │
│  │ Intent      │  │ Study Plan  │  │ Calendar         │    │
│  │ Detector    │  │ Provider    │  │ Service          │    │
│  └─────────────┘  └─────────────┘  └──────────────────┘    │
└───────────────────────────┬─────────────────────────────────┘
                            │ HTTP/WebSocket
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      Backend (Python)                       │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │ CAS          │  │ Planning     │  │ Knowledge       │   │
│  │ Dispatch     │  │ Service      │  │ Navigator       │   │
│  └──────────────┘  └──────────────┘  └─────────────────┘   │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │ Skill        │  │ Adaptive     │  │ Notification    │   │
│  │ Dispatcher   │  │ Loop         │  │ Scheduler       │   │
│  └──────────────┘  └──────────────┘  └─────────────────┘   │
│                                                              │
│  Database: study_plans, daily_tasks, plan_adjustments,     │
│            node_skill_mapping, knowledge_navigations        │
└─────────────────────────────────────────────────────────────┘
```

---

## 依赖关系

```
M1 (意图+参数)
  ↓
M2 (知识导航) ← M1
  ↓
M3 (计划生成) ← M2, knowledge-graph-evolution (预设路径)
  ↓
M4 (日历集成) ← M3
  ↓
M5 (通知) ← M4
  ↓
M6 (Skill 调度) ← M3
  ↓
M7 (自适应) ← M6, knowledge-graph-evolution (诊断)
  ↓
M8 (前端集成) ← M1-M7 全部
```