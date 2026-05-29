# Learning OS 能力生态架构文档

本文档沉淀当前产品方向：把项目从“AI 聊天 + 若干学习工具”升级为可工业化落地的学习 OS。目标不是堆学习方法库，而是建立一个可扩展、可编排、可独立使用、可共创的能力生态。

## 1. 产品目标

项目最终应支持三类使用方式：

- 用户直接打开工具箱，独立使用某个能力应用，比如出题、背单词、导图、讲义、复盘、日历。
- 用户在对话框表达需求，由助教 Agent 澄清信息、选择能力、编排学习节点、写入计划表并跟踪执行。
- 创作者通过应用商店或搭建器贡献能力、玩法、数据源、内容适配器、Skill 流程。

一句话定位：

```text
学习领域的 Capability OS
+ 能力应用商店
+ 可视化搭建器
+ 智能助教编排器
```

## 2. 核心分层

系统不应把所有东西都做成 Skill，也不应把所有工具都变成 Agent。推荐层级如下：

```text
Data Type
  学习数据类型：词条、概念、公式、题目、讲义、导图节点、日历事件。

Operation
  最小执行函数：生成题目、批改答案、解析文档、生成干扰项、更新记忆状态。

Action
  一次标准化调用：带输入校验、参数补全、权限、兜底和渲染结果。

Pattern
  学习玩法框架：百词斩式识别、多邻国式闯关、Anki 式卡片、步骤排序、费曼追问。

Adapter
  内容适配器：英语单词、政治概念、数学公式、物理定律、错题知识点。

Capability
  用户能理解的能力：智能出题、构建导图、背单词、复盘、安排计划。

Capability App
  能力的独立使用界面，也就是 mini-app / 能力应用。

Learning Node
  学习地图上的关卡：引用某个 Capability，并声明进入条件、完成条件、状态和产物。

Skill / Recipe
  多个能力或节点组成的流程配方，比如考前冲刺、章节预习、错题复盘。

Agent
  决策和编排者：负责追问、选择能力、组合节点、调度计划、失败纠偏。
```

## 3. 为什么 mini-app 不等于 Agent

Agent 是决策者，Capability App 是稳定工作台。

比如“智能出题”：

- Capability App 负责参数、题目展示、答题、批改、保存错题。
- Agent 负责判断何时需要练习、练什么、做多少、是否加入复盘。

如果每个 mini-app 都变成 Agent，系统会出现多个局部智能体争夺决策权。正确做法是：

```text
Agent 调用能力
能力应用承载界面
Operation 执行函数
Provider/MCP 提供底层工具
```

## 4. 能力应用的本质结构

一个 Capability App 不是一个页面，而是一组可组合声明：

```yaml
id: quiz.generate
kind: capability_app
title: 智能出题
version: 1.0.0

inputs: []
outputs: []
operations: []
actions: []
patterns: []
adapters: []
views: []
node_templates: []
providers: []
fallbacks: []
permissions: []
agent_contract: {}
completion: {}
```

现阶段项目先落地最小可用协议：

```text
id
title
description
category
action_id
mini_app_route
standalone
orchestratable
schedulable
node_types
provider_refs
fallback_refs
```

后续再扩展输入输出 schema、Pattern、Adapter、权限和完成条件。

## 5. Pattern：让“百词斩”和“多邻国”变成框架

“背单词”不应该别扭地复用普通出题，也不应该一开始做成封闭的百词斩仿品。应该拆成：

```text
Pattern: recognition_choice
Adapter: vocabulary
Data Source: 用户词表 / 教材 / 词典 API / LLM
Review Policy: SM2 / 错题优先 / 每日新词
Capability: vocabulary.memory
App: 背单词工作台
```

同一个 Pattern 可以换内容：

```text
recognition_choice + vocabulary         -> 背英语单词
recognition_choice + political_concept  -> 背政治概念
cloze_fill         + formula            -> 背数学公式
step_ordering      + proof_step         -> 练证明步骤
```

这能避免每来一个需求就新造一个完整 app。

## 6. 商店、搭建器、Agent 的关系

三者应并存，并共享同一套 Capability Package 协议：

```text
应用商店
  普通用户安装别人做好的能力包、玩法包、数据源包、Skill 包。

创造中心
  高级用户或创作者用可视化搭建器组合 Pattern、Adapter、数据源和反馈策略。

Agent
  识别需求、查找本地能力、发现缺口、推荐安装、自动组合已授权能力。
```

第一版不建议静默自动下载。推荐流程：

```text
识别需求
-> 查找本地能力
-> 本地没有则查商店
-> 展示推荐和权限
-> 用户确认安装
-> 加入当前学习路线
```

## 7. 现有项目对应关系

当前代码里已有很多雏形：

- `backend/cas`：Action、参数补全、执行器、对话调度雏形。
- `backend/skill_registry.py`：Skill / Recipe 雏形。
- `backend/mcp_layer`：Provider / MCP 工具雏形。
- `lib/features/toolkit`：Capability App 独立入口雏形。
- `lib/features/spec`：学习计划与时间轴雏形。
- `lib/core/component`：前端组件注册雏形。
- `lib/features/skill_runner`：Skill 独立运行器雏形。

