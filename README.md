# 伴学 - AI 智能学习助手

[![Flutter](https://img.shields.io/badge/Flutter-3.11+-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11+-0175C2?style=flat-square&logo=dart)](https://dart.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.95+-009688?style=flat-square&logo=fastapi)](https://fastapi.tiangolo.com)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

一款 AI 驱动的多端学习助手应用，支持问答、思维导图、日程管理、错题本等核心功能，帮助学生高效学习和知识管理。

---

## 目录

- [功能特性](#功能特性)
- [技术架构](#技术架构)
- [项目结构](#项目结构)
- [快速开始](#快速开始)
  - [环境要求](#环境要求)
  - [后端服务](#后端服务)
  - [Flutter 应用](#flutter-应用)
- [使用示例](#使用示例)
  - [登录与认证](#登录与认证)
  - [AI 问答](#ai-问答)
  - [思维导图](#思维导图)
  - [日程管理](#日程管理)
  - [错题本](#错题本)
- [开发指南](#开发指南)
  - [代码生成](#代码生成)
  - [路由配置](#路由配置)
  - [状态管理](#状态管理)
  - [API 调用](#api-调用)
- [贡献指南](#贡献指南)
- [常见问题](#常见问题)

---

## 功能特性

### 🎯 核心功能

| 模块 | 描述 |
|------|------|
| **AI 问答室** | 智能对话，支持多轮上下文理解，关联学科知识 |
| **思维导图** | 可视化知识结构，支持导入 XMind/FreeMind |
| **日历计划** | 日程管理、倒计时、任务统计 |
| **工具箱** | 错题本、笔记本、问答挑战、随机测验 |
| **技能市场** | 浏览和安装 AI 技能扩展 |
| **课程空间** | 学科知识库，支持 Markdown/LLaTeX 渲染 |

### 📱 多端支持

- ✅ Android
- ✅ iOS
- ✅ macOS
- ✅ Windows
- ✅ Linux
- ✅ Web

---

## 技术架构

```
┌─────────────────────────────────────────────────────────────┐
│                         Flutter App                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │   Chat   │  │ Calendar │  │  Library │  │ Toolkit  │    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
│       └────────────┴──────────────┴─────────────┘          │
│                           │                                  │
│                    ┌──────┴──────┐                          │
│                    │  Riverpod   │  (状态管理)               │
│                    └──────┬──────┘                          │
│                           │                                  │
│                    ┌──────┴──────┐                          │
│                    │  GoRouter   │  (路由导航)               │
│                    └─────────────┘                          │
└────────────────────────────┬────────────────────────────────┘
                             │ HTTP
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                      FastAPI Backend                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │   Auth   │  │  Chat AI  │  │  Calendar │  │ Library  │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ Subjects │  │ Sessions  │  │ Notebooks │  │ Marketplace│ │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| **前端框架** | Flutter 3.11+ | 跨平台 UI 框架 |
| **状态管理** | Riverpod 2.6 | 编译时安全的状态管理 |
| **路由** | GoRouter 14.6 | 声明式路由 |
| **HTTP 客户端** | Dio 5.7 | 网络请求库 |
| **后端框架** | FastAPI | Python 高性能 API |
| **数据库** | SQLite | 轻量级本地/云端存储 |

### 主要依赖

- **UI 组件**: flutter_quill (富文本), flutter_markdown (Markdown), flutter_math_fork (LaTeX)
- **数据存储**: shared_preferences, flutter_secure_storage
- **媒体处理**: image_picker, file_picker, screenshot
- **Web 内容**: webview_flutter, archive (XMind 解析)
- **PDF**: pdf, printing
- **日历**: table_calendar, flutter_local_notifications

---

## 项目结构

```
study_assistant_app/
├── lib/                          # Flutter 应用源码
│   ├── main.dart                 # 程序入口
│   ├── app.dart                  # App 根组件
│   ├── routes/                   # 路由配置
│   │   └── app_router.dart       # GoRouter 路由定义
│   ├── providers/                # Riverpod 状态提供者
│   ├── features/                 # 功能模块
│   │   ├── auth/                 # 认证模块
│   │   ├── chat/                 # 问答模块
│   │   ├── calendar/             # 日历模块
│   │   ├── library/               # 课程空间
│   │   ├── toolkit/              # 工具箱
│   │   ├── profile/               # 个人中心
│   │   ├── subjects/             # 学科管理
│   │   ├── skill_marketplace/    # 技能市场
│   │   └── skill_creation/        # 技能创建
│   ├── core/                     # 核心组件
│   │   ├── network/              # 网络层
│   │   ├── storage/              # 存储服务
│   │   ├── theme/                # 主题配置
│   │   ├── skill/                # 技能系统
│   │   └── mcp/                  # MCP 协议
│   ├── components/              # 公共组件
│   │   ├── library/              # 知识库组件
│   │   ├── mindmap_entry/        # 脑图入口
│   │   ├── mistake_book/         # 错题本
│   │   └── notebook/             # 笔记本
│   ├── widgets/                 # 通用 Widget
│   ├── services/                # 业务服务
│   ├── models/                  # 数据模型
│   └── tools/                   # 工具函数
│
├── backend/                      # FastAPI 后端服务
│   ├── main.py                  # 服务入口
│   ├── routers/                 # API 路由
│   │   ├── auth.py              # 认证
│   │   ├── chat.py              # 问答
│   │   ├── calendar.py          # 日历
│   │   ├── library.py           # 知识库
│   │   ├── subjects.py          # 学科
│   │   ├── sessions.py          # 思维导图会话
│   │   └── marketplace.py       # 技能市场
│   ├── services/               # 业务逻辑
│   ├── models/                 # 数据模型
│   ├── prompts/                # AI 提示词
│   └── database.py             # 数据库配置
│
├── api/                          # API 层代码
│   ├── main.py                  # API 入口
│   └── routers/                # API 路由
│
├── android/                     # Android 平台代码
├── ios/                         # iOS 平台代码
├── macos/                       # macOS 平台代码
├── windows/                     # Windows 平台代码
├── linux/                       # Linux 平台代码
├── web/                         # Web 平台代码
│
├── assets/                      # 静态资源
│   ├── images/                 # 图片资源
│   └── fonts/                  # 字体文件
│
├── docs/                        # 项目文档
├── skills/                      # AI 技能定义
├── test/                        # 测试代码
│
├── pubspec.yaml                # Flutter 依赖配置
└── requirements.txt            # Python 依赖配置
```

---

## 快速开始

### 环境要求

| 环境 | 版本要求 |
|------|----------|
| Flutter SDK | ≥ 3.11.4 |
| Dart SDK | ≥ 3.0 |
| Python | ≥ 3.10 |
| Node.js | ≥ 18 (可选，用于 web 开发) |
| Android Studio | 最新版 (Android 开发) |
| Xcode | ≥ 15 (iOS 开发) |

### 后端服务

#### 1. 安装依赖

```bash
cd backend
pip install -r requirements.txt
```

#### 2. 配置环境变量

创建 `.env` 文件：

```bash
# 数据库配置
DATABASE_URL=sqlite:///./study_assistant.db

# JWT 密钥
JWT_SECRET=your-secret-key-change-in-production

# CORS 配置 (可选)
CORS_ALLOWED_ORIGINS=https://your-domain.com

# API 基础 URL
API_BASE_URL=http://localhost:8000
```

#### 3. 初始化数据库

```bash
cd backend
python run_migration.py
```

#### 4. 启动服务

```bash
# 开发模式 (热重载)
uvicorn main:app --reload --port 8000

# 生产模式
uvicorn main:app --host 0.0.0.0 --port 8000
```

后端服务运行在: http://localhost:8000

API 文档: http://localhost:8000/docs

### Flutter 应用

#### 1. 安装 Flutter SDK

参考 [官方文档](https://docs.flutter.dev/get-started/install) 安装 Flutter。

#### 2. 获取依赖

```bash
cd study_assistant_app
flutter pub get
```

#### 3. 配置 API 地址

编辑 `lib/core/network/dio_client.dart` 中的 `baseUrl`：

```dart
// 开发环境
static const baseUrl = 'http://10.0.2.2:8000/api';  // Android 模拟器
// static const baseUrl = 'http://localhost:8000/api';  // iOS 模拟器

// 生产环境
// static const baseUrl = 'https://your-api-domain.com/api';
```

#### 4. 生成代码

```bash
# 生成 Riverpod、Freezed、JSON 序列化代码
dart run build_runner build --delete-conflicting-outputs
```

#### 5. 运行应用

```bash
# 运行到默认设备
flutter run

# 运行到特定平台
flutter run -d android     # Android
flutter run -d ios         # iOS
flutter run -d macos       # macOS
flutter run -d web         # Web
```

#### 6. 构建发布

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web
```

---

## 使用示例

### 登录与认证

应用启动后自动跳转登录页面：

```
┌─────────────────────────────────┐
│           伴 学                  │
│                                 │
│    ┌─────────────────────┐      │
│    │   📱 手机号/邮箱    │      │
│    └─────────────────────┘      │
│                                 │
│    ┌─────────────────────┐      │
│    │   🔒 密码           │      │
│    └─────────────────────┘      │
│                                 │
│    [       登 录        ]        │
│                                 │
│    还没有账号？[立即注册]        │
└─────────────────────────────────┘
```

### AI 问答

1. 进入 **问答室** Tab
2. 输入问题或选择预设问题
3. AI 实时回答，支持追问

```
┌─────────────────────────────────┐
│  问答室                          │
├─────────────────────────────────┤
│  ┌─────────────────────────┐   │
│  │  请教一道数学题           │   │
│  │  "如何证明勾股定理？"    │   │
│  └─────────────────────────┘   │
│                                 │
│           ┌─────────────────┐  │
│           │ 勾股定理的证明... │  │
│           │ (AI 回答区域)     │  │
│           └─────────────────┘  │
│                                 │
├─────────────────────────────────┤
│  [📷] [📁] [🎤] [➕]            │
│  ┌─────────────────────────┐   │
│  │ 输入消息...               │   │
│  └─────────────────────────┘   │
└─────────────────────────────────┘
```

### 思维导图

1. 进入 **课程空间** → 选择学科
2. 创建或选择思维导图会话
3. 支持：
   - 添加/编辑/删除节点
   - 拖拽调整布局
   - 导出为图片
   - 导入 XMind/FreeMind 文件

### 日程管理

1. 进入 **工具箱** → 日历
2. 创建任务/事件
3. 设置提醒和重复规则
4. 查看倒计时和统计

### 错题本

1. 进入 **工具箱** → 错题本
2. 拍照或手动录入错题
3. 添加正确答案和解题思路
4. 定期复习和测验

---

## 开发指南

### 代码生成

项目使用 `build_runner` 自动生成代码：

```bash
# 完整重建
dart run build_runner build --delete-conflicting-outputs

# 监听变化自动重建
dart run build_runner watch --delete-conflicting-outputs

# 清理生成文件后重建
dart run build_runner build --delete-conflicting-outputs
```

**需要生成代码的库：**

| 库 | 生成文件 | 说明 |
|----|---------|------|
| Riverpod | `.g.dart` | 状态提供者 |
| Freezed | `.g.dart` | 不可变数据类 |
| JSON Serializable | `.g.dart` | JSON 序列化 |

### 路由配置

路由定义在 `lib/routes/app_router.dart`：

```dart
class R {
  R._();

  // 定义路由路径常量
  static const chat = '/';
  static const toolkit = '/toolkit';
  static const profile = '/profile';

  // 带参数的路由
  static String chatSession(String chatId) => '/chat/$chatId';
  static String subjectDetail(int id) => '/profile/resources/$id';
}
```

新增路由示例：

```dart
GoRoute(
  path: '/new-page',
  builder: (_, __) => const NewPage(),
),
```

### 状态管理

使用 Riverpod 管理状态：

```dart
// 定义 Provider
final myProvider = Provider<MyService>((ref) {
  return MyService();
});

// 定义 StateNotifier
final counterProvider = StateNotifierProvider<CounterNotifier, int>((ref) {
  return CounterNotifier();
});

// 在 Widget 中使用
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Text('$count');
  }
}
```

### API 调用

通过 Dio 客户端调用后端 API：

```dart
import 'package:dio/dio.dart';
import 'core/network/dio_client.dart';

// 创建 API 服务
class MyApiService {
  final Dio _dio = DioClient.instance.dio;

  Future<List<dynamic>> fetchData() async {
    final response = await _dio.get('/my-endpoint');
    return response.data;
  }

  Future<void> postData(Map<String, dynamic> data) async {
    await _dio.post('/my-endpoint', data: data);
  }
}
```

---

## 贡献指南

欢迎贡献代码！请遵循以下步骤：

### 开发流程

1. **Fork 仓库**
   ```bash
   git clone https://github.com/your-fork/study_assistant_app.git
   cd study_assistant_app
   ```

2. **创建分支**
   ```bash
   # 功能分支
   git checkout -b feature/your-feature-name

   # 修复分支
   git checkout -b fix/your-bug-fix

   # 文档分支
   git checkout -b docs/your-doc-update
   ```

3. **开发与测试**
   ```bash
   # 运行测试
   flutter test

   # 运行分析
   flutter analyze
   ```

4. **提交代码**
   ```bash
   # 暂存更改
   git add .

   # 提交 (遵循 Conventional Commits)
   git commit -m 'feat: add new feature'
   git commit -m 'fix: resolve issue #123'
   git commit -m 'docs: update README'
   ```

5. **推送并创建 PR**
   ```bash
   git push origin feature/your-feature-name
   ```

### 提交规范

| 类型 | 说明 |
|------|------|
| `feat:` | 新功能 |
| `fix:` | Bug 修复 |
| `docs:` | 文档更新 |
| `style:` | 代码格式调整 |
| `refactor:` | 重构 |
| `test:` | 测试相关 |
| `chore:` | 构建/工具相关 |

### 代码规范

- 遵循 Flutter 官方 [Style Guide](https://dart-lang.github.io/linter/lints/)
- 使用 `flutter analyze` 检查代码
- 所有公开 API 必须有文档注释
- 新功能需要配套测试

### 分支管理

```
master          ──── 稳定版本 (生产环境)
    │
    ├── develop      ──── 开发分支 (集成测试)
    │   │
    │   ├── feature/xxx   ──── 功能开发
    │   ├── fix/xxx       ──── Bug 修复
    │   └── docs/xxx      ──── 文档更新
    │
    └── release/x.x.x ──── 发布分支
```

### Issue 报告

报告问题时，请包含：

- 问题描述
- 复现步骤
- 预期行为 vs 实际行为
- 环境信息 (Flutter 版本、平台等)
- 截图或日志（如有）

---

## 常见问题

### Q: 运行 `flutter pub get` 失败？

**A:** 确保 Flutter SDK 已正确安装，并运行以下命令：

```bash
flutter doctor
flutter pub cache repair
flutter pub get
```

### Q: 后端服务启动报错？

**A:** 检查 Python 依赖是否完整安装：

```bash
cd backend
pip install -r requirements.txt
python run_migration.py
```

### Q: Android 构建失败？

**A:** 确保 Android SDK 和 NDK 已正确配置：

```bash
flutter doctor -v
```

### Q: 代码生成报错？

**A:** 清理并重新生成：

```bash
rm -rf .dart_tool/build
dart run build_runner build --delete-conflicting-outputs
```

### Q: 如何获取 API 文档？

**A:** 后端服务启动后访问：http://localhost:8000/docs

---

## 许可证

本项目采用 [MIT 许可证](LICENSE)。

---

## 联系方式

- 项目主页：https://github.com/your-org/study_assistant_app
- 问题反馈：https://github.com/your-org/study_assistant_app/issues
- 讨论交流：https://github.com/your-org/study_assistant_app/discussions

---

<p align="center">
  <strong>Made with ❤️ and Flutter</strong>
</p>
