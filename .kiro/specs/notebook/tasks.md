# 实现计划：笔记本功能

## 概述

按照"数据层 → 服务层 → Provider 层 → UI 层"的顺序逐步实现笔记本功能，每个阶段均与前一阶段的代码集成，最终完成从聊天页多选收藏到笔记本管理的完整闭环。

## 任务列表

- [x] 1. 数据模型与 API 常量
  - [x] 1.1 创建 `lib/models/notebook.dart`，定义 `Notebook` 和 `Note` 数据类
    - 实现 `Notebook.fromJson` / `toJson`
    - 实现 `Note.fromJson` / `toJson`
    - 实现 `Note.displayTitle` getter（无标题时截取前 20 字符）
    - 实现 `Note.hasTitleSet` 和 `Note.isImported` getter
    - _需求：6.5, 9.1, 9.2_

  - [ ]* 1.2 为 `Note.displayTitle` 编写属性测试
    - **属性 13：无标题笔记显示标题截取**
    - **验证需求：6.5**

  - [x] 1.3 在 `ApiConstants` 中新增 `notebooks` 和 `notes` 常量
    - _需求：9.1, 9.2_

- [x] 2. 后端数据库 Schema 与初始化逻辑
  - [x] 2.1 编写 `notebooks` 和 `notes` 表的 SQL migration 文件
    - 包含所有字段、约束、外键（ON DELETE CASCADE / SET NULL）
    - 创建 `idx_notebooks_user_id` 索引
    - 创建 `idx_notes_notebook_subject` 复合索引
    - _需求：9.1, 9.2, 9.3, 9.4_

  - [x] 2.2 在后端用户注册逻辑中实现 `init_user_notebooks` 函数
    - 插入"好题本"、"错题本"、"笔记"、"通用"四个系统预设本（`is_system=True`）
    - _需求：1.1, 1.2_

  - [ ]* 2.3 为系统预设本初始化编写属性测试
    - **属性 1：系统预设本初始化完整性**
    - **验证需求：1.1, 1.2**

- [x] 3. 后端 API — 笔记本管理端点
  - [x] 3.1 实现 `GET /api/notebooks` 端点
    - 按排序规则返回（`is_system DESC, is_pinned DESC, sort_order ASC, created_at DESC`）
    - 仅返回 `is_archived = false` 的笔记本（主列表）
    - _需求：1.4, 2.7_

  - [ ]* 3.2 为笔记本列表排序编写属性测试
    - **属性 3：笔记本列表排序不变量**
    - **验证需求：1.4, 2.3, 2.7**

  - [x] 3.3 实现 `POST /api/notebooks` 端点
    - 校验名称非空且 ≤ 64 字符，否则返回 422
    - 新建本 `is_system = false`
    - _需求：2.1, 2.2_

  - [ ]* 3.4 为笔记本名称校验编写属性测试
    - **属性 4：笔记本名称校验**
    - **验证需求：2.1, 2.2**

  - [x] 3.5 实现 `PATCH /api/notebooks/{id}` 端点
    - 支持更新 `name`、`is_pinned`、`is_archived`、`sort_order`
    - _需求：2.3, 2.4, 2.5_

  - [ ]* 3.6 为归档可见性编写属性测试
    - **属性 5：归档后主列表不可见**
    - **验证需求：2.4**

  - [x] 3.7 实现 `DELETE /api/notebooks/{id}` 端点
    - 系统预设本（`is_system = true`）返回 `403 Forbidden`
    - 用户自定义本级联删除所有笔记
    - _需求：1.3, 2.6_

  - [ ]* 3.8 为系统本不可删除编写属性测试
    - **属性 2：系统预设本不可删除**
    - **验证需求：1.3**

  - [ ]* 3.9 为级联删除编写属性测试
    - **属性 6：删除自定义本级联删除笔记**
    - **验证需求：2.6**

