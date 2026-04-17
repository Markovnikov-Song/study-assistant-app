# 实现计划：思维导图编辑器（Mindmap Editor）

## 概述

在现有 `MindMapPage`（路由 `/mindmap`）基础上，逐步构建手动编辑层、AI 协调、格式导入、OCR 识别、持久化管理和导出能力。
实现语言：Dart / Flutter，状态管理：Riverpod 2.x。

## 任务

- [x] 1. 扩展数据模型与核心领域层
  - [x] 1.1 扩展 `TreeNode` 模型，增加 `nodeId`（UUID）、`parentId`、`isUserCreated` 字段，将 `depth` 上限从 4 扩展到 6
    - 更新 `toJson` / `fromJson`，保持向后兼容
    - _需求：1.5、2.4_
  - [x] 1.2 新建 `MindmapMeta` 数据类（`id`、`subjectId`、`name`、`createdAt`、`updatedAt`）及其 JSON 序列化
    - _需求：10.3_
  - [x] 1.3 新建 `NodeTreeState` 数据类（`roots`、`isDirty`、`lastSavedAt`、`draggingNodeId`、`dropTargetId`）
    - _需求：4.1、10.1_
  - [x] 1.4 新建密封异常类 `sealed class MindmapException`，包含 `MaxDepthExceeded`、`CannotDeleteRoot`、`CircularMove`、`CannotDeleteLastMindmap`
    - _需求：1.5、3.3、4.4、10.6_

- [x] 2. 实现 `NodeTreeEditor` 核心领域对象
  - [x] 2.1 实现 `NodeTreeEditor`：`addChild`、`addSibling`、`updateText`、`deleteNode`、`moveNode`、`isDescendant`、`nodeDepth`、`allNodes`
    - 纯 Dart 类，无 Flutter 依赖
    - `addChild` / `addSibling` 对空白文本不创建节点
    - `updateText` 截断超过 200 字符的文本
    - `deleteNode` 递归删除所有后代
    - `moveNode` 调用 `isDescendant` 检测循环
    - _需求：1.1–1.5、2.2–2.4、3.1–3.3、4.1–4.5_
  - [ ]* 2.2 为 `addChild` 编写属性测试
    - **属性 1：子节点添加后父节点 children 增加 1，新子节点 depth = 父节点 depth + 1**
    - **验证：需求 1.1、1.5**
  - [ ]* 2.3 为空白文本添加编写属性测试
    - **属性 2：空白文本不被添加，节点总数不变**
    - **验证：需求 1.4**
  - [ ]* 2.4 为 `updateText` 编写属性测试
    - **属性 3：节点文本更新后可读回**
    - **验证：需求 2.2**
  - [ ]* 2.5 为节点文本长度编写属性测试
    - **属性 5：所有节点 text.length ≤ 200**
    - **验证：需求 2.4、7.7**
  - [ ]* 2.6 为 `deleteNode` 编写属性测试
    - **属性 6：删除节点后其后代全部消失**
    - **验证：需求 3.2**
  - [ ]* 2.7 为 `moveNode` 编写属性测试
    - **属性 7：任意操作后所有节点 depth ≤ 6**
    - **验证：需求 1.5、4.3**
  - [ ]* 2.8 为循环移动检测编写属性测试
    - **属性 8：moveNode 到后代节点时抛出 CircularMove，树结构不变**
    - **验证：需求 4.4**

- [x] 3. 实现 `EditHistory`
  - [x] 3.1 实现 `EditHistory`：`push`、`undo`、`redo`、`canUndo`、`canRedo`、`clearRedo`，最多保留 50 步快照
    - _需求：5.1–5.6_
  - [ ]* 3.2 为撤销恢复编写属性测试
    - **属性 9：执行单步编辑后 undo，序列化结果等于操作前状态**
    - **验证：需求 5.2**
  - [ ]* 3.3 为撤销-重做往返编写属性测试
    - **属性 10：操作→撤销→重做后，序列化结果与仅执行操作后相同**
    - **验证：需求 5.3**
  - [ ]* 3.4 为历史栈上限编写属性测试
    - **属性 11：超过 50 次操作后，撤销栈长度始终 ≤ 50**
    - **验证：需求 5.1**
  - [ ]* 3.5 为新操作清空重做栈编写属性测试
    - **属性 12：撤销后执行新操作，canRedo 为 false**
    - **验证：需求 5.6**

