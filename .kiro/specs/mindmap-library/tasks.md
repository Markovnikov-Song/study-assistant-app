# 实现计划：学校（mindmap-library）

## 概述

按照"数据层 → 后端路由 → Flutter 路由与骨架页 → 核心 UI → 思维导图引擎 → 讲义生成 → 讲义编辑器 → 导出 → 进度可视化"的顺序逐步实现，每个阶段均与前一阶段集成，最终完成从学科课程卡片到节点讲义编辑导出的完整闭环。

## 任务列表

- [x] 1. 数据库模型与迁移
  - [x] 1.1 在 `study_assistant_streamlit/database.py` 中新增 `MindmapNodeState` ORM 模型
    - 字段：`id`、`user_id`（FK users）、`session_id`（FK conversation_sessions）、`node_id`（String 512）、`is_lit`（SmallInteger，默认 1）、`updated_at`（TIMESTAMPTZ）
    - 添加 `UniqueConstraint("user_id", "session_id", "node_id", name="uq_node_state")`
    - 添加 `Index("idx_node_states_user_session", "user_id", "session_id")`
    - _需求：12.1_

  - [x] 1.2 在 `study_assistant_streamlit/database.py` 中新增 `NodeLecture` ORM 模型
    - 字段：`id`、`user_id`（FK users）、`session_id`（FK conversation_sessions）、`node_id`（String 512）、`content`（JSONB）、`resource_scope`（JSONB，nullable）、`created_at`、`updated_at`
    - 添加 `UniqueConstraint("user_id", "session_id", "node_id", name="uq_node_lecture")`
    - 添加 `Index("idx_node_lectures_user_session", "user_id", "session_id")`
    - _需求：12.2_

  - [x] 1.3 创建 SQL 迁移文件 `backend/migrations/add_mindmap_library_tables.sql`
    - 包含 `mindmap_node_states` 和 `node_lectures` 两张表的完整 DDL
    - 包含所有约束、索引、外键（ON DELETE CASCADE）
    - _需求：12.1、12.2、12.4、12.5_

- [ ] 2. 后端路由模块
  - [x] 2.1 创建 `backend/routers/library.py`，实现学科与大纲相关端点
    - `GET /subjects`：查询当前用户所有学科，聚合每个学科的大纲数量、总节点数（从 conversation_history 解析）、已点亮节点数（从 mindmap_node_states 聚合）
    - `GET /subjects/{subject_id}/sessions`：返回该学科下所有 `session_type='mindmap'` 的会话，按 `created_at` 降序，附带每条大纲的进度摘要
    - `PATCH /sessions/{session_id}/title`：更新会话 `title`，校验非空且 ≤ 64 字符，否则返回 422
    - `DELETE /sessions/{session_id}`：删除会话，级联删除对应的 `mindmap_node_states` 和 `node_lectures` 记录
    - _需求：2.1、2.2、2.6、2.7、12.5_

  - [x] 2.2 在 `backend/routers/library.py` 中实现节点树与节点状态端点
    - `GET /sessions/{session_id}/nodes`：从 `conversation_history` 取最新 `role='assistant'` 记录，解析 Markdown 返回节点树 JSON
    - `PATCH /sessions/{session_id}/content`：更新 `conversation_history` 中该会话最新 assistant 记录的 `content` 字段
    - `GET /sessions/{session_id}/node-states`：返回该会话所有节点点亮状态 `{node_id: bool}`
    - `POST /sessions/{session_id}/node-states`：批量 upsert 节点点亮状态（`INSERT ... ON CONFLICT DO UPDATE`）
    - _需求：3.3、5.2、5.3、5.5、5.6_

  - [ ]* 2.3 为节点点亮状态幂等性编写属性测试（Python + hypothesis）
    - **属性 9：节点点亮状态幂等性**
    - **验证需求：5.6**

  - [x] 2.4 在 `backend/routers/library.py` 中实现讲义 CRUD 端点
    - `GET /lectures/{session_id}/{node_id}`：返回讲义内容，不存在时返回 404
    - `POST /lectures`：生成讲义（调用 LectureGeneratorService），存储到 `node_lectures`
    - `PATCH /lectures/{lecture_id}`：增量更新 `content` 字段（不替换整条记录）
    - `DELETE /lectures/{session_id}/{node_id}`：删除讲义记录
    - `POST /lectures/{id}/export`：接受 `format=docx`，调用 python-docx 生成 Word 文件流返回
    - _需求：7.2、7.3、7.4、7.5、9.2、9.4、10.4、12.3_

  - [ ]* 2.5 为讲义内容往返一致性编写属性测试（Python + hypothesis）
    - **属性 11：讲义内容往返一致性**
    - **验证需求：9.2、12.7**

  - [x] 2.6 在 `backend/main.py` 中注册 library 路由
    - `app.include_router(library.router, prefix="/api/library", tags=["library"])`
    - _需求：13.1_

