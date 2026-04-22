# 设计文档：UI 重设计（对话中心版）

## 概述

将 Flutter 学习助手应用从「答疑室为中心的多 Tab 内嵌」架构，重构为以**对话为主入口**的交互架构（类比豆包式体验）。底部 4 个 Tab 作为主导航，通用聊天页（`/`）为默认首页，场景意图识别在对话流中触发跳转卡片，其余功能通过 Tab 直达或对话内卡片引导进入。

核心变化：根路由从 `/classroom` 改为 `/`；ClassroomPage 拆解为独立的 ChatPage（参数化）+ 工具箱子页；路由按模块拆分；新增 SceneCard、IntentDetector、SpecPage、currentSessionProvider。

---

## 架构总览

```mermaid
graph TD
    App[MaterialApp] --> Router[GoRouter]
    Router --> Shell[ShellRoute / ShellPage]
    Shell --> ChatPage[ChatPage\n路由: /]
    Shell --> CourseSpace[CourseSpacePage\n路由: /course-space]
    Shell --> Toolkit[ToolkitPage\n路由: /toolkit]
    Shell --> Profile[ProfilePage\n路由: /profile]

    Router --> AuthRoutes[auth_routes\n/login /register]
    Router --> ChatRoutes[chat_routes\n/chat/:chatId/*]
    Router --> ToolkitRoutes[toolkit_routes\n/toolkit/*]
    Router --> CourseSpaceRoutes[course_space_routes\n/course-space/*]
    Router --> SpecRoute[/spec → SpecPage]

    ChatPage -->|意图识别| IntentDetector
    IntentDetector -->|插入卡片| SceneCard
    SceneCard -->|用户确认| Router

    ChatPage -->|chatProvider\nchatId| ChatNotifier
    ChatNotifier --> ChatService
```

---

## 路由结构设计

### 新旧路由对比

| 旧路由 | 新路由 | 说明 |
|--------|--------|------|
| `/classroom`（根） | `/`（根） | 通用聊天页，默认首页 |
| `/classroom`（问答 Tab） | `/chat/:chatId` | 单次对话 Session |
| `/classroom`（解题 Tab） | `/toolkit/solve` | 解题页独立路由 |
| `/classroom`（出题 Tab） | `/toolkit/quiz` | 出题页独立路由 |
| `/classroom`（导图 Tab） | `/course-space/:subjectId/mindmap/:nodeId` | 归入课程空间 |
| `/library` | `/course-space` | 重命名，语义更清晰 |
| `/stationery` | `/toolkit` | 重命名，4 列网格 |
| `/profile` | `/profile` | 保留 |
| `/mistakes` | `/toolkit/mistake-book` | 归入工具箱子路由 |
| `/profile/notebooks` | `/toolkit/notebooks` | 归入工具箱子路由 |
| `/mindmap-entry` | 废弃 | 入口合并至工具箱 |

### 完整路由树

```
/login                                          登录页
/register                                       注册页
/                                               通用聊天页（ShellRoute 根）
/chat/:chatId                                   对话 Session 页
/chat/:chatId/subject/:subjectId                学科专属对话
/chat/:chatId/task/:taskId                      任务关联对话
/spec                                           Spec 规划模式页
/course-space                                   课程空间（学科列表）
/course-space/:subjectId                        学科详情（大纲/导图/讲义）
/course-space/:subjectId/outline/:nodeId        大纲节点
/course-space/:subjectId/mindmap/:nodeId        思维导图
/course-space/:subjectId/lecture/:nodeId        讲义
/toolkit                                        工具箱（4 列网格）
/toolkit/mistake-book                           错题本列表
/toolkit/mistake-book/:mistakeId                错题详情
/toolkit/notebooks                              笔记本列表
/toolkit/notebooks/:notebookId                  笔记本详情
/toolkit/notebooks/:notebookId/notes/:noteId    笔记详情
/toolkit/solve                                  解题页
/toolkit/solve/:chatId                          解题对话 Session
/toolkit/quiz                                   出题页
/toolkit/quiz/:chatId                           出题对话 Session
/profile                                        个人中心
/profile/subjects                               学科管理
/profile/history                                对话历史
```

### 路由模块拆分

```
lib/routes/
├── app_router.dart          # 主路由组装，ShellRoute + redirect 逻辑
├── auth_routes.dart         # /login, /register
├── chat_routes.dart         # /, /chat/:chatId, /chat/:chatId/subject/*, /spec
├── course_space_routes.dart # /course-space/**
└── toolkit_routes.dart      # /toolkit/**
```

