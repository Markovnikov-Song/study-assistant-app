# 设计文档：讲义导出为书（Lecture Book Export）

## 概述

本功能在现有讲义页面（`LecturePage`）的导出菜单中新增"导出为书"入口，
允许用户从大纲树中多选节点，将各节点的讲义合并为一份带目录的完整文档，
支持 PDF（后端 reportlab，内嵌中文字体）和 Word（后端 python-docx）两种格式。

核心设计原则：
- **后端生成**：所有文件生成逻辑在 FastAPI 后端完成，前端只负责 UI 和文件下载。
- **渐进降级**：无讲义节点静默跳过；LaTeX 渲染失败回退为原始文本；字体不可用返回明确错误。
- **零新表**：不引入新数据库表，复用现有 `node_lectures`、`conversation_sessions` 等。

---

## 架构

```
┌─────────────────────────────────────────────────────────────────┐
│  Flutter 前端                                                    │
│                                                                  │
│  LecturePage._showExportMenu()                                   │
│    └─ "导出为书" 选项                                            │
│         └─ ExportBookDialog (新建)                               │
│              ├─ 节点树 + 复选框 UI                               │
│              └─ BookExportService.exportBook(...)  (新建)        │
│                   └─ POST /api/library/sessions/{id}/export-book │
└──────────────────────────────┬──────────────────────────────────┘
                               │ HTTP (multipart binary response)
┌──────────────────────────────▼──────────────────────────────────┐
│  FastAPI 后端  backend/routers/library.py                        │
│                                                                  │
│  export_book()  (新增路由)                                       │
│    ├─ 鉴权 + session 所有权校验                                  │
│    ├─ 批量查询 NodeLecture（按 node_ids）                        │
│    ├─ 过滤无讲义节点                                             │
│    └─ BookExporter (新建 backend/services/book_exporter.py)      │
│         ├─ PdfBookExporter  (reportlab)                          │
│         │    ├─ 中文字体加载（NotoSansSC / 系统 CJK 回退）       │
│         │    ├─ TOC 生成（含页码）                               │
│         │    └─ LaTeX → PNG 渲染（matplotlib，带缓存）           │
│         └─ DocxBookExporter (python-docx)                        │
│              ├─ 中文字体段落样式                                 │
│              ├─ TOC 书签超链接                                   │
│              └─ LaTeX → PNG 渲染（同上）                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 组件与接口

### 后端新增

#### 路由：`POST /api/library/sessions/{session_id}/export-book`

```python
class ExportBookIn(BaseModel):
    node_ids: list[str]          # 必填，非空
    format: Literal["pdf", "docx"]  # 必填
    include_toc: bool = True     # 可选，默认 True
```

响应：
- `200` — 二进制文件流，`Content-Disposition: attachment; filename="book_{session_id}.{ext}"`
- `404` — session 不存在或不属于当前用户
- `422` — `node_ids` 为空 / `format` 非法 / 所有节点均无讲义

#### `backend/services/book_exporter.py`

```python
class BookExporter:
    """抽象基类，定义 build() 接口。"""
    def build(
        self,
        session_title: str,
        nodes: list[NodeInfo],       # 有序，已过滤无讲义
        include_toc: bool,
    ) -> bytes: ...

class PdfBookExporter(BookExporter): ...
class DocxBookExporter(BookExporter): ...

@dataclass
class NodeInfo:
    node_id: str
    text: str          # 节点标题
    depth: int         # 1–4
    blocks: list[dict] # LectureBlock JSONB
```

#### LaTeX 渲染工具 `backend/services/latex_renderer.py`

```python
class LatexRenderer:
    """将 LaTeX 字符串渲染为 PNG bytes，带请求级缓存。"""
    def __init__(self): self._cache: dict[str, bytes] = {}
    def render(self, latex: str, display: bool = False) -> bytes | None: ...
```

- 使用 `matplotlib` + `mathtext` 渲染（无需完整 LaTeX 安装）
- 失败时返回 `None`，调用方回退为原始文本

### 前端新增

#### `lib/features/library/lecture/export_book_dialog.dart`

```dart
class ExportBookDialog extends ConsumerStatefulWidget {
  final int sessionId;
  final String sessionTitle;
  final List<TreeNode> nodes;
  final Set<String> hasLectureNodeIds;
}
```

内部状态：
- `_selected: Set<String>` — 已勾选节点 ID（初始全选）
- `_isExporting: bool`
- `_format: ExportFormat` (pdf / docx)

#### `lib/services/book_export_service.dart`

```dart
class BookExportService {
  Future<Uint8List> exportBook({
    required int sessionId,
    required List<String> nodeIds,
    required String format,
    bool includeToc = true,
  });
}
```

使用 `Dio` 发起请求，`responseType: ResponseType.bytes`，超时 120 秒。

---

## 数据模型

### 请求体（后端 Pydantic）

```python
class ExportBookIn(BaseModel):
    node_ids: list[str]
    format: Literal["pdf", "docx"]
    include_toc: bool = True

    @field_validator("node_ids")
    @classmethod
    def validate_node_ids(cls, v):
        if not v:
            raise ValueError("node_ids 不能为空")
        return v

    @field_validator("format")
    @classmethod
    def validate_format(cls, v):
        if v not in ("pdf", "docx"):
            raise ValueError("不支持的导出格式")
        return v