- [ ] 3. 检查点 — 后端基础可用
  - 确保所有后端测试通过，`/api/library/subjects` 接口可访问，两张新表已创建，如有疑问请向用户确认。

- [x] 4. Flutter 数据模型与服务层
  - [x] 4.1 创建 `lib/models/mindmap_library.dart`，定义所有数据类
    - `SubjectWithProgress`：`subject`、`totalNodes`、`litNodes`、`sessionCount`、`lastVisitedAt`
    - `MindMapSession`：`id`、`title`、`resourceScopeLabel`、`createdAt`、`totalNodes`、`litNodes`
    - `TreeNode`：`nodeId`、`text`、`depth`（1-4）、`parentId`、`isUserCreated`、`children`、`isExpanded`
    - `MindMapProgress`：`total`、`lit`，`percent` getter
    - `LectureBlock`、`LectureContent`（对应后端 JSONB 结构）
    - _需求：1.2、2.1、4.1、6.1_

  - [x] 4.2 创建 `lib/services/library_service.dart`，封装所有 library API 调用
    - 封装 `getSubjects`、`getSessions`、`renameSession`、`deleteSession`
    - 封装 `getNodes`、`updateContent`、`getNodeStates`、`updateNodeStates`
    - 封装 `getLecture`、`generateLecture`、`patchLecture`、`deleteLecture`、`exportLecture`
    - _需求：2.1、3.3、5.2、7.2、9.2、10.1_

- [x] 5. Flutter 路由扩展
  - [x] 5.1 在 `lib/routes/app_router.dart` 中将 `/library` 路由改为嵌套结构
    - `ShellRoute` 内 `/library` → `SchoolPage`
    - 子路由 `:subjectId` → `CourseSpacePage`
    - 子路由 `:subjectId/mindmap/:sessionId` → `EditableMindMapPage`
    - 子路由 `:subjectId/mindmap/:sessionId/lecture/:nodeId` → `LecturePage`
    - 在 `AppRoutes` 中新增对应路径常量和辅助方法
    - _需求：1.1、2.4、3.1、7.3_

- [x] 6. Riverpod Provider 层
  - [x] 6.1 创建 `lib/providers/library_provider.dart`，实现所有 Provider
    - `schoolSubjectsProvider`：`AsyncNotifierProvider<List<SubjectWithProgress>>`
    - `courseSessionsProvider`：`AsyncNotifierProvider.family<List<MindMapSession>, int>`（按 subjectId）
    - `mindMapNodesProvider`：`FutureProvider.family<TreeNode, int>`（按 sessionId）
    - `nodeStatesProvider`：`StateNotifierProvider.family<NodeStatesNotifier, Map<String, bool>, int>`
    - `mindMapProgressProvider`：派生 Provider，计算 `MindMapProgress`
    - `nodeLectureExistsProvider`：`FutureProvider.family<bool, ({int sessionId, String nodeId})>`
    - _需求：1.2、5.2、5.5、6.1、6.2、6.4_

  - [ ]* 6.2 为进度计算完整性编写属性测试（Dart）
    - **属性 10：进度计算完整性不变量**
    - **验证需求：6.6_

- [x] 7. SchoolPage（学校主页）
  - [x] 7.1 将 `lib/features/library/library_page.dart` 重构为 `SchoolPage`
    - 使用 `schoolSubjectsProvider` 加载数据
    - 每张课程卡片显示：学科名称、分类、大纲数量、整体进度百分比、最近访问时间
    - 卡片提供「开始学习」按钮，点击跳转 `/library/:subjectId`
    - 置顶学科排在最前，其余按最近访问时间降序
    - 顶部搜索栏，实时过滤学科名称或分类
    - 空状态引导文字
    - _需求：1.1、1.2、1.3、1.4、1.5、1.6_

  - [ ]* 7.2 为置顶学科排序不变量编写属性测试（Dart）
    - **属性 2：置顶学科排序不变量**
    - **验证需求：1.4**

  - [ ]* 7.3 为搜索过滤子集属性编写属性测试（Dart）
    - **属性 3：搜索过滤子集属性**
    - **验证需求：1.6**