`app_router.dart` 只负责组装各模块路由列表和 redirect 逻辑，不再内联所有路由定义。

---

## 组件架构设计

### ShellPage（底部导航壳）

**改动点**：路由表从 `['/classroom', '/library', '/stationery', '/profile']` 改为 `['/', '/course-space', '/toolkit', '/profile']`；图标从 `school_outlined` 改为 `chat_bubble_outline`；Tab 名称「文具盒」改为「工具箱」（steering 文档中两者并存，以 requirements.md 为准：「文具盒」Tab 名保留，路由改为 `/toolkit`）。

```dart
// shell_page.dart 关键改动
static const _routes = ['/', '/course-space', '/toolkit', '/profile'];
static const _tabs = [
  (Icons.chat_bubble_outline,   Icons.chat_bubble,   '答疑室'),
  (Icons.menu_book_outlined,    Icons.menu_book,     '图书馆'),
  (Icons.edit_outlined,         Icons.edit,          '文具盒'),
  (Icons.person_outline,        Icons.person,        '我的'),
];
```

PageView 的子页面列表同步更新为 `[ChatPage(), CourseSpacePage(), ToolkitPage(), ProfilePage()]`。

---

### ChatPage（通用聊天页，参数化重构）

**现状**：`ChatPage` 无路由参数，依赖全局 `currentSubjectProvider` 获取学科 ID，`_key` 固定为 `(subjectId, 'qa')`。

**目标**：支持三种场景，通过路由参数区分：

| 场景 | 路由 | 参数 | chatProvider key |
|------|------|------|-----------------|
| 通用对话 | `/` | 无 | `('general', 'qa')` |
| 学科专属 | `/chat/:chatId/subject/:subjectId` | chatId, subjectId | `(chatId, 'subject')` |
| 任务对话 | `/chat/:chatId/task/:taskId` | chatId, taskId | `(chatId, 'task')` |

**接口设计**：

```dart
class ChatPage extends ConsumerStatefulWidget {
  final String? chatId;       // null → 通用对话（根路由 /）
  final int? subjectId;       // 学科专属对话
  final String? taskId;       // 任务对话

  const ChatPage({super.key, this.chatId, this.subjectId, this.taskId});
}
```

**顶栏逻辑**：
- `subjectId != null` → 显示学科名 + 返回按钮
- `taskId != null` → 显示任务名 + 返回按钮
- 两者均为 null → 显示「学习助手」+ 新建按钮

**chatProvider key 迁移**：

```dart
// 旧：(int subjectId, String type)
// 新：(String chatKey, String type)
// chatKey = chatId ?? 'general'
(String, String) get _providerKey => (widget.chatId ?? 'general', _sessionType);
```

`chatProvider` 的 Family 参数类型从 `(int, String)` 改为 `(String, String)`，`chatId` 作为字符串传入（通用对话用 `'general'`）。

**SceneCard 插入点**：在 `_ChatBody` 的消息列表渲染中，识别 `ChatMessage` 的 `type == MessageType.sceneCard` 时渲染 `SceneCard` 组件而非气泡。

---

### SceneCard（场景识别卡片）

新建 `lib/widgets/scene_card.dart`。

**数据模型**：

```dart
enum SceneType { subject, planning, tool, spec }

class SceneCardData {
  final SceneType type;
  final String title;       // 卡片标题，如「检测到高数相关问题」
  final String? subtitle;   // 副标题，可选
  final String confirmLabel;   // 主操作按钮文字
  final String dismissLabel;   // 次操作按钮文字
  final Map<String, dynamic> payload; // 跳转所需参数（subjectId/taskId/toolRoute）
  final bool dismissed;     // 是否已关闭（防止重复触发）
}
```

**Widget 接口**：

```dart
class SceneCard extends StatelessWidget {
  final SceneCardData data;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;
  // ...
}
```

**视觉规格**：圆角卡片（`borderRadius: 12`），左侧彩色竖条区分场景类型，主操作按钮 `FilledButton`，次操作按钮 `TextButton`。

---

### IntentDetector（意图识别服务）

新建 `lib/services/intent_detector.dart`。

**职责**：分析用户输入文本，返回识别到的意图类型和相关参数。

