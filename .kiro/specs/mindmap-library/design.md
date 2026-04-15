# 设计文档：学校（School）/ 图书馆（mindmap-library）

## 概述

将现有「图书馆」Tab 升级为「学校」Tab，构建以学科为课程、思维导图为大纲、AI 讲义为课程内容的个人学习空间。

核心技术栈：Flutter（Android）+ Riverpod + GoRouter，后端 FastAPI + PostgreSQL + PGVector，LLM 使用 DeepSeek-V3（SiliconFlow API）。

---

## 架构

### 整体分层

```
Flutter 前端
├── 路由层（GoRouter）
├── 页面层（Pages）
├── 状态层（Riverpod Providers）
├── 服务层（API Services）
└── 组件层（Widgets）

FastAPI 后端
├── 路由层（Routers）
├── 服务层（Services）
│   ├── MindMapParserService   ← 新增
│   ├── LectureGeneratorService ← 新增
│   ├── NodeStateService        ← 新增
│   └── RAGPipeline（复用）
└── 数据层（PostgreSQL + PGVector）
```

### 数据流

```
用户点击节点「生成讲义」
  → Flutter 调用 POST /api/library/lectures
  → LectureGeneratorService
      ├── RAGPipeline.retrieve(node_text, subject_id, doc_ids)
      ├── MemoryService.get_merged_memory(user_id, subject_id)
      ├── 构建 prompt（节点路径 + RAG 上下文 + 用户画像）
      └── LLMService.chat(messages)  → DeepSeek-V3
  → 存储到 node_lectures 表
  → 返回讲义内容
  → Flutter 跳转到 LecturePage
```

---

## 组件与接口

### 后端新增路由模块

