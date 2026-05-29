# Requirements Document

## Introduction

本文档定义「自动化全链路学习规划系统」，实现从用户自然语言输入到完整学习闭环的自动化。用户只需说「我要备考材料力学」，系统自动完成：

1. 意图识别与参数提取
2. 多轮对话收集缺失参数（考试时间、范围等）
3. 生成学习计划与知识导航
4. 写入日历
5. 系统提示（Push 通知）
6. 调用 Mini-app/Skill 执行学习
7. 错题反馈 → 动态调整计划

---

## Glossary

- **Intent_Detector**：意图检测器，识别用户输入的学习意图类型
- **Parameter_Extractor**：参数提取器，从用户输入中提取结构化参数（学科、时间、范围等）
- **Multi_Turn_Collector**：多轮对话收集器，在参数缺失时引导用户补充
- **Knowledge_Navigator**：知识导航，基于学习目标生成结构化的知识点学习顺序
- **Study_Plan_Generator**：学习计划生成器，调用 LLM 生成详细的学习计划
- **Calendar_Integrator**：日历集成器，将学习任务写入日历系统
- **Notification_Scheduler**：通知调度器，安排学习提醒
- **Skill_Dispatcher**：Skill 分发器，调用合适的 Mini-app/Skill 执行学习任务
- **Adaptive_Loop**：自适应循环，根据学习反馈动态调整计划
- **CAS**：Conversational Action System，现有对话动作系统

---

## Requirements

### Requirement 1：增强型意图识别与参数提取

**User Story:** 作为学习者，我希望能用自然语言描述学习目标（如「我要备考材料力学，下个月期末考试」），系统能自动提取学科、考试时间、学习范围等参数。

#### Acceptance Criteria

1. THE Intent_Detector SHALL 在接收用户输入后，首先调用 CAS 识别意图类型（planning/subject/skill）。
2. WHEN 意图类型为 planning，THE Parameter_Extractor SHALL 从输入文本中提取以下参数：
   - `subject`：学科名称（如「材料力学」）
   - `examDate`：考试日期（如「下个月期末」需转换为具体日期）
   - `examScope`：考试范围（如「前五章」「全部内容」）
   - `dailyHours`：每日学习时长（可选，默认 2 小时）
   - `targetScore`：目标分数（可选）
3. THE Parameter_Extractor SHALL 使用 LLM 进行语义日期解析（如「下个月」「期末」「后天」转换为具体日期）。
4. WHEN 参数提取不完整（如缺少 examDate），THE System SHALL 进入多轮对话模式，主动询问缺失参数。
5. THE Multi_Turn_Collector SHALL 记录已收集的参数状态，避免重复询问。
6. THE Multi_Turn_Collector SHALL 支持「快捷补充」：提供选项按钮（如「本周/下周/下月」）而非纯文本输入。

### Requirement 2：知识导航生成（Knowledge Navigator）

**User Story:** 作为学习者，我希望系统能根据我的学习目标生成一个结构化的知识学习顺序，让我知道先学什么、后学什么。

#### Acceptance Criteria

1. WHEN 参数收集完整，THE Knowledge_Navigator SHALL 调用后端服务，基于学科和考试范围生成知识导航。
2. THE Knowledge_Navigator SHALL 输出结构化知识节点列表，包含：
   - `nodeId`：节点唯一标识
   - `nodeTitle`：知识点名称
   - `prerequisites`：前置知识点列表
   - `estimatedHours`：预估学习时长
   - `priority`：优先级（核心/基础/拓展）
3. THE Knowledge_Navigator SHALL 根据考试范围筛选相关知识点，优先覆盖高频考点。
4. THE Knowledge_Navigator SHALL 优先展示「预设学习路径」中的核心节点（来自 knowledge-graph-evolution 功能）。
5. THE Knowledge_Navigator SHALL 输出知识导航的 Markdown 格式文本，供前端渲染为思维导图预览。

### Requirement 3：学习计划生成（Study Plan Generator）

**User Story:** 作为学习者，我希望系统能生成一份详细的学习计划，包括每天的任务、时间安排。

#### Acceptance Criteria