```dart
enum IntentType { none, subject, planning, tool, spec }

class DetectedIntent {
  final IntentType type;
  final Map<String, dynamic> params; // subjectName/toolName 等
}

abstract class IntentDetector {
  Future<DetectedIntent> detect(String userInput, {List<Subject>? subjects});
}

class RuleBasedIntentDetector implements IntentDetector {
  // 规则匹配：关键词 + 学科名列表
  // 优先级：spec > planning > subject > tool > none
}
```

**触发规则（初版，规则匹配）**：

| 意图 | 触发条件 |
|------|----------|
| `subject` | 输入包含已知学科名（从 `subjectsProvider` 获取） |
| `planning` | 包含「备考」「复习计划」「考试」「学习目标」等关键词 |
| `tool` | 包含「笔记」「错题」「记录」「整理」等关键词 |
| `spec` | 包含「系统学习」「完整计划」「从零开始」等大型任务关键词 |

**调用时机**：在 `ChatNotifier.sendMessage` 完成后，由 `ChatPage` 调用 `IntentDetector.detect(userInput)`，若返回非 `none` 意图且该消息尚未触发过卡片，则向消息列表追加一条 `type == sceneCard` 的消息。

---

### ToolkitPage（工具箱，数据驱动）

重构 `lib/components/mistake_book/stationery_page.dart` → 迁移至 `lib/features/toolkit/toolkit_page.dart`。

**工具配置模型**：

```dart
class ToolItem {
  final String id;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String route;
}

// 初始工具列表（数据驱动，无需改动布局代码即可扩展）
const List<ToolItem> kDefaultTools = [
  ToolItem(id: 'mistake-book', icon: Icons.error_outline,    label: '错题本', route: '/toolkit/mistake-book'),
  ToolItem(id: 'notebooks',    icon: Icons.book_outlined,    label: '笔记本', route: '/toolkit/notebooks'),
  ToolItem(id: 'solve',        icon: Icons.calculate_outlined, label: '解题',  route: '/toolkit/solve'),
  ToolItem(id: 'quiz',         icon: Icons.quiz_outlined,    label: '出题',   route: '/toolkit/quiz'),
];
```

**布局**：`GridView.builder`，`crossAxisCount: 4`，`childAspectRatio: 0.85`（图标 + 文字标签）。

**卡片样式**：圆角方形容器（`borderRadius: 16`）+ 居中图标（`size: 36`）+ 下方文字标签，与手机桌面 App 图标一致。

---

### SpecPage（新建）

新建 `lib/features/spec/spec_page.dart`。

**职责**：Spec 规划模式入口页，展示大型学习任务的结构化拆解和进度管理。

**初版设计**：占位页面，顶栏「Spec 规划模式」+ 返回按钮，主体展示「功能开发中」提示，后续迭代补充完整功能。

---

## 状态管理设计

### Provider 变更清单

| Provider | 变更 | 说明 |
|----------|------|------|
| `currentSubjectProvider` | 保留 | 全局当前学科，`StateProvider<Subject?>` |
| `authProvider` | 保留 | 登录状态 |
| `subjectsProvider` | 保留 | 学科列表缓存 |
| `chatProvider` | **修改 key 类型** | `(int, String)` → `(String, String)`，chatId 改为字符串 |
| `currentSessionProvider` | **新建** | `StateProvider<Session?>`，追踪当前活跃 Session |
| `classroomInitialTabProvider` | **废弃** | ClassroomPage 拆解后不再需要 |

### currentSessionProvider

```dart
// lib/providers/current_session_provider.dart
final currentSessionProvider = StateProvider<Session?>((ref) => null);
```

**生命周期**：
- 用户进入某个 `/chat/:chatId` 页面时，由 ChatPage 写入当前 Session
- `authProvider` 变为未登录时，自动清除（在 `app_router.dart` 的 redirect 或 `authProvider` 监听中处理）

### chatProvider key 迁移

```dart
// 旧
final chatProvider = StateNotifierProviderFamily<ChatNotifier, AsyncValue<List<ChatMessage>>, (int, String)>(...);

// 新
final chatProvider = StateNotifierProviderFamily<ChatNotifier, AsyncValue<List<ChatMessage>>, (String, String)>(...);
// key.$1 = chatId（字符串），key.$2 = sessionType（'qa'/'subject'/'task'）
```