- [x] 4. 后端 API — 笔记管理端点
  - [x] 4.1 实现 `GET /api/notebooks/{id}/notes` 端点
    - 按 `subject_id` 分组，每组内按 `created_at` 降序
    - _需求：3.1, 3.2, 3.5_

  - [x] 4.2 实现 `POST /api/notes` 批量创建端点
    - 接受消息数组，每条消息创建独立笔记记录
    - 保存 `original_content`、`role`、`source_session_id`、`source_message_id`、`sources`
    - 允许同一消息收藏到不同笔记本（不做重复限制）
    - _需求：5.1, 5.2, 5.5_

  - [ ]* 4.3 为批量收藏编写属性测试
    - **属性 10：批量收藏创建独立笔记**
    - **验证需求：5.1, 5.2**

  - [ ]* 4.4 为同一消息多次收藏编写属性测试
    - **属性 11：同一消息可收藏到多个笔记本**
    - **验证需求：5.5**

  - [x] 4.5 实现 `GET /api/notes/{noteId}`、`PATCH /api/notes/{noteId}`、`DELETE /api/notes/{noteId}` 端点
    - PATCH 支持更新 `title` 和 `original_content`（标题 ≤ 64 字符）
    - _需求：6.2, 6.3_

  - [ ]* 4.6 为笔记编辑 Round-Trip 编写属性测试
    - **属性 12：笔记内容编辑 Round-Trip**
    - **验证需求：6.2, 6.3**

  - [x] 4.7 实现 `POST /api/notes/{noteId}/generate-title` 端点
    - 调用 LLM 生成 ≤ 30 字标题和 ≤ 5 条提纲，持久化保存
    - 失败时返回错误信息，不清空已有标题
    - _需求：6.1, 6.2, 6.4_

  - [x] 4.8 实现 `POST /api/notes/{noteId}/import-to-rag` 端点
    - 内容为空时返回错误
    - 已导入时先删除旧 Document 及其 Chunk，再创建新 Document
    - 失败时回滚 Document 记录，更新 `imported_to_doc_id`
    - _需求：7.1, 7.2, 7.4, 7.5, 7.6_

  - [ ]* 4.9 为导入资料库更新字段编写属性测试
    - **属性 14：导入资料库更新 imported_to_doc_id**
    - **验证需求：7.2, 7.5**

- [x] 5. 检查点 — 确保所有后端测试通过
  - 确保所有测试通过，如有疑问请向用户确认。

- [x] 6. Flutter 服务层与 Provider 层
  - [x] 6.1 创建 `lib/services/notebook_service.dart`
    - 封装所有笔记本和笔记相关的 Dio HTTP 调用
    - _需求：9.1, 9.2_

  - [x] 6.2 创建 `lib/providers/notebook_provider.dart`
    - 实现 `notebookListProvider`（`AsyncNotifierProvider`）
    - 实现 `notebookNotesProvider`（`AsyncNotifierProviderFamily<..., int>`，按 `subject_id` 分组）
    - 实现 `noteDetailProvider`（`AsyncNotifierProviderFamily<..., int>`）
    - _需求：1.4, 2.7, 3.1, 3.5_

  - [x] 6.3 创建 `lib/providers/multi_select_provider.dart`
    - 实现 `MultiSelectState`（`isActive`、`selectedMessageIds`）
    - 实现 `MultiSelectNotifier`：长按激活、点击切换选中、取消清空
    - _需求：4.1, 4.3, 4.5_

  - [ ]* 6.4 为多选切换幂等性编写属性测试
    - **属性 9：多选模式切换不变量**
    - **验证需求：4.3**

- [x] 7. 路由扩展
  - [x] 7.1 在 `lib/routes/app_router.dart` 的 `/profile` 路由下新增三级笔记本路由
    - 新增 `AppRoutes.notebooks`、`notebookDetail(int id)`、`noteDetail(int nbId, int noteId)` 常量
    - 配置对应 `GoRoute`（`NotebookListPage`、`NotebookDetailPage`、`NoteDetailPage`）
    - _需求：8.1, 8.3, 8.4_

