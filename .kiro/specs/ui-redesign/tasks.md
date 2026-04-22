# 实施计划：UI 重设计（对话中心版）

## 概述

将应用从「答疑室多 Tab 内嵌」架构重构为以对话为主入口的交互架构。按依赖顺序分阶段实施：先迁移底层状态管理和数据模型，再重构路由层，最后逐步替换各页面组件，最终清理废弃文件。

## 任务列表

- [x] 1. 状态管理层变更
  - [x] 1.1 迁移 `chatProvider` Family key 类型
    - 修改 `lib/providers/chat_provider.dart`：将 `StateNotifierProviderFamily` 的参数类型从 `(int, String)` 改为 `(String, String)`
    - 同步修改 `chatSendingProvider` 的 Family 参数类型为 `(String, String)`
    - 修改 `ChatNotifier` 构造函数：`_subjectId` 字段类型从 `int` 改为 `String`，命名改为 `_chatKey`
    - 通用对话 key 为 `('general', 'qa')`，学科对话 key 为 `(chatId, 'subject')`，任务对话 key 为 `(chatId, 'task')`
    - _Requirements: 14.4_

  - [x] 1.2 新建 `currentSessionProvider`
    - 新建 `lib/providers/current_session_provider.dart`
    - 定义 `Session` 数据类（含 `id`、`title`、`updatedAt`、`subjectId?`、`taskId?` 字段）
    - 定义 `final currentSessionProvider = StateProvider<Session?>((ref) => null)`
    - _Requirements: 14.5_

  - [x] 1.3 扩展 `ChatMessage` 数据模型
    - 修改 `lib/models/chat_message.dart`：新增 `MessageType` 枚举（`text`、`sceneCard`）
    - 在 `ChatMessage` 中新增 `type` 字段（默认 `MessageType.text`）和 `sceneCardData` 字段（可为 null）
    - 确保现有 `ChatMessage.local(...)` 工厂方法向后兼容
    - _Requirements: 14.4_

- [x] 2. 路由层重构
  - [x] 2.1 新建 `auth_routes.dart`
    - 新建 `lib/routes/auth_routes.dart`，导出 `/login`、`/register` 两条 `GoRoute`
    - _Requirements: 13.1, 13.3_

  - [x] 2.2 新建 `chat_routes.dart`
    - 新建 `lib/routes/chat_routes.dart`，包含以下路由：
      - `/`（根路由，`ChatPage()` 无参版本）
      - `/chat/:chatId`（`ChatPage(chatId: ...)` ）
      - `/chat/:chatId/subject/:subjectId`（`ChatPage(chatId: ..., subjectId: ...)`）
      - `/chat/:chatId/task/:taskId`（`ChatPage(chatId: ..., taskId: ...)`）
      - `/spec`（`SpecPage()`）
    - _Requirements: 13.1, 13.3_

  - [x] 2.3 新建 `course_space_routes.dart`
    - 新建 `lib/routes/course_space_routes.dart`，包含 `/course-space`、`/course-space/:subjectId`、`/course-space/:subjectId/outline/:nodeId`、`/course-space/:subjectId/mindmap/:nodeId`、`/course-space/:subjectId/lecture/:nodeId`
    - _Requirements: 13.1, 13.3_

  - [x] 2.4 新建 `toolkit_routes.dart`
    - 新建 `lib/routes/toolkit_routes.dart`，包含 `/toolkit`、`/toolkit/mistake-book`、`/toolkit/mistake-book/:mistakeId`、`/toolkit/notebooks`、`/toolkit/notebooks/:notebookId`、`/toolkit/notebooks/:notebookId/notes/:noteId`、`/toolkit/solve`、`/toolkit/solve/:chatId`、`/toolkit/quiz`、`/toolkit/quiz/:chatId`
    - _Requirements: 13.1, 13.3_

  - [x] 2.5 重写 `app_router.dart`
    - 重写 `lib/routes/app_router.dart`：
      - 更新 `AppRoutes` 常量类，根路由改为 `/`，移除旧的 `/classroom`、`/stationery`、`/library` 常量，新增 `/course-space`、`/toolkit` 等
      - `initialLocation` 改为 `/`
      - `redirect` 逻辑中登录后跳转目标改为 `/`
      - `ShellRoute` 子路由改为 `/`、`/course-space`、`/toolkit`、`/profile`
      - 组装 `authRoutes`、`chatRoutes`、`courseSpaceRoutes`、`toolkitRoutes` 模块路由列表
      - 废弃 `classroomInitialTabProvider` 相关引用
      - 未定义路由重定向至 `/`（Requirements: 13.2）
    - _Requirements: 13.1, 13.2, 13.3, 1.2, 1.5_