1. THE Study_Plan_Generator SHALL 调用 LLM，基于以下输入生成学习计划：
   - 学科 + 考试日期（计算剩余天数）
   - 知识导航节点列表
   - 每日学习时长
   - 用户历史学习数据（可选）
2. THE Study_Plan_Generator SHALL 输出 Markdown 格式的学习计划，包含：
   - 总体目标描述
   - 阶段划分（如「基础阶段（第1-2周）」「强化阶段（第3-4周）」「冲刺阶段（最后1周）」）
   - 每日学习任务列表
   - 每周复盘建议
3. THE Study_Plan_Generator SHALL 遵循以下约束：
   - 每日任务不超过 3 条
   - 最后一周预留给冲刺复习
   - 周末可适当减少任务量
4. THE Study_Plan_Generator SHALL 将生成的计划存储到数据库，关联用户 ID 和学科 ID。
5. THE Study_Plan_Generator SHALL 支持「计划预览确认」：生成计划后不直接执行，等待用户确认。

### Requirement 4：日历写入与任务同步（Calendar Integration）

**User Story:** 作为学习者，我希望学习计划能自动写入日历，每天收到学习提醒。

#### Acceptance Criteria

1. WHEN 用户确认学习计划，THE Calendar_Integrator SHALL 将计划中的每日任务转换为日历事件。
2. THE Calendar_Integrator SHALL 为每个学习任务创建日历事件，包含：
   - 事件标题：「材料力学 - 第1章：力的基本概念」
   - 开始/结束时间
   - 知识点关联（用于后续掌握度追踪）
   - 重复规则（如「每天」）
3. THE Calendar_Integrator SHALL 在计划开始前一天创建「学习计划即将开始」预告事件。
4. THE Calendar_Integrator SHALL 支持「弹性日历」：允许用户拖动调整任务时间，系统自动重新平衡后续任务。
5. THE Calendar_Integrator SHALL 与现有日历系统（`lib/services/calendar_service.dart`）集成，复用现有数据模型。

### Requirement 5：学习提醒与系统通知（Notification Scheduling）

**User Story:** 作为学习者，我希望每天能收到学习提醒，让我不要忘记按计划学习。

#### Acceptance Criteria

1. THE Notification_Scheduler SHALL 根据学习计划安排每日学习提醒。
2. THE Notification_Scheduler SHALL 支持以下提醒策略：
   - 固定时间提醒（如每天 20:00）
   - 任务开始前提醒（如任务前 15 分钟）
   - 未完成累积提醒（当天任务未完成时）
3. THE Notification_Scheduler SHALL 在移动端使用系统通知，在网页端使用浏览器通知（Web Push）。
4. THE Notification_Scheduler SHALL 在通知中包含：
   - 今日学习目标
   - 预计学习时长
   - 点击跳转快速开始
5. THE Notification_Scheduler SHALL 支持「勿扰模式」：用户可设置不提醒的时间段。

### Requirement 6：Skill/Mini-app 调度执行（Skill Dispatcher）

**User Story:** 作为学习者，我希望系统能自动安排合适的学习工具（如出题、错题练习、费曼学习法）来帮助我学习。

#### Acceptance Criteria

1. THE Skill_Dispatcher SHALL 根据当前学习阶段和知识点，智能推荐合适的 Skill/Mini-app：
   - 学习新知识 → 推荐「讲义阅读」或「费曼学习法」
   - 巩固练习 → 推荐「专项练习题」或「错题复习」
   - 阶段复盘 → 推荐「知识导图」或「综合测试」
2. THE Skill_Dispatcher SHALL 维护「知识点-Skill 映射表」：
   ```json
   {
     "材料力学-应力分析": ["skill_mindmap", "skill_quiz_stress"],
     "材料力学-强度理论": ["skill_mindmap", "skill_mistake_review"]
   }
   ```
3. WHEN 用户点击日历中的学习任务，THE Skill_Dispatcher SHALL 自动启动对应的 Mini-app。
4. THE Skill_Dispatcher SHALL 支持「学习闭环」：完成 Skill 后自动记录学习结果，更新知识点掌握度。

