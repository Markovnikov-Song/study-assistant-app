# 需求文档：讲义导出为书（Lecture Book Export）

## 简介

本功能允许用户在讲义页面中勾选大纲节点，将多个节点的讲义内容合并为一份完整的"书"，
自动生成目录，并导出为 PDF 或 Word（.docx）格式。

核心解决三个现有痛点：
1. 现有 Flutter 端 PDF 导出中文全部乱码（未内嵌中文字体）
2. 导出只能针对单个节点，无法批量合并
3. 导出文件没有目录

导出逻辑全部在后端（FastAPI + Python）完成，前端仅负责节点选择 UI 和文件下载。

---

## 词汇表

- **Book_Exporter**：后端负责将多节点讲义合并并生成文件的服务模块
- **Export_Dialog**：前端节点选择与导出触发的对话框组件
- **Node**：大纲树中的一个知识点节点，对应 `node_lectures` 表中的一条记录
- **Lecture**：某个 Node 对应的讲义内容，以 JSONB blocks 格式存储
- **Book**：由多个 Lecture 按大纲顺序拼接而成的完整文档
- **TOC**：Table of Contents，目录，列出各章节标题及其页码（PDF）或书签（Word）
- **LectureBlock**：讲义内容的最小单元，类型包括 heading、paragraph、code、list、quote
- **Session**：一份大纲（`conversation_sessions` 表中的一条记录）
- **Chinese_Font**：内嵌于 PDF 的中文字体文件，用于解决中文乱码问题

---

## 需求

### 需求 1：节点多选

**用户故事：** 作为学生，我希望在导出前能够从大纲树中勾选任意节点，
以便只导出我关心的章节，而不是整份大纲。

#### 验收标准

1. WHEN 用户点击讲义页面的"导出为书"入口，THE Export_Dialog SHALL 以树形结构展示当前 Session 的所有大纲节点。
2. THE Export_Dialog SHALL 为每个节点显示一个复选框，初始状态为全部勾选。
3. WHEN 用户勾选或取消勾选一个父节点，THE Export_Dialog SHALL 同步勾选或取消勾选该节点的所有子节点。
4. THE Export_Dialog SHALL 在节点旁以绿点标识该节点已有讲义，以灰点标识尚无讲义。
5. THE Export_Dialog SHALL 提供"全选"和"全不选"快捷操作。
6. WHEN 用户未勾选任何节点，THE Export_Dialog SHALL 禁用导出按钮并显示提示文字"请至少选择一个节点"。

---

### 需求 2：无讲义节点处理

**用户故事：** 作为学生，我希望系统能明确告知哪些节点没有讲义，
以便我决定是否跳过它们或先生成讲义再导出。

#### 验收标准

1. THE Export_Dialog SHALL 统计并显示已勾选节点中无讲义节点的数量。
2. WHEN 已勾选节点中存在无讲义节点，THE Export_Dialog SHALL 显示警告："X 个节点暂无讲义，导出时将跳过"。
3. WHEN 用户确认导出，THE Book_Exporter SHALL 静默跳过无讲义节点，不中断导出流程。
4. IF 已勾选节点全部无讲义，THEN THE Book_Exporter SHALL 返回错误码 422，并附带消息"所选节点均无讲义内容"。

---

### 需求 3：目录生成

**用户故事：** 作为学生，我希望导出的书自动包含目录，
以便快速定位各章节内容。

#### 验收标准

1. THE Book_Exporter SHALL 根据已勾选且有讲义的节点，按大纲树的深度优先顺序生成 TOC。
2. THE Book_Exporter SHALL 将 TOC 插入在正文内容之前，作为文档第一页或第一节。
3. WHEN 导出格式为 PDF，THE Book_Exporter SHALL 在 TOC 中为每个条目标注对应页码。
4. WHEN 导出格式为 Word，THE Book_Exporter SHALL 使用 Word 内置书签（Bookmark）实现 TOC 条目的超链接跳转。
5. THE Book_Exporter SHALL 根据节点在大纲中的深度（depth 1–4）对 TOC 条目进行缩进，深度每增加 1 级缩进增加 4 个空格当量。

---

### 需求 4：PDF 导出（中文支持）

**用户故事：** 作为学生，我希望导出的 PDF 文件中文字符正常显示，
以便在任何设备上阅读而不出现乱码。

#### 验收标准

1. THE Book_Exporter SHALL 使用后端 `reportlab` 库生成 PDF，不依赖 Flutter 端 `pdf` 包。
2. THE Book_Exporter SHALL 在生成 PDF 时内嵌 Chinese_Font（如 NotoSansSC 或系统可用的 CJK 字体），确保所有中文字符正常渲染。
3. IF 指定的 Chinese_Font 文件不存在，THEN THE Book_Exporter SHALL 尝试回退到系统字体目录中的备选 CJK 字体；若均不可用，则返回错误码 500 并附带消息"中文字体不可用，无法生成 PDF"。
4. THE Book_Exporter SHALL 将 PDF 页面格式设置为 A4（210mm × 297mm），页边距为上下 20mm、左右 25mm。
5. THE Book_Exporter SHALL 对不同 LectureBlock 类型应用差异化排版：heading 使用加粗字体并按 level 设置字号（H1=18pt，H2=15pt，H3=13pt），code 使用等宽字体并添加灰色背景，quote 添加左侧竖线装饰，list 添加项目符号。
6. WHEN 导出完成，THE Book_Exporter SHALL 在 HTTP 响应头中设置 `Content-Disposition: attachment; filename="book_{session_id}.pdf"`。

