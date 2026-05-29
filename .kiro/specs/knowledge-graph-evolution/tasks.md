# 实现计划：知识图谱进化（从"知识森林"到"学习引擎"）

## 概述

将现有静态思维导图升级为动态学习引擎，核心目标：
- 降低认知负荷（预设路径）
- 增强学习反馈（节点状态+游戏化）
- 实现精准教学（热力图+智能诊断）
- 构建多维图谱（五维图谱体系）

## 任务

### 阶段一：基础能力建设（节点状态与路径系统）

- [ ] 1. 数据模型层：节点状态与路径
  - [ ] 1.1 在 `lib/models/mindmap_library.dart` 中新增 `NodeState` 枚举：`locked`, `unlocked`, `inProgress`, `mastered`
  - [ ] 1.2 在 `lib/models/mindmap_library.dart` 中新增 `LearningPath` 数据模型
    - 字段：`id`, `subjectId`, `name`, `nodeIds[]`（有序节点ID列表）, `prerequisites{}`（节点ID → 前置节点ID列表）
  - [ ] 1.3 在 `lib/models/mindmap_library.dart` 中新增 `NodeMastery` 数据模型
    - 字段：`userId`, `sessionId`, `nodeId`, `masteryLevel`（0-100）, `lastPracticedAt`, `correctCount`, `wrongCount`, `lectureReadDuration`
  - [ ] 1.4 在后端 `database.py` 中新增对应 ORM 模型
  - [ ] 1.5 创建数据库迁移脚本，添加 `mindmap_learning_paths` 和 `mindmap_node_mastery` 表

- [ ] 2. Flutter 层：节点状态服务
  - [ ] 2.1 在 `lib/services/` 中新增 `learning_path_service.dart`
    - `getLearningPath(subjectId)`：获取学科的预设路径
    - `getNodeStates(sessionId)`：获取会话中所有节点状态
    - `updateNodeState(sessionId, nodeId, state)`：更新节点状态
    - `calculateMastery(sessionId, nodeId)`：计算掌握度
  - [ ] 2.2 在 `lib/providers/` 中新增 `learning_path_provider.dart`
    - `learningPathProvider(subjectId)`：预设路径
    - `nodeStatesProvider(sessionId)`：节点状态列表
    - `pathProgressProvider(sessionId)`：路径进度百分比

- [ ] 3. Flutter 层：MindMapPainter 状态渲染
  - [ ] 3.1 修改 `lib/tools/mindmap/mindmap_painter.dart`
    - 新增 `nodeStates` Map 参数传入节点状态
    - 根据 `NodeState` 渲染不同颜色和图标：
      - Locked：灰色背景 + 锁图标
      - Unlocked：白色边框
      - InProgress：蓝色脉冲动画
      - Mastered：绿色背景 + 对勾
    - 路径节点用实线连接，非路径节点用虚线
  - [ ] 3.2 修改 `lib/components/library/editable_mindmap_page.dart`
    - 引入 `nodeStatesProvider` 数据
    - 传递给 `MindMapPainter`
    - 在顶部添加路径进度条：「3/15 节点已点亮」

### 阶段二：游戏化与热力图

- [ ] 4. 游戏化激励系统
  - [ ] 4.1 在 `lib/services/` 中新增 `achievement_service.dart`
    - 定义成就类型：初学者(5节点)、进阶学习者(20节点)、知识猎人(50节点)等
    - `checkAchievements(userId, masteredCount)`：检查并返回新成就
  - [ ] 4.2 在 `lib/components/library/editable_mindmap_page.dart` 中
    - 节点变为 Mastered 状态时，显示「节点已点亮」Toast 动画
    - 在个人中心页面显示「知识地图成就」
  - [ ] 4.3 在后端新增成就记录表 `user_achievements`

- [ ] 5. 掌握度热力图
  - [ ] 5.1 修改 `lib/tools/mindmap/mindmap_painter.dart`
    - 新增 `heatmapMode: bool` 参数
    - 在热力图模式下，根据 `masteryLevel` 计算颜色：
      - 0-20%：#D32F2F
      - 21-40%：#F57C00
      - 41-60%：#FBC02D
      - 61-80%：#8BC34A
      - 81-100%：#388E3C
  - [ ] 5.2 在 `editable_mindmap_page.dart` 中
    - 右上角添加「热力图/路径模式」切换开关
    - 显示热力图图例
  - [ ] 5.3 掌握度计算逻辑
    - 公式：`masteryLevel = correctRate * 50 + (1 - wrongRatio) * 30 + readDuration / total * 20`
    - 每次完成练习后重新计算

### 阶段三：智能诊断与推送

