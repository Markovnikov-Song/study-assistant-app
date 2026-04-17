# 技术设计文档：思维导图编辑器（Mindmap Editor）

## 概述

本文档描述在现有 Flutter 学习辅助 App 的思维导图页（`MindMapPage`，路由 `/mindmap`）基础上，
新增手动树形编辑、AI 协调、格式导入、OCR 识别、持久化管理和导出能力的技术设计。

现有架构基础：
- 状态管理：Riverpod 2.x（`flutter_riverpod` + `riverpod_annotation`）
- 路由：go_router ShellRoute 底部导航
- 本地存储：`shared_preferences`（键值对）
- 现有思维导图：AI 生成 Markdown → WebView 渲染（markmap-lib）
- 现有 `TreeNode` 模型和 `MindMapParser` / `MindMapSerializer` 已实现 Markdown ↔ 树的转换

新功能在现有基础上扩展，不替换现有 AI 生成能力，而是在其旁边增加手动编辑层。

---

## 架构

### 整体分层

```
┌─────────────────────────────────────────────────────────┐
│                    MindMapPage (UI)                      │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │ MindmapEditor│  │ToolbarWidget │  │MindmapSelector│  │
│  │  (Canvas)    │  │              │  │  (Dropdown)   │  │
│  └──────────────┘  └──────────────┘  └───────────────┘  │
├─────────────────────────────────────────────────────────┤
│                  Riverpod Providers                      │
│  mindmapListProvider  activeMindmapProvider             │
│  nodeTreeProvider     editHistoryProvider               │
├─────────────────────────────────────────────────────────┤
│               Domain / Use-Case Layer                    │
│  NodeTreeEditor   ImportParser   ExportService          │
│  EditHistory      OcrService     MindmapRepository      │
├─────────────────────────────────────────────────────────┤
│                  Infrastructure Layer                    │
│  MindmapLocalDataSource (SharedPreferences)             │
│  AiMindmapService (existing)   OcrApiClient             │
└─────────────────────────────────────────────────────────┘
```

### 关键设计决策

1. **本地优先**：所有导图数据存储在 `SharedPreferences`，序列化为 JSON。不依赖后端持久化，离线可用。
2. **Markdown 作为内部格式**：`TreeNode` 树与 Markdown 大纲之间的双向转换复用现有 `MindMapParser` / `MindMapSerializer`，扩展至 6 级深度。
3. **不可变快照撤销**：`EditHistory` 存储 Markdown 字符串快照（而非操作对象），实现简单且与序列化层天然对齐。
4. **Canvas 渲染**：手动编辑模式使用现有 `CustomPaint` + `InteractiveViewer` 方案（`MindMapPainter`），不引入新的渲染依赖。
5. **XMind/FreeMind 解析**：在 Flutter 端用 `dart:convert` + XML 解析（`xml` 包）实现，不依赖后端。

---

## 组件与接口

### 数据流

```
用户操作
  │
  ▼
NodeTreeEditor.addNode / editNode / deleteNode / moveNode
  │  ① 推入 EditHistory 快照
  │  ② 更新内存中的 NodeTree
  │  ③ 触发防抖持久化（2s）
  ▼
MindmapRepository.save(subjectId, mindmapId, markdown)
  │
  ▼
SharedPreferences  key: "mindmap_{subjectId}_{mindmapId}"
```

### NodeTreeEditor

核心领域对象，封装所有树变更操作，纯 Dart 类（无 Flutter 依赖），便于单元测试。

```dart
class NodeTreeEditor {
  List<TreeNode> roots;
  
  // 添加子节点，返回新节点；depth > 6 时抛出 MaxDepthExceeded
  TreeNode addChild(String parentId, String text);
  
  // 在 nodeId 之后插入兄弟节点
  TreeNode addSibling(String nodeId, String text);
  
  // 更新节点文本；text 超过 200 字符时截断
  void updateText(String nodeId, String text);
  
  // 删除节点及其所有后代；nodeId 为根节点时抛出 CannotDeleteRoot
  void deleteNode(String nodeId);
  
  // 移动节点到 targetId 下；targetId 是 nodeId 后代时抛出 CircularMove
  void moveNode(String nodeId, String targetId);
  
  // 查询
  bool isDescendant(String ancestorId, String nodeId);
  int nodeDepth(String nodeId);
  List<TreeNode> allNodes(); // 前序遍历展平
}
```