- [x] 8. CourseSpacePage（课程空间）
  - [x] 8.1 创建 `lib/features/library/course_space_page.dart`
    - 使用 `courseSessionsProvider(subjectId)` 加载大纲列表
    - 每条大纲显示：标题（空则"未命名大纲"）、资料范围标签、生成时间、进度"N/M"
    - 按 `createdAt` 降序排列
    - 顶部显示该学科整体进度条
    - 「新建大纲」入口（跳转原思维导图生成页）
    - 「资料库」快捷入口（跳转 `/profile/resources/:subjectId`）
    - _需求：2.1、2.2、2.3、2.8、2.9、13.3_

  - [x] 8.2 实现大纲「⋯」菜单（重命名 / 删除）
    - 重命名：弹出输入对话框，校验非空且 ≤ 64 字符，调用 `renameSession`
    - 删除：弹出确认对话框，确认后调用 `deleteSession`，Toast 提示"已删除"
    - _需求：2.5、2.6、2.7_

  - [ ]* 8.3 为大纲列表时间降序不变量编写属性测试（Dart）
    - **属性 4：大纲列表时间降序不变量**
    - **验证需求：2.2**

  - [ ]* 8.4 为大纲名称校验属性编写属性测试（Dart）
    - **属性 5：大纲名称校验属性**
    - **验证需求：2.7**

- [x] 9. MindMapParser 与 MindMapSerializer
  - [x] 9.1 创建 `lib/features/library/mindmap/mindmap_parser.dart`，实现 `MindMapParser`
    - 按 `#` `##` `###` `####` 层级解析 Markdown 为 `TreeNode` 树
    - 节点 ID 生成规则：`L{depth}_{祖先路径}_{文本}`，重复兄弟节点附加 `_2`、`_3` 序号
    - 根节点为 `#` 级别，其余按层级构建父子关系
    - _需求：4.1、4.2、4.3_

  - [ ]* 9.2 为 Markdown 解析节点 ID 唯一性编写属性测试（Dart）
    - **属性 7：Markdown 解析节点 ID 唯一性**
    - **验证需求：4.3**

  - [x] 9.3 创建 `lib/features/library/mindmap/mindmap_serializer.dart`，实现 `MindMapSerializer`
    - `serialize(TreeNode root)` → Markdown 字符串
    - 保持层级缩进，用户自建节点与 AI 节点序列化格式一致
    - _需求：3.3、3.5、3.6_

  - [ ]* 9.4 为 Markdown 解析往返一致性编写属性测试（Dart）
    - **属性 8：Markdown 解析往返一致性**
    - **验证需求：4.5**

- [x] 10. 检查点 — 解析器可用
  - 确保 MindMapParser 和 MindMapSerializer 单元测试通过，如有疑问请向用户确认。

- [x] 11. MindMapPainter（CustomPainter 渲染引擎）
  - [x] 11.1 创建 `lib/features/library/mindmap/mindmap_painter.dart`，实现 `MindMapPainter`
    - 继承 `CustomPainter`，绘制节点矩形（圆角）和贝塞尔曲线连接线
    - 按节点状态着色：默认 / 已点亮（primary）/ 半点亮（primaryContainer）/ 用户自建（tertiaryContainer）
    - 已有讲义的节点右上角绘制 📖 图标
    - 支持节点折叠/展开（跳过折叠子树的绘制）
    - _需求：3.1、3.10、3.11、5.2、5.4_

  - [x] 11.2 创建 `lib/features/library/editable_mindmap_page.dart`，集成 `InteractiveViewer` + `CustomPaint`
    - `InteractiveViewer` 支持双指缩放和平移
    - 顶部显示进度条和进度文字"已学习 N / 总计 M 个知识点（X%）"
    - 使用 `mindMapNodesProvider` 和 `nodeStatesProvider` 驱动渲染
    - _需求：3.1、6.1、6.2_

- [x] 12. 节点手势交互
  - [x] 12.1 在 `EditableMindMapPage` 中实现单击节点手势
    - 命中检测：根据节点矩形坐标判断点击位置
    - 单击弹出 `NodeActionSheet`（BottomSheet），包含：「生成讲义」/「查看讲义」、「添加子节点」、「编辑文本」、「删除节点」
    - _需求：3.2、7.1_

  - [x] 12.2 实现长按节点手势，弹出点亮操作菜单
    - 「标记为已学习」：调用 `nodeStatesProvider` 更新状态，持久化到后端
    - 「取消标记」：删除点亮记录，恢复未点亮样式
    - 父节点子节点全亮时自动渲染为半点亮样式
    - _需求：5.1、5.2、5.3、5.4_

  - [ ]* 12.3 为节点文本校验属性编写属性测试（Dart）
    - **属性 6：节点文本校验属性**
    - **验证需求：3.4**