- [x] 8. 笔记本 UI — 列表页与详情页
  - [x] 8.1 创建 `lib/features/notebook/widgets/notebook_card.dart`
    - 显示笔记本名称，右侧"⋯"菜单（置顶/取消置顶、归档/取消归档、删除）
    - 系统预设本不显示删除选项
    - _需求：1.3, 1.5, 2.3, 2.4_

  - [x] 8.2 创建 `lib/features/notebook/notebook_list_page.dart`
    - 系统预设本固定顶部，用户自定义本支持 `ReorderableListView` 长按拖拽排序
    - 已归档笔记本折叠在底部"已归档"分组
    - 右上角"+ 新建"按钮，弹出输入对话框，校验名称
    - _需求：1.4, 2.1, 2.2, 2.3, 2.4, 2.5, 8.1_

  - [x] 8.3 创建 `lib/features/notebook/widgets/subject_section.dart` 和 `note_card.dart`
    - `NoteCard`：显示 `displayTitle`（无标题时灰色斜体）、日期、role
    - `SubjectSection`：学科栏标题 + 笔记列表
    - _需求：3.5, 6.5_

  - [x] 8.4 创建 `lib/features/notebook/notebook_detail_page.dart`
    - 顶部 `TabBar`："通用"栏在索引 0，后接所有未归档学科
    - 每个 Tab 展示对应学科栏的笔记列表（`created_at` 降序）
    - _需求：3.1, 3.2, 3.3, 3.4, 8.3_

  - [ ]* 8.5 为学科栏完整性编写属性测试
    - **属性 7：学科栏完整性**
    - **验证需求：3.1, 3.2**

- [x] 9. 笔记详情页
  - [x] 9.1 创建 `lib/features/notebook/note_detail_page.dart`
    - 展示标题、提纲（bullet list）、原始内容（`MarkdownLatexView` 渲染）、参考来源（可折叠）
    - 底部操作栏："✨ AI 生成标题提纲"和"📚 导入资料库"按钮
    - 已导入时按钮变为"✅ 已导入（查看）"，点击跳转 `/profile/subjects/:subjectId`
    - 编辑模式：支持手动修改标题（≤ 64 字）和正文
    - _需求：6.1, 6.2, 6.3, 6.4, 6.5, 7.1, 7.2, 7.3, 7.4, 7.6, 8.4_

- [x] 10. 聊天页多选模式扩展
  - [x] 10.1 修改 `lib/features/chat/chat_page.dart`，集成多选模式
    - 消息气泡 `onLongPress` 触发 `multiSelectProvider` 激活，并将该消息加入选中集合
    - 多选模式下：AppBar 替换为"✕ 已选中 N 条消息"，底部显示"取消"和"收藏到笔记本 (N)"操作栏
    - 选中消息气泡显示蓝色边框 + 勾选图标
    - 未选中任何消息时点击"收藏"，Toast 提示"请至少选择一条消息"
    - _需求：4.1, 4.2, 4.3, 4.5, 4.6_

  - [x] 10.2 创建 `lib/features/notebook/widgets/notebook_picker_sheet.dart`
    - 展示所有未归档笔记本列表（单选）
    - 选中笔记本后展示学科选择下拉框（含"通用"选项）
    - "确认收藏"按钮调用批量创建笔记接口
    - 成功后退出多选模式，Toast 提示"已收藏 N 条笔记到《笔记本名称》"
    - 失败时保持多选模式，Toast 提示"收藏失败，请重试"
    - _需求：4.4, 5.1, 5.2, 5.3, 5.4, 8.2_

- [x] 11. 我的页面入口
  - [x] 11.1 修改 `lib/features/profile/profile_page.dart`，新增"笔记本"入口
    - 在功能列表中添加"📓 笔记本"列表项，点击跳转 `AppRoutes.notebooks`
    - _需求：8.1_

- [x] 12. 最终检查点 — 确保所有测试通过
  - 确保所有测试通过，如有疑问请向用户确认。

## 备注

- 标有 `*` 的子任务为可选项，可跳过以加快 MVP 进度
- 每个任务均引用了具体需求条款以保证可追溯性
- 属性测试使用 `dart_test` + Dart PBT 库实现，每个属性运行 ≥ 100 次迭代
- 每条属性测试需在注释中标注属性编号，例如：`// Feature: notebook, Property 3: 笔记本列表排序不变量`