### EditHistory

```dart
class EditHistory {
  static const int maxSize = 50;
  
  final List<String> _undoStack = [];  // Markdown 快照
  final List<String> _redoStack = [];
  
  void push(String snapshot);          // 新操作前调用
  String? undo(String currentSnapshot); // 返回上一个快照
  String? redo();                       // 返回下一个快照
  
  bool get canUndo;
  bool get canRedo;
  void clearRedo();                     // 新操作后清空重做栈
}
```

### ImportParser

```dart
sealed class ImportResult {}
class ImportSuccess extends ImportResult { final List<TreeNode> roots; }
class ImportError extends ImportResult {
  final ImportErrorType type;
  final String message;
}

enum ImportErrorType { unsupportedFormat, parseFailure, noStructure }

class ImportParser {
  // 从文件字节解析，根据扩展名分发
  static ImportResult parseFile(Uint8List bytes, String filename);
  
  // Markdown 大纲 → Node_Tree
  static ImportResult parseMarkdown(String text);
  
  // XMind (.xmind 是 ZIP，内含 content.xml)
  static ImportResult parseXMind(Uint8List bytes);
  
  // FreeMind (.mm XML)
  static ImportResult parseFreeMind(String xmlText);
  
  // OCR 层级文本 → Node_Tree（缩进/编号推断层级）
  static ImportResult parseOcrLines(List<OcrLine> lines);
}
```

### MindmapRepository

```dart
class MindmapRepository {
  // 获取某学科下所有导图元数据
  Future<List<MindmapMeta>> listMindmaps(int subjectId);
  
  // 加载某导图的 Node_Tree
  Future<List<TreeNode>> loadTree(int subjectId, String mindmapId);
  
  // 保存（覆盖）某导图的 Node_Tree
  Future<void> saveTree(int subjectId, String mindmapId, List<TreeNode> roots);
  
  // 创建新导图
  Future<MindmapMeta> createMindmap(int subjectId, String name);
  
  // 删除导图（学科下只剩一份时拒绝）
  Future<void> deleteMindmap(int subjectId, String mindmapId);
  
  // 重命名
  Future<void> renameMindmap(int subjectId, String mindmapId, String newName);
}
```

### Riverpod Providers

```dart
// 当前学科下的导图列表
final mindmapListProvider = FutureProvider.family<List<MindmapMeta>, int>(
  (ref, subjectId) => ref.read(mindmapRepositoryProvider).listMindmaps(subjectId),
);

// 当前激活的导图 ID（每个学科独立）
final activeMindmapIdProvider = StateProvider.family<String?, int>(
  (ref, subjectId) => null,
);

// 当前激活导图的节点树（可变状态）
final nodeTreeProvider = StateNotifierProvider.family<NodeTreeNotifier, NodeTreeState, (int, String)>(
  (ref, key) => NodeTreeNotifier(ref, subjectId: key.$1, mindmapId: key.$2),
);

// 编辑历史（每个导图独立）
final editHistoryProvider = Provider.family<EditHistory, (int, String)>(
  (ref, key) => EditHistory(),
);
```

### OcrService

```dart
class OcrService {
  // 调用后端 OCR API，超时 30 秒
  Future<OcrResult> recognize(Uint8List imageBytes);
}

class OcrResult {
  final List<OcrLine> lines;
}

class OcrLine {
  final String text;
  final double confidence;  // 0.0 ~ 1.0
  final int indentLevel;    // 推断的缩进层级（0-based）
}
```

### ExportService

```dart
class ExportService {
  // 序列化为 Markdown 大纲文本
  static String toMarkdown(List<TreeNode> roots);
  
  // 截图导出为 PNG（复用现有 screenshot 包）
  static Future<Uint8List> toPng(GlobalKey repaintKey);
  
  // 触发系统分享/保存
  static Future<void> shareMarkdown(String content, String filename);
  static Future<void> savePng(Uint8List bytes, String filename);
}
```

