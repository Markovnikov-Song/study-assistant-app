# 伴学 App 软件架构文档

> 最后更新：2026-04-23

## 1. 整体架构

### 1.1 技术栈

| 层级 | 技术选型 |
|------|----------|
| 框架 | Flutter ≥3.11.4 |
| 状态管理 | Riverpod (StateNotifier + FamilyProvider) |
| 路由 | GoRouter + ShellRoute |
| HTTP 客户端 | Dio (单例 + 拦截器) |
| 本地存储 | SharedPreferences |
| 后端通信 | REST API + SSE 流式响应 |

### 1.2 目录结构

```
lib/
├── main.dart                 # 入口
├── app.dart                  # App 根组件
├── routes/
│   └── app_router.dart       # 路由配置 + R 类路径常量
├── core/                     # 核心基础设施
│   ├── agent/                # Agent 系统
│   ├── component/            # 通用组件库
│   ├── constants/            # 常量（API 地址等）
│   ├── event_bus/            # 事件总线（跨模块通信）
│   ├── mcp/                  # MCP 协议
│   ├── mini_app/             # 微应用契约
│   ├── network/              # Dio HTTP 客户端
│   ├── skill/                # Skill 技能系统
│   ├── storage/              # 本地存储服务
│   └── theme/                # 主题系统
├── features/                 # 功能模块（按领域组织）
│   ├── auth/                # 认证（登录/注册）
│   ├── calendar/            # 日历模块
│   ├── chat/                # 答疑室
│   ├── history/             # 历史记录
│   ├── home/                # 首页 Shell
│   ├── profile/             # 用户中心
│   ├── resources/           # 资源管理
│   ├── skill_creation/      # Skill 创建
│   ├── skill_marketplace/  # Skill 市场
│   ├── skill_runner/        # Skill 执行器
│   ├── spec/                # Spec 规划模式
│   ├── subjects/            # 学科管理
│   ├── subject_detail/      # 学科详情
│   └── toolkit/             # 工具箱
├── components/              # 业务组件
│   ├── chat/                # 聊天相关组件
│   ├── library/             # 图书馆组件（脑图、讲义等）
│   ├── mindmap/             # 脑图编辑器
│   ├── mindmap_entry/       # 脑图入口
│   ├── mistake_book/        # 错题本
│   ├── notebook/            # 笔记本
│   ├── quiz/                # 测验
│   └── solve/               # 解题
├── widgets/                  # 通用 UI 组件
│   ├── markdown_latex_view.dart
│   ├── mcp_status_indicator.dart
│   ├── message_search_delegate.dart
│   ├── scene_card.dart
│   ├── session_history_sheet.dart
│   └── subject_bar.dart
├── providers/               # Riverpod Providers
├── services/               # 服务层
├── models/                  # 数据模型
└── tools/                   # 工具集
```

### 1.3 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                         App (MaterialApp.router)            │
├─────────────────────────────────────────────────────────────┤
│  ShellPage (底部4Tab + PageView保活 + SVG背景)              │
├────────────────┬────────────────┬────────────────┬──────────┤
│   答疑室        │    图书馆      │    工具箱       │   我的   │
│  (ChatPage)    │ (LibraryPage) │ (ToolkitPage)  │(Profile) │
├────────────────┴────────────────┴────────────────┴──────────┤
│                     Riverpod (状态管理层)                    │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │Services  │  │ Providers │  │  Models  │  │  Events  │   │
│  │(数据层)  │  │ (状态层)  │  │ (实体)   │  │ (事件)   │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
├─────────────────────────────────────────────────────────────┤
│         DioClient (单例) ──────────────→ FastAPI Backend     │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. 核心模块分析

### 2.1 Chat/答疑室模块 ⭐⭐⭐⭐

**架构**：
```
ChatPage (UI层)
    │
    ├── IntentDetector (意图识别)
    │       ├── RuleBasedIntentDetector
    │       └── SceneCard (场景卡片)
    │
    └── ChatNotifier (StateNotifier)
            │
            ├── ChatService (HTTP)
            ├── SSE Stream (流式响应)
            └── ChatMessage Model
```

**亮点**：
- SSE 流式打字机效果
- `StateNotifierProvider.family` 按会话隔离状态
- 意图识别 + 场景卡片引导

**待改进**：
- ChatNotifier 过于臃肿，建议拆分

### 2.2 Calendar/日历模块 ⭐⭐⭐⭐⭐