- [ ] 4. 检查点 — 确保所有测试通过，如有疑问请询问用户

- [x] 5. 实现 `ImportParser`
  - [x] 5.1 实现 `ImportParser.parseMarkdown`：将 `#`/`##`/`-`/`*` 大纲解析为 `List<TreeNode>`，无可识别结构时返回 `ImportError.noStructure`
    - _需求：8.1–8.4_
  - [ ]* 5.2 为 Markdown 深度映射编写属性测试
    - **属性 16：parseMarkdown 返回节点的 depth 等于对应 `#` 数量**
    - **验证：需求 8.2、8.3**
  - [ ]* 5.3 为 Markdown 往返编写属性测试
    - **属性 17：parse → serialize → parse，节点文本序列和层级结构完全等价**
    - **验证：需求 8.5、11.4**
  - [x] 5.4 实现 `ImportParser.parseXMind`：解压 ZIP，解析 `content.xml`，提取第一个工作表节点树；ZIP 损坏或缺少 content.xml 时返回 `ImportError.parseFailure`
    - _需求：7.2、7.6_
  - [x] 5.5 实现 `ImportParser.parseFreeMind`：解析 `.mm` XML，转换为 `List<TreeNode>`；解析失败时返回 `ImportError.parseFailure`
    - _需求：7.3、7.6_
  - [x] 5.6 实现 `ImportParser.parseFile`：根据文件扩展名分发到对应解析器；不支持的格式返回 `ImportError.unsupportedFormat`；所有导入节点文本截断至 200 字符
    - _需求：7.1、7.5、7.7_
  - [ ]* 5.7 为不支持格式编写属性测试
    - **属性 14：扩展名非 .xmind/.mm 时返回 ImportError.unsupportedFormat**
    - **验证：需求 7.5**
  - [ ]* 5.8 为导入节点文本截断编写属性测试
    - **属性 15：导入后所有节点 text.length ≤ 200**
    - **验证：需求 7.7**
  - [x] 5.9 实现 `ImportParser.parseOcrLines`：将 `List<OcrLine>`（含 `indentLevel`）转换为 `List<TreeNode>`
    - _需求：9.4_

- [x] 6. 实现 `ExportService`
  - [x] 6.1 实现 `ExportService.toMarkdown`：将 `List<TreeNode>` 序列化为 `#` 标题层级 Markdown 大纲文本
    - _需求：11.1、11.2_
  - [ ]* 6.2 为序列化深度映射编写属性测试
    - **属性 20：toMarkdown 输出中每个节点对应行的 `#` 数量等于节点 depth**
    - **验证：需求 11.2**
  - [x] 6.3 实现 `ExportService.toPng`：使用 `RepaintBoundary` + `screenshot` 包截图，返回 `Uint8List`
    - _需求：11.3_
  - [x] 6.4 实现 `ExportService.shareMarkdown` 和 `ExportService.savePng`：调用系统分享/保存
    - _需求：11.2、11.3_

- [x] 7. 实现 `MindmapRepository` 与本地存储
  - [x] 7.1 实现 `MindmapLocalDataSource`：基于 `SharedPreferences`，按 Schema 读写 `mindmap_meta_{subjectId}`、`mindmap_tree_{subjectId}_{id}`、`mindmap_active_{subjectId}`
    - _需求：10.1、10.2_
  - [x] 7.2 实现 `MindmapRepository`：`listMindmaps`、`loadTree`、`saveTree`、`createMindmap`、`deleteMindmap`（学科下只剩一份时抛出 `CannotDeleteLastMindmap`）、`renameMindmap`
    - _需求：10.3–10.6_
  - [ ]* 7.3 为最后一份导图不可删除编写属性测试
    - **属性 19：学科下导图数量为 1 时，deleteMindmap 抛出 CannotDeleteLastMindmap**
    - **验证：需求 10.6**

- [ ] 8. 检查点 — 确保所有测试通过，如有疑问请询问用户