```

### 内部数据流

```
ExportBookIn.node_ids
  → 查询 node_lectures WHERE session_id=X AND node_id IN (...)
  → 按 node_ids 原始顺序排列（保留大纲顺序）
  → 过滤掉无记录的节点（静默跳过）
  → 若过滤后为空 → 422
  → 构造 List[NodeInfo] → BookExporter.build()
```

### LectureBlock 类型映射

| block.type | PDF 处理 | Word 处理 |
|------------|----------|-----------|
| `heading` | 加粗，H1=18pt / H2=15pt / H3=13pt | Heading 1/2/3 样式 |
| `paragraph` | 正文 11pt | Normal 样式，宋体 |
| `code` | 等宽字体，灰色背景框 | 等宽字体，浅灰底纹 |
| `list` | 项目符号 `•` | List Bullet 样式 |
| `quote` | 左侧 3pt 竖线，斜体 | 缩进段落 + 左边框 |

### TOC 条目结构

```python
@dataclass
class TocEntry:
    title: str
    depth: int   # 1–4，控制缩进
    page: int    # PDF 专用
    anchor: str  # Word 书签名，如 "node_L1_材料力学"
```

---

## 正确性属性

*属性（Property）是在系统所有合法执行中都应成立的特征或行为——本质上是对系统应做什么的形式化陈述。属性是人类可读规范与机器可验证正确性保证之间的桥梁。*

### 属性 1：节点顺序保留

*对于任意* 有序节点 ID 列表（其中所有节点均有讲义），`BookExporter.build()` 生成的文档中各章节的出现顺序应与输入列表的顺序完全一致。

**验证：需求 3.1**

### 属性 2：无讲义节点静默跳过

*对于任意* 包含部分无讲义节点的节点集合，`BookExporter.build()` 的输出中章节数量应恰好等于有讲义节点的数量，且输出内容中不包含任何无讲义节点的标题或正文。

**验证：需求 2.3**

### 属性 3：TOC 条目与正文章节一一对应

*对于任意* 有效导出请求，生成文档的 TOC 条目标题集合应与正文中实际出现的章节标题集合完全相同（无多余条目、无遗漏条目）。

**验证：需求 3.1、3.2**

### 属性 4：TOC 缩进与节点深度一致

*对于任意* depth 值为 1–4 的节点，其 TOC 条目的缩进量应等于 `(depth - 1) × 4` 个空格当量（depth=1 无缩进，depth=4 缩进 12 个空格当量）。

**验证：需求 3.5**

### 属性 5：LaTeX 渲染缓存幂等性

*对于任意* 包含重复 LaTeX 字符串的列表，`LatexRenderer` 在同一实例中对相同字符串的实际渲染调用次数应等于该列表中唯一字符串的数量（重复字符串命中缓存，不重复渲染）。

**验证：需求 6.4**

### 属性 6：非法请求体被拒绝且不触发生成

*对于任意* `node_ids` 为空数组的请求，以及 *对于任意* `format` 不为 `"pdf"` 或 `"docx"` 的请求，系统应返回 HTTP 422 状态码，且 `BookExporter.build()` 不被调用。

**验证：需求 7.3、7.4**

### 属性 7：Session 所有权校验

*对于任意* 不属于当前认证用户的 `session_id`，导出接口应返回 HTTP 404，且不查询任何讲义数据。

**验证：需求 7.5**

### 属性 8：Word 文档中文字体与标题样式

*对于任意* 包含 heading、paragraph、code、list、quote 各类型 block 的 Word 导出结果，所有段落的字体应为中文兼容字体（宋体或微软雅黑），且 heading block 的段落样式应与其 level 值对应（level=1 → Heading 1，level=2 → Heading 2，level=3 → Heading 3）。

**验证：需求 5.2、5.3、5.4**

### 属性 9：LaTeX 公式渲染为嵌入图片

*对于任意* text 字段中包含行内 LaTeX（`$...$`）或块级 LaTeX（`$$...$$`）的 LectureBlock，在渲染器可用的情况下，导出文档中对应位置应包含嵌入图片元素而非原始 LaTeX 文本。

**验证：需求 6.1、6.2**

### 属性 10：导出文件名格式

*对于任意* session 标题字符串和合法 format 值（`"pdf"` 或 `"docx"`），前端触发下载时传递给 `FileSaver` 的文件名应符合 `{session_title}_{format}.{ext}` 格式（ext 与 format 对应）。

**验证：需求 8.2**

---

## 错误处理

| 场景 | 处理方式 |
|------|----------|
| `node_ids` 为空 | 422，"node_ids 不能为空" |
| `format` 非法 | 422，"不支持的导出格式" |
| session 不存在 / 不属于当前用户 | 404，"大纲不存在" |
| 所有选中节点均无讲义 | 422，"所选节点均无讲义内容" |
| 中文字体文件不存在且无系统回退 | 500，"中文字体不可用，无法生成 PDF" |
| LaTeX 渲染失败（matplotlib 异常） | 降级：插入原始 LaTeX 文本 + "[公式渲染失败，原始代码如下]" 标注 |
| 后端生成超时（>120s） | 前端显示"导出超时，请减少选择的节点数量后重试" |
| 后端返回其他错误 | 前端 SnackBar 显示后端错误消息，重新启用导出按钮 |

### 中文字体查找顺序（PDF）

1. `backend/assets/fonts/NotoSansSC-Regular.ttf`（优先，项目内置）
2. `/usr/share/fonts/` 下递归搜索 `*.ttf` / `*.otf`，过滤文件名含 `CJK`、`Noto`、`WenQuanYi`、`Source Han` 的字体
3. 均不可用 → 500 错误

---

## 测试策略

### 单元测试（后端 pytest）

- `test_book_exporter.py`
  - 验证 `PdfBookExporter` 和 `DocxBookExporter` 对各 block 类型的渲染输出
  - 验证 TOC 条目数量与有讲义节点数量一致
  - 验证无讲义节点被正确过滤
  - 验证 `ExportBookIn` 校验器对空 `node_ids` 和非法 `format` 的拒绝行为
- `test_latex_renderer.py`
  - 验证相同公式字符串在同一 `LatexRenderer` 实例中只渲染一次（缓存命中）
  - 验证渲染失败时返回 `None`

### 属性测试（后端 Hypothesis，前端 dart_test + fast_check 等效）

每个属性测试最少运行 100 次迭代。

```python
# 标签格式：Feature: lecture-book-export, Property {N}: {描述}
```

- **属性 1**：生成随机有序节点列表（均有讲义），调用 `BookExporter.build()`，断言输出文档中章节顺序与输入一致。
  `# Feature: lecture-book-export, Property 1: 节点顺序保留`

