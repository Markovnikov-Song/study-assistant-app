# 科目、资料库与 RAG 来源

## 基本信息

| 字段 | 内容 |
| --- | --- |
| 功能 ID | `subjects.resources_rag` |
| 当前状态 | 已实现主流程 |
| 主要入口 | `/profile/subjects`、`/profile/resources`、`/profile/resources/:id` |
| 后端前缀 | `/api/subjects`、`/api/documents`、`/api/chat` |
| 自动化覆盖 | `SUBJECT-P1-01`、`DOC-P1-01`、`RAG-P1-01` |

## 功能目标

科目是学习数据的组织边界。资料库负责把教材、讲义、课件、笔记导入、错题和真题材料解析为可检索知识块。RAG 来源负责在资料问答时把回答对应到具体文件和片段，让用户知道答案来自哪里。

讲义、笔记、错题等内容产物不应为了入库而互相伪装。它们各自保留原数据表，资料库里创建可检索的 `Document/Chunk` 镜像，并由源对象保存 `imported_to_doc_id` 指针指向资料库 Document。用户在错题本/讲义页看到的是原对象，在资料库/RAG 中看到的是同一份内容的可检索索引。

资料包导入只导入资源，不自动创建科目，不自动创建知识树。创建科目、生成思维导图、建立知识树都必须是用户明确确认后的动作。

## 用户流程

1. 用户在科目管理中新建科目。
2. 用户进入资料管理，选择某个科目。
3. 系统展示该科目的资料库状态：资料数量、知识块数量、导图是否就绪。
4. 用户可以上传资料、重建全部索引，或后续对单个资料执行操作。
5. 系统按资源来源和用途展示分类：教材资料、生成讲义、错题资源、笔记导入、真题练习、其他资料。
6. 用户从知识点生成讲义后，讲义可以直接导入资料库，不需要先保存为笔记。
7. 用户可以把错题直接导入资料库；源错题继续留在错题本/复习队列，资料库 Document 作为检索镜像。
8. 用户在对话或解题中使用资料问答时，后端通过 SSE 返回 `[SOURCES]` 帧。
9. 前端把来源挂到 assistant 消息上，UI 展示参考来源。

## 已实现能力

- 科目列表、新建、编辑、置顶、归档、删除。
- 资料管理按科目进入详情。
- 资料库状态展示：文档数、知识块数、导图状态。
- 资料列表按资源类型分组：教材资料、生成讲义、错题资源、笔记导入、真题练习、其他资料。
- 全量重建索引请求。
- RAG 流式问答来源解析。
- 笔记导入资料库后可成为 RAG 文档。
- 讲义可直接导入资料库，也可保存为笔记。
- 错题可直接导入资料库，错题本保留源对象，资料库保留检索镜像。

## 技术结构

| 层级 | 文件 | 说明 |
| --- | --- | --- |
| 科目 UI | `lib/features/subjects/subjects_page.dart` | 科目管理页和表单 |
| 资料入口 | `lib/features/resources/resources_page.dart` | 资料管理科目列表 |
| 资料详情 | `lib/features/subject_detail/subject_detail_page.dart` | 资料、历年题、设置 Tab |
| 资料 Tab | `lib/features/subject_detail/tabs/docs_tab.dart` | 资料状态、上传、重建索引、资料列表 |
| 讲义回写 | `lib/components/library/lecture/lecture_page.dart` | 讲义直接导入资料库，或保存为笔记 |
| 错题回写 | `lib/components/review/review_page.dart`、`lib/components/mistake_book/mistake_book_page.dart` | 错题直接导入资料库 |
| Provider | `lib/providers/subject_provider.dart` | 科目查询和操作 |
| Provider | `lib/providers/document_provider.dart` | 资料、知识库状态、上传/删除/重建索引 |
| Chat Provider | `lib/providers/chat_provider.dart` | 解析 SSE `[SOURCES]` 并写入消息 |
| 模型 | `lib/models/subject.dart` | 科目模型 |
| 模型 | `lib/models/document.dart` | 资料和知识库状态 |
| 模型 | `lib/models/chat_message.dart` | `MessageSource` 与消息来源 |
| 后端 | `backend/routers/chat.py` | SSE 返回 sources |
| 后端 | `backend/services/rag_pipeline.py` | 检索、重排、生成和来源收集 |

## API 合同

详见 `docs/manifests/apis.json`。

核心端点：

- `GET /api/subjects`
- `POST /api/subjects`
- `GET /api/documents?subject_id=...`
- `GET /api/documents/knowledge-base?subject_id=...`
- `POST /api/documents/reindex-all?subject_id=...`
- `POST /api/library/lectures/{lecture_id}/import-to-rag?subject_id=...`
- `POST /api/review/mistakes/{note_id}/import-to-rag`
- `POST /api/chat/query/stream`

## 行为边界

- 资料包导入不得自动创建科目或知识树，只能进入用户已选择的科目资料库。
- 资源分类优先使用 `parser_backend`：`lecture`、`mistake`、`note`；没有来源字段时才根据文件名兜底归类。
- 讲义和错题入库不是复制业务对象，而是创建资料库检索镜像，并由源对象保存 `imported_to_doc_id`。
- Playwright 不稳定覆盖浏览器文件选择器，真实上传需要后端 E2E 或专门测试夹具。
- 单文档三点菜单当前坐标测试较脆，建议给 Flutter 组件补语义 key 后再升级。
- RAG 来源必须由后端返回；如果没有检索到资料，UI 不应伪造来源。

## 验证方式

- `npx playwright test tests/playwright/subject_resource_flow.spec.ts --reporter=list`
- `flutter test test/providers/chat_provider_sources_test.dart`

验收点：

- 新建科目请求体包含 `name/category/description/color_index`。
- 资料库页面可读取知识库状态并触发全量重建索引。
- SSE `[SOURCES]` 会挂到 assistant 消息 `sources` 上。