当前最大问题不是缺功能，而是这些抽象彼此平行。下一步要加统一的 `CapabilityRegistry`。

## 8. 改造路线

### 阶段一：能力注册表

- 新增后端 `capabilities` 模块。
- 通过 YAML 声明内置能力。
- 新增 `/api/capabilities`。
- 工具箱从能力注册表加载独立能力，失败时保留本地默认工具。
- CAS action 通过 `action_id` 与 capability 关联。

### 阶段二：学习节点协议

- StudyPlanItem 增加 `capability_id` 和 `capability_params`。
- 计划表中的任务可以打开对应 Capability App 或直接执行 Action。
- 节点声明进入条件、完成条件、产物和兜底。

### 阶段三：Pattern / Adapter

- 抽象记忆训练、闯关练习、卡片复习、步骤排序等学习玩法。
- 把背单词、背概念、背公式、背错题知识点做成内容适配器。

### 阶段四：商店与搭建器

- 应用商店分发 Capability Package。
- 搭建器生成同样格式的 Capability Package。
- Agent 根据需求推荐安装或组合。

## 9. 判断原则

遇到新需求时不要先问“要不要做一个新 app”，而是问：

```text
这是新内容域，还是新学习模式？
```

- 新内容域：做 Adapter。
- 新玩法：做 Pattern。
- 新底层能力：做 Operation / Provider。
- 新独立入口：做 Capability App。
- 新学习流程：做 Skill / Recipe。
- 新长期任务：做 Learning Node + Plan。

## 10. 当前落地切口

本轮改造先做最小闭环：

```text
Capability YAML
-> CapabilityRegistry
-> /api/capabilities
-> 工具箱动态读取 standalone capabilities
-> 保留现有工具路由
```

这一步完成后，现有功能会开始拥有统一生态身份，后续才能自然扩展到商店、搭建器、Agent 编排和计划表节点。

## 11. 主线入口：助教先行，工坊供给

学习辅助软件工坊不是主入口，而是能力供给层。用户的默认入口仍然是聊天界面的助教：

```text
用户表达目标
-> 助教多轮追问补齐信息
-> 生成知识点地图
-> 把地图节点绑定到 Capability App
-> 写入计划表 / 日历
-> 按节点调用讲义、出题、记忆训练、复盘等工具执行
-> 根据完成数据继续调整路线
```

工坊解决的是“能力从哪里来、怎样扩展、怎样共创”的问题；助教解决的是“此刻该学什么、用什么方式学、排到什么时候、完成标准是什么”的问题。

计划节点至少应保存：

```text
capability_id: 使用哪个能力应用
capability_params: 本次调用参数，比如背多少词、练哪些题、主题是什么
completion_contract: 完成标准，比如 attempted_count、accuracy、read_done
planned_date: 进入时间轴 / 计划表
status: pending / done / skipped
```

这样“背单词 30 个”不再只是日历上的一行文字，而是一个可打开、可执行、可统计、可复盘的学习节点。

## 12. 本轮执行闭环

当前最小执行闭环已经从“可编排”推进到“可启动、可回写”：

```text
PlanItem
-> capability_id / capability_params
-> 打开对应 mini-app
-> mini-app 按参数执行
-> completion_result 回写计划项
-> active/today plan provider 刷新
```

第一批落地：

- `memory.drill` 独立路由：`/toolkit/memory-drill`
- 计划进入记忆训练时携带 `topic`、`count`、`content_type`、`plan_id`、`item_id`
- 训练完成后回写 `attempted_count`、`correct_count`、`accuracy`
- `quiz.generate` 支持从计划带主题和题量进入，并在生成后回写完成

这仍然是工业化骨架的早期形态，但已经具备后续做提醒强度、学习画像、复盘调度、掌握度模型的关键数据接口。

## 13. Capability Execution Contract

前端能力应用不应直接互相约定一堆散落的 query 参数。统一使用 `CapabilityExecutionContext` 表达一次能力执行：

```text
capabilityId: 能力 ID
topic: 本次执行主题
count: 本次执行数量
contentType: 内容适配类型
planId / itemId: 是否绑定计划节点
params: 能力应用自定义参数
```

统一启动：

```text
PlanItem
-> CapabilityLaunchService.routeForPlanItem
-> CapabilityExecutionContext
-> appendCapabilityQuery
-> mini-app route
```

统一完成：

```text
mini-app result
-> PlanTaskCompletionService.complete
-> PATCH /api/study-planner/plans/{plan_id}/items/{item_id}
-> completion_result
-> 刷新 active/today plan
```

后续新增 mini-app 的规则：

- 如果只是新内容域，优先新增 Adapter，而不是新 app。
- 如果是新玩法框架，新增 Pattern，并复用执行协议。
- 如果需要独立界面，新增 Capability App，但必须接入 `CapabilityExecutionContext`。
- 如果能进入计划表，必须产出 `completion_result`，不能只标记 done。