---

### 需求 5：Word 导出（中文支持）

**用户故事：** 作为学生，我希望导出的 Word 文件中文字符正常显示且格式规范，
以便在 Word 中进一步编辑。

#### 验收标准

1. THE Book_Exporter SHALL 使用后端 `python-docx` 库生成 Word 文件。
2. THE Book_Exporter SHALL 为 Word 文件中的所有段落和标题指定中文兼容字体（如"宋体"或"微软雅黑"），确保中文字符正常显示。
3. THE Book_Exporter SHALL 将 heading 类型的 LectureBlock 映射为 Word 内置标题样式（Heading 1 / Heading 2 / Heading 3），以支持 Word 自动目录功能。
4. THE Book_Exporter SHALL 将 code 类型的 LectureBlock 映射为等宽字体段落，并添加浅灰色底纹。
5. THE Book_Exporter SHALL 在每个节点讲义内容之间插入分节符（Section Break），使各节在 Word 中独立分页。
6. WHEN 导出完成，THE Book_Exporter SHALL 在 HTTP 响应头中设置 `Content-Disposition: attachment; filename="book_{session_id}.docx"`。

---

### 需求 6：LaTeX 公式处理

**用户故事：** 作为理工科学生，我希望讲义中的数学公式在导出文件中能够正确呈现，
以便导出内容与在线阅读体验一致。

#### 验收标准

1. WHEN LectureBlock 的 text 字段包含行内 LaTeX 公式（`$...$` 格式），THE Book_Exporter SHALL 将其渲染为图片并嵌入 PDF 或 Word 文件中。
2. WHEN LectureBlock 的 text 字段包含块级 LaTeX 公式（`$$...$$` 格式），THE Book_Exporter SHALL 将其渲染为独立居中图片并嵌入文件中。
3. IF LaTeX 公式渲染失败（如 `matplotlib` 或 `sympy` 不可用），THEN THE Book_Exporter SHALL 以原始 LaTeX 源码文本替代图片，并在该段落前附加标注"[公式渲染失败，原始代码如下]"。
4. THE Book_Exporter SHALL 对 LaTeX 渲染结果进行缓存，相同公式字符串在同一次导出请求中只渲染一次。

---

### 需求 7：批量导出 API

**用户故事：** 作为前端开发者，我希望后端提供统一的批量导出接口，
以便前端通过一次请求完成多节点合并导出。

#### 验收标准

1. THE Book_Exporter SHALL 提供 HTTP POST 接口 `POST /api/library/sessions/{session_id}/export-book`，接受 JSON 请求体。
2. THE Book_Exporter SHALL 接受请求体字段：`node_ids`（字符串数组，必填）、`format`（枚举 `"pdf"` 或 `"docx"`，必填）、`include_toc`（布尔值，可选，默认 `true`）。
3. IF `node_ids` 为空数组，THEN THE Book_Exporter SHALL 返回错误码 422 并附带消息"node_ids 不能为空"。
4. IF `format` 不是 `"pdf"` 或 `"docx"`，THEN THE Book_Exporter SHALL 返回错误码 422 并附带消息"不支持的导出格式"。
5. THE Book_Exporter SHALL 验证请求用户对该 Session 的所有权；IF 验证失败，THEN THE Book_Exporter SHALL 返回错误码 404。
6. WHEN 导出文件生成成功，THE Book_Exporter SHALL 以二进制流形式返回文件内容，HTTP 状态码为 200。

---

### 需求 8：前端下载与进度反馈

**用户故事：** 作为学生，我希望点击导出后能看到进度提示，并在完成后自动下载文件，
以便了解导出状态而不是面对空白等待。

#### 验收标准

1. WHEN 用户点击"导出"按钮，THE Export_Dialog SHALL 显示加载指示器并禁用导出按钮，防止重复提交。
2. WHEN 后端返回文件流，THE Export_Dialog SHALL 调用 `FileSaver` 触发文件下载，文件名格式为 `{session_title}_{format}.{ext}`。
3. WHEN 导出成功，THE Export_Dialog SHALL 关闭对话框并显示 SnackBar 提示"导出成功"。
4. IF 后端返回错误，THEN THE Export_Dialog SHALL 显示错误 SnackBar，内容包含后端返回的错误消息，并重新启用导出按钮。
5. THE Export_Dialog SHALL 设置请求超时为 120 秒；IF 超时，THEN THE Export_Dialog SHALL 显示提示"导出超时，请减少选择的节点数量后重试"。

---

### 需求 9：导出入口集成

**用户故事：** 作为学生，我希望"导出为书"的入口与现有导出菜单自然融合，
以便不打断现有操作习惯。

#### 验收标准

1. THE Export_Dialog SHALL 在讲义页面（`LecturePage`）现有导出底部菜单中新增"导出为书 (.pdf/.docx)"选项。
2. WHILE 当前节点讲义正在加载，THE Export_Dialog SHALL 禁用"导出为书"入口。
3. THE Export_Dialog SHALL 作为独立的全屏或大尺寸底部弹窗展示，与现有单节点导出菜单区分。
