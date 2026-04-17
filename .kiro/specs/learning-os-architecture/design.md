# 设计文档：Learning OS 架构

## 概述

Learning OS 是对现有学习 App 的架构升级，将其重构为类比"操作系统"的三层分层架构。系统以 Agent 为内核，以 Skill 为应用单元，以可插拔 Component 为工具层，在不中断现有功能的前提下渐进式引入新架构。

本文档描述架构设计、目录结构、骨架文件清单、迁移映射表和三阶段重构计划，并给出可验证的正确性属性。

---

## 架构

### 系统分层模型

```
┌─────────────────────────────────────────────────────────────┐
│                        UI 层（Flutter）                      │
│   底部导航 5 Tab：问答 / 解题 / 导图 / 出题 / 我的           │
│   模式切换入口叠加在"我的"页面或主页顶部                     │
└────────────────────────┬────────────────────────────────────┘
                         │ Intent / 用户操作
┌────────────────────────▼────────────────────────────────────┐
│                   内核层（Agent Kernel）                     │
│   AgentKernel                                               │
│   ├── resolveIntent(text) → IntentResult                    │
│   ├── dispatchSkill(skill, context) → SkillExecution        │
│   └── coordinateComponents(components, data) → void        │
└────────────────────────┬────────────────────────────────────┘
                         │ 调度 Skill / 查询 SkillLibrary
┌────────────────────────▼────────────────────────────────────┐
│                   应用层（Skill Library）                    │
│   SkillLibrary                                              │
│   ├── 内置 Skill（问答、解题、导图、出题、多课学习…）         │
│   ├── 用户自定义 Skill                                       │
│   ├── SkillCreationAdapter（对话式/经验贴/手动三路径）        │
│   └── SkillParser（可插拔 AI 解析接口）                      │
└────────────────────────┬────────────────────────────────────┘
                         │ 调用 Component
┌────────────────────────▼────────────────────────────────────┐
│                   工具层（Component Registry）               │
│   ComponentRegistry                                         │
│   ├── Notebook（笔记本）                                     │
│   ├── MistakeBook（错题本）                                  │
│   ├── MindMap（思维导图）                                    │
│   ├── Quiz（出题）                                           │
│   ├── Chat（问答）                                           │
│   ├── Solve（解题）                                          │
│   ├── Calendar（日历）                                       │
│   └── Timer（计时器）                                        │
└────────────────────────┬────────────────────────────────────┘
                         │ 读写数据
┌────────────────────────▼────────────────────────────────────┐
│                   数据层（Storage / Services）               │
│   StorageService + 各 Service（auth/chat/notebook/…）        │
│   统一 Session 数据关联存储                                  │
└─────────────────────────────────────────────────────────────┘
```

### 四种使用模式与 UI 关系

```
主页顶部 / "我的"页面
┌──────────────────────────────────────────┐
│  Learning OS 模式选择                    │
│  ┌──────────┐ ┌──────────┐              │
│  │ Skill 驱动│ │ 多课学习 │              │
│  └──────────┘ └──────────┘              │
│  ┌──────────┐ ┌──────────┐              │
│  │  DIY 模式 │ │ 纯手动   │              │
│  └──────────┘ └──────────┘              │
└──────────────────────────────────────────┘
         ↓ 不替换底部导航
┌──────────────────────────────────────────┐
│  底部导航（ui-redesign.md 定义，保持不变）│
│  问答 │ 解题 │ 导图 │ 出题 │ 我的        │
└──────────────────────────────────────────┘
```

---

## 组件与接口

### ComponentInterface

所有 Component 必须实现的标准接口：

```dart
abstract class ComponentInterface {
  /// 打开组件，传入上下文（学科 ID、Session ID 等）
  Future<void> open(ComponentContext context);

  /// 向组件写入数据（笔记内容、错题记录等）
  Future<void> write(ComponentData data);

  /// 从组件读取数据
  Future<ComponentData> read(ComponentQuery query);

  /// 关闭组件，释放资源
  Future<void> close();
}
```

### ComponentRegistry

```dart
abstract class ComponentRegistry {
  /// 注册组件，验证 ComponentInterface 实现完整性
  void register(ComponentInterface component, ComponentMeta meta);

  /// 获取组件实例，不存在时返回 ComponentNotFoundError
  Result<ComponentInterface> get(String componentId);

  /// 列出所有已注册组件
  List<ComponentMeta> listAll();
}
```