- [x] 9. 实现 Riverpod Providers 与 `NodeTreeNotifier`
  - [x] 9.1 新建 `mindmapRepositoryProvider`，提供 `MindmapRepository` 单例
  - [x] 9.2 实现 `mindmapListProvider`（`FutureProvider.family<List<MindmapMeta>, int>`）
  - [x] 9.3 实现 `activeMindmapIdProvider`（`StateProvider.family<String?, int>`），初始化时从 `MindmapRepository` 读取上次激活的导图 ID
  - [x] 9.4 实现 `NodeTreeNotifier`（`StateNotifier<NodeTreeState>`）：
    - 封装 `NodeTreeEditor` 和 `EditHistory`
    - 每次变更后推入 `EditHistory` 快照
    - 变更后 2 秒防抖触发 `MindmapRepository.saveTree`
    - 暴露 `addChild`、`addSibling`、`updateText`、`deleteNode`、`moveNode`、`undo`、`redo` 方法
    - _需求：5.1–5.6、10.1_
  - [x] 9.5 实现 `nodeTreeProvider`（`StateNotifierProvider.family<NodeTreeNotifier, NodeTreeState, (int, String)>`）
  - [x] 9.6 实现 `editHistoryProvider`（`Provider.family<EditHistory, (int, String)>`）
  - [x] 9.7 在 `currentSubjectProvider` 变更时，保存当前学科导图并加载新学科对应导图
    - _需求：10.2_

- [x] 10. 实现 `OcrService`
  - [x] 10.1 新建 `OcrApiClient`，调用后端 OCR API，超时 30 秒，超时时抛出 `OcrTimeoutException`
    - _需求：9.2、9.7_
  - [x] 10.2 实现 `OcrService.recognize`：调用 `OcrApiClient`，返回 `OcrResult`（含 `List<OcrLine>`，每行含 `text`、`confidence`、`indentLevel`）
    - _需求：9.2、9.6_
  - [ ]* 10.3 为 OCR 置信度高亮编写属性测试
    - **属性 18：shouldHighlight(score) 当且仅当 score < 0.7 时返回 true**
    - **验证：需求 9.6**

- [x] 11. 实现导图选择器与多导图管理 UI
  - [x] 11.1 新建 `MindmapSelectorDropdown` Widget：下拉菜单列出当前学科所有导图，支持切换、新建（弹出命名对话框）、删除（确认对话框，最后一份时禁用）
    - _需求：10.3–10.6_
  - [ ]* 11.2 为 `MindmapSelectorDropdown` 编写 Widget 测试
    - 验证导图切换、新建、删除禁用逻辑
    - _需求：10.3–10.6_

- [x] 12. 实现节点树手动编辑 UI（`MindmapEditorCanvas`）
  - [x] 12.1 新建 `MindmapEditorCanvas` Widget，基于现有 `CustomPaint` + `InteractiveViewer`（`MindMapPainter`）渲染节点树
    - 每个节点显示文本、添加子节点按钮、添加兄弟节点按钮、删除按钮（根节点隐藏）
    - 深度达 6 级时禁用"添加子节点"按钮并显示提示
    - _需求：1.1、1.2、1.5、3.3_
  - [x] 12.2 实现节点内联编辑状态：双击节点进入编辑模式，显示预填文本的输入框（最多 200 字符），确认/失焦保存，Escape/取消按钮丢弃
    - _需求：2.1–2.4_
  - [x] 12.3 实现节点删除确认对话框：点击删除按钮弹出确认提示，确认后调用 `NodeTreeNotifier.deleteNode`
    - _需求：3.1、3.2_
  - [x] 12.4 实现拖拽重排：长按节点进入拖拽模式（半透明跟随），悬停目标节点 500ms 后高亮，释放时调用 `NodeTreeNotifier.moveNode`；循环移动时恢复原位并显示提示
    - _需求：4.1–4.5_

- [x] 13. 实现工具栏（`MindmapToolbar`）
  - [x] 13.1 新建 `MindmapToolbar` Widget，包含撤销/重做按钮（状态由 `editHistoryProvider` 驱动）、导入文件按钮、粘贴 Markdown 按钮、拍照识别按钮、发送给 AI 优化按钮、导出按钮
    - _需求：5.4、5.5、7.1、8.1、9.1、11.1_
  - [x] 13.2 实现撤销/重做按钮逻辑：`canUndo`/`canRedo` 为 false 时禁用
    - _需求：5.4、5.5_

