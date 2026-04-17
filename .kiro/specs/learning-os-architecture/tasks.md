# 实施计划：Learning OS 架构重构

## 概述

本计划分三阶段渐进式重构现有 Flutter 学习 App 为 Learning OS 分层架构。
**当前执行范围：第一阶段——目录迁移与骨架搭建**，核心原则是只调整形式，不改变功能。

---

## 任务

### 第一阶段：目录迁移与骨架搭建

- [x] 1. 搬移 `features/chat/` → `components/chat/`
  - 使用 smartRelocate 将 `lib/features/chat/chat_page.dart` 移动到 `lib/components/chat/chat_page.dart`
  - 确认 import 路径自动更新（app_router.dart 等引用方）
  - _需求：6.1, 6.2_

- [x] 2. 搬移 `features/solve/` → `components/solve/`
  - 使用 smartRelocate 将 `lib/features/solve/solve_page.dart` 移动到 `lib/components/solve/solve_page.dart`
  - 确认 import 路径自动更新
  - _需求：6.1, 6.2_

- [x] 3. 搬移 `features/quiz/` → `components/quiz/`
  - 使用 smartRelocate 将 `lib/features/quiz/quiz_page.dart` 移动到 `lib/components/quiz/quiz_page.dart`
  - 确认 import 路径自动更新
  - _需求：6.1, 6.2_

- [x] 4. 搬移 `features/stationery/` → `components/mistake_book/`
  - 使用 smartRelocate 将 `lib/features/stationery/mistake_book_page.dart` 移动到 `lib/components/mistake_book/mistake_book_page.dart`
  - 使用 smartRelocate 将 `lib/features/stationery/stationery_page.dart` 移动到 `lib/components/mistake_book/stationery_page.dart`
  - 确认 import 路径自动更新
  - _需求：6.1, 6.2_

- [x] 5. 搬移 `features/notebook/` → `components/notebook/`（含子目录）
  - 使用 smartRelocate 搬移以下文件到 `lib/components/notebook/`：
    - `note_detail_page.dart`
    - `notebook_detail_page.dart`
    - `notebook_list_page.dart`
  - 使用 smartRelocate 搬移 `widgets/` 子目录下四个文件到 `lib/components/notebook/widgets/`：
    - `note_card.dart`
    - `notebook_card.dart`
    - `notebook_picker_sheet.dart`
    - `subject_section.dart`
  - 确认 import 路径自动更新
  - _需求：6.1, 6.2_

- [x] 6. 搬移 `features/mindmap/` → `components/mindmap/`（含子目录）
  - 使用 smartRelocate 搬移根目录下 4 个文件到 `lib/components/mindmap/`：
    - `mindmap_page.dart`
    - `mindmap_view_native.dart`
    - `mindmap_view_stub.dart`
    - `mindmap_view_web.dart`
  - 使用 smartRelocate 搬移 `data/` 子目录（3 个文件）到 `lib/components/mindmap/data/`
  - 使用 smartRelocate 搬移 `domain/` 子目录（5 个文件）到 `lib/components/mindmap/domain/`
  - 使用 smartRelocate 搬移 `models/` 子目录（3 个文件）到 `lib/components/mindmap/models/`
  - 使用 smartRelocate 搬移 `providers/` 子目录（1 个文件）到 `lib/components/mindmap/providers/`
  - 使用 smartRelocate 搬移 `widgets/` 子目录（8 个文件）到 `lib/components/mindmap/widgets/`
  - 确认 import 路径自动更新
  - _需求：6.1, 6.2_

- [x] 7. 搬移 `features/library/` → `components/library/`（含子目录）
  - 使用 smartRelocate 搬移根目录下 3 个文件到 `lib/components/library/`：
    - `course_space_page.dart`
    - `editable_mindmap_page.dart`
    - `library_page.dart`
  - 使用 smartRelocate 搬移 `lecture/` 子目录（4 个文件）到 `lib/components/library/lecture/`
  - 使用 smartRelocate 搬移 `mindmap/` 子目录（3 个文件）到 `lib/components/library/mindmap/`
  - 确认 import 路径自动更新
  - _需求：6.1, 6.2_

- [x] 8. 创建骨架文件：`core/component/component_interface.dart`
  - 定义 `ComponentContext`、`ComponentData`、`ComponentQuery` 数据类
  - 定义 `ComponentInterface` 抽象类，包含四个方法签名：`open`、`write`、`read`、`close`
  - 只写接口定义，无业务逻辑
  - _需求：3.1_