- [ ] 6. 错题分析与薄弱点检测
  - [ ] 6.1 在 `lib/services/` 中新增 `skill_diagnostic_service.dart`
    - `analyzeWrongAnswer(examId)`：分析错题涉及的知识点
    - `getWeakNodes(userId, subjectId, topK=5)`：获取最薄弱的 K 个节点
    - `mapQuestionToNodes(questionId)`：将题目映射到知识点节点
  - [ ] 6.2 在后端 `services/` 中新增 `skill_diagnostic_service.py`
    - 维护题目-知识点映射表
    - 根据用户错题历史计算节点掌握度
  - [ ] 6.3 在 `database.py` 中新增 `question_node_mapping` 表
    - 字段：`id`, `question_id`, `node_id`, `weight`（关联权重）

- [ ] 7. 智能资源推送
  - [ ] 7.1 在 `lib/features/home/` 中修改首页逻辑
    - 当检测到新的薄弱节点时，显示「知识短板」卡片
    - 列出前 5 个最薄弱知识点
  - [ ] 7.2 在「知识短板」卡片中
    - 点击薄弱节点 → 跳转到对应讲义
    - 「一键补强」按钮 → 同时打开讲义 + 练习题
  - [ ] 7.3 集成日历服务
    - 自动在日历中添加「复习薄弱点」任务
    - 使用现有 `calendar_service.addEvent()`

### 阶段四：多维图谱体系

- [ ] 8. 多维图谱数据模型
  - [ ] 8.1 在 `lib/models/mindmap_library.dart` 中新增 `GraphDimension` 枚举
  - [ ] 8.2 在 `lib/models/mindmap_library.dart` 中新增 `NodeDimensionMapping` 模型
    - 字段：`nodeId`, `dimension`（枚举）, `mappingValue`, `source`（manual/ai）
  - [ ] 8.3 在后端新增表 `node_dimension_mappings`
  - [ ] 8.4 创建初始维度映射数据（手动配置或 LLM 生成）

- [ ] 9. Flutter 多维图谱视图
  - [ ] 9.1 修改 `editable_mindmap_page.dart`
    - 添加 Tab 栏：知识 | 能力 | 问题 | 素质 | 思政
    - 切换 Tab 时更新 `GraphDimension` 状态
  - [ ] 9.2 修改 `mindmap_painter.dart`
    - 根据 `GraphDimension` 切换节点标签和颜色
    - 能力图谱：节点显示能力名称
    - 问题图谱：节点显示关联题型
    - 素质图谱：节点显示素养标签
    - 思政图谱：节点显示思政元素
  - [ ] 9.3 实现「五维联动」
    - 点击节点弹出 BottomSheet
    - 同时显示该节点在五类图谱中的信息

### 阶段五：班级视角与教学决策

- [ ] 10. 教师班级视图
  - [ ] 10.1 在后端 `routers/` 中新增 `/api/teacher/class-heatmap` 接口
    - 参数：`classId`, `subjectId`
    - 返回：各节点平均掌握度、Top 3 薄弱知识点、需要关注学生列表
  - [ ] 10.2 在 Flutter 新增教师页面 `lib/screens/teacher/class_heatmap_page.dart`
    - 展示班级热力图
    - 用颜色标识需要讲解的知识点
    - 点击节点查看详细统计
  - [ ] 10.3 班级学习报告生成
    - 使用 `printing` 包生成 PDF
    - 包含：知识点分布图、进步趋势图、学生详情

### 阶段六：专业级联图谱

- [ ] 11. 课程关联图谱
  - [ ] 11.1 在后端新增 `course_knowledge_links` 表
    - 字段：`id`, `source_course_id`, `target_course_id`, `shared_node_ids[]`, `link_type`
  - [ ] 11.2 在 Flutter 新增专业图谱视图
    - 展示多门课程的知识点
    - 用颜色区分不同课程
    - 跨学科知识点显示多重连接
  - [ ] 11.3 在节点上显示课程标签
    - 某知识点在哪些课程中出现

---

## 技术债务与优化

- [ ] TD-1: 优化 MindMapPainter 性能（大量节点时）
- [ ] TD-2: 添加节点状态变化的 WebSocket 推送（实时更新）
- [ ] TD-3: 缓存掌握度计算结果（避免重复计算）
- [ ] TD-4: 移动端适配（路径视图在小屏幕上的显示）

---

## 里程碑

| 里程碑 | 交付物 | 预计完成 |
|--------|--------|----------|
| M1: 路径与状态 | 预设路径、节点状态、进度显示 | - |
| M2: 游戏化 | 成就系统、点亮动画 | - |
| M3: 热力�� | 掌握度热力图、切换开关 | - |
| M4: 智能诊断 | 错题分析、薄弱点推送 | - |
| M5: 多维图谱 | 五维图谱切换、联动展示 | - |
| M6: 班级视图 | 教师热力图、班级报告 | - |
| M7: 专业图谱 | 课程关联、跨学科展示 | - |

---

## 依赖关系

```
M1 (路径+状态)
  ↓
M2 (游戏化) ← M1
  ↓
M3 (热力图) ← M1
  ↓
M4 (智能诊断) ← M3
  ↓
M5 (多维图谱) ← M1
  ↓
M6 (班级视图) ← M3
  ↓
M7 (专业图谱) ← M5
```