- [x] 14. 实现导入流程 UI
  - [x] 14.1 新建 `ImportModeDialog` Widget：导入/AI 生成完成后弹出"替换当前导图"或"合并到当前导图"选择
    - 替换：调用 `NodeTreeNotifier` 替换根节点树并推入 `EditHistory`
    - 合并：将新树追加为当前根节点的子节点，保留现有节点
    - _需求：6.1–6.3、7.4、9.4_
  - [ ]* 14.2 为 `ImportModeDialog` 编写 Widget 测试
    - 验证替换/合并行为
    - _需求：6.1–6.3_
  - [ ]* 14.3 为合并操作保留原有节点编写属性测试
    - **属性 13：合并后原有 N 个节点的 nodeId 和 text 全部出现在合并后的树中**
    - **验证：需求 6.3_
  - [x] 14.4 实现文件导入入口：调用文件选择器，读取文件字节，调用 `ImportParser.parseFile`，成功后弹出 `ImportModeDialog`，失败时显示对应错误提示
    - _需求：7.1–7.6_
  - [x] 14.5 实现粘贴 Markdown 大纲入口：弹出文本输入对话框，调用 `ImportParser.parseMarkdown`，成功后弹出 `ImportModeDialog`，失败时显示错误提示
    - _需求：8.1–8.4_

- [x] 15. 实现 OCR 识别流程 UI
  - [x] 15.1 实现拍照/相册选取入口：调用 `image_picker`，获取图片字节后调用 `OcrService.recognize`，超时/失败时显示对应提示
    - _需求：9.1、9.5、9.7_
  - [x] 15.2 新建 `OcrPreviewSheet` Widget：展示 `List<OcrLine>` 识别结果，置信度 < 0.7 的行以黄色高亮，支持用户修改文本和调整 `indentLevel`，确认后调用 `ImportParser.parseOcrLines` 并弹出 `ImportModeDialog`
    - _需求：9.3、9.4、9.6_
  - [ ]* 15.3 为 `OcrPreviewSheet` 编写 Widget 测试
    - 验证低置信度高亮、文本编辑、层级调整
    - _需求：9.3、9.6_

- [x] 16. 实现 AI 协调流程
  - [x] 16.1 在 `NodeTreeNotifier` 中实现 AI 生成结果接收逻辑：当前树非空时弹出 `ImportModeDialog`；将当前树文本结构附加到 AI 生成请求上下文
    - _需求：6.1、6.4_
  - [x] 16.2 实现"发送给 AI 优化"按钮逻辑：调用 `ExportService.toMarkdown` 序列化当前树，发送给 `AiMindmapService`，结果以"合并"模式展示
    - _需求：6.5_

- [x] 17. 实现导出流程 UI
  - [x] 17.1 实现导出 Markdown 入口：调用 `ExportService.toMarkdown` + `ExportService.shareMarkdown`，触发系统分享/保存
    - _需求：11.1、11.2_
  - [x] 17.2 实现导出 PNG 入口：用 `RepaintBoundary` 包裹画布，调用 `ExportService.toPng` + `ExportService.savePng`
    - _需求：11.3_

- [x] 18. 将所有组件集成到 `MindMapPage`
  - [x] 18.1 在 `MindMapPage` 中集成 `MindmapSelectorDropdown`（顶部）、`MindmapEditorCanvas`（主区域）、`MindmapToolbar`（底部），与现有 AI 生成 WebView 渲染并存
    - _需求：1–11（全部）_
  - [x] 18.2 确保学科切换（`currentSubjectProvider` 变更）时正确保存/加载导图，并更新 `MindmapSelectorDropdown`
    - _需求：10.2_

- [x] 19. 最终检查点 — 确保所有测试通过，如有疑问请询问用户

## 备注

- 标有 `*` 的子任务为可选项，可跳过以加快 MVP 进度
- 每个任务均引用具体需求条款以保证可追溯性
- 属性测试使用 `fast_check` 包，每个属性至少运行 100 次迭代
- 单元测试使用 `flutter_test`，Widget 测试覆盖关键交互流程
- 检查点任务确保增量验证，避免集成阶段集中暴露问题
