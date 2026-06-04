# 对话与能力调度

## 基本信息

| 字段 | 内容 |
| --- | --- |
| 功能 ID | `chat.cas` |
| 当前状态 | 部分实现 |
| 主要入口 | `/`、`/chat/:chatId`、`/chat/:chatId/subject/:subjectId` |
| 后端前缀 | `/api/chat`、`/api/cas`、`/api/capabilities` |

## 功能目标

对话是用户进入学习系统的自然语言入口。能力调度负责识别用户意图，并跳转到解题、计划、思维导图、练习、软件工坊等具体功能。

## 用户流程

1. 用户在首页输入问题或学习需求。
2. 系统根据文本识别意图。
3. 普通知识问答走 RAG/聊天流。
4. 明确功能意图会生成跳转或能力执行上下文。
5. 用户确认后进入对应页面。
6. 对话历史和来源信息保留，供后续追问。

## 技术结构

| 层级 | 文件 | 说明 |
| --- | --- | --- |
| 页面 | `lib/features/chat/chat_page.dart` | 主聊天页、输入框、来源展示、场景卡 |
| 响应式页面 | `lib/features/chat/responsive_chat_page.dart` | shell 中的聊天入口 |
| Provider | `lib/providers/chat_provider.dart` | 消息状态、SSE、RAG sources、发送/取消 |
| Service | `lib/services/chat_service.dart` | `/api/chat/query` 和 `/api/chat/query/stream` |
| 意图识别 | `lib/services/intent_detector.dart` | 本地意图检测 |
| CAS | `backend/cas/` | 后端能力执行层 |
| Chat API | `backend/routers/chat.py` | 普通问答和 SSE |

## 关键实现点

- `ChatNotifier.sendMessage` 会乐观插入用户消息和 assistant 占位消息。
- 流式响应中 `[SESSION_ID:x]` 会更新当前会话。
- 流式响应中 `[SOURCES]{...}` 会解析为 `MessageSource[]` 并挂到 assistant 消息。
- `[NEEDS_CONFIRMATION]` 表示严格资料模式下未找到相关内容，需要用户确认是否结合通用知识。
- `BackgroundTaskService` 会尝试启用 wakelock，但 wakelock 失败不应中断对话。

## 行为边界

- CAS 调度失败不能吞掉用户输入。
- RAG 没有来源时不能伪造来源。
- 对话跳转到工具页时要保留上下文参数，例如 `subject_id`、`node_id`、`topic`。
- 软件工坊相关意图目前只应进入工坊入口或构建器，不应承诺完整生成能力。

## 验证方式

- `flutter test test/providers/chat_provider_sources_test.dart`
- 入口 smoke：`npx playwright test tests/playwright/p1_shell_flow.spec.ts --reporter=list`

验收点：

- SSE sources 能进入 assistant 消息。
- 聊天入口登录态可打开。
- wakelock 通道不可用时不会让聊天流崩溃。