`ChatNotifier` 内部的 `_subjectId` 字段改为从路由参数传入，不再依赖 `currentSubjectProvider`。

---

## 数据模型设计

### ChatMessage 扩展

现有 `ChatMessage` 需新增 `type` 字段以支持 SceneCard 消息：

```dart
enum MessageType { text, sceneCard }

// 在 ChatMessage 中新增
final MessageType type;
final SceneCardData? sceneCardData; // type == sceneCard 时非空
```

### Session 模型

新建或复用现有 Session 模型，确保包含：

```dart
class Session {
  final String id;
  final String title;
  final DateTime updatedAt;
  final String? subjectId;
  final String? taskId;
}
```

---

## 改动文件清单

### 新建文件

| 文件路径 | 说明 |
|----------|------|
| `lib/routes/auth_routes.dart` | 登录/注册路由 |
| `lib/routes/chat_routes.dart` | 对话相关路由（/, /chat/**, /spec） |
| `lib/routes/course_space_routes.dart` | 课程空间路由 |
| `lib/routes/toolkit_routes.dart` | 工具箱路由 |
| `lib/features/chat/chat_page.dart` | 参数化 ChatPage（替换原 components/chat/chat_page.dart） |
| `lib/features/toolkit/toolkit_page.dart` | 工具箱页（4 列网格，数据驱动） |
| `lib/features/spec/spec_page.dart` | Spec 规划模式页 |
| `lib/widgets/scene_card.dart` | 场景识别卡片组件 |
| `lib/services/intent_detector.dart` | 意图识别服务 |
| `lib/providers/current_session_provider.dart` | 当前 Session 状态 |

### 修改文件

| 文件路径 | 改动说明 |
|----------|----------|
| `lib/routes/app_router.dart` | 重写：根路由改为 `/`，组装模块路由，redirect 逻辑保留 |
| `lib/features/home/shell_page.dart` | 路由表、图标、Tab 名更新；子页面列表更新 |
| `lib/providers/chat_provider.dart` | chatProvider Family key 类型从 `(int, String)` 改为 `(String, String)` |
| `lib/models/chat_message.dart` | 新增 `MessageType` 枚举和 `sceneCardData` 字段 |

### 废弃/迁移文件

| 文件路径 | 处理方式 |
|----------|----------|
| `lib/components/mistake_book/stationery_page.dart` | 迁移至 `lib/features/toolkit/toolkit_page.dart` |
| `lib/components/chat/chat_page.dart` | 迁移至 `lib/features/chat/chat_page.dart`（参数化重构） |
| `lib/features/classroom/classroom_page.dart` | 废弃，功能拆解至 ChatPage + ToolkitPage |
| `lib/components/library/library_page.dart` | 迁移至 `lib/features/course_space/course_space_page.dart` |

### 保留不动文件

| 文件路径 | 说明 |
|----------|------|
| `lib/components/solve/solve_page.dart` | 保留，路由入口改为 `/toolkit/solve` |
| `lib/components/quiz/quiz_page.dart` | 保留，路由入口改为 `/toolkit/quiz` |
| `lib/components/mindmap/mindmap_page.dart` | 保留，入口改为课程空间 |
| `lib/features/profile/profile_page.dart` | 保留 |
| `lib/providers/auth_provider.dart` | 保留 |
| `lib/providers/current_subject_provider.dart` | 保留 |

---

## 关键设计决策

**1. ChatPage 参数化方式**：选择构造函数参数（而非仅依赖路由参数读取），便于在 ShellRoute 根路由 `/` 直接实例化 `ChatPage()` 无参版本，同时支持 `/chat/:chatId/subject/:subjectId` 等深层路由传参。

**2. chatProvider key 从 int 改为 String**：通用对话没有数字 subjectId，用字符串 `'general'` 作为 key 更自然；学科专属对话用 `chatId` 字符串作为 key，与路由参数一致。

**3. IntentDetector 初版用规则匹配**：避免引入额外 API 调用延迟，规则匹配在本地同步执行，后续可替换为 LLM 分类接口而不影响调用方。

**4. SceneCard 作为消息列表中的特殊消息类型**：而非 SnackBar 或 Dialog，保证卡片在对话流中有历史记录，用户可回滚查看，且不阻断输入。

**5. 工具箱数据驱动**：`kDefaultTools` 为常量列表，后续扩展只需追加 `ToolItem`，`GridView.builder` 自动适配，无需改动布局代码。
