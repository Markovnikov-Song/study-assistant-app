# 笔记系统

## 基本信息

| 字段 | 内容 |
| --- | --- |
| 功能 ID | `notes.notebooks` |
| 当前状态 | 已实现主流程 |
| 主要入口 | `/toolkit/notebooks`、`/toolkit/notebooks/:notebookId`、`/toolkit/notebooks/:notebookId/notes/:noteId` |
| 后端前缀 | `/api/notebooks`、`/api/notes` |
| 自动化覆盖 | `NOTE-P1-01`、`solve_flow.spec.ts`、`backend/tests/test_review_note_contracts.py` |

## 功能目标

笔记系统负责沉淀学习内容。笔记可以来自手写、解题结果、对话内容或错题复盘。笔记详情页支持 AI 润色，也可以导入资料库，成为 RAG 检索材料。

## 用户流程

1. 用户进入笔记本列表。
2. 用户打开某个笔记本和笔记详情。
3. 用户查看原始内容、标题、来源和导入状态。
4. 用户点击 AI 润色，后端返回润色内容。
5. 用户点击导入资料库，后端生成或关联文档。
6. 笔记更新 `imported_to_doc_id` 后，可参与资料问答和学习材料生成。

## 技术结构

| 层级 | 文件 | 说明 |
| --- | --- | --- |
| 笔记本列表 | `lib/components/notebook/notebook_list_page.dart` | 笔记本入口 |
| 笔记本详情 | `lib/components/notebook/notebook_detail_page.dart` | 笔记列表 |
| 笔记详情 | `lib/components/notebook/note_detail_page.dart` | 查看、编辑、润色、导入资料库 |
| Provider | `lib/providers/notebook_provider.dart` | 笔记本和笔记状态 |
| Service | `lib/services/notebook_service.dart` | Notebook/Note API |
| 后端 | `backend/routers/notebooks.py` | 笔记本 API |
| 后端 | `backend/routers/notes.py` | 笔记详情、润色、导入 RAG |

## API 合同

核心端点：

- `GET /api/notebooks`
- `GET /api/notebooks/{id}`
- `POST /api/notes`
- `GET /api/notes/{id}`
- `PATCH /api/notes/{id}`
- `POST /api/notes/{id}/polish`
- `POST /api/notes/{id}/import-to-rag`

## 数据字段

关键字段：

- `notebook_id`
- `subject_id`
- `role`
- `original_content`
- `title`
- `outline`
- `sources`
- `imported_to_doc_id`
- `note_type`
- `mistake_status`

## 行为边界

- 润色不应覆盖原文，除非用户确认保存。
- 导入资料库失败不应破坏笔记本身。
- 如果 `imported_to_doc_id` 已存在，UI 应提示已导入。

## 验证方式

- `npx playwright test tests/playwright/notebook_flow.spec.ts --reporter=list`
- `npx playwright test tests/playwright/solve_flow.spec.ts --reporter=list`

验收点：

- 笔记详情可打开。
- 点击 AI 润色会请求 `/api/notes/{id}/polish`。
- 点击导入资料库会请求 `/api/notes/{id}/import-to-rag`。
- 保存笔记时来源能保留。