- [x] 13. 节点编辑操作（增 / 改 / 删 / 撤销）
  - [x] 13.1 实现「编辑文本」操作
    - 弹出文本输入对话框，校验非空且 ≤ 200 字符
    - 更新内存节点树，序列化后调用 `PATCH /sessions/{sessionId}/content` 持久化
    - 操作前将当前 Markdown 快照推入撤销栈（最多 20 步）
    - _需求：3.3、3.4、3.8_

  - [x] 13.2 实现「添加子节点」操作
    - 弹出文本输入对话框，校验非空且 ≤ 200 字符
    - 在内存节点树中插入新子节点（`isUserCreated = true`），序列化后持久化
    - _需求：3.5、3.8、3.10_

  - [x] 13.3 实现「删除节点」操作
    - 弹出确认对话框；根节点拒绝删除并提示"根节点不可删除"
    - 删除该节点及所有子节点，序列化后持久化
    - _需求：3.6、3.7、3.8_

  - [x] 13.4 实现「撤销」操作
    - AppBar 提供撤销按钮，点击从撤销栈弹出上一个 Markdown 快照
    - 重新解析快照并更新渲染视图，调用后端持久化
    - _需求：3.9_

- [x] 14. 检查点 — 思维导图交互可用
  - 确保节点增删改撤销、点亮状态持久化均正常工作，如有疑问请向用户确认。

- [x] 15. LectureGeneratorService（后端）
  - [x] 15.1 创建 `backend/services/lecture_generator_service.py`
    - 实现 `build_lecture_prompt(node_path, rag_context, user_memory, parent_summary)`，按设计文档构造 system + user messages
    - 实现 `generate(session_id, node_id, user_id, subject_id)`：
      - 从 `conversation_history` 解析节点路径
      - 调用 `RAGPipeline.retrieve` 限定 `resource_scope.doc_ids` 范围
      - 读取 `UserMemory`，注入用户画像
      - 可选：读取父节点讲义前 500 字作为 `parent_summary`
      - 调用 `LLMService.chat`，将结果转换为 JSONB blocks 格式存入 `node_lectures`
    - RAG 无结果时在 blocks 顶部插入 warning 块
    - _需求：7.2、8.1、8.2、8.3、8.4、8.5、8.6、8.7_

  - [x] 15.2 将 `POST /api/library/lectures` 端点与 `LectureGeneratorService` 连接
    - 生成超时（>30s）返回 504；LLM 失败返回 502；不保存不完整内容
    - _需求：7.3、7.4_

- [x] 16. Flutter 讲义生成流程
  - [x] 16.1 在 `NodeActionSheet` 中实现「生成讲义」流程
    - 点击后关闭 BottomSheet，在节点位置显示加载动画
    - 调用 `library_service.generateLecture`，成功后跳转 `LecturePage`
    - 失败时显示错误 Toast 并保留「重新生成」入口
    - 生成成功后刷新 `nodeLectureExistsProvider`，节点显示 📖 图标
    - _需求：7.1、7.2、7.3、7.4、7.5_

- [x] 17. BlockConverter（JSONB ↔ Quill Delta）
  - [x] 17.1 创建 `lib/features/library/lecture/block_converter.dart`，实现 `BlockConverter`
    - `blocksToQuillDelta(List<LectureBlock> blocks)` → Quill Delta JSON
    - `quillDeltaToBlocks(Delta delta)` → `List<LectureBlock>`，保留 `source` 字段
    - 支持：heading（H1-H3）、paragraph（含 bold/italic/code spans）、code block、list（有序/无序）、quote
    - _需求：9.1、9.6_

  - [ ]* 17.2 为 BlockConverter 往返一致性编写属性测试（Dart）
    - 验证 `blocksToQuillDelta` → `quillDeltaToBlocks` 往返后 blocks 结构不变
    - **验证需求：9.1**

