# Flutter 路由清单

路由常量定义在 `lib/routes/app_routes.dart`，路由装配定义在 `lib/routes/app_router.dart`。机器可读版本见 `docs/manifests/routes.json`。

## Shell Tab

| 路径 | 页面 | 说明 |
| --- | --- | --- |
| `/` | `ChatPage` | 默认对话页 |
| `/course-space` | `LibraryPage` | 科目空间/资料库入口 |
| `/toolkit` | `ToolkitPage` | 学习工具箱 |
| `/profile` | `ProfilePage` | 个人中心 |

## 认证与引导

| 路径 | 说明 |
| --- | --- |
| `/splash` | 启动页 |
| `/onboarding` | 新手引导 |
| `/onboarding?replay=1` | 重放引导 |
| `/login` | 登录 |
| `/register` | 注册 |

## 对话与计划

| 路径 | 说明 |
| --- | --- |
| `/chat/:chatId` | 指定会话 |
| `/chat/:chatId/subject/:subjectId` | 科目上下文会话 |
| `/chat/:chatId/task/:taskId` | 任务上下文会话 |
| `/chat/feynman` | 费曼学习入口 |
| `/spec` | 学习计划/规划对话 |

## 科目空间和思维导图

| 路径 | 说明 |
| --- | --- |
| `/course-space/:subjectId` | 单科空间 |
| `/course-space/:subjectId?generate=1` | 打开并触发生成 |
| `/course-space/:subjectId/mindmap/:sessionId` | 思维导图 |
| `/course-space/:subjectId/mindmap/:sessionId/lecture?node_id=...` | 节点讲义 |
| `/mindmap-entry` | 独立思维导图入口 |
| `/mindmap-entry?generate=1` | 独立生成入口 |

## 工具箱

| 路径 | 说明 |
| --- | --- |
| `/toolkit/mistake-book` | 错题本 |
| `/toolkit/review` | 历史兼容入口：打开错题本；复习队列作为后端调度机制保留 |
| `/toolkit/solve` | 解题助手 |
| `/toolkit/quiz` | 出题/练习 |
| `/toolkit/practice` | 去练习：按科目、知识点、计划组织练习 |
| `/toolkit/memory-drill` | 记忆练习 |
| `/toolkit/settings` | 工具设置 |
| `/toolkit/mindmap-workshop` | 思维导图工坊 |
| `/toolkit/notebooks` | 笔记本列表 |
| `/toolkit/notebooks/:notebookId` | 笔记本详情 |
| `/toolkit/notebooks/:notebookId/notes/:noteId` | 笔记详情 |

## 日历

| 路径 | 说明 |
| --- | --- |
| `/toolkit/calendar` | 学习日历 |
| `/toolkit/calendar/task/:taskId` | 指定任务日历视图 |
| `/toolkit/calendar/countdown` | 倒计时列表 |
| `/toolkit/calendar/stats` | 日历统计 |

## 软件工坊和 Skill

| 路径 | 说明 |
| --- | --- |
| `/skill-marketplace` | Skill 市场 |
| `/skill-create-dialog` | 对话式创建 Skill |
| `/my-skills` | 我的 Skill |
| `/workshop` | 软件工坊首页 |
| `/workshop/builder` | 软件工坊构建器 |
| `/workshop/apps/:appId` | Mini App 运行/编辑页 |

## 个人中心

| 路径 | 说明 |
| --- | --- |
| `/profile/edit` | 编辑资料 |
| `/profile/memory` | 学习记忆 |
| `/profile/subjects` | 科目管理 |
| `/profile/resources` | 资源管理 |
| `/profile/resources/:id` | 资源/科目详情 |
| `/profile/history` | 历史 |
| `/profile/token-usage` | Token 使用 |
| `/profile/token-usage/detail` | Token 明细 |
| `/profile/notifications` | 通知设置 |
| `/profile/api-config` | API 配置 |
| `/profile/logs` | 日志 |
| `/profile/settings` | 设置 |

## 维护要求

- 新页面必须先在 `app_routes.dart` 有稳定路由常量，再在 `app_router.dart` 注册。
- 涉及深链或通知跳转的路由必须写入对应功能文档和 `docs/manifests/routes.json`。
- 路由参数要在功能文档中说明含义、类型和默认行为。