- [x] 9. 创建骨架文件：`core/component/component_registry.dart`
  - 定义 `ComponentNotFoundError` 和 `ComponentInterfaceError` 错误类
  - 定义 `ComponentRegistry` 抽象类，包含三个方法签名：`register`、`get`、`listAll`
  - 只写接口定义，无业务逻辑
  - _需求：3.2, 3.3, 3.4, 3.5_

- [x] 10. 创建骨架文件：`core/skill/skill_model.dart`
  - 定义 `SkillType` 和 `SkillSource` 枚举
  - 定义 `LearningMode` 和 `SessionStatus` 枚举
  - 定义 `PromptNode` 数据类
  - 定义 `Skill` 数据类（含所有字段：id、name、description、tags、promptChain、requiredComponents、version、createdAt、type、createdBy、source）
  - 定义 `SkillDraft` 数据类
  - 定义 `ComponentMeta` 数据类
  - 定义 `Session` 数据类
  - 定义 `IntentResult`、`SkillExecution`、`SessionContext`、`CoordinationData` 占位数据类
  - _需求：1.1, 1.4, 1.5_

- [x] 11. 创建骨架文件：`core/skill/skill_library.dart`
  - 定义 `SkillValidationError` 错误类
  - 定义 `SkillLibrary` 抽象类，包含方法签名：`save`、`get`、`list`、`delete`、`filter`
  - 只写接口定义，无业务逻辑
  - _需求：1.1, 1.2, 1.3, 1.4, 1.6_

- [x] 12. 创建骨架文件：`core/skill/skill_creation_adapter.dart`
  - 定义 `SkillCreationAdapter` 抽象类，包含三个方法签名：`createFromDialog`、`createFromText`、`createManually`
  - 只写接口定义，无业务逻辑
  - _需求：8.3.2_

- [x] 13. 创建骨架文件：`core/skill/skill_parser.dart`
  - 定义 `ParseError` 错误类
  - 定义 `SkillParser` 抽象类，包含 `parse(String text)` 方法签名
  - 提供返回空草稿的默认实现（`DefaultSkillParser`）
  - _需求：8.3.3_

- [x] 14. 创建骨架文件：`core/agent/agent_kernel.dart`
  - 定义 `SkillExecutionError` 错误类
  - 定义 `AgentKernel` 抽象类，包含三个方法签名：`resolveIntent`、`dispatchSkill`、`coordinateComponents`
  - 只写接口定义，无业务逻辑
  - _需求：2.1, 2.4, 2.6_

- [x] 15. 回归验证：运行 `flutter analyze` 确认无编译错误
  - 执行 `flutter analyze` 检查所有 import 路径是否正确更新
  - 修复任何因迁移导致的 import 错误
  - 确认 `lib/routes/app_router.dart` 中的路由引用均已更新
  - 确认所有骨架文件无语法错误
  - _需求：6.2, 6.3_

---

### 第二阶段：ComponentInterface 挂载（当前不执行）

- [ ]* 16. 为 Chat 实现 ComponentInterface
  - 在 `lib/components/chat/` 中新建 `chat_component.dart`
  - 实现 `open`/`write`/`read`/`close` 四个方法，包装现有 ChatPage 逻辑
  - _需求：3.1, 3.6_

- [ ]* 17. 为 Solve 实现 ComponentInterface
  - 在 `lib/components/solve/` 中新建 `solve_component.dart`
  - 实现四个标准方法，包装现有 SolvePage 逻辑
  - _需求：3.1, 3.6_

- [ ]* 18. 为 MindMap 实现 ComponentInterface
  - 在 `lib/components/mindmap/` 中新建 `mindmap_component.dart`
  - 实现四个标准方法，包装现有 MindMapPage 逻辑
  - _需求：3.1, 3.6_

- [ ]* 19. 为 Quiz 实现 ComponentInterface
  - 在 `lib/components/quiz/` 中新建 `quiz_component.dart`
  - 实现四个标准方法，包装现有 QuizPage 逻辑
  - _需求：3.1, 3.6_

- [ ]* 20. 为 Notebook 实现 ComponentInterface
  - 在 `lib/components/notebook/` 中新建 `notebook_component.dart`
  - 实现四个标准方法，包装现有 NotebookListPage 逻辑
  - _需求：3.1, 3.6_

- [ ]* 21. 为 MistakeBook 实现 ComponentInterface
  - 在 `lib/components/mistake_book/` 中新建 `mistake_book_component.dart`
  - 实现四个标准方法，包装现有 MistakeBookPage 逻辑
  - _需求：3.1, 3.6_

