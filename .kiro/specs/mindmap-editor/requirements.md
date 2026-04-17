# 需求文档：思维导图编辑器（Mindmap Editor）

## 简介

本功能在现有思维导图页（`MindMapPage`，路由 `/mindmap`）的基础上，新增手动树形编辑能力、
与 AI 自动生成的协调机制、主流格式文件导入，以及拍照 OCR 识别目录结构四大能力。

现有功能：AI 自动生成 Markdown 文本，在 WebView 中渲染。
新增功能核心目标：
1. 用户可逐节点手动构建/编辑/删除/移动思维导图树
2. 手动编辑与 AI 生成可互相转化、协调工作
3. 支持导入 XMind / FreeMind 等主流格式
4. 支持拍照 → OCR → 自动识别目录结构并转为可编辑节点树

---

## 词汇表

- **MindMap_Editor**：前端思维导图编辑器组件，负责节点树的渲染与交互
- **Node**：思维导图中的一个节点，包含文本内容、唯一 ID、父节点引用、子节点列表、深度信息
- **Root_Node**：思维导图的根节点，深度为 0，无父节点
- **Node_Tree**：由 Root_Node 及其所有后代 Node 构成的有序树形结构
- **AI_Generator**：现有 AI 自动生成思维导图的后端服务
- **Mindmap_Service**：前端负责与后端通信的服务层
- **Import_Parser**：后端负责解析 XMind / FreeMind 等格式文件并转换为 Node_Tree 的模块
- **OCR_Service**：后端负责对图片进行文字识别并提取目录层级结构的服务
- **Edit_History**：记录用户编辑操作的撤销/重做栈
- **Subject**：学科，通过 Riverpod `currentSubjectProvider` 全局共享的当前学科上下文

---

## 需求

### 需求 1：节点手动添加

**用户故事：** 作为学生，我希望能在思维导图中手动添加子节点或兄弟节点，
以便逐步构建符合我理解的知识结构。

#### 验收标准

1. WHEN 用户长按或点击某个 Node 的添加按钮，THE MindMap_Editor SHALL 在该 Node 下创建一个新的空白子节点，并立即进入文本编辑状态。
2. WHEN 用户在某个 Node 上触发"添加兄弟节点"操作，THE MindMap_Editor SHALL 在该 Node 的同级位置（其后）插入一个新的空白节点，并立即进入文本编辑状态。
3. WHEN 用户完成文本输入并确认（点击完成或失去焦点），THE MindMap_Editor SHALL 将新节点持久化到本地状态，并更新渲染。
4. IF 用户在文本为空时确认，THEN THE MindMap_Editor SHALL 删除该空白节点，不保留空节点。
5. THE MindMap_Editor SHALL 支持在任意深度（最多 6 级）添加子节点；IF 当前节点深度已达 6 级，THEN THE MindMap_Editor SHALL 禁用"添加子节点"操作并显示提示"已达最大层级深度"。

---

### 需求 2：节点编辑

**用户故事：** 作为学生，我希望能修改已有节点的文本内容，
以便纠正错误或更新知识点描述。

#### 验收标准

1. WHEN 用户双击某个 Node，THE MindMap_Editor SHALL 将该节点切换为文本编辑状态，显示可编辑的文本输入框，并预填当前节点文本。
2. WHEN 用户完成编辑并确认，THE MindMap_Editor SHALL 更新该节点的文本内容并退出编辑状态。
3. WHEN 用户按下取消（如 Escape 键或点击取消按钮），THE MindMap_Editor SHALL 丢弃本次编辑，恢复节点原始文本。
4. THE MindMap_Editor SHALL 限制节点文本长度不超过 200 个字符；IF 用户输入超过 200 个字符，THEN THE MindMap_Editor SHALL 截断输入并显示提示"节点文本最多 200 个字符"。

---

### 需求 3：节点删除

**用户故事：** 作为学生，我希望能删除不需要的节点，
以便保持思维导图的简洁和准确。

#### 验收标准

1. WHEN 用户选中某个非 Root_Node 并触发删除操作，THE MindMap_Editor SHALL 显示确认对话框，提示"删除该节点将同时删除其所有子节点，确认删除？"。
2. WHEN 用户确认删除，THE MindMap_Editor SHALL 从 Node_Tree 中移除该节点及其所有后代节点，并更新渲染。
3. IF 用户尝试删除 Root_Node，THEN THE MindMap_Editor SHALL 禁用删除操作，不显示删除入口。
4. WHEN 节点被删除，THE MindMap_Editor SHALL 将该操作记录到 Edit_History，以支持撤销。

---

### 需求 4：节点移动（拖拽重排）

**用户故事：** 作为学生，我希望能通过拖拽调整节点的位置和层级，
以便重新组织知识结构而无需删除重建。

#### 验收标准