- [x] 3. ShellPage 更新
  - [x] 3.1 更新 `shell_page.dart` 路由表与 Tab 配置
    - 修改 `lib/features/home/shell_page.dart`：
      - `_routes` 改为 `['/', '/course-space', '/toolkit', '/profile']`
      - `_tabs` 图标改为 `chat_bubble_outline`/`chat_bubble`、`menu_book_outlined`/`menu_book`、`edit_outlined`/`edit`、`person_outline`/`person`
      - Tab 名称「答疑室」「图书馆」「文具盒」「我的」（以 requirements.md 为准）
      - `_pages` 子页面列表改为 `[ChatPage(), CourseSpacePage(), ToolkitPage(), ProfilePage()]`
      - 移除对 `ClassroomPage`、`StationeryPage`、`LibraryPage` 的 import
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 4. ChatPage 参数化重构
  - [x] 4.1 新建参数化 `ChatPage`
    - 新建 `lib/features/chat/chat_page.dart`
    - 构造函数接受 `chatId`（`String?`）、`subjectId`（`int?`）、`taskId`（`String?`）三个可选参数
    - `_providerKey` 计算逻辑：`(chatId ?? 'general', sessionType)`
    - 顶栏逻辑：`subjectId != null` → 学科名 + 返回按钮；`taskId != null` → 任务名 + 返回按钮；两者均 null → 「学习助手」+ 新建按钮
    - 迁移原 `lib/components/chat/chat_page.dart` 的消息列表、输入栏、气泡等子组件
    - 消息列表渲染中识别 `message.type == MessageType.sceneCard` 时渲染 `SceneCard` 而非气泡
    - 移除对 `currentSubjectProvider` 的依赖（改为构造函数参数传入）
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 3.1, 3.2, 3.3, 3.4_

  - [x] 4.2 接入 `currentSessionProvider`
    - 在 `ChatPage` 进入时（`initState` 或 `didChangeDependencies`）将当前 Session 写入 `currentSessionProvider`
    - 在 `ChatPage` 离开时（`dispose`）清除 `currentSessionProvider`
    - _Requirements: 14.5, 14.6_

- [x] 5. 工具箱页重构
  - [x] 5.1 新建 `ToolkitPage`
    - 新建 `lib/features/toolkit/toolkit_page.dart`
    - 定义 `ToolItem` 数据类（`id`、`icon`、`iconColor`、`label`、`route` 字段）
    - 定义 `kDefaultTools` 常量列表，包含「错题本」`/toolkit/mistake-book`、「笔记本」`/toolkit/notebooks`、「解题」`/toolkit/solve`、「出题」`/toolkit/quiz` 四个工具
    - 使用 `GridView.builder`，`crossAxisCount: 4`，`childAspectRatio: 0.85`
    - 工具卡片样式：圆角方形容器（`borderRadius: 16`）+ 居中图标（`size: 36`）+ 下方文字标签
    - 点击卡片调用 `context.push(item.route)`
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7_

- [x] 6. SceneCard 组件
  - [x] 6.1 新建 `SceneCard` 组件
    - 新建 `lib/widgets/scene_card.dart`
    - 定义 `SceneType` 枚举（`subject`、`planning`、`tool`、`spec`）
    - 定义 `SceneCardData` 数据类（`type`、`title`、`subtitle?`、`confirmLabel`、`dismissLabel`、`payload`、`dismissed` 字段）
    - 实现 `SceneCard` StatelessWidget：接受 `data`、`onConfirm`、`onDismiss` 参数
    - 视觉规格：圆角卡片（`borderRadius: 12`），左侧彩色竖条区分场景类型，`FilledButton` 主操作，`TextButton` 次操作
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3, 5.4, 6.1, 6.2, 6.3, 6.4, 7.1, 7.2, 7.3_

