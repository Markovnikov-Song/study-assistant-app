# 设计文档：笔记本功能

## 概述

笔记本功能为学科学习助手 App 提供"对话 → 笔记 → 资料库 → 更好的 RAG"的学习闭环。用户可在聊天页长按消息进入多选模式，将选中消息收藏到指定笔记本的学科栏中，每条笔记支持 AI 生成标题提纲或手动编辑，并可一键导入对应学科的 RAG 资料库。

本设计基于现有 Flutter + Riverpod 架构，遵循 UI 重设计规范（底部 5-Tab 导航，`currentSubjectProvider` 全局学科状态），笔记本入口挂载在 `/profile` 路由下。

---

## 架构

### 整体分层

```
┌─────────────────────────────────────────────────────┐
│                    UI Layer                         │
│  NotebookListPage / NotebookDetailPage / NoteDetail │
│  ChatPage（多选模式扩展）                            │
│  NotebookPickerSheet（底部弹出面板）                 │
└──────────────────────┬──────────────────────────────┘
                       │ Riverpod Providers
┌──────────────────────▼──────────────────────────────┐
│                  Provider Layer                     │
│  notebookListProvider / notebookDetailProvider      │
│  noteDetailProvider / multiSelectProvider           │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│                  Service Layer                      │
│  NotebookService / NoteService                      │
└──────────────────────┬──────────────────────────────┘
                       │ HTTP (Dio)
┌──────────────────────▼──────────────────────────────┐
│                  Backend API                        │
│  FastAPI  /api/notebooks  /api/notes                │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│                  Database Layer                     │
│  PostgreSQL: notebooks / notes tables               │
└─────────────────────────────────────────────────────┘
```

### 与现有架构的集成点

- **聊天页**：在 `_Bubble` 的 `onLongPress` 基础上扩展多选模式状态机
- **路由**：在 `/profile` 下新增 `notebooks`、`notebooks/:id`、`notebooks/:id/notes/:noteId` 三级路由
- **全局学科**：笔记本详情页的学科分栏直接读取 `subjectsProvider`，无需额外状态
- **RAG 导入**：复用现有 `DocumentService` 的上传/创建接口

---

## 组件与接口

### Flutter 文件结构

```
lib/features/notebook/
  notebook_list_page.dart       # 笔记本列表页
  notebook_detail_page.dart     # 笔记本详情页（学科分栏）
  note_detail_page.dart         # 笔记详情/编辑页
  widgets/
    notebook_picker_sheet.dart  # 收藏时弹出的笔记本选择面板
    notebook_card.dart          # 笔记本列表卡片
    note_card.dart              # 笔记卡片
    subject_section.dart        # 学科分栏组件

lib/models/
  notebook.dart                 # Notebook / Note 数据模型

lib/services/
  notebook_service.dart         # API 调用封装

lib/providers/
  notebook_provider.dart        # 所有笔记本相关 Provider

# 聊天页扩展（在现有文件中修改）
lib/features/chat/chat_page.dart          # 新增多选模式
lib/providers/multi_select_provider.dart  # 多选状态
```

### 路由扩展

在 `app_router.dart` 的 `/profile` 路由下新增：

```dart
// AppRoutes 新增常量
static const notebooks        = '/profile/notebooks';
static String notebookDetail(int id) => '/profile/notebooks/$id';
static String noteDetail(int nbId, int noteId) => '/profile/notebooks/$nbId/notes/$noteId';

// GoRoute 配置
GoRoute(
  path: 'notebooks',
  builder: (_, __) => const NotebookListPage(),
  routes: [
    GoRoute(
      path: ':nbId',
      builder: (_, state) => NotebookDetailPage(
        notebookId: int.parse(state.pathParameters['nbId']!),
      ),
      routes: [
        GoRoute(
          path: 'notes/:noteId',
          builder: (_, state) => NoteDetailPage(
            notebookId: int.parse(state.pathParameters['nbId']!),
            noteId: int.parse(state.pathParameters['noteId']!),
          ),
        ),
      ],
    ),
  ],
),
```

### API 接口

后端新增以下 REST 端点（FastAPI）：