1. WHEN 用户长按某个非 Root_Node 并拖动，THE MindMap_Editor SHALL 进入拖拽模式，以半透明样式跟随手指移动显示被拖节点。
2. WHEN 拖拽中的节点悬停在目标 Node 上超过 500ms，THE MindMap_Editor SHALL 高亮目标节点，提示可作为其子节点放置。
3. WHEN 用户释放拖拽，THE MindMap_Editor SHALL 将被拖节点（及其所有子节点）移动到目标节点下，成为其最后一个子节点。
4. IF 目标节点是被拖节点的后代节点，THEN THE MindMap_Editor SHALL 拒绝该移动操作，恢复节点到原始位置，并显示提示"不能将节点移动到其自身的子节点下"。
5. WHEN 节点移动完成，THE MindMap_Editor SHALL 将该操作记录到 Edit_History，以支持撤销。

---

### 需求 5：撤销与重做

**用户故事：** 作为学生，我希望能撤销误操作并重做已撤销的操作，
以便在编辑过程中自由探索而不担心出错。

#### 验收标准

1. THE MindMap_Editor SHALL 维护 Edit_History，记录添加、编辑、删除、移动节点的操作，最多保留 50 步历史。
2. WHEN 用户触发撤销操作，THE MindMap_Editor SHALL 将 Node_Tree 恢复到上一步操作前的状态。
3. WHEN 用户触发重做操作，THE MindMap_Editor SHALL 将 Node_Tree 恢复到最近一次撤销前的状态。
4. WHILE Edit_History 为空，THE MindMap_Editor SHALL 禁用撤销按钮。
5. WHILE 重做栈为空，THE MindMap_Editor SHALL 禁用重做按钮。
6. WHEN 用户在撤销后执行新的编辑操作，THE MindMap_Editor SHALL 清空重做栈。

---

### 需求 6：手动编辑与 AI 生成协调

**用户故事：** 作为学生，我希望 AI 生成的导图和我手动编辑的导图能够协调工作，
以便在 AI 生成的基础上进行个性化调整，或将手动编辑的结构作为 AI 生成的参考。

#### 验收标准

1. WHEN AI_Generator 生成新的 Node_Tree，THE MindMap_Editor SHALL 提示用户选择"替换当前导图"或"合并到当前导图"，而非直接覆盖。
2. WHEN 用户选择"替换当前导图"，THE MindMap_Editor SHALL 将当前 Node_Tree 替换为 AI 生成的 Node_Tree，并将替换操作记录到 Edit_History。
3. WHEN 用户选择"合并到当前导图"，THE MindMap_Editor SHALL 将 AI 生成的 Node_Tree 作为当前 Root_Node 的新子节点追加，保留现有节点不变。
4. WHEN 用户触发 AI 生成时，IF 当前 Node_Tree 非空，THEN THE Mindmap_Service SHALL 将当前 Node_Tree 的文本结构作为上下文附加到 AI 生成请求中，以引导 AI 生成与现有结构相关的内容。
5. THE MindMap_Editor SHALL 在工具栏提供"发送给 AI 优化"按钮；WHEN 用户点击该按钮，THE Mindmap_Service SHALL 将当前完整 Node_Tree 发送给 AI_Generator，请求对现有结构进行优化或补充，并以"合并"模式展示结果。

---

### 需求 7：导入 XMind 格式

**用户故事：** 作为学生，我希望能导入 XMind 文件，
以便复用已有的思维导图资料而无需重新手动录入。

#### 验收标准

1. THE MindMap_Editor SHALL 在工具栏提供"导入文件"入口，支持选择本地文件。
2. WHEN 用户选择 `.xmind` 格式文件，THE Import_Parser SHALL 解析该文件并将其第一个工作表的节点树转换为 Node_Tree 结构。
3. WHEN 用户选择 `.mm`（FreeMind）格式文件，THE Import_Parser SHALL 解析该 XML 文件并将其节点树转换为 Node_Tree 结构。
4. WHEN 导入成功，THE MindMap_Editor SHALL 提示用户选择"替换当前导图"或"合并到当前导图"，行为与需求 6.1 一致。
5. IF 导入文件格式不受支持，THEN THE Import_Parser SHALL 返回错误，THE MindMap_Editor SHALL 显示提示"不支持该文件格式，请选择 .xmind 或 .mm 文件"。
6. IF 导入文件解析失败（文件损坏或格式异常），THEN THE Import_Parser SHALL 返回错误，THE MindMap_Editor SHALL 显示提示"文件解析失败，请检查文件是否完整"。
7. THE Import_Parser SHALL 将导入节点的文本长度截断至 200 个字符，超出部分静默丢弃。

---

### 需求 8：导入 Markdown 大纲格式

**用户故事：** 作为学生，我希望能导入 Markdown 大纲文本，
以便将笔记或 AI 生成的 Markdown 快速转为可编辑的思维导图。

#### 验收标准