- [ ]* 22. 实现 ComponentRegistry，注册六个内置 Component
  - 在 `lib/core/component/` 中新建 `component_registry_impl.dart`
  - 实现 `register`/`get`/`listAll` 方法，含接口完整性验证逻辑
  - 注册 Chat、Solve、MindMap、Quiz、Notebook、MistakeBook 六个 Component
  - _需求：3.2, 3.3, 3.4, 3.5, 3.6_

- [ ]* 23. 实现 SkillLibrary 的保存/查询/过滤/删除逻辑
  - 在 `lib/core/skill/` 中新建 `skill_library_impl.dart`
  - 实现 Skill 验证（空 promptChain、未注册 Component 检查）
  - 实现按标签和关键词过滤查询
  - _需求：1.1, 1.2, 1.3, 1.4, 1.6_

- [ ]* 24. 在 providers/ 中添加 componentRegistryProvider 和 skillLibraryProvider
  - 新建 `lib/providers/component_registry_provider.dart`
  - 新建 `lib/providers/skill_library_provider.dart`
  - _需求：3.4_

- [ ]* 25. 属性测试：ComponentRegistry 注册与查询
  - 写属性测试验证属性 9（接口不完整时注册被拒绝）
  - 写属性测试验证属性 10（未注册组件返回错误而非异常）
  - _需求：3.2, 3.5_

---

### 第三阶段：AgentKernel 与 SkillLibrary 业务逻辑实现（当前不执行）

- [ ]* 26. 实现 AgentKernel（resolveIntent + dispatchSkill）
  - 在 `lib/core/agent/` 中新建 `agent_kernel_impl.dart`
  - 实现 `resolveIntent` 接入 AI 服务，3 秒内返回结果
  - 实现 `dispatchSkill` 按 Prompt_Chain 顺序执行，含失败节点处理
  - _需求：2.1, 2.2, 2.3, 2.4, 2.6_

- [ ]* 27. 实现 SkillCreationAdapter 三条创建路径
  - 在 `lib/core/skill/` 中新建 `skill_creation_adapter_impl.dart`
  - 实现 `createFromDialog`（对话式引导流程）
  - 实现 `createFromText`（经验贴解析路径）
  - 实现 `createManually`（手动填写路径）
  - _需求：8.1, 8.2, 7.1_

- [ ]* 28. 实现 SkillParser（接入 AI 模型）
  - 在 `lib/core/skill/` 中新建 `skill_parser_impl.dart`
  - 实现 `parse` 方法，从非结构化文本提取步骤生成 SkillDraft
  - 实现无法解析时返回 ParseError 的逻辑
  - _需求：8.2.1, 8.2.3, 8.2.4_

- [ ]* 29. 在"我的"页面添加四种模式切换入口
  - 修改 `lib/features/profile/profile_page.dart`，叠加 Learning OS 模式选择区块
  - 支持 Skill 驱动、多课学习、DIY、纯手动四种模式入口
  - 不替换底部导航，叠加在现有 UI 之上
  - _需求：4.1_

- [ ]* 30. 实现 Session 统一数据关联存储
  - 在 `lib/services/` 中新建 `session_service.dart`
  - 实现 Session 创建、暂停、完成、查询逻辑
  - 实现按 Session ID、日期范围、学科、模式类型过滤查询
  - _需求：4.7, 5.1, 5.2, 5.3_

- [ ]* 31. 预留 Skill_Marketplace 开放 API 骨架端点
  - 在 `lib/services/` 中新建 `skill_marketplace_service.dart`
  - 预留 `POST /api/skills`、`GET /api/skills`、`GET /api/skills/{id}` 三个端点骨架
  - 各端点返回固定占位响应
  - _需求：8.3.1_

- [ ]* 32. 属性测试：Prompt_Chain 顺序执行与 JSON 往返一致性
  - 写属性测试验证属性 7（Prompt_Chain 顺序执行与数据传递）
  - 写属性测试验证属性 8（节点失败时执行终止并记录）
  - 写属性测试验证属性 13（Skill JSON 导出导入往返一致性）
  - 写属性测试验证属性 14（SkillParser 解析有效文本产生合法草稿）
  - _需求：2.4, 2.6, 7.6, 8.2.6_

---

## 备注

- 标注 `*` 的任务为可选任务，属于第二、三阶段，当前不执行
- 第一阶段所有任务均不修改任何现有业务逻辑，不重写任何 Widget
- 属性测试使用 `fast_check` 库，标签格式：`// Feature: learning-os-architecture, Property {N}: {属性描述}`
- 回归验证以 `flutter analyze` 通过为准