```
# 笔记本管理
GET    /api/notebooks                    # 获取当前用户笔记本列表
POST   /api/notebooks                    # 创建用户自定义本
PATCH  /api/notebooks/{id}              # 更新笔记本（名称/置顶/归档/排序）
DELETE /api/notebooks/{id}              # 删除用户自定义本（级联删除笔记）

# 笔记管理
GET    /api/notebooks/{id}/notes        # 获取笔记本内笔记（按 subject_id 分组）
POST   /api/notes                       # 批量创建笔记（收藏消息）
GET    /api/notes/{noteId}              # 获取单条笔记详情
PATCH  /api/notes/{noteId}              # 更新笔记（标题/正文）
DELETE /api/notes/{noteId}              # 删除单条笔记

# AI 功能
POST   /api/notes/{noteId}/generate-title   # AI 生成标题提纲
POST   /api/notes/{noteId}/import-to-rag    # 导入资料库
```

### `ApiConstants` 新增常量

```dart
static const String notebooks = '/api/notebooks';
static const String notes     = '/api/notes';
```

---

## 数据模型

### Flutter 模型（`lib/models/notebook.dart`）

```dart
class Notebook {
  final int id;
  final String name;
  final bool isSystem;
  final bool isPinned;
  final bool isArchived;
  final int sortOrder;
  final DateTime createdAt;
}

class Note {
  final int id;
  final int notebookId;
  final int? subjectId;          // null 表示通用栏
  final int? sourceSessionId;
  final int? sourceMessageId;
  final String role;             // 'user' | 'assistant'
  final String originalContent;
  final String? title;
  final List<String>? outline;   // JSONB 存储的提纲要点
  final int? importedToDocId;    // 已导入的 Document ID
  final List<MessageSource>? sources;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 显示标题：有 title 用 title，否则截取前 20 字符
  String get displayTitle =>
      (title != null && title!.isNotEmpty)
          ? title!
          : originalContent.length > 20
              ? originalContent.substring(0, 20)
              : originalContent;

  bool get hasTitleSet => title != null && title!.isNotEmpty;
  bool get isImported => importedToDocId != null;
}
```

### PostgreSQL Schema

```sql
-- 笔记本表
CREATE TABLE notebooks (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name        VARCHAR(64) NOT NULL,
    is_system   BOOLEAN NOT NULL DEFAULT FALSE,
    is_pinned   BOOLEAN NOT NULL DEFAULT FALSE,
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order  INTEGER NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notebooks_user_id ON notebooks(user_id);

-- 笔记表
CREATE TABLE notes (
    id                  SERIAL PRIMARY KEY,
    notebook_id         INTEGER NOT NULL REFERENCES notebooks(id) ON DELETE CASCADE,
    subject_id          INTEGER REFERENCES subjects(id) ON DELETE SET NULL,
    source_session_id   INTEGER REFERENCES conversation_sessions(id) ON DELETE SET NULL,
    source_message_id   INTEGER,
    role                VARCHAR(16) NOT NULL CHECK (role IN ('user', 'assistant')),
    original_content    TEXT NOT NULL,
    title               VARCHAR(64),
    outline             JSONB,
    imported_to_doc_id  INTEGER REFERENCES documents(id) ON DELETE SET NULL,
    sources             JSONB,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notes_notebook_subject ON notes(notebook_id, subject_id);
```

### 排序规则（后端查询）

```sql
SELECT * FROM notebooks
WHERE user_id = :user_id AND is_archived = FALSE
ORDER BY
    is_system DESC,          -- 系统本优先
    is_pinned DESC,          -- 置顶优先
    sort_order ASC,          -- sort_order 升序
    created_at DESC;         -- 最后按创建时间降序
```

### 系统预设本初始化

用户首次注册时，后端触发初始化逻辑，插入四条系统预设本：

```python
SYSTEM_NOTEBOOKS = ["好题本", "错题本", "笔记", "通用"]

def init_user_notebooks(user_id: int, db: Session):
    for i, name in enumerate(SYSTEM_NOTEBOOKS):
        db.add(Notebook(
            user_id=user_id,
            name=name,
            is_system=True,
            sort_order=i,
        ))
    db.commit()
```

---

## UI 组件设计

### 笔记本列表页（NotebookListPage）