- [x] 7. IntentDetector 服务
  - [x] 7.1 新建 `IntentDetector` 服务
    - 新建 `lib/services/intent_detector.dart`
    - 定义 `IntentType` 枚举（`none`、`subject`、`planning`、`tool`、`spec`）
    - 定义 `DetectedIntent` 数据类（`type`、`params` 字段）
    - 定义 `abstract class IntentDetector` 接口，方法 `Future<DetectedIntent> detect(String userInput, {List<Subject>? subjects})`
    - 实现 `RuleBasedIntentDetector`：优先级 `spec > planning > subject > tool > none`
      - `spec`：包含「系统学习」「完整计划」「从零开始」等关键词
      - `planning`：包含「备考」「复习计划」「考试」「学习目标」等关键词
      - `subject`：输入包含已知学科名（从传入的 `subjects` 列表匹配）
      - `tool`：包含「笔记」「错题」「记录」「整理」等关键词
    - _Requirements: 4.1, 5.1, 6.1, 7.1_

  - [x] 7.2 在 `ChatPage` 中接入 `IntentDetector`
    - 在 `ChatPage` 中实例化 `RuleBasedIntentDetector`
    - `sendMessage` 完成后调用 `detect(userInput, subjects: ...)`
    - 若返回非 `none` 意图且该消息尚未触发过卡片（`dismissed == false`），向消息列表追加一条 `type == MessageType.sceneCard` 的消息
    - `SceneCard` 的 `onConfirm` 回调根据 `IntentType` 执行对应路由跳转
    - `SceneCard` 的 `onDismiss` 回调将该消息的 `dismissed` 标记为 `true` 并更新状态
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3, 5.4, 6.1, 6.2, 6.3, 6.4, 7.1, 7.2, 7.3_

- [x] 8. SpecPage 新建
  - [x] 8.1 新建 `SpecPage` 占位页
    - 新建 `lib/features/spec/spec_page.dart`
    - 顶栏显示「Spec 规划模式」+ 返回按钮
    - 主体展示「功能开发中」占位提示
    - _Requirements: 7.2_

- [x] 9. 废弃旧文件清理
  - [x] 9.1 清理 `ClassroomPage` 及相关引用
    - 确认 `lib/features/classroom/classroom_page.dart` 中的 `classroomInitialTabProvider` 已无引用后，删除该文件
    - 移除 `app_router.dart` 中对 `ClassroomPage` 的 import 和路由注册
    - _Requirements: 13.1_

  - [x] 9.2 迁移并清理 `StationeryPage`
    - 确认 `ToolkitPage` 已完整替代 `StationeryPage` 功能后，删除 `lib/components/mistake_book/stationery_page.dart`
    - 移除所有对 `StationeryPage` 的 import 引用
    - _Requirements: 8.1_

  - [x] 9.3 清理旧 `ChatPage`
    - 确认 `lib/features/chat/chat_page.dart` 已完整替代后，删除 `lib/components/chat/chat_page.dart`
    - 更新所有仍引用旧 `ChatPage` 的文件（如 `classroom_page.dart` 已删除，检查其他引用点）
    - _Requirements: 2.1, 3.1_

  - [x] 9.4 最终检查点
    - 确保所有测试通过，路由跳转正常，底部 Tab 切换正常，如有问题请向用户反馈。

## 备注

- 标有 `*` 的子任务为可选项，可跳过以加快 MVP 进度
- 任务 1（状态管理层）必须先于任务 4（ChatPage 重构）完成，因为 ChatPage 依赖新的 `chatProvider` key 类型
- 任务 2（路由层）必须先于任务 3（ShellPage）完成，因为 ShellPage 需要引用新路由常量
- 任务 6（SceneCard）和任务 7（IntentDetector）可与任务 4 并行，但最终接入需在任务 4 完成后进行
