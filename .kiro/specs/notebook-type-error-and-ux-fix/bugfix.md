# Bugfix Requirements Document

## Introduction

本文档合并处理笔记本模块的两个 Bug：

**Bug 1 — 类型崩溃**：`notebook_service.dart` 的 `getNotebookNotes` 方法以及 `notebook.dart` 的
`Note.fromJson` / `Notebook.fromJson` 中，所有数值字段均使用 `(json['x'] as num).toInt()` 硬转型。
当后端返回的 `subject_id`、`id` 等字段为字符串时，`as num` 直接抛出
`type 'String' is not a subtype of type 'num'`，导致笔记本详情页完全无法加载。
该模式与已修复的 `calendar-tab-type-error` 完全相同。

**Bug 2 — 新建笔记 UX**：点击笔记本详情页右下角 FAB 时，系统弹出 `_NewNoteSheet` 底部弹窗，
将标题输入、学科选择、类型选择、Quill 富文本编辑器全部塞入一个高度受限的弹窗，体验极差。
正确做法是 push 一个全屏页面（复用或参考 `NoteDetailPage` 的全屏编辑布局）。

---

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN `Note.fromJson` 解析后端返回的笔记 JSON，且 `id`、`notebook_id` 等字段的运行时类型为
`String` 时，系统抛出 `type 'String' is not a subtype of type 'num'` 并崩溃，笔记列表无法渲染。

1.2 WHEN `Note.fromJson` 解析 `subject_id`、`source_session_id`、`source_message_id`、
`imported_to_doc_id` 等可空数值字段，且字段值为字符串时，系统抛出
`type 'String' is not a subtype of type 'num'` 并崩溃。

1.3 WHEN `Notebook.fromJson` 解析 `id` 或 `sort_order` 字段，且字段值为字符串时，系统抛出
`type 'String' is not a subtype of type 'num'` 并崩溃，笔记本列表无法渲染。

1.4 WHEN `getNotebookNotes` 解析分组响应中的 `subject_id` 键，且该值为字符串时，系统抛出
`type 'String' is not a subtype of type 'num'`，导致笔记分组数据无法加载。

1.5 WHEN 用户点击笔记本详情页右下角 FAB 新建笔记时，系统弹出 `_NewNoteSheet` 底部弹窗，
将 Quill 富文本编辑器限制在约 160px 高度内，用户无法正常输入和编辑笔记内容。

### Expected Behavior (Correct)

2.1 WHEN `Note.fromJson` 解析 `id`、`notebook_id` 等必填数值字段，且字段值为字符串时，系统
SHALL 使用安全解析工具函数（如 `_toInt`）将其转换为整数，而不抛出类型异常。

2.2 WHEN `Note.fromJson` 解析 `subject_id`、`source_session_id`、`source_message_id`、
`imported_to_doc_id` 等可空数值字段，且字段值为字符串时，系统 SHALL 使用安全解析工具函数将其
转换为整数或返回 `null`，而不抛出类型异常。

2.3 WHEN `Notebook.fromJson` 解析 `id` 或 `sort_order` 字段，且字段值为字符串时，系统 SHALL
使用安全解析工具函数将其转换为整数，而不抛出类型异常。

2.4 WHEN `getNotebookNotes` 解析分组响应中的 `subject_id` 键，且该值为字符串时，系统 SHALL
使用安全解析工具函数将其转换为整数，正确构建分组 Map，而不抛出类型异常。

2.5 WHEN 用户点击笔记本详情页右下角 FAB 新建笔记时，系统 SHALL push 一个全屏页面（包含学科选择、
标题输入、Quill 富文本编辑器），提供与 `NoteDetailPage` 一致的全屏编辑体验。

### Unchanged Behavior (Regression Prevention)

3.1 WHEN 后端返回格式正确的 JSON（所有数值字段均为 `int` 或 `double`）时，系统 SHALL CONTINUE TO
正确解析 `Note` 和 `Notebook` 对象，笔记列表和笔记本列表正常显示。

3.2 WHEN `getNotebookNotes` 接收到格式正确的分组响应时，系统 SHALL CONTINUE TO 按 `subject_id`
正确分组笔记，Tab 栏各分区数据准确。

3.3 WHEN 用户在笔记本详情页点击已有笔记卡片时，系统 SHALL CONTINUE TO push `NoteDetailPage`
全屏编辑页，编辑和保存功能不受影响。

3.4 WHEN 用户在新建笔记全屏页填写内容并保存时，系统 SHALL CONTINUE TO 调用创建接口，成功后刷新
笔记列表，与原底部弹窗的数据写入逻辑保持一致。

3.5 WHEN `NoteDetailPage` 的 AI 润色、AI 生成标题、导入资料库、删除等功能被调用时，系统 SHALL
CONTINUE TO 正常执行，不受本次改动影响。

---

## Bug Condition Pseudocode

### Bug 1 — 类型崩溃

```pascal
FUNCTION isBugCondition_TypeCrash(X)
  INPUT: X of type JSON field value (dynamic)
  OUTPUT: boolean

  RETURN X is String AND expected type is num/int
END FUNCTION

// Property: Fix Checking
FOR ALL X WHERE isBugCondition_TypeCrash(X) DO
  result ← Note.fromJson'(X) OR Notebook.fromJson'(X) OR getNotebookNotes'(X)
  ASSERT no_crash(result) AND result is valid parsed integer
END FOR

// Property: Preservation Checking
FOR ALL X WHERE NOT isBugCondition_TypeCrash(X) DO
  ASSERT Note.fromJson(X) = Note.fromJson'(X)
  ASSERT Notebook.fromJson(X) = Notebook.fromJson'(X)
END FOR
```

### Bug 2 — 新建笔记 UX

```pascal
FUNCTION isBugCondition_NewNoteUX(action)
  INPUT: action of type UserAction
  OUTPUT: boolean

  RETURN action = FAB_TAP AND current_page = NotebookDetailPage
END FUNCTION

// Property: Fix Checking
FOR ALL action WHERE isBugCondition_NewNoteUX(action) DO
  result ← handleFabTap'(action)
  ASSERT result = FULLSCREEN_PAGE_PUSHED AND NOT BOTTOM_SHEET_SHOWN
END FOR

// Property: Preservation Checking
FOR ALL action WHERE NOT isBugCondition_NewNoteUX(action) DO
  ASSERT handleNavigation(action) = handleNavigation'(action)
END FOR
```