```
┌─────────────────────────────────────────┐
│  ← 笔记本                    [+ 新建]   │
├─────────────────────────────────────────┤
│  📌 好题本                    >         │
│  📌 错题本                    >         │
│  📌 笔记                      >         │
│  📌 通用                      >         │
├─────────────────────────────────────────┤
│  我的笔记本                             │
│  ┌─────────────────────────────────┐   │
│  │ 📓 高数复习                  ⋯  │   │
│  └─────────────────────────────────┘   │
│  ▼ 已归档（1）                          │
└─────────────────────────────────────────┘
```

- 系统预设本固定在顶部，不可拖拽排序
- 用户自定义本支持长按拖拽排序（`ReorderableListView`）
- 每个自定义本右侧"⋯"菜单：置顶/取消置顶、归档/取消归档、删除
- 已归档笔记本折叠在底部，点击展开

### 笔记本详情页（NotebookDetailPage）

```
┌─────────────────────────────────────────┐
│  ← 好题本                               │
├─────────────────────────────────────────┤
│  [通用] [材料力学] [高等数学] [英语]    │  ← 学科 Tab 栏
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────┐   │
│  │ 📝 弯曲正应力公式推导           │   │
│  │ 2025-01-15  assistant           │   │
│  └─────────────────────────────────┘   │
│  ┌─────────────────────────────────┐   │
│  │ 📝 （无标题）截面惯性矩的计算…  │   │  ← 灰色显示标题
│  │ 2025-01-14  user                │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

- 顶部 `TabBar` 展示"通用"栏 + 所有未归档学科
- 每个 Tab 内容为该学科栏的笔记列表，按 `created_at` 降序
- 无标题笔记以灰色斜体显示前 20 字符

### 笔记详情页（NoteDetailPage）

```
┌─────────────────────────────────────────┐
│  ← 笔记详情              [编辑] [⋯]    │
├─────────────────────────────────────────┤
│  标题：弯曲正应力公式推导               │
│  ─────────────────────────────────────  │
│  提纲：                                 │
│  • 中性轴概念                           │
│  • σ = M·y / I 推导过程                │
│  • 适用条件                             │
│  ─────────────────────────────────────  │
│  原始内容：                             │
│  [MarkdownLatexView 渲染]               │
│  ─────────────────────────────────────  │
│  参考来源：[展开]                       │
├─────────────────────────────────────────┤
│  [✨ AI 生成标题提纲]  [📚 导入资料库]  │
└─────────────────────────────────────────┘
```

- 已导入时"导入资料库"按钮变为"✅ 已导入（查看）"
- 点击"查看"跳转到 `/profile/resources/:subjectId`

### 多选模式（ChatPage 扩展）

```
┌─────────────────────────────────────────┐
│  ✕ 已选中 3 条消息                      │  ← 替换 AppBar
├─────────────────────────────────────────┤
│                                         │
│  [消息气泡，选中的显示蓝色边框+勾选图标] │
│                                         │
├─────────────────────────────────────────┤
│  [取消]          [收藏到笔记本 (3)]     │  ← 底部操作栏
└─────────────────────────────────────────┘
```

### 笔记本选择面板（NotebookPickerSheet）

```
┌─────────────────────────────────────────┐
│  选择笔记本                             │
├─────────────────────────────────────────┤
│  ○ 好题本                               │
│  ○ 错题本                               │
│  ● 笔记  ──────────────────────────    │  ← 选中
│    学科：[通用 ▾]                       │  ← 选中笔记本后展示学科选择
│  ○ 通用                                 │
│  ○ 高数复习                             │
├─────────────────────────────────────────┤
│              [确认收藏]                 │
└─────────────────────────────────────────┘
```

---

## Riverpod Provider 设计

```dart
// 笔记本列表（当前用户）
final notebookListProvider = AsyncNotifierProvider<NotebookListNotifier, List<Notebook>>();

// 笔记本详情（含笔记，按 subject_id 分组）
// key: notebookId
final notebookNotesProvider = AsyncNotifierProviderFamily<NotebookNotesNotifier, Map<int?, List<Note>>, int>();

// 单条笔记详情
// key: noteId
final noteDetailProvider = AsyncNotifierProviderFamily<NoteDetailNotifier, Note, int>();

// 多选模式状态
final multiSelectProvider = StateNotifierProvider<MultiSelectNotifier, MultiSelectState>();