### Requirement 7：错题反馈与计划调整（Adaptive Loop）

**User Story:** 作为学习者，我希望系统能根据我的错题情况自动调整学习计划，重点复习薄弱环节。

#### Acceptance Criteria

1. THE Adaptive_Loop SHALL 监听用户的解题/练习结果。
2. WHEN 用户完成练习后，THE Adaptive_Loop SHALL 执行以下分析：
   - 识别错题涉及的知识点
   - 计算这些知识点的掌握度下降
   - 标记为「薄弱点」
3. THE Adaptive_Loop SHALL 根据薄弱点自动调整后续学习计划：
   - 在计划中插入「薄弱点复习」任务
   - 调整后续任务的优先级
   - 延长薄弱知识点相关任务的时间
4. THE Adaptive_Loop SHALL 在调整计划后通过通知告知用户：「根据您的练习情况，我们已为您调整了学习计划，重点加强 XXX 知识点」。
5. THE Adaptive_Loop SHALL 支持「手动调整覆盖」：用户可手动调整计划，系统会记住用户偏好。
6. THE Adaptive_Loop SHALL 记录调整历史，供用户查看计划变更轨迹。

### Requirement 8：全链路状态管理与前端展示

**User Story:** 作为学习者，我希望能看到整个学习流程的进度，了解当前处于哪个阶段。

#### Acceptance Criteria

1. THE System SHALL 在前端提供「学习流程状态页」，展示：
   - 当前阶段：参数收集中 → 计划生成中 → 执行中 → 调整中
   - 各阶段完成状态（✓/进行中/待开始）
2. THE System SHALL 在 Chat 页面集成全链路对话：
   - 用户：「我要备考材料力学」
   - 系统：「好的，您计划什么时间考试？」（参数收集）
   - 用户：「下个月期末」
   - 系统：「考试范围是全书还是前几章？」（参数收集）
   - 用户：「前五章」
   - 系统：（生成计划+写入日历+展示预览）
3. THE System SHALL 提供「学习仪表盘」小部件，在首页展示：
   - 当前进行中的学习计划
   - 今日任务完成进度
   - 薄弱点提醒
   - 快捷开始按钮

---

## User Flow Diagram

```
用户输入
  │
  ▼
┌─────────────────┐
│  意图识别       │ ──→ planning 类型
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  参数提取       │ ──→ 缺失参数?
└────────┬────────┘
         │ 是
         ▼
┌─────────────────┐
│  多轮对话收集   │ ──→ 补充参数
└────────┬────────┘
         │ 否
         ▼
┌─────────────────┐
│  知识导航生成   │ ──→ 知识点列表
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  学习计划生成   │ ──→ 每日任务
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  用户确认       │ ──→ 确认/修改
└────────┬────────┘
         │ 确认
         ▼
┌─────────────────┐
│  日历写入       │ ──→ 创建日历事件
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  通知调度       │ ──→ 安排学习提醒
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  执行学习       │ ←── Skill/Mini-app
│  (循环)         │     │
└────────┬────────┘     │
         │             │
         ▼             ▼
┌─────────────────┐ 错题反馈
│  错题分析       │ ────────┐
└────────┬────────┘         │
         │                 │
         ▼                 ▼
┌─────────────────┐   ┌─────────────────┐
│  计划调整       │ ← │ 薄弱点强化     │
└─────────────────┘   └─────────────────┘
         │
         └──────→ (继续执行学习循环)
```

---

## Out of Scope

1. 跨学科综合计划（多学科同时备考）— V2
2. AI 自动调整学习路径（手动配置为主）— V2
3. 与外部日历同步（Google Calendar/Outlook）
4. 离线模式支持

---

## Dependencies

- 现有 CAS 系统（`lib/features/cas/`, `backend/cas/`）
- 知识图谱进化功能（`knowledge-graph-evolution` spec）
- 日历服务（`lib/services/calendar_service.dart`）
- 通知服务（`lib/services/notification_service.dart`）
- Skill 生态系统（`backend/skill_registry.py`）
- 错题本系统（`lib/features/mistake_book/`）