### AgentKernel

```dart
abstract class AgentKernel {
  /// 解析用户自然语言意图，返回推荐 Skill 列表和 Component 列表
  Future<IntentResult> resolveIntent(String text, SessionContext session);

  /// 按 Skill 的 Prompt_Chain 顺序调度执行
  Future<SkillExecution> dispatchSkill(Skill skill, SessionContext session);

  /// 协调多个 Component 完成复合任务（如多课学习计划）
  Future<void> coordinateComponents(List<String> componentIds, CoordinationData data);
}
```

### SkillCreationAdapter

```dart
abstract class SkillCreationAdapter {
  /// 对话式创建：启动引导对话流程
  Future<SkillDraft> createFromDialog();

  /// 经验贴导入：解析文本生成草稿
  Future<SkillDraft> createFromText(String text);

  /// 手动创建：直接填写字段
  Future<SkillDraft> createManually();
}
```

### SkillParser

```dart
abstract class SkillParser {
  /// 解析非结构化文本，返回 Skill 草稿（可插拔 AI 实现）
  Future<SkillDraft> parse(String text);
}
```

---

## 数据模型

### Skill

```dart
class Skill {
  final String id;                        // 唯一标识符（UUID）
  final String name;                      // Skill 名称
  final String description;              // 描述
  final List<String> tags;               // 适用学科标签
  final List<PromptNode> promptChain;    // Prompt 链（至少 1 个节点）
  final List<String> requiredComponents; // 所需 Component ID 列表
  final String version;                  // 版本号（语义化版本）
  final DateTime createdAt;              // 创建时间
  final SkillType type;                  // builtin | custom
  final String? createdBy;              // 创建者 User ID（custom 时必填）
  final SkillSource? source;            // 来源（内置/用户创建/第三方/经验贴导入）
}

enum SkillType { builtin, custom }
enum SkillSource { builtin, userCreated, thirdPartyApi, experienceImport }
```

### PromptNode

```dart
class PromptNode {
  final String id;
  final String prompt;           // Prompt 模板
  final Map<String, String> inputMapping;  // 上一节点输出 → 本节点输入映射
}
```

### SkillDraft

```dart
class SkillDraft {
  final String? name;
  final String? description;
  final List<String> tags;
  final List<PromptNode> promptChain;
  final List<String> requiredComponents;
  final bool isDraft;            // 草稿状态标志
  final int? sourceTextLength;  // 经验贴导入时记录原始字符数
}
```

### ComponentMeta

```dart
class ComponentMeta {
  final String id;
  final String name;
  final String version;
  final List<String> supportedDataTypes;
  final bool isBuiltin;
}
```

### Session

```dart
class Session {
  final String id;
  final String userId;
  final LearningMode mode;       // skillDriver | multiSubject | diy | manual
  final String? skillId;
  final List<String> componentIds;
  final DateTime startedAt;
  final DateTime? endedAt;
  final SessionStatus status;   // active | paused | completed
}

enum LearningMode { skillDriver, multiSubject, diy, manual }
enum SessionStatus { active, paused, completed }
```

### ComponentContext / ComponentData / ComponentQuery

```dart
class ComponentContext {
  final String sessionId;
  final String? subjectId;       // 复用 currentSubjectProvider 的学科 ID
  final Map<String, dynamic> extra;
}

class ComponentData {
  final String componentId;
  final String dataType;
  final Map<String, dynamic> payload;
}

class ComponentQuery {
  final Map<String, dynamic> filters;
  final int? limit;
  final String? cursor;
}
```

---

## 新目录结构