@immutable
class MultiSelectState {
  final bool isActive;
  final Set<int> selectedMessageIds;  // ChatMessage.id
}
```

---

## 正确性属性

*属性（Property）是在系统所有有效执行中都应成立的特征或行为——本质上是对系统应该做什么的形式化陈述。属性是人类可读规范与机器可验证正确性保证之间的桥梁。*

### 属性 1：系统预设本初始化完整性

*对任意* 新注册用户，首次登录后查询笔记本列表，返回结果中必须包含名称分别为"好题本"、"错题本"、"笔记"、"通用"的四个笔记本，且这四个笔记本的 `is_system` 均为 `true`。

**验证需求：1.1, 1.2**

---

### 属性 2：系统预设本不可删除

*对任意* `is_system = true` 的笔记本，执行删除操作后，该笔记本仍然存在于数据库中，且 API 返回错误响应。

**验证需求：1.3**

---

### 属性 3：笔记本列表排序不变量

*对任意* 包含系统预设本和用户自定义本的笔记本集合，查询返回的列表中，所有 `is_system = true` 的笔记本的索引均小于所有 `is_system = false` 的笔记本的索引；在同一分组内，`is_pinned = true` 的笔记本索引均小于 `is_pinned = false` 的笔记本索引；在同一置顶状态内，按 `sort_order` 升序排列。

**验证需求：1.4, 2.3, 2.7**

---

### 属性 4：笔记本名称校验

*对任意* 长度为 0 或大于 64 的字符串作为笔记本名称，创建操作应返回校验错误，且数据库中不新增笔记本记录；*对任意* 长度在 1 到 64 之间的字符串，创建操作应成功，且新笔记本的 `is_system = false`。

**验证需求：2.1, 2.2**

---

### 属性 5：归档后主列表不可见

*对任意* 笔记本，执行归档操作后，查询主列表（`is_archived = false`）不包含该笔记本；执行取消归档后，主列表重新包含该笔记本。

**验证需求：2.4**

---

### 属性 6：删除自定义本级联删除笔记

*对任意* 包含 N 条笔记的用户自定义本，删除该笔记本后，这 N 条笔记均不再存在于数据库中。

**验证需求：2.6**

---

### 属性 7：学科栏完整性

*对任意* 用户的未归档学科集合（大小为 K），打开任意笔记本后，学科栏列表包含 K + 1 个栏（K 个学科栏 + 1 个"通用"栏），且"通用"栏的索引为 0。

**验证需求：3.1, 3.2**

---

### 属性 8：新增学科传播到所有笔记本

*对任意* 拥有 M 个笔记本的用户，新增一个学科后，每个笔记本的学科栏列表均包含该新学科对应的栏。

**验证需求：3.3**

---

### 属性 9：多选模式切换不变量

*对任意* 消息列表，在多选模式下，对同一条消息连续点击两次，其选中状态应恢复到点击前的状态（切换幂等性）；已选中消息数量始终等于 `selectedMessageIds` 集合的大小。

**验证需求：4.3**

---

### 属性 10：批量收藏创建独立笔记

*对任意* N 条选中消息（N ≥ 1），确认收藏到指定笔记本和学科栏后，数据库中新增恰好 N 条笔记记录，每条笔记的 `original_content` 与对应消息的 `content` 一致，`sources` 字段与原消息的 `sources` 一致。

**验证需求：5.1, 5.2**

---

### 属性 11：同一消息可收藏到多个笔记本

*对任意* 消息，将其收藏到 K 个不同笔记本后，数据库中存在 K 条 `source_message_id` 相同的笔记记录，分属不同笔记本。

**验证需求：5.5**

---

### 属性 12：笔记内容编辑 Round-Trip

*对任意* 有效标题（长度 ≤ 64）和正文内容，对笔记执行编辑保存后，再次读取该笔记，返回的 `title` 和 `original_content` 与保存时的值完全一致。

**验证需求：6.2, 6.3**

---

### 属性 13：无标题笔记显示标题截取

*对任意* `title` 为 null 或空字符串的笔记，其 `displayTitle` 等于 `originalContent` 的前 `min(20, originalContent.length)` 个字符。

**验证需求：6.5**

---

### 属性 14：导入资料库更新 imported_to_doc_id

*对任意* 笔记，导入资料库成功后，该笔记的 `imported_to_doc_id` 不为 null，且等于新创建的 Document 的 ID；再次导入后，`imported_to_doc_id` 更新为新 Document 的 ID，旧 Document 不再存在。

**验证需求：7.2, 7.5**

---

### 属性 15：用户删除级联清理

*对任意* 拥有 M 个笔记本和 N 条笔记的用户，删除该用户账号后，数据库中不存在任何 `user_id` 等于该用户 ID 的笔记本记录，也不存在任何属于这些笔记本的笔记记录。

**验证需求：9.5**

---

## 错误处理

| 场景 | 处理方式 |
|------|----------|
| 删除系统预设本 | 后端返回 `403 Forbidden`，前端 Toast 提示"系统预设本不可删除" |
| 笔记本名称为空或超长 | 后端返回 `422 Unprocessable Entity`，前端表单内联错误提示 |
| 收藏时未选中任何消息 | 前端拦截，Toast 提示"请至少选择一条消息" |
| 收藏网络错误 | 保持多选模式，Toast 提示"收藏失败，请重试" |
| AI 生成标题失败 | Toast 提示"AI 生成失败，请手动填写或稍后重试"，不清空已有标题 |
| 导入资料库时笔记内容为空 | 前端拦截，提示"笔记内容为空，无法导入" |
| 导入资料库失败 | 后端回滚 Document 记录，前端 Toast 提示"导入失败，请重试" |
| 网络请求超时 | 统一由 `DioClient` 拦截器处理，显示通用错误提示 |

---

## 测试策略

### 单元测试（example-based）

针对具体场景和边界条件：

- `Notebook.displayTitle`：无标题时截取前 20 字符，有标题时返回标题
- `MultiSelectNotifier`：长按进入多选、点击切换选中、取消清空状态
- `NotebookListNotifier`：排序规则（系统本 > 置顶 > sort_order > created_at）
- 笔记本名称校验：空字符串、65 字符、1 字符、64 字符边界
- `NotebookPickerSheet` 渲染：验证展示所有未归档笔记本
- `ProfilePage` 渲染：验证包含"笔记本"入口

### 属性测试（property-based）

使用 `dart_test` + `fast_check`（或等效的 Dart PBT 库）实现，每个属性测试运行 ≥ 100 次迭代。

每个测试用注释标注对应属性：
```dart
// Feature: notebook, Property 3: 笔记本列表排序不变量
test('notebook list ordering invariant', () { ... });
```

需要实现属性测试的属性：

| 属性编号 | 测试重点 | 生成器 |
|----------|----------|--------|
| 属性 1 | 系统预设本初始化 | 随机用户 ID |
| 属性 2 | 系统本不可删除 | 随机系统本 ID |
| 属性 3 | 列表排序不变量 | 随机笔记本集合（含系统/置顶/sort_order 组合） |
| 属性 4 | 名称校验 | 随机字符串（空/超长/有效） |
| 属性 5 | 归档可见性 | 随机笔记本 |
| 属性 6 | 级联删除 | 随机笔记本 + 随机 N 条笔记 |
| 属性 7 | 学科栏完整性 | 随机学科集合（K 个未归档） |
| 属性 9 | 多选切换幂等 | 随机消息列表 + 随机点击序列 |
| 属性 10 | 批量收藏 | 随机 N 条消息 |
| 属性 12 | 编辑 Round-Trip | 随机标题和正文内容 |
| 属性 13 | 无标题截取 | 随机长度的 originalContent |
| 属性 14 | 导入更新字段 | 随机笔记 |
| 属性 15 | 用户删除级联 | 随机用户 + 随机笔记本/笔记数量 |

### 集成测试

- AI 生成标题提纲（属性 6.1）：对 2 个示例笔记内容，验证标题 ≤ 30 字，提纲 ≤ 5 条
- RAG 导入流程（属性 7.1）：对 1-2 个示例笔记，验证 Document 记录创建，状态为 pending/processing

### Smoke 测试

- `notebooks` 表存在且包含所有必要字段（需求 9.1）
- `notes` 表存在且包含所有必要字段（需求 9.2）
- `notebooks.user_id` 索引存在（需求 9.3）
- `notes(notebook_id, subject_id)` 复合索引存在（需求 9.4）