---

## 数据模型

### MindmapMeta

```dart
class MindmapMeta {
  final String id;          // UUID
  final int subjectId;
  final String name;        // 用户命名，最长 50 字符
  final DateTime createdAt;
  final DateTime updatedAt;
  
  Map<String, dynamic> toJson();
  factory MindmapMeta.fromJson(Map<String, dynamic> json);
}
```

### 扩展后的 TreeNode

现有 `TreeNode` 模型基本满足需求，需要以下扩展：

```dart
class TreeNode {
  final String nodeId;
  final String text;        // 最长 200 字符
  final int depth;          // 1-6（扩展自现有 1-4）
  final String? parentId;
  final bool isUserCreated;
  final List<TreeNode> children;
  bool isExpanded;
  
  // 新增：用于拖拽高亮状态（仅 UI 层，不持久化）
  // 通过 UI 层 Set<String> 管理，不放入模型
}
```

### NodeTreeState

```dart
class NodeTreeState {
  final List<TreeNode> roots;
  final bool isDirty;           // 是否有未保存的变更
  final DateTime? lastSavedAt;
  final String? draggingNodeId; // 当前拖拽中的节点
  final String? dropTargetId;   // 当前悬停的目标节点
}
```

### 本地存储 Schema

```
SharedPreferences keys:
  "mindmap_meta_{subjectId}"          → JSON array of MindmapMeta
  "mindmap_tree_{subjectId}_{id}"     → Markdown string (Node_Tree 序列化)
  "mindmap_active_{subjectId}"        → String (active mindmap id)
```

### OcrLine（用于 OCR 预览编辑）

```dart
class OcrLine {
  final String text;
  final double confidence;
  int indentLevel;          // 可由用户在预览界面调整
  bool isSelected;          // 用户可取消选中某行
}
```

---

## 正确性属性

*属性（Property）是在系统所有合法执行中都应成立的特征或行为——本质上是对系统应做什么的形式化陈述。属性是人类可读规范与机器可验证正确性保证之间的桥梁。*

### 属性 1：子节点添加后父节点 children 增加 1

*对任意* 合法的 Node_Tree 和任意深度未达 6 级的节点，调用 `addChild` 后，该节点的 `children.length` 应恰好增加 1，且新子节点的 `depth` 等于父节点 `depth + 1`。

**验证：需求 1.1、1.5**

---

### 属性 2：空白文本节点不被添加

*对任意* 仅由空白字符（空格、制表符、换行符）组成的字符串，调用 `addChild` 或 `addSibling` 时，Node_Tree 的节点总数应保持不变。

**验证：需求 1.4**

---

### 属性 3：节点文本更新后可读回

*对任意* Node_Tree 中的节点和任意有效文本（长度 1-200），调用 `updateText(nodeId, newText)` 后，通过 `nodeId` 查找该节点，其 `text` 应等于 `newText`。

**验证：需求 2.2**

---

### 属性 4：取消编辑恢复原始文本

*对任意* 节点，开始编辑（记录原始文本）后调用取消，该节点的 `text` 应与编辑前完全相同。

**验证：需求 2.3**

---

### 属性 5：节点文本长度不变量

*对任意* 通过 `addChild`、`addSibling`、`updateText` 或导入操作产生的节点，其 `text.length` 应始终 ≤ 200。

**验证：需求 2.4、7.7**

---

### 属性 6：删除节点后其后代全部消失

*对任意* Node_Tree 和任意非根节点 N，调用 `deleteNode(N.nodeId)` 后，对树进行前序遍历，N 及其所有后代节点均不应出现在遍历结果中。

**验证：需求 3.2**

---

### 属性 7：节点深度不变量

*对任意* 初始合法的 Node_Tree，执行任意次数的 `addChild`、`addSibling`、`moveNode` 操作后，树中所有节点的 `depth` 应始终 ≤ 6。

**验证：需求 1.5、4.3**