- **属性 2**：生成随机节点集合，随机标记部分为"无讲义"，断言输出章节数 == 有讲义节点数，且无讲义节点标题不出现在输出中。
  `# Feature: lecture-book-export, Property 2: 无讲义节点静默跳过`

- **属性 3**：生成随机节点集合，断言 TOC 条目标题集合 == 正文章节标题集合（集合相等，无多余无遗漏）。
  `# Feature: lecture-book-export, Property 3: TOC 与正文一一对应`

- **属性 4**：生成随机 depth 1–4 的节点，断言 TOC 缩进量 == (depth - 1) × 4 空格当量。
  `# Feature: lecture-book-export, Property 4: TOC 缩进与深度一致`

- **属性 5**：生成随机 LaTeX 字符串列表（含重复），断言 `LatexRenderer.render()` 调用次数 == 去重后的唯一字符串数。
  `# Feature: lecture-book-export, Property 5: LaTeX 缓存幂等性`

- **属性 6**：生成随机非法请求体（空 node_ids 或随机非法 format 字符串），断言路由返回 422 且 `BookExporter.build()` 未被调用。
  `# Feature: lecture-book-export, Property 6: 非法请求体被拒绝且不触发生成`

- **属性 7**：生成随机 session_id（不属于当前用户），断言路由返回 404。
  `# Feature: lecture-book-export, Property 7: Session 所有权校验`

- **属性 8**：生成随机各类型 block 列表，调用 `DocxBookExporter.build()`，解析 docx XML，断言所有段落字体为中文兼容字体，heading block 的段落样式与 level 对应。
  `# Feature: lecture-book-export, Property 8: Word 中文字体与标题样式`

- **属性 9**：生成随机包含 LaTeX 的 block 列表（渲染器 mock 为可用），断言输出文档中对应位置包含图片元素。
  `# Feature: lecture-book-export, Property 9: LaTeX 公式渲染为嵌入图片`

- **属性 10**：生成随机 session 标题和合法 format 值，断言 `FileSaver` 接收到的文件名符合 `{title}_{format}.{ext}` 格式。
  `# Feature: lecture-book-export, Property 10: 导出文件名格式`

### 集成测试

- 端到端：使用真实 SQLite 测试数据库，调用 `POST /api/library/sessions/{id}/export-book`，验证响应头 `Content-Disposition` 和文件字节非空。
- 字体回退：mock 内置字体路径不存在，验证系统字体查找逻辑。

### 前端测试（Flutter）

- `ExportBookDialog` widget 测试：
  - 全选/全不选按钮行为
  - 父节点勾选联动子节点
  - 无节点勾选时导出按钮禁用
  - 有无讲义节点时警告文字显示
- `BookExportService` 单元测试（mock Dio）：验证请求参数构造正确。