```
lib/
├── core/
│   ├── agent/
│   │   └── agent_kernel.dart           # AgentKernel 抽象类骨架
│   ├── skill/
│   │   ├── skill_model.dart            # Skill / SkillDraft / PromptNode 数据模型
│   │   ├── skill_library.dart          # SkillLibrary 骨架
│   │   ├── skill_creation_adapter.dart # SkillCreationAdapter 接口
│   │   └── skill_parser.dart           # SkillParser 接口
│   ├── component/
│   │   ├── component_interface.dart    # ComponentInterface 抽象类
│   │   └── component_registry.dart    # ComponentRegistry 骨架
│   ├── constants/                      # 不变
│   ├── network/                        # 不变
│   └── storage/                        # 不变
├── components/                         # 新增：原 features/ 工具类模块
│   ├── chat/                           # 原 features/chat/
│   ├── solve/                          # 原 features/solve/
│   ├── mindmap/                        # 原 features/mindmap/
│   ├── quiz/                           # 原 features/quiz/
│   ├── notebook/                       # 原 features/notebook/
│   ├── mistake_book/                   # 原 features/stationery/
│   └── library/                        # 原 features/library/
├── features/                           # 保留：UI 入口和导航
│   ├── auth/
│   ├── home/
│   ├── profile/
│   └── subjects/
├── models/                             # 不变，后续扩展 Skill/Component 模型
├── providers/                          # 不变，后续扩展 skillProvider/agentProvider
├── routes/                             # 不变，import 路径随迁移更新
├── services/                           # 不变
└── widgets/                            # 不变
```

---

## 骨架文件清单

| 文件路径 | 内容说明 | 阶段 |
|----------|----------|------|
| `core/component/component_interface.dart` | ComponentInterface 抽象类（open/write/read/close） | 第一阶段 |
| `core/component/component_registry.dart` | ComponentRegistry 骨架（register/get/listAll） | 第一阶段 |
| `core/skill/skill_model.dart` | Skill / SkillDraft / PromptNode / ComponentMeta 数据模型 | 第一阶段 |
| `core/skill/skill_library.dart` | SkillLibrary 骨架（save/get/list/delete/filter） | 第一阶段 |
| `core/skill/skill_creation_adapter.dart` | SkillCreationAdapter 接口（三个方法签名） | 第一阶段 |
| `core/skill/skill_parser.dart` | SkillParser 接口（parse 方法签名，返回空草稿默认实现） | 第一阶段 |
| `core/agent/agent_kernel.dart` | AgentKernel 骨架（resolveIntent/dispatchSkill/coordinateComponents） | 第一阶段 |

---

## 迁移映射表

| 现有模块路径 | 新路径 | 新架构层级 | 迁移阶段 |
|-------------|--------|-----------|---------|
| `features/chat/` | `components/chat/` | 工具层（Component） | 第一阶段 |
| `features/solve/` | `components/solve/` | 工具层（Component） | 第一阶段 |
| `features/mindmap/` | `components/mindmap/` | 工具层（Component） | 第一阶段 |
| `features/quiz/` | `components/quiz/` | 工具层（Component） | 第一阶段 |
| `features/notebook/` | `components/notebook/` | 工具层（Component） | 第一阶段 |
| `features/stationery/` | `components/mistake_book/` | 工具层（Component） | 第一阶段 |
| `features/library/` | `components/library/` | 工具层（Component） | 第一阶段 |
| `features/auth/` | `features/auth/` | UI 层（不变） | — |
| `features/home/` | `features/home/` | UI 层（不变） | — |
| `features/profile/` | `features/profile/` | UI 层（不变） | — |
| `features/subjects/` | `features/subjects/` | UI 层（不变） | — |
| `features/history/` | `features/history/` | UI 层（整合进"我的"） | — |
| `features/resources/` | `features/subjects/` 下 | UI 层（整合进学科管理） | — |
| `features/subject_detail/` | `features/subjects/subject_resources/` | UI 层（重命名） | — |
| `models/` | `models/`（扩展 Skill/Component 模型） | 数据层 | 第一阶段 |
| `providers/` | `providers/`（扩展 skillProvider/agentProvider） | 状态层 | 第二阶段 |
| `services/` | `services/`（不变） | 数据层 | — |
| `core/constants/` | `core/constants/` | 内核层（不变） | — |
| `core/network/` | `core/network/` | 内核层（不变） | — |
| `core/storage/` | `core/storage/` | 内核层（不变） | — |

---

## 正确性属性

*属性（Property）是在系统所有合法执行中都应成立的特征或行为——本质上是对系统应做什么的形式化陈述。属性是人类可读规范与机器可验证正确性保证之间的桥梁。*

### 属性 1：Skill 字段完整性

*对于任意* 合法创建的 Skill 对象，其 id、name、description、tags、promptChain、requiredComponents、version、createdAt 字段均应存在且非空。

**验证：需求 1.1**

---

### 属性 2：空 Prompt_Chain 被拒绝

