# Requirements Document

## Introduction

本文档定义「知识图谱进化」功能，旨在将现有的静态"知识森林"升级为动态的"学习引擎"。基于文章《从"知识森林"到"学习引擎"》的分析，解决以下核心痛点：

1. **认知负荷过重**：节点过于细碎，无明确起点和路径
2. **缺乏引导机制**：学生面对密恐级图谱无从下手
3. **静态展示**：无法根据学习行为动态调整
4. **教学断层**：无法精准识别薄弱点，因材施教
5. **单一维度**：仅有知识图谱，缺乏能力/问题/素质/思政图谱

---

## Glossary

- **Knowledge_Graph**：知识图谱，以节点+边展示知识点及其关系的可视化结构
- **Learning_Path**：预设学习路径，由教师或系统设计的知识点学习顺序
- **Node_State**：节点状态，包含：未学习(Locked)、进行中(Active)、已掌握(Mastered)、有讲义(HasLecture)
- **Mastery_Heatmap**：掌握度热力图，用颜色深浅表示知识点掌握程度
- **Adaptive_Recommendation**：自适应推荐，基于学习数据智能推送资源
- **Multi_Dimensional_Graph**：多维图谱，包含知识图谱、能力图谱、问题图谱、素质图谱、思政图谱
- **Path_Progress**：路径进度，学生在预设路径上的学习进度百分比
- **Skill_Diagnostic**：技能诊断，通过解题/练习数据分析知识掌握情况

---

## Requirements

### Requirement 1：预设学习路径（Preset Learning Path）

**User Story:** 作为学习者，我希望打开知识图谱时能看到一条清晰的学习路径，而不是面对密密麻麻的节点无从下手。

#### Acceptance Criteria

1. THE System SHALL 为每个学科的思维导图提供预设学习路径（Learning_Path），由核心知识点按先修顺序排列组成。
2. WHEN 用户首次进入某学科的思维导图，THE System SHALL 默认只展示路径上的前 3-5 个核心节点，其他节点默认折叠。
3. THE Learning_Path SHALL 定义每个节点的"前置节点"（prerequisites），只有前置节点完成学习后才能解锁后续节点。
4. THE System SHALL 在导图视图中用连接线标注 Learning_Path 的完整路径，非路径节点用虚线表示。
5. WHEN 用户完成路径上某个节点的学习（通过讲义阅读或测验），THE System SHALL 自动展开并高亮下一节点。
6. THE System SHALL 提供「查看完整图谱」开关，用户可一键切换到全视图（保留路径高亮）。

### Requirement 2：节点状态与游戏化激励（Node State & Gamification）

**User Story:** 作为学习者，我希望每学习一个知识点就能看到进度反馈，让我知道自己在图谱上的学习进度，产生成就感。

#### Acceptance Criteria

1. THE System SHALL 为每个知识节点维护 Node_State，包含：Locked（未解锁）、Unlocked（已解锁）、InProgress（进行中）、Mastered（已掌握）。
2. THE Node_State SHALL 根据以下行为自动更新：
   - 用户阅读某节点的讲义 → InProgress
   - 用户完成该节点的测验且正确率 ≥80% → Mastered
   - 前置节点 Mastered → 当前节点 Unlocked
3. THE MindMap_Painter SHALL 根据 Node_State 用不同颜色渲染节点：
   - Locked：灰色（#9E9E9E），显示锁图标
   - Unlocked：白色边框（#424242）
   - InProgress：蓝色脉冲动画（#1976D2）
   - Mastered：绿色实心（#4CAF50）+ √ 图标
4. THE System SHALL 在思维导图顶部显示「路径进度」：已掌握节点数/路径总节点数，如「3/15 节点已点亮」。
5. WHEN 用户完成一个节点的学习，THE System SHALL 显示「节点已点亮」的成功提示动画（类似游戏成就解锁）。
6. THE System SHALL 提供「知识地图成就系统」，包含：「初学者」（点亮 5 节点）、「进阶学习者」（点亮 20 节点）、「知识猎人」（点亮 50 节点）等成就。

### Requirement 3：掌握度热力图（Mastery Heatmap）

**User Story:** 作为学习者，我希望一眼就能看出哪些知识点已经掌握、哪些是薄弱点，让我对自己的学习情况有清晰认知。

#### Acceptance Criteria

1. THE System SHALL 在思维导图的「热力图模式」中，用颜色深浅表示各节点的掌握程度。
2. THE Mastery_Heatmap SHALL 定义以下颜色梯度：
   - 0-20%：深红（#D32F2F）— 严重薄弱
   - 21-40%：橙色（#F57C00）— 需要加强
   - 41-60%：黄色（#FBC02D）— 初步了解
   - 61-80%：浅绿（#8BC34A）— 基本掌握
   - 81-100%：深绿（#388E3C）— 完全掌握
