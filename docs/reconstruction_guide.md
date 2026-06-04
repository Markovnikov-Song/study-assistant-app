# 项目复原指南

## 目标

这份文档说明：在没有源代码的情况下，如何仅根据 `docs/` 目录复原“伴学”项目。理想状态不是逐字还原每一行代码，而是复原产品闭环、模块边界、数据模型、API、前端路由、平台能力和验收方法。

复原时应优先读取机器清单：

- `docs/manifests/features.json`：功能、状态和已知缺口。
- `docs/manifests/code_map.json`：功能对应的页面、Provider、Service、模型、后端和测试。
- `docs/manifests/routes.json`：前端路由。
- `docs/manifests/apis.json`：关键 API 合约。
- `docs/manifests/data_models.json`：核心数据模型。
- `docs/manifests/test_matrix.json`：测试分层和验收状态。

## 权威顺序

如果文档之间出现冲突，按以下顺序判断：

1. 当前代码和测试。
2. `docs/manifests/*.json`。
3. `docs/features/*.md`。
4. `docs/inventory/*.md`。
5. `docs/testing/*.md`。
6. `.kiro/` 和历史草稿。

`.kiro/` 只保留为历史背景，不作为当前实现依据。

## 复原步骤

### 1. 复原产品模型

先阅读：

- `docs/README.md`
- `docs/project_blueprint.md`
- `docs/features/*.md`
- `docs/documentation_status.md`

需要明确：

- 用户是谁。
- 主学习闭环是什么。
- 哪些能力已实现、部分实现、规划中或受平台限制。
- 功能之间如何串联。

### 2. 复原技术栈

| 层级 | 技术 |
| --- | --- |
| 移动端/桌面端 UI | Flutter |
| 前端状态管理 | Riverpod |
| 前端路由 | GoRouter |
| 网络客户端 | Dio |
| 本地偏好 | SharedPreferences |
| 后端 | FastAPI + Python |
| Android 原生桥 | Kotlin + MethodChannel |
| iOS 原生桥 | Swift + MethodChannel |
| 文档解析/RAG | 后端文档服务、向量化、检索来源回传 |
| 软件工坊 | JSON 运行配置 + Flutter 渲染 |

### 3. 复原基础目录

```text
backend/
  main.py
  app_routes.py
  routers/
  services/
  models/
lib/
  core/
  components/
  features/
  models/
  providers/
  routes/
  services/
android/
ios/
docs/
tests/
```

### 4. 复原后端

先建立 FastAPI 入口：

- `backend/main.py`
- `backend/app_routes.py`

再按 `docs/manifests/apis.json` 和 `docs/manifests/code_map.json` 恢复 router、service 和模型。每个接口至少需要：

- 路由和 HTTP 方法。
- 请求模型。
- 响应模型。
- 鉴权依赖。
- 核心业务服务。
- 错误码和降级策略。
- 对应测试。

### 5. 复原前端

先恢复基础层：

- `lib/routes/app_routes.dart`
- `lib/routes/app_router.dart`
- `lib/core/network/dio_client.dart`
- `lib/providers/auth_provider.dart`
- `lib/features/home/responsive_shell.dart`

再按 `docs/manifests/routes.json` 恢复页面。每个页面至少需要：

- 路由参数。
- Provider 状态。
- API service。
- 用户主流程。
- 空状态、加载态、错误态。
- 自动化验收点。

### 6. 按依赖顺序复原功能

推荐顺序：

1. 认证与用户。
2. 科目和资源库。
3. 科目空间、思维导图、讲义。
4. 对话和能力调度。
5. 学习计划。
6. 日历和提醒。
7. 番茄钟和专注防打扰。
8. 错题和复习队列。
9. 笔记。
10. 出题和练习。
11. 解题助手。
12. 软件工坊。

软件工坊仍是当前最大未完成域，复原时应标记为部分实现，不要把规划能力当成已完成能力。

### 7. 复原平台能力

Android：

- 通知权限。
- 精确闹钟权限。
- 前台服务。
- 使用情况访问。
- 悬浮窗。
- APK 安装 FileProvider。

iOS：

- 系统通知。
- 普通设置入口。
- Screen Time、应用锁和跨应用限制需要 Apple entitlement；没有 entitlement 时只能文档化为受限能力。

### 8. 验证复原结果

最低验收标准：

- Flutter Web build 通过。
- Flutter analyze 没有新增阻断问题。
- 后端 FastAPI 可启动。
- Playwright L1/L2 用例能覆盖主要入口。
- 关键后端合约测试通过。
- 科目创建、资源状态、RAG 来源、日历事件、番茄钟、错题、笔记、出题、解题主流程可验证。
- Android/iOS 锁屏通知、悬浮窗、应用锁等 L5 能力用真机或模拟器单独验收。

## 给 AI 的复原提示词

```text
请根据 docs/ 目录复原一个 Flutter + FastAPI 学习助手项目。先阅读 docs/README.md、docs/reconstruction_guide.md、docs/project_blueprint.md、docs/manifests/*.json、docs/features/*.md。严格区分 implemented、partial、planned、platform_limited。先生成目录结构和最小可运行骨架，再按功能逐步实现。每个功能必须包含页面入口、状态管理、API 服务、数据模型、错误态和测试。不要把 iOS Screen Time 或应用锁描述成无 entitlement 即可使用的能力。
```