- [x] 18. LecturePage 与讲义编辑器
  - [x] 18.1 创建 `lib/features/library/lecture/lecture_page.dart`
    - 使用 `flutter_quill` 展示讲义内容，加载时调用 `BlockConverter.blocksToQuillDelta`
    - 顶部格式工具栏：H1-H3、加粗、斜体、行内代码、代码块、有序列表、无序列表、引用块
    - AI 生成段落与用户编辑段落以不同背景色区分（`source` 字段判断）
    - 右上角显示保存状态指示器（"已保存" / "保存中…" / "保存失败"）
    - _需求：9.1、9.3、9.6_

  - [x] 18.2 实现 `LectureEditorNotifier`（`StateNotifier`）
    - `onContentChanged(Delta delta)`：标记 `isDirty = true`，重置 5 秒防抖计时器
    - `_autoSave()`：调用 `BlockConverter.quillDeltaToBlocks`，调用 `patchLecture` 接口
    - 保存失败时显示"保存失败，请检查网络"横幅，监听 `connectivity_plus` 网络恢复后自动重试
    - _需求：9.2、9.5_

  - [x] 18.3 实现 `PopScope` 强制保存
    - 拦截返回手势，调用 `forceSave()`，保存完成后执行 `context.pop()`
    - 若仍有未保存内容且网络不可用，弹出确认对话框
    - _需求：9.4_

- [x] 19. 讲义导出
  - [x] 19.1 实现 Markdown 导出（客户端）
    - 创建 `lib/features/library/lecture/lecture_exporter.dart`，实现 `exportToMarkdown(List<LectureBlock> blocks)`
    - heading → `#` / `##` / `###`；paragraph → 纯文本（含 bold/italic/code spans）；code → ` ```lang\n...\n``` `；list → `- ` / `1. `；quote → `> `
    - 调用 `FileSaver.instance.saveFile()` 触发系统文件保存对话框
    - _需求：10.1、10.2、10.6_

  - [ ]* 19.2 为 Markdown 导出内容一致性编写属性测试（Dart）
    - **属性 12：Markdown 导出内容一致性**
    - **验证需求：10.6**

  - [x] 19.3 实现 PDF 导出（客户端，`pdf` 包）
    - 在 `LectureExporter` 中实现 `exportToPdf(List<LectureBlock> blocks)`
    - 使用 `pw.Document` 将各 block 转换为对应 `pw.Widget`，保留标题层级、列表、代码块格式
    - 调用 `FileSaver` 保存
    - _需求：10.1、10.3、10.6_

  - [x] 19.4 实现 Word 导出（后端 python-docx + 前端下载）
    - 前端调用 `POST /api/library/lectures/{id}/export?format=docx`，接收文件流
    - 使用 `FileSaver` 保存 `.docx` 文件
    - 导出失败时显示错误 Toast 并提供「重试」入口
    - _需求：10.1、10.4、10.5、10.6_

  - [x] 19.5 在 `LecturePage` 中添加「导出」操作入口
    - AppBar 右侧「导出」按钮，弹出格式选择菜单（Markdown / PDF / Word）
    - _需求：10.1_

- [x] 20. 检查点 — 讲义完整流程可用
  - 确保讲义生成、编辑、自动保存、导出均正常工作，如有疑问请向用户确认。

- [x] 21. 进度可视化与完成庆祝
  - [x] 21.1 完善 `SchoolPage` 课程卡片进度显示
    - 使用 `schoolSubjectsProvider` 中的 `litNodes / totalNodes` 计算百分比
    - 卡片上显示进度百分比和进度条
    - _需求：1.2、6.4_

  - [ ]* 21.2 为课程卡片渲染完整性编写属性测试（Dart）
    - **属性 1：课程卡片渲染完整性**
    - **验证需求：1.2、1.3**

  - [x] 21.3 实现节点点亮时实时更新进度条
    - `nodeStatesProvider` 变更时，`mindMapProgressProvider` 自动重新计算
    - `EditableMindMapPage` 顶部进度条和文字实时刷新，无需手动刷新页面
    - _需求：6.1、6.2_

  - [x] 21.4 实现完成庆祝动画
    - 当 `progress.lit == progress.total && progress.total > 0` 时触发撒花动画（使用 `confetti` 包或自绘粒子）
    - 进度文字旁显示"🎉 全部完成！"标识
    - _需求：6.5_

- [x] 22. 最终检查点 — 确保所有测试通过
  - 确保所有测试通过，如有疑问请向用户确认。

## 备注

- 标有 `*` 的子任务为可选项，可跳过以加快 MVP 进度
- 每个任务均引用了具体需求条款以保证可追溯性
- 属性测试 Python 端使用 `pytest + hypothesis`，Dart 端使用 `dart_test` + 自定义生成器，每个属性运行 ≥ 100 次迭代
- 每条属性测试需在注释中标注属性编号，例如：`// Feature: mindmap-library, Property 8: Markdown 解析往返一致性`
- 大纲内容复用现有 `conversation_sessions` + `conversation_history` 表，不新增冗余表（需求 12.6）