3. THE Mastery_Heatmap SHALL 基于以下数据计算掌握度：
   - 解题正确率（权重 50%）
   - 错题本中该知识点相关错误次数（负向权重 30%）
   - 讲义阅读时长（正向权重 20%）
4. THE System SHALL 在导图右上角提供「热力图/路径模式」切换开关。
5. THE System SHALL 在热力图模式下显示图例，说明各颜色代表的掌握程度。

### Requirement 4：智能诊断与精准推送（Smart Diagnosis & Push）

**User Story:** 作为学习者，我希望系统能发现我的薄弱点，并自动推送相关的学习资源帮我补齐短板。

#### Acceptance Criteria

1. THE System SHALL 在用户完成每次解题/练习后，分析错题涉及的知识点，更新相关节点的掌握度。
2. THE System SHALL 识别「薄弱节点」（掌握度 < 40%），并自动执行以下推送：
   - 推送相关知识节点的讲义链接
   - 推送该知识点的专项练习题
   - 在日历中添加「复习薄弱点」的任务提醒
3. THE System SHALL 在「课程空间」首页显示「知识短板」卡片，列出前 5 个最薄弱的知识点。
4. WHEN 用户点击某薄弱节点，THE System SHALL 展示「一键补强」按钮，点击后打开相关讲义和练习。
5. THE System SHALL 支持「学习闭环」：薄弱点检测 → 资源推送 → 练习反馈 → 重新评估 → 掌握度更新。

### Requirement 5：多维图谱体系（Multi-Dimensional Graphs）

**User Story:** 作为学习者，我希望不仅能看到知识点，还能看到能力维度、问题维度、素质维度和思政维度，让学习更有目标感。

#### Acceptance Criteria

1. THE System SHALL 在现有知识图谱（Knowledge Graph）基础上，新增四类图谱：
   - **能力图谱（Capability Graph）**：将知识点映射到具体能力（如「材料力学」→ 「工程分析能力」）
   - **问题图谱（Problem Graph）**：将知识点关联到典型问题/题型
   - **素质图谱（Quality Graph）**：将知识点关联到素养维度（如「团队协作」「创新思维」）
   - **思政图谱（Ideological Graph）**：将知识点关联到思政元素（如「工程师伦理」「家国情怀」）
2. THE System SHALL 在思维导图页面提供图谱类型切换 Tab：知识 | 能力 | 问题 | 素质 | 思政。
3. THE System SHALL 在切换图谱类型时，保持节点位置不变，只改变节点标签/颜色/关联边。
4. THE System SHALL 支持「五维联动」：选择某节点后，同时显示其在五类图谱中的信息。
5. THE Backend SHALL 维护节点-维度映射表，支持批量导入和手动配置。

### Requirement 6：班级视角与教学决策支持（Class View & Teaching Decision）

**User Story:** 作为教师，我希望能看到班级学生的整体知识掌握情况，精准识别需要重点讲解的知识点。

#### Acceptance Criteria

1. THE System SHALL 为教师提供「班级热力图」视图，显示班级学生各知识点的平均掌握度。
2. THE Class_Heatmap SHALL 用颜色深浅表示班级整体掌握情况：
   - 0-30%：红色 — 需要全班精讲
   - 31-60%：黄色 — 需要部分讲解
   - 61-100%：绿色 — 可一带而过
3. THE System SHALL 在班级热力图上标注「Top 3 薄弱知识点」，供教师备课参考。
4. THE System SHALL 支持教师查看特定学生的个人掌握度详情。
5. THE System SHALL 生成班级学习报告（PDF），包含：知识点掌握分布图、进步趋势图、需要关注的学生列表。

### Requirement 7：专业级联图谱（Professional Cascade Graph）

**User Story:** 作为学生，我希望能看到某门课在整个专业培养体系中的位置，以及它与前后序课程的关联。

#### Acceptance Criteria

1. THE System SHALL 将课程级知识图谱扩展为专业级图谱，关联前序课程、当前课程、后续课程的知识点。
2. THE Professional_Graph SHALL 定义课程间的「知识依赖链」：
   - 前置课程 → 当前课程（如「高等数学」→ 「材料力学」）
   - 当前课程 → 后续课程（如「材料力学」→ 「机械设计」）
3. THE System SHALL 在专业图谱视图中，用不同颜色区分不同课程的节点。
4. THE System SHALL 支持跨学科知识关联展示，当知识点涉及多学科时显示跨界连线。
5. THE Professional_Graph SHALL 在节点上显示该知识点在哪些课程中出现（课程标签）。

---

## Out of Scope

1. 移动端离线使用（需要本地数据库支持）
2. 多人协作编辑同一知识图谱
3. AI 自动生成预设学习路径（初期由教师手动配置）
4. 与外部学习管理系统（LMS）集成

---

## Dependencies

- 现有 MindMap 数据模型（`lib/models/mindmap_library.dart`）
- 现有 ConversationSession 数据库结构
- 错题本数据（MistakeBook）
- 日历服务（Calendar Service）
- LLM Service（用于生成节点-能力映射）