---

### 属性 8：禁止循环移动

*对任意* Node_Tree 中的节点 A 和 A 的任意后代节点 D，调用 `moveNode(A.nodeId, D.nodeId)` 应抛出 `CircularMove` 异常，且树结构保持不变。

**验证：需求 4.4**

---

### 属性 9：撤销恢复前一状态

*对任意* 初始树状态 S0，执行任意单步编辑操作（添加/编辑/删除/移动）得到状态 S1，再调用 `undo()` 后，树的序列化结果应等于 S0 的序列化结果。

**验证：需求 5.2**

---

### 属性 10：撤销-重做往返

*对任意* 编辑操作，执行操作→撤销→重做后，树的序列化结果应与仅执行操作后（未撤销）的序列化结果相同。

**验证：需求 5.3**

---

### 属性 11：历史栈长度上限

*对任意* 次数（> 50）的编辑操作序列，`EditHistory` 的撤销栈长度应始终 ≤ 50。

**验证：需求 5.1**

---

### 属性 12：新操作后重做栈清空

*对任意* 撤销操作后，执行任意新的编辑操作，`EditHistory.canRedo` 应为 `false`。

**验证：需求 5.6**

---

### 属性 13：合并操作保留原有节点

*对任意* 当前 Node_Tree（含 N 个节点）和 AI 生成的 Node_Tree，执行"合并"操作后，原有 N 个节点的 `nodeId` 和 `text` 应全部出现在合并后的树中。

**验证：需求 6.3**

---

### 属性 14：不支持格式返回错误

*对任意* 扩展名既非 `.xmind` 也非 `.mm` 的文件名，`ImportParser.parseFile` 应返回 `ImportError(type: unsupportedFormat)`。

**验证：需求 7.5**

---

### 属性 15：导入节点文本截断不变量

*对任意* 包含超长文本节点（`text.length > 200`）的导入源（XMind、FreeMind、Markdown），导入后所有节点的 `text.length` 应 ≤ 200。

**验证：需求 7.7**（与属性 5 互补，专门针对导入路径）

---

### 属性 16：Markdown 解析深度映射

*对任意* 合法的 Markdown 大纲文本，`ImportParser.parseMarkdown` 返回的每个节点，其 `depth` 应等于对应标题行的 `#` 数量（`#` → 1，`##` → 2，…，`######` → 6）。

**验证：需求 8.2、8.3**

---

### 属性 17：Markdown 往返属性

*对任意* 合法的 Markdown 大纲文本 M，执行 `parse(M)` 得到树 T，再执行 `serialize(T)` 得到 M'，再执行 `parse(M')` 得到树 T'，T 和 T' 的节点文本序列和层级结构应完全等价。

**验证：需求 8.5、11.4**

---

### 属性 18：OCR 置信度高亮不变量

*对任意* 置信度分数列表，`shouldHighlight(score)` 当且仅当 `score < 0.7` 时返回 `true`。

**验证：需求 9.6**

---

### 属性 19：最后一份导图不可删除

*对任意* 学科，当该学科下的导图数量为 1 时，`MindmapRepository.deleteMindmap` 应抛出 `CannotDeleteLastMindmap` 异常。

**验证：需求 10.6**

---

### 属性 20：序列化深度映射

*对任意* 合法的 Node_Tree，`ExportService.toMarkdown` 返回的 Markdown 文本中，每个节点对应行的 `#` 数量应等于该节点的 `depth`。

**验证：需求 11.2**

---

## 错误处理