**架构**：
```
CalendarPage
    │
    ├── MonthView / TimetableView (视图层)
    │
    ├── CalendarProviders (按月缓存)
    │
    ├── EventBus (跨模块通信)
    │
    └── CalendarApiService (数据层)
```

**亮点**：
- 完整的 MVC 结构
- EventBus 解耦（聊天→日历触发）
- 月份预取优化

### 2.3 Skill/技能系统 ⭐⭐⭐⭐

**模型设计**：
```dart
class Skill {
  final List<PromptNode> promptChain;  // 链式编排
  final List<String> requiredComponents;
}

class PromptNode {
  final String prompt;
  final Map<String, String> inputMapping;
}
```

**亮点**：
- 清晰的数据模型
- PromptChain 链式编排
- Marketplace 雏形

**待改进**：
- 缺少 PromptChain 执行引擎
- 缺少本地持久化

---

## 3. 状态管理

### 3.1 Riverpod 模式

| 类型 | 用途 | 示例 |
|------|------|------|
| `Provider` | 服务单例 | `chatServiceProvider` |
| `StateNotifierProvider` | 复杂状态 | `authProvider` |
| `StateNotifierProvider.family` | 带参数状态 | `chatProvider(chatKey)` |
| `FutureProvider` | 异步数据 | `subjectsProvider` |
| `FutureProvider.family` | 带参数异步 | `sessionsProvider(subjectId)` |

### 3.2 EventBus 跨模块通信

```dart
// 触发
AppEventBus.instance.fire(CalendarEventCreated(...));

// 监听
bus.on<CalendarEventCreated>().listen((e) { ... });
```

---

## 4. 网络层

### 4.1 DioClient 单例

```dart
DioClient.instance.init();  // main.dart 初始化

// 拦截器
- AuthInterceptor: 自动注入 Bearer Token
- PrettyDioLogger: 请求/响应日志
```

### 4.2 API 调用模式

```dart
// Service 层
class ChatService {
  Stream<String> sendMessageStream(...) async* {
    // SSE 流式响应
  }
}
```

---

## 5. 路由设计

### 5.1 路由结构

```
/login, /register                    # Auth
/                                   # 答疑室（根）
/chat/:chatId                       # 聊天会话
/course-space/:subjectId            # 课程空间
/course-space/:subjectId/mindmap/:sessionId  # 脑图编辑
/toolkit/*                          # 工具箱子路由
/profile/*                          # 用户中心子路由
```

### 5.2 ShellRoute (底部导航)

```dart
ShellRoute(
  builder: (_, __, child) => ShellPage(child: child),
  routes: [
    GoRoute(path: '/'),              // 答疑室
    GoRoute(path: '/course-space'),  // 图书馆
    GoRoute(path: '/toolkit'),       // 工具箱
    GoRoute(path: '/profile'),       // 我的
  ],
)
```

---

## 6. 改进路线图

### 已完成 ✅

| 日期 | 改进项 |
|------|--------|
| 2026-04-23 | 修复 lint 错误（wand_outlined 图标） |
| 2026-04-23 | 清理未使用变量和导入 |
| 2026-04-23 | 清理废弃路由别名 |
| 2026-04-23 | 生成架构文档 |

### 待完成

| 优先级 | 改进项 | 说明 |
|--------|--------|------|
| 🔴 高 | 拆分 ChatNotifier | 分离业务逻辑和状态管理 |
| 🔴 高 | 实现 PromptChain 引擎 | Skill 系统核心 |
| 🟡 中 | 添加网络重试机制 | Dio 拦截器 |
| 🟡 中 | 本地持久化缓存 | Hive/Isar |
| 🟢 低 | refreshToken 支持 | Auth 增强 |
| 🟢 低 | withOpacity → withValues | Flutter 3.33+ 适配 |

---

## 7. 开发规范

### 7.1 文件命名

- 页面：`xxx_page.dart`
- 组件：`xxx_widget.dart` 或 `xxx_component.dart`
- Provider：`xxx_provider.dart`
- Service：`xxx_service.dart`
- Model：`xxx_model.dart`

### 7.2 路由常量

使用 `R` 类定义所有路由路径：

```dart
class R {
  static const chat = '/';
  static String chatSession(String id) => '/chat/$id';
}
```

### 7.3 Provider 命名

```dart
// Service
final xxxServiceProvider = Provider<XxxService>((ref) => XxxService());

// State
final xxxProvider = StateNotifierProvider<XxxNotifier, XxxState>((ref) => ...);

// Family
final xxxProvider = FutureProvider.family<T, K>((ref, key) => ...);
```

---

*文档由 AI 架构师自动生成*
