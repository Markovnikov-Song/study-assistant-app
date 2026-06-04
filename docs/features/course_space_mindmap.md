# 科目空间、思维导图与讲义

## 基本信息

| 字段 | 内容 |
| --- | --- |
| 功能 ID | `course_space.mindmap_lecture` |
| 当前状态 | 部分实现 |
| 主要入口 | `/course-space`、`/course-space/:subjectId`、`/course-space/:subjectId/mindmap/:sessionId` |
| 后端前缀 | `/api/library`、`/api/chat`、`/api/documents` |

## 功能目标

科目空间是围绕一个科目组织资料、思维导图、讲义和学习进度的地方。它把资料库、RAG、导图、讲义、练习和复习连接起来。

## 用户流程

1. 用户进入科目空间。
2. 用户选择一个科目。
3. 页面展示该科目的导图 session、学习进度和资料入口。
4. 用户可以从全部资料或选定资料生成思维导图。
5. 用户进入导图后查看、编辑节点。
6. 用户可以从节点生成讲义、进入练习或继续学习。
7. 讲义可导入资料库，继续供 RAG 使用。

## 技术结构

| 层级 | 文件 | 说明 |
| --- | --- | --- |
| 科目空间首页 | `lib/components/library/library_page.dart` | 科目卡片和概览 |
| 科目详情 | `lib/components/library/course_space_page.dart` | 导图列表、生成入口、进度 |
| 导图编辑 | `lib/components/library/editable_mindmap_page.dart` | 节点编辑、导图交互 |
| 讲义 | `lib/components/library/lecture/lecture_page.dart` | 讲义编辑和导入 RAG |
| Provider | `lib/providers/library_provider.dart` | 科目空间和导图 session |
| Provider | `lib/providers/document_provider.dart` | 资料范围 |
| RAG 设置 | `lib/providers/rag_sync_settings_provider.dart` | 讲义自动导入资料库 |
| Service | `lib/services/library_service.dart` | library/chat/mindmap API |
| 后端 | `backend/routers/library.py` | session、讲义、导图相关 API |
| 后端 | `backend/services/mindmap_service.py` | 导图生成和解析 |

## 数据与状态

关键对象：

- 科目 `Subject`
- 资料 `StudyDocument`
- 导图 session `MindMapSession`
- 导图节点和边
- 讲义内容
- RAG 导入状态

## 行为边界

- “知识关联图”仍是扩展方向，不应写成已完整实现。
- 导图生成依赖资料解析状态；资料未就绪时应提示。
- 讲义导入 RAG 失败不应破坏讲义本身。

## 验证方式

当前主要通过单元测试和入口 smoke 覆盖：

- `test/features/library/mindmap_parser_test.dart`
- `test/features/library/lecture/export_book_dialog_test.dart`
- `tests/playwright/p1_shell_flow.spec.ts`

后续应补：

- 资料范围选择 -> 生成导图 -> 打开导图 -> 生成讲义的 L2/L3 业务验收。