`backend/routers/library.py` — 统一挂载在 `/api/library`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/subjects` | 获取学科列表（含进度汇总） |
| GET | `/subjects/{subject_id}/sessions` | 获取某学科下所有 mindmap 会话（大纲列表） |
| PATCH | `/sessions/{session_id}/title` | 重命名大纲 |
| DELETE | `/sessions/{session_id}` | 删除大纲（级联删除讲义和点亮状态） |
| GET | `/sessions/{session_id}/nodes` | 解析大纲返回节点树 |
| PATCH | `/sessions/{session_id}/content` | 更新大纲 Markdown 内容（编辑节点后） |
| GET | `/sessions/{session_id}/node-states` | 获取某大纲所有节点点亮状态 |
| POST | `/sessions/{session_id}/node-states` | 批量更新节点点亮状态 |
| GET | `/lectures/{session_id}/{node_id}` | 获取某节点讲义 |
| POST | `/lectures` | 生成节点讲义 |
| PATCH | `/lectures/{lecture_id}` | 增量更新讲义内容 |
| DELETE | `/lectures/{session_id}/{node_id}` | 删除讲义 |

### Flutter 前端新增页面

| 页面 | 路由 | 说明 |
|------|------|------|
| `SchoolPage` | `/library` | 学科课程卡片列表（替换原 LibraryPage） |
| `CourseSpacePage` | `/library/:subjectId` | 某学科的大纲列表 |
| `EditableMindMapPage` | `/library/:subjectId/mindmap/:sessionId` | 可交互思维导图 |
| `LecturePage` | `/library/:subjectId/mindmap/:sessionId/lecture/:nodeId` | 讲义详情与编辑 |

---

## 数据模型

### 新增表：mindmap_node_states

```sql
CREATE TABLE mindmap_node_states (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_id  INTEGER NOT NULL REFERENCES conversation_sessions(id) ON DELETE CASCADE,
    node_id     VARCHAR(512) NOT NULL,   -- 基于层级路径生成的稳定 ID
    is_lit      SMALLINT NOT NULL DEFAULT 1,  -- 1=已点亮
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_node_state UNIQUE (user_id, session_id, node_id)
);
CREATE INDEX idx_node_states_user_session ON mindmap_node_states (user_id, session_id);
```

### 新增表：node_lectures

```sql
CREATE TABLE node_lectures (
    id              SERIAL PRIMARY KEY,
    user_id         INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_id      INTEGER NOT NULL REFERENCES conversation_sessions(id) ON DELETE CASCADE,
    node_id         VARCHAR(512) NOT NULL,
    content         JSONB NOT NULL,          -- 富文本内容，见下方结构
    resource_scope  JSONB,                   -- 资料范围标识，如 {"doc_ids": [1,2,3]}
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_node_lecture UNIQUE (user_id, session_id, node_id)
);
CREATE INDEX idx_node_lectures_user_session ON node_lectures (user_id, session_id);
```

### node_lectures.content 结构（JSONB）

```json
{
  "version": 1,
  "blocks": [
    {
      "id": "block_001",
      "type": "heading",        // heading | paragraph | code | list | quote
      "level": 2,               // heading 专用：1-3
      "text": "概念定义",
      "source": "ai"            // ai | user（区分 AI 生成与用户编辑）
    },
    {
      "id": "block_002",
      "type": "paragraph",
      "text": "正应力是...",
      "source": "ai",
      "spans": [                // 行内格式
        {"start": 0, "end": 3, "bold": true}
      ]
    },
    {
      "id": "block_003",
      "type": "code",
      "language": "python",
      "text": "sigma = F / A",
      "source": "ai"
    }
  ]
}
```

### conversation_sessions 表扩展字段

无需新增字段，复用现有结构：
- `session_type = 'mindmap'`
- `title`：大纲标题
- 大纲 Markdown 内容存储在 `conversation_history` 表中，`role='assistant'` 的最新一条记录

### 节点 ID 生成规则

节点 ID 基于层级路径生成，格式为 `L{depth}_{parent_path}_{text_hash}_{seq}`：

```
# 材料力学                    → node_id: "L1_材料力学"
## 应力分析                   → node_id: "L2_材料力学_应力分析"
### 主应力                    → node_id: "L3_材料力学_应力分析_主应力"
### 主应力（重复兄弟节点）     → node_id: "L3_材料力学_应力分析_主应力_2"
```

---

## 导航与路由

### GoRouter 路由扩展

在 `app_router.dart` 的 ShellRoute 中，`/library` 路由改为嵌套结构：

```dart
GoRoute(
  path: AppRoutes.library,
  builder: (_, _) => const SchoolPage(),
  routes: [
    GoRoute(
      path: ':subjectId',
      builder: (_, state) => CourseSpacePage(
        subjectId: int.parse(state.pathParameters['subjectId']!),
      ),
      routes: [
        GoRoute(
          path: 'mindmap/:sessionId',
          builder: (_, state) => EditableMindMapPage(
            subjectId: int.parse(state.pathParameters['subjectId']!),
            sessionId: int.parse(state.pathParameters['sessionId']!),
          ),
          routes: [
            GoRoute(
              path: 'lecture/:nodeId',
              builder: (_, state) => LecturePage(
                subjectId: int.parse(state.pathParameters['subjectId']!),
                sessionId: int.parse(state.pathParameters['sessionId']!),
                nodeId: Uri.decodeComponent(state.pathParameters['nodeId']!),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
),
```

### 导航流程

```
SchoolPage（学科卡片列表）
  ↓ 点击课程卡片
CourseSpacePage（大纲列表）
  ↓ 点击大纲
EditableMindMapPage（可交互思维导图）
  ↓ 点击节点 → 「生成/查看讲义」
LecturePage（讲义详情 + 编辑 + 导出）
```

---

## 可交互思维导图实现方案

### 方案选择

放弃原只读 WebView + markmap.js 方案，改为 **Flutter 原生自绘**，原因：
1. WebView 与 Flutter 双向通信复杂，节点点亮状态同步困难
2. 原生绘制可完全控制节点样式（点亮/半点亮/有讲义图标）
3. 手势识别（单击/长按/缩放/平移）在原生层更可靠

### 渲染引擎：CustomPainter + InteractiveViewer

```
EditableMindMapPage
└── InteractiveViewer（支持双指缩放、平移）
    └── CustomPaint（MindMapPainter）
        ├── 绘制连接线（贝塞尔曲线）
        ├── 绘制节点矩形（圆角，按状态着色）
        ├── 绘制节点文字
        └── 绘制状态图标（📖 有讲义 / ✓ 已点亮）
```

### 节点状态颜色规则

| 状态 | 背景色 | 文字色 | 边框 |
|------|--------|--------|------|
| 默认 | `surface` | `onSurface` | `outlineVariant` |
| 已点亮 | `primary` | `onPrimary` | 无 |
| 半点亮（子节点全亮） | `primaryContainer` | `onPrimaryContainer` | 无 |
| 用户自建节点 | `tertiaryContainer` | `onTertiaryContainer` | 虚线 |
| 有讲义 | 同上 + 右上角 📖 图标 | — | — |

### 节点交互

**单击节点** → 显示操作浮层 `NodeActionSheet`（BottomSheet）：
- 「生成讲义」/ 「查看讲义」
- 「添加子节点」
- 「编辑文本」
- 「删除节点」

**长按节点** → 显示点亮操作菜单：
- 「标记为已学习」/ 「取消标记」

**点击有子节点的节点** → 折叠/展开子树（在浮层之外，通过双击或专用折叠按钮触发）

### 大纲 Markdown 编辑持久化

节点编辑操作（增/删/改）均在内存中操作节点树，操作完成后：
1. 将节点树序列化回 Markdown 字符串
2. 调用 `PATCH /api/library/sessions/{sessionId}/content` 持久化
3. 本地维护撤销栈（最多 20 步），存储每次操作前的 Markdown 快照

---

## 讲义生成流程

### Prompt 构造

```python
def build_lecture_prompt(
    node_path: list[str],      # ["材料力学", "应力分析", "主应力"]
    rag_context: str,          # RAG 检索结果
    user_memory: dict,         # 用户画像
    parent_summary: str = "",  # 父节点讲义前 500 字（可选）
) -> list[dict]:

    node_full_path = " > ".join(node_path)
    current_node = node_path[-1]

    system = f"""你是一位专业的学科辅导老师，正在为学生生成知识点讲义。
当前知识点在学科体系中的位置：{node_full_path}
请针对「{current_node}」生成保姆级别详细讲义，不跳步骤，不省略推导过程。

讲义必须包含以下结构（每部分有明确标题）：
## 概念定义
## 核心原理
## 详细推导或说明
## 典型例题（含完整解析）
## 常见误区
## 小结

用户学习画像：
{format_memory(user_memory)}
"""
    messages = [{"role": "system", "content": system}]

    if parent_summary:
        messages.append({
            "role": "user",
            "content": f"父节点讲义摘要（供参考，保持连贯性）：\n{parent_summary}"
        })

    messages.append({
        "role": "user",
        "content": f"参考资料（来自学科资料库）：\n{rag_context}\n\n请生成「{current_node}」的详细讲义。"
    })

    return messages
```

### RAG 检索范围限定

生成讲义时，RAG 检索限定在该大纲关联的资料范围（`resource_scope.doc_ids`）内：

```python
# 从 node_lectures.resource_scope 或 conversation_sessions 关联的 doc_ids 获取
vector_store = rag.get_vector_store(subject_id)
docs = vector_store.similarity_search_with_score(
    node_text,
    k=8,
    filter={"document_id": {"$in": doc_ids}}  # PGVector metadata filter
)
```

### 无资料降级处理

当 RAG 检索无结果时，讲义顶部自动插入提示块：

```json
{
  "id": "notice_001",
  "type": "paragraph",
  "text": "⚠️ 本讲义未检索到相关资料，内容基于通用知识生成",
  "source": "ai",
  "style": "warning"
}
```

---

## 富文本编辑器方案

### 选型：flutter_quill

使用 `flutter_quill` 包（成熟的 Flutter 富文本编辑器），支持需求中所有格式：H1-H3、正文、加粗、斜体、行内代码、代码块、有序/无序列表、引用块。

### 内容格式转换

后端存储自定义 JSONB 格式（见数据模型），前端与 Quill Delta 格式互转：

```
后端 JSONB blocks  ←→  转换层（BlockConverter）  ←→  Quill Delta
```

`BlockConverter` 负责：
- `blocksToQuillDelta(blocks)` → Quill Delta（加载时）
- `quillDeltaToBlocks(delta)` → JSONB blocks（保存时），保留 `source` 字段

### 自动保存机制

```dart
class LectureEditorNotifier extends StateNotifier<LectureEditorState> {
  Timer? _saveTimer;

  void onContentChanged(Delta delta) {
    state = state.copyWith(delta: delta, isDirty: true);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 5), _autoSave);
  }

  Future<void> _autoSave() async {
    if (!state.isDirty) return;
    try {
      final blocks = BlockConverter.quillDeltaToBlocks(state.delta);
      await _api.patchLecture(state.lectureId, blocks);
      state = state.copyWith(isDirty: false, saveError: null);
    } catch (e) {
      state = state.copyWith(saveError: e.toString());
      // 网络恢复后重试由 connectivity_plus 监听触发
    }
  }
}
```

### 离开页面时强制保存

`LecturePage` 使用 `PopScope` 拦截返回手势，确保未保存内容先持久化：

```dart
PopScope(
  canPop: false,
  onPopInvokedWithResult: (didPop, _) async {
    if (!didPop) {
      await ref.read(lectureEditorProvider.notifier).forceSave();
      if (context.mounted) context.pop();
    }
  },
  child: ...,
)
```

---

## 导出流程

### Markdown 导出

```dart
String exportToMarkdown(List<Block> blocks) {
  // blocks → Markdown 字符串
  // heading → # ## ###
  // paragraph → 纯文本（含 bold/italic/code spans）
  // code → ```lang\n...\n```
  // list → - item 或 1. item
  // quote → > text
}
// 调用 FileSaver.instance.saveFile() 触发系统文件保存对话框
```

### PDF 导出

使用 `pdf` 包（dart）在客户端生成 PDF，无需后端：

```dart
Future<Uint8List> exportToPdf(List<Block> blocks) async {
  final doc = pw.Document();
  doc.addPage(pw.MultiPage(
    build: (ctx) => blocks.map((b) => _blockToWidget(b)).toList(),
  ));
  return doc.save();
}
```

### Word（.docx）导出

使用后端 Python `python-docx` 库生成，前端调用 `POST /api/library/lectures/{id}/export?format=docx`，后端返回文件流，前端用 `FileSaver` 保存。

---

## 状态管理（Riverpod Providers）

```dart
// 学科列表（含进度汇总）
final schoolSubjectsProvider = FutureProvider<List<SubjectWithProgress>>(...)

// 某学科的大纲列表
final courseSessionsProvider = FutureProvider.family<List<MindMapSession>, int>(
  (ref, subjectId) => ...
)

// 某大纲的节点树（解析后）
final mindMapNodesProvider = FutureProvider.family<MindMapTree, int>(
  (ref, sessionId) => ...
)

// 某大纲的节点点亮状态 Map<nodeId, bool>
final nodeStatesProvider = StateNotifierProvider.family<NodeStatesNotifier, Map<String, bool>, int>(
  (ref, sessionId) => NodeStatesNotifier(sessionId)
)

// 进度计算（派生 Provider）
final mindMapProgressProvider = Provider.family<MindMapProgress, int>(
  (ref, sessionId) {
    final nodes = ref.watch(mindMapNodesProvider(sessionId));
    final states = ref.watch(nodeStatesProvider(sessionId));
    return nodes.maybeWhen(
      data: (tree) => MindMapProgress.calculate(tree.allNodes, states),
      orElse: () => MindMapProgress.empty(),
    );
  }
)

// 讲义编辑器状态
final lectureEditorProvider = StateNotifierProvider.autoDispose
    .family<LectureEditorNotifier, LectureEditorState, LectureKey>(...)

// 某节点是否已有讲义（用于节点图标显示）
final nodeLectureExistsProvider = FutureProvider.family<bool, NodeKey>(...)
```

### 数据模型（Flutter 端）

```dart
class SubjectWithProgress {
  final Subject subject;
  final int totalNodes;
  final int litNodes;
  final int sessionCount;
  final DateTime? lastVisitedAt;
}

class MindMapSession {
  final int id;
  final String title;
  final String? resourceScopeLabel;
  final DateTime createdAt;
  final int totalNodes;
  final int litNodes;
}

class TreeNode {
  final String nodeId;
  final String text;
  final int depth;          // 1-4
  final String? parentId;
  final bool isUserCreated; // 区分 AI 生成 vs 用户自建
  final List<TreeNode> children;
  bool isExpanded;
}

class MindMapProgress {
  final int total;
  final int lit;
  int get percent => total == 0 ? 0 : (lit / total * 100).floor();
}
```

---

## 正确性属性

*属性是在系统所有有效执行中都应成立的特征或行为——本质上是关于系统应该做什么的形式化陈述。属性是人类可读规范与机器可验证正确性保证之间的桥梁。*

### 属性 1：课程卡片渲染完整性

*对任意* 非空学科列表，渲染后的课程卡片数量应等于学科数量，且每张卡片包含学科名称、学习进度、「开始学习」按钮。

**验证：需求 1.2、1.3**

### 属性 2：置顶学科排序不变量

*对任意* 包含置顶和非置顶学科的混合列表，经排序函数处理后，所有置顶学科的索引均小于所有非置顶学科的索引。

**验证：需求 1.4**

### 属性 3：搜索过滤子集属性

*对任意* 学科列表和任意搜索关键词，过滤结果应是原列表的子集，且结果中每个学科的名称或分类字段均包含该关键词（大小写不敏感）。

**验证：需求 1.6**

### 属性 4：大纲列表时间降序不变量

*对任意* 大纲（MindMapSession）列表，经排序函数处理后，相邻两项的 `created_at` 满足前者 ≥ 后者。

**验证：需求 2.2**

### 属性 5：大纲名称校验属性

*对任意* 字符串输入，若其长度为 0 或超过 64 个字符（含纯空白字符串），校验函数应返回错误；若长度在 1-64 之间（去除首尾空白后），校验函数应返回通过。

**验证：需求 2.7**

### 属性 6：节点文本校验属性

*对任意* 字符串输入，若其去除首尾空白后长度为 0 或超过 200 个字符，节点文本校验函数应返回错误；否则应返回通过。

**验证：需求 3.4**

### 属性 7：Markdown 解析节点 ID 唯一性

*对任意* 有效的 Markdown 大纲文本（包含重复文本的兄弟节点），`MindMapParser` 解析后所有节点的 `nodeId` 字段两两不同。

**验证：需求 4.3**

### 属性 8：Markdown 解析往返一致性

*对任意* 有效的 Markdown 大纲文本，经 `MindMapParser.parse()` 解析为节点树，再经 `MindMapSerializer.serialize()` 序列化回 Markdown，再次解析后得到的节点树结构（nodeId、text、depth、parentId）应与第一次解析结果完全相同。

**验证：需求 4.5**

### 属性 9：节点点亮状态幂等性

*对任意* `(user_id, session_id, node_id)` 组合，多次写入相同的点亮状态后，数据库中该组合的记录数应恰好为 1，且 `is_lit` 值等于最后一次写入的值。

**验证：需求 5.6**

### 属性 10：进度计算完整性不变量

*对任意* 节点集合和任意点亮状态映射，`ProgressTracker.calculate()` 返回的 `lit + (total - lit) == total` 恒成立，即已点亮节点数与未点亮节点数之和等于总节点数。

**验证：需求 6.6**

### 属性 11：讲义内容往返一致性

*对任意* 富文本内容（JSONB blocks 格式），经 `PATCH /api/library/lectures/{id}` 保存后，通过 `GET /api/library/lectures/{session_id}/{node_id}` 读取的 `content.blocks` 应与保存前的内容完全相同（字段级别等价）。

**验证：需求 9.2、12.7**

### 属性 12：Markdown 导出内容一致性

*对任意* 讲义内容（blocks 列表），`exportToMarkdown(blocks)` 导出的 Markdown 字符串经 Markdown 解析后，所有文本内容应与原始 blocks 中的文本内容语义等价（不丢失任何文本段落）。

**验证：需求 10.6**

---

## 错误处理

### 讲义生成失败

- 网络超时（>30s）：返回 `504`，前端显示「生成超时，请重试」，保留「重新生成」按钮
- LLM API 失败：返回 `502`，前端显示「AI 服务暂时不可用」，不保存不完整内容
- RAG 检索失败：降级为无资料模式继续生成，讲义顶部插入警告块

### 自动保存失败

- 网络断开：前端显示「保存失败，请检查网络」横幅，本地缓存未保存内容
- 监听 `connectivity_plus` 网络恢复事件，自动重试保存
- 离开页面时若仍有未保存内容，弹出确认对话框

### 节点操作失败

- 编辑/删除节点后后端持久化失败：回滚本地节点树到操作前状态，显示 Toast 错误提示
- 撤销栈在持久化失败时不推入新快照

### 导出失败

- PDF/Word 生成失败：显示错误 Toast，提供「重试」按钮，不生成损坏文件
- 文件保存对话框取消：静默处理，不显示错误

---

## 测试策略

### 单元测试

- `MindMapParser`：解析各种层级结构、重复节点、空文本节点
- `MindMapSerializer`：序列化后格式正确
- `ProgressTracker.calculate()`：各种节点/状态组合
- `BlockConverter`：JSONB blocks ↔ Quill Delta 互转
- `exportToMarkdown()`：各种 block 类型的 Markdown 输出
- 校验函数：大纲名称、节点文本的边界值

### 属性测试（Property-Based Testing）

使用 `fast_check`（TypeScript/Dart 端）或 `hypothesis`（Python 端）：

- 每个属性测试运行最少 100 次迭代
- 每个测试用注释标注对应的设计属性编号
- 标注格式：`// Feature: mindmap-library, Property {N}: {property_text}`

**Python 端（pytest + hypothesis）**：
- 属性 7、8：`MindMapParser` 往返一致性和 ID 唯一性
- 属性 9：`NodeStateService` 幂等性
- 属性 11：讲义内容往返一致性

**Dart 端（test + 自定义生成器）**：
- 属性 2、4：排序函数不变量
- 属性 3：搜索过滤子集属性
- 属性 5、6：校验函数边界
- 属性 10：进度计算完整性
- 属性 12：Markdown 导出一致性

### 集成测试

- 讲义生成完整流程（RAG + LLM + 存储）：使用 mock LLM 和 mock PGVector
- 节点点亮状态持久化：真实数据库（测试库）
- 大纲级联删除：验证讲义和点亮状态同步删除

### 冒烟测试

- 底部导航「学校」Tab 存在且图标正确
- `/api/library/subjects` 接口可访问
- 数据库表 `mindmap_node_states`、`node_lectures` 已创建