*对于任意* promptChain 为空列表的 Skill 定义，SkillLibrary 的保存操作应返回验证失败错误，且该 Skill 不应出现在后续查询结果中。

**验证：需求 1.2**

---

### 属性 3：引用未注册 Component 时拒绝保存

*对于任意* 包含未在 ComponentRegistry 中注册的组件 ID 的 Skill，SkillLibrary 应拒绝保存，且返回的错误信息中应包含该缺失组件的名称。

**验证：需求 1.3**

---

### 属性 4：Skill 查询结果均含类型标注

*对于任意* Skill 列表查询，所有返回的 Skill 对象都应包含 type 字段，且值为 builtin 或 custom 之一。

**验证：需求 1.4**

---

### 属性 5：Skill 过滤查询结果一致性

*对于任意* 过滤条件（学科标签或名称关键词），SkillLibrary 返回的所有 Skill 都应满足该过滤条件，不应包含不匹配的结果。

**验证：需求 1.6**

---

### 属性 6：推荐 Skill 理由长度约束

*对于任意* Intent 输入，Agent 返回的每个推荐 Skill 的推荐理由字符数应不超过 50 字。

**验证：需求 2.2**

---

### 属性 7：Prompt_Chain 顺序执行与数据传递

*对于任意* 包含多个 PromptNode 的 Skill，dispatchSkill 执行时各节点应按 promptChain 列表顺序依次调用，且第 n 个节点的输出应作为第 n+1 个节点的输入。

**验证：需求 2.4**

---

### 属性 8：Prompt 节点失败时执行终止并记录

*对于任意* 在执行过程中失败的 PromptNode，AgentKernel 应终止当前 Skill 的后续节点执行，记录失败节点信息，并向调用方返回包含可读说明的错误，而非继续执行或静默失败。

**验证：需求 2.6**

---

### 属性 9：ComponentInterface 实现不完整时注册被拒绝

*对于任意* 未完整实现 ComponentInterface（缺少 open/write/read/close 任意一个方法）的组件，ComponentRegistry 的 register 操作应返回验证失败错误，该组件不应出现在后续 listAll 结果中。

**验证：需求 3.2**

---

### 属性 10：未注册组件返回错误而非异常

*对于任意* 未在 ComponentRegistry 中注册的组件 ID，调用 get 方法应返回包含该组件 ID 的"组件未找到"错误，而不应抛出未处理异常。

**验证：需求 3.5**

---

### 属性 11：Session 数据完整关联

*对于任意* 完成的 Session，该 Session 期间产生的所有数据（Skill 执行记录、Component 操作日志、用户学习数据）应均关联到同一个 Session ID 下，通过该 Session ID 查询应能取回全部数据。

**验证：需求 5.2**

---

### 属性 12：历史 Session 查询过滤一致性

*对于任意* 查询条件（Session ID、日期范围、学科、模式类型），返回的所有 Session 记录都应满足该查询条件，不应包含不匹配的记录。

**验证：需求 5.3**

---

### 属性 13：Skill JSON 导出导入往返一致性

*对于任意* 合法的自定义 Skill 对象，将其导出为 JSON 文件后再导入，所得 Skill 对象的所有字段（id 除外，导入时重新分配）应与原 Skill 完全一致。

**验证：需求 7.6**

---

### 属性 14：SkillParser 解析有效文本产生合法草稿

*对于任意* 包含有效步骤结构的学习经验文本，SkillParser.parse 返回的 SkillDraft 应包含至少一个 PromptNode，满足需求 1 的最低结构要求。

**验证：需求 8.2.6**

---

## 错误处理

| 错误场景 | 处理方式 | 返回给调用方 |
|---------|---------|------------|
| Skill 验证失败（空 promptChain / 缺失 Component） | 拒绝保存，返回字段级错误描述 | `SkillValidationError` |
| Component 未注册 | 返回错误对象，不抛异常 | `ComponentNotFoundError(componentId)` |
| Component 注册验证失败 | 拒绝注册，返回缺失方法列表 | `ComponentInterfaceError` |
| Prompt 节点执行失败 | 终止 Skill 执行，记录失败节点 | `SkillExecutionError(nodeId, reason)` |
| 数据写入失败 | 记录失败日志，不丢弃数据 | `StorageWriteError` |
| Session 切换时有活跃 Session | 提示用户确认，保存 Session 状态后切换 | UI 确认对话框 |
| SkillParser 无法解析文本 | 返回可读提示，建议补充内容或改用对话式创建 | `ParseError(reason)` |