1. THE MindMap_Editor SHALL 提供"粘贴 Markdown 大纲"入口，接受用户粘贴的 Markdown 文本。
2. WHEN 用户提交 Markdown 文本，THE Import_Parser SHALL 将以 `#`、`##`、`###` 等标题层级和 `-`、`*` 列表项构成的大纲结构解析为 Node_Tree。
3. THE Import_Parser SHALL 将 `#` 标题映射为深度 1 节点，`##` 映射为深度 2，以此类推，最多支持 6 级。
4. IF 输入文本不包含任何可识别的大纲结构，THEN THE Import_Parser SHALL 返回错误，THE MindMap_Editor SHALL 显示提示"未识别到有效的大纲结构，请使用 # 标题或 - 列表格式"。
5. FOR ALL 合法的 Markdown 大纲文本，将其解析为 Node_Tree 后再序列化回 Markdown 大纲，所得文本的层级结构应与原始输入等价（往返属性）。

---

### 需求 9：拍照 OCR 识别目录结构

**用户故事：** 作为学生，我希望能拍摄书本目录或手写导图照片，
通过 OCR 自动识别并转换为可编辑的思维导图节点，
以便快速将纸质资料数字化。

#### 验收标准

1. THE MindMap_Editor SHALL 在工具栏提供"拍照识别"入口，支持调用设备相机拍照或从相册选取图片。
2. WHEN 用户提供图片，THE OCR_Service SHALL 对图片进行文字识别，提取文本内容及其缩进/编号层级信息。
3. WHEN OCR_Service 识别完成，THE MindMap_Editor SHALL 展示识别结果预览，允许用户在确认前手动修正识别文本和层级关系。
4. WHEN 用户确认识别结果，THE Import_Parser SHALL 将识别到的层级文本结构转换为 Node_Tree，并提示用户选择"替换"或"合并"，行为与需求 6.1 一致。
5. IF OCR_Service 识别失败（图片模糊、内容不可读），THEN THE OCR_Service SHALL 返回错误，THE MindMap_Editor SHALL 显示提示"图片识别失败，请确保图片清晰且包含文字内容"。
6. THE OCR_Service SHALL 在识别结果中为每个文本行标注置信度分数；WHEN 置信度低于 0.7 的文本行存在时，THE MindMap_Editor SHALL 在预览界面中以黄色高亮标注这些低置信度文本，提示用户重点核查。
7. THE OCR_Service SHALL 在 30 秒内返回识别结果；IF 超时，THEN THE MindMap_Editor SHALL 显示提示"识别超时，请重试或手动输入"。

---

### 需求 10：导图持久化与多导图管理

**用户故事：** 作为学生，我希望我的手动编辑能够自动保存，
并能在同一学科下管理多份导图，
以便不丢失编辑成果，并针对不同章节维护独立的导图。

#### 验收标准

1. THE MindMap_Editor SHALL 在用户每次完成节点操作（添加/编辑/删除/移动）后 2 秒内自动将 Node_Tree 持久化到本地存储。
2. WHEN 用户切换学科（`currentSubjectProvider` 变更），THE MindMap_Editor SHALL 保存当前学科的 Node_Tree，并加载新学科对应的 Node_Tree。
3. THE MindMap_Editor SHALL 支持在同一学科下创建多份命名导图；WHEN 用户点击"新建导图"，THE MindMap_Editor SHALL 创建一份空白导图并提示用户输入导图名称。
4. THE MindMap_Editor SHALL 在顶部提供导图切换下拉菜单，列出当前学科下的所有导图，WHEN 用户切换导图时，THE MindMap_Editor SHALL 加载对应的 Node_Tree。
5. WHEN 用户触发"删除导图"操作，THE MindMap_Editor SHALL 显示确认对话框；WHEN 用户确认，THE MindMap_Editor SHALL 删除该导图及其所有节点数据。
6. IF 当前学科下只有一份导图，THEN THE MindMap_Editor SHALL 禁用"删除导图"操作，防止删除最后一份导图。

---

### 需求 11：导出导图

**用户故事：** 作为学生，我希望能将编辑好的思维导图导出为常用格式，
以便在其他工具中使用或分享给他人。

#### 验收标准

1. THE MindMap_Editor SHALL 提供导出功能，支持导出为 Markdown 大纲（`.md`）格式。
2. WHEN 用户触发 Markdown 导出，THE MindMap_Editor SHALL 将 Node_Tree 序列化为以 `#` 标题层级表示的 Markdown 大纲文本，并触发文件下载或系统分享。
3. THE MindMap_Editor SHALL 支持导出为图片（PNG）格式，将当前导图渲染结果截图保存。
4. FOR ALL 合法的 Node_Tree，将其导出为 Markdown 后再通过需求 8 的导入功能重新导入，所得 Node_Tree 的节点文本和层级结构应与原始 Node_Tree 等价（往返属性）。