| 错误场景 | 处理方式 | 用户提示 |
|---------|---------|---------|
| 添加子节点时深度已达 6 级 | `NodeTreeEditor` 抛出 `MaxDepthExceeded`，UI 禁用按钮 | "已达最大层级深度" |
| 删除根节点 | `NodeTreeEditor` 抛出 `CannotDeleteRoot`，UI 隐藏删除入口 | 不显示（入口不可见） |
| 循环移动（移到后代下） | `NodeTreeEditor` 抛出 `CircularMove`，恢复原位 | "不能将节点移动到其自身的子节点下" |
| 导入不支持的格式 | `ImportParser` 返回 `ImportError.unsupportedFormat` | "不支持该文件格式，请选择 .xmind 或 .mm 文件" |
| 导入文件解析失败 | `ImportParser` 返回 `ImportError.parseFailure` | "文件解析失败，请检查文件是否完整" |
| Markdown 无可识别结构 | `ImportParser` 返回 `ImportError.noStructure` | "未识别到有效的大纲结构，请使用 # 标题或 - 列表格式" |
| OCR 识别失败 | `OcrService` 抛出 `OcrException`，UI 显示提示 | "图片识别失败，请确保图片清晰且包含文字内容" |
| OCR 超时（> 30s） | `OcrService` 抛出 `OcrTimeoutException` | "识别超时，请重试或手动输入" |
| 持久化失败 | `MindmapRepository` 抛出异常，UI 显示 SnackBar，不回滚内存状态 | "保存失败，请检查存储空间" |
| 删除最后一份导图 | `MindmapRepository` 抛出 `CannotDeleteLastMindmap`，UI 禁用按钮 | 不显示（按钮禁用） |

所有异常均为自定义密封类（`sealed class MindmapException`），便于穷举处理。

---

## 测试策略

### 测试分层

```
单元测试（纯 Dart）
  ├── NodeTreeEditor — 所有树变更操作
  ├── EditHistory — 撤销/重做逻辑
  ├── ImportParser — Markdown/XMind/FreeMind/OCR 解析
  ├── ExportService.toMarkdown — 序列化逻辑
  └── MindmapRepository — 本地存储读写（mock SharedPreferences）

Widget 测试
  ├── MindmapSelectorDropdown — 导图切换 UI
  ├── OcrPreviewSheet — OCR 预览与编辑
  └── ImportModeDialog — 替换/合并选择对话框

集成测试
  ├── OCR API 调用（1-2 个真实图片样本）
  └── 学科切换时导图加载/保存
```

### 属性测试配置

使用 [`fast_check`](https://pub.dev/packages/fast_check) 包（Dart 属性测试库）。

每个属性测试运行最少 **100 次**迭代。每个测试用注释标注对应的设计属性：

```dart
// Feature: mindmap-editor, Property 17: Markdown 往返属性
test('markdown round-trip preserves structure', () {
  fc.assert(
    fc.property(arbitraryMarkdownOutline(), (markdown) {
      final tree = ImportParser.parseMarkdown(markdown);
      // ...
    }),
    numRuns: 100,
  );
});
```

### 属性测试生成器

需要实现以下 Arbitrary 生成器：

- `arbitraryNodeTree(maxDepth: 6, maxChildren: 5)` — 生成随机合法 Node_Tree
- `arbitraryMarkdownOutline(maxDepth: 6)` — 生成随机合法 Markdown 大纲文本
- `arbitraryNodeText()` — 生成随机 1-200 字符文本（含中文、特殊字符）
- `arbitraryXMindXml()` — 生成随机合法 XMind content.xml 结构
- `arbitraryFreeMindXml()` — 生成随机合法 FreeMind .mm XML 结构
- `arbitraryOcrLines()` — 生成随机 OcrLine 列表（含随机置信度）

### 单元测试重点

- `NodeTreeEditor.deleteNode`：验证后代全部消失（属性 6）
- `NodeTreeEditor.moveNode`：验证循环检测（属性 8）
- `EditHistory`：边界条件（空栈撤销、超过 50 步）
- `ImportParser.parseMarkdown`：空输入、纯空白、超深层级（> 6）
- `ImportParser.parseXMind`：ZIP 损坏、缺少 content.xml
- `MindmapRepository`：学科切换时的保存/加载顺序

### 不适用属性测试的部分

以下功能使用示例测试或集成测试：
- UI 状态（拖拽模式进入/退出、对话框弹出）：Widget 测试
- OCR API 调用：集成测试（1-2 个样本）
- PNG 导出：Widget 测试（验证 `RepaintBoundary` 截图非空）
- AI 协调对话框：Widget 测试