---

## 测试策略

### 单元测试

针对具体示例和边界条件：

- Skill 模型验证逻辑（空 promptChain、缺失字段）
- ComponentRegistry 注册/查询逻辑
- SkillLibrary 过滤查询逻辑
- Session 数据关联逻辑
- JSON 序列化/反序列化

### 属性测试

使用 [fast_check](https://pub.dev/packages/fast_check)（Dart PBT 库）验证上述 14 个正确性属性，每个属性测试运行最少 100 次迭代。

测试标签格式：`// Feature: learning-os-architecture, Property {N}: {属性描述}`

重点属性测试：

- **属性 3**：生成随机未注册组件名列表，验证 SkillLibrary 拒绝保存并在错误中包含组件名
- **属性 5**：生成随机 Skill 集合和过滤条件，验证过滤结果的完整性和准确性
- **属性 7**：生成随机 PromptNode 序列，验证执行顺序和数据传递链
- **属性 9**：生成缺少不同方法组合的组件，验证注册拒绝逻辑
- **属性 13**：生成随机合法 Skill，验证 JSON 往返一致性（round-trip）
- **属性 14**：生成包含步骤结构的随机文本，验证 SkillParser 输出合法性

### 集成测试

- Agent 意图解析端到端流程（含 AI 服务调用，1-3 个代表性示例）
- 多课学习 Skill 生成 Learning_Plan 完整流程
- Session 跨设备同步（验证延迟 ≤ 10 秒）
- 现有功能模块迁移后行为一致性回归测试

### 冒烟测试

- ComponentInterface 四个标准方法定义存在
- 六个内置 Component（Notebook/MistakeBook/Calendar/Timer/MindMap/Chat/Solve/Quiz）均已注册
- 底部导航 5 个 Tab 在迁移后正常渲染

---

## 三阶段重构计划

### 第一阶段：目录迁移与骨架搭建（只调整形式，不改业务逻辑）

**目标**：建立新目录结构，搬移文件，更新 import 路径，创建所有骨架文件。

**工作内容**：

1. 创建 `components/` 目录，将 `features/` 中的工具类模块按迁移映射表移动
2. 更新 `routes/app_router.dart` 中的 import 路径
3. 创建 7 个骨架文件（见骨架文件清单）
4. 在 `models/` 中添加 Skill / SkillDraft / PromptNode / ComponentMeta / Session 数据模型
5. 验证：所有现有功能在迁移后行为不变（回归测试）

**约束**：不修改任何现有业务逻辑，不重写任何 Widget。

---

### 第二阶段：ComponentInterface 挂载

**目标**：为各 Component 挂载 ComponentInterface，完成 ComponentRegistry 注册。

**工作内容**：

1. 为 Chat、Solve、MindMap、Quiz、Notebook、MistakeBook 各自实现 ComponentInterface 的四个方法（open/write/read/close 包装现有逻辑）
2. 实现 ComponentRegistry，完成六个内置 Component 的注册
3. 实现 SkillLibrary 的保存/查询/过滤/删除逻辑
4. 在 `providers/` 中添加 `componentRegistryProvider` 和 `skillLibraryProvider`
5. 验证：属性 9、10 的测试通过

**约束**：ComponentInterface 实现层包装现有 Flutter Widget，不要求重写 UI 层。

---

### 第三阶段：AgentKernel 与 SkillLibrary 业务逻辑实现

**目标**：实现 AgentKernel 的意图解析与调度，完善 Skill 创建生态。

**工作内容**：

1. 实现 AgentKernel（resolveIntent 接入 AI 服务，dispatchSkill 按 Prompt_Chain 顺序执行）
2. 实现 SkillCreationAdapter 的三条创建路径（对话式/经验贴/手动）
3. 实现 SkillParser（接入 AI 模型，可插拔）
4. 在"我的"页面或主页顶部添加四种模式切换入口（叠加在现有底部导航之上）
5. 实现 Session 统一数据关联存储
6. 预留 Skill_Marketplace 开放 API 骨架端点
7. 验证：属性 7、8、13、14 的测试通过，集成测试通过

**约束**：底部导航 5 个 Tab 保持不变，模式切换入口叠加而非替换。
