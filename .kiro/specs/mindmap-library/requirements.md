# 需求文档：学校（School）

## 简介

将现有「导图」Tab 升级为「学校」Tab，打造一个以学科为课程、以思维导图为大纲、以 AI 讲义为课程内容的个人学习空间。

用户在「学校」里拥有自己的课程体系：每个学科是一门课，每张思维导图是这门课的大纲，点击大纲中的任意知识点节点可按需生成保姆级 AI 讲义，讲义可编辑、可导出。学习进度通过节点点亮可视化呈现，让用户像修课一样感受知识积累的成就感。

---

## 概念映射

| 现实学校 | App 概念 |
|---------|---------|
| 学校 | 「学校」Tab 主页 |
| 课程 | 学科（Subject） |
| 课程大纲 | 思维导图（可编辑） |
| 课程讲义 | 节点 AI 讲义文档 |
| 修课记录 | 节点点亮进度 |
| 图书馆 | 学科资料库 |

---

## 词汇表

- **School（学校）**：底部导航「学校」Tab，用户个人学习空间的总入口，展示所有课程（学科）。
- **Course_Card（课程卡片）**：学校主页中每个学科的展示卡片，显示课程名称、大纲数量、整体学习进度。
- **Course_Space（课程空间）**：进入某个学科后的详情页，包含该学科的所有大纲（思维导图）列表和快捷操作。
- **Syllabus（大纲）**：即思维导图，作为课程的知识框架，同一学科可有多张大纲（对应不同资料范围）。
- **Editable_MindMap（可编辑大纲）**：支持用户直接在渲染后的思维导图上进行节点增删改操作的交互式视图。
- **MindMap_Editor（大纲编辑器）**：处理节点增删改并将变更持久化到后端的服务。
- **MindMap_Parser（大纲解析器）**：将 Markdown 格式的思维导图文本解析为树节点列表的服务。
- **Tree_Node（树节点）**：大纲中的单个知识点单元，包含节点文本、层级、点亮状态、是否有讲义等属性。
- **Lit_Node（已点亮节点）**：用户标记为已学习的节点，视觉上以高亮样式区分。
- **Lecture（讲义）**：针对某个节点由 AI 按需生成的富文本学习文档，包含保姆级详细讲解。
- **Lecture_Generator（讲义生成器）**：调用 LLM 并结合 RAG 检索结果与用户画像生成讲义的后端服务。
- **Lecture_Editor（讲义编辑器）**：供用户对讲义进行富文本编辑的前端组件，参考飞书文档交互风格。
- **Lecture_Exporter（讲义导出器）**：将讲义导出为 Markdown、PDF 或 Word 格式的服务。
- **Progress_Tracker（进度追踪器）**：记录和计算节点点亮进度的服务。
- **Node_State_Manager（节点状态管理器）**：持久化存储和更新节点点亮状态的后端服务。
- **RAG_Retriever（RAG 检索器）**：基于 PGVector 从学科资料库检索与节点主题相关上下文的服务。
- **User_Memory（用户画像）**：存储在 `UserMemory` 表中的用户学习偏好和知识背景，用于定制讲义风格。
- **Resource_Scope（资料范围）**：生成大纲时选择的资料子集，同一学科可基于不同资料范围生成多张大纲。
- **ConversationSession（会话）**：存储大纲内容的会话记录，`session_type` 为 `mindmap`。

---

## 需求

### 需求 1：学校主页——课程列表

**用户故事：** 作为学生，我希望进入「学校」Tab 后能看到我所有学科的课程卡片，直观了解每门课的学习状态，以便快速进入想学的课程。

#### 验收标准

1. THE School SHALL 将底部导航「导图」Tab 替换为「学校」Tab，图标使用 `school_outlined`，点击后进入学校主页。
2. WHEN 用户进入学校主页时，THE School SHALL 以卡片列表展示该用户的所有学科，每张课程卡片显示：学科名称、学科分类（若有）、大纲数量（该学科下的思维导图数）、整体学习进度（所有大纲已点亮节点数之和 / 总节点数之和，百分比）、最近访问时间。
3. THE School SHALL 在每张课程卡片上提供「开始学习」快捷按钮，点击后直接进入该学科的课程空间。
4. THE School SHALL 将置顶学科排在列表最前，其余按最近访问时间降序排列。
5. WHEN 用户没有任何学科时，THE School SHALL 显示空状态引导："你还没有任何课程，去「我的」→「学科管理」创建一个学科开始学习吧"。
6. THE School SHALL 在主页顶部提供搜索入口，WHEN 用户输入关键词时，THE School SHALL 实时过滤课程卡片列表，匹配学科名称或分类。

---

### 需求 2：课程空间——大纲管理

**用户故事：** 作为学生，我希望进入某门课程后能看到该学科下所有的大纲（思维导图），并能创建新大纲或打开已有大纲，以便管理我的课程框架。

#### 验收标准

1. WHEN 用户点击课程卡片进入课程空间时，THE Course_Space SHALL 展示该学科下所有大纲的列表，每条大纲显示：大纲标题（取会话 `title` 字段，若为空则显示"未命名大纲"）、资料范围标签、生成时间、该大纲的学习进度（N/M）。
2. THE Course_Space SHALL 按会话 `created_at` 降序排列大纲列表，最新生成的排在最前。
3. THE Course_Space SHALL 提供「新建大纲」入口，点击后跳转到大纲生成页（原思维导图生成页），生成完成后自动返回课程空间并刷新列表。
4. WHEN 用户点击某条大纲时，THE Course_Space SHALL 跳转到该大纲的可编辑视图（需求 5）。
5. THE Course_Space SHALL 在每条大纲右侧提供「⋯」菜单，包含：重命名、删除两个操作。
6. WHEN 用户确认删除某条大纲时，THE Course_Space SHALL 级联删除该大纲下所有节点的讲义和点亮状态，并以 Toast 提示"已删除"。
7. IF 用户提交的大纲名称为空或超过 64 个字符，THEN THE Course_Space SHALL 返回校验错误，拒绝更新。
8. THE Course_Space SHALL 在页面顶部显示该学科的整体学习进度条，汇总所有大纲的节点点亮情况。
9. THE Course_Space SHALL 提供「资料库」快捷入口，点击后跳转到该学科的资料管理页。

---

### 需求 3：可编辑大纲（思维导图交互编辑）

**用户故事：** 作为学生，我希望打开大纲后能直接在渲染好的思维导图上编辑节点，而不只是只读浏览，以便根据自己的理解调整知识框架。

#### 验收标准

1. THE Editable_MindMap SHALL 以可交互模式渲染思维导图，替代原只读 WebView，支持节点的直接编辑操作。
2. WHEN 用户单击某个节点时，THE Editable_MindMap SHALL 在节点旁显示操作浮层，提供：「生成讲义」（若已有讲义则显示「查看讲义」）、「添加子节点」、「编辑文本」、「删除节点」四个操作入口。
3. WHEN 用户选择「编辑文本」并提交新文本时，THE MindMap_Editor SHALL 更新该节点文本并将变更持久化到后端对应的 `ConversationHistory` 记录中。
4. IF 用户提交的节点文本为空或超过 200 个字符，THEN THE MindMap_Editor SHALL 拒绝提交并显示校验错误提示。
5. WHEN 用户选择「添加子节点」并输入节点文本后，THE MindMap_Editor SHALL 在该节点下新增子节点，并将更新后的完整导图 Markdown 持久化到后端。
6. WHEN 用户选择「删除节点」并确认时，THE MindMap_Editor SHALL 删除该节点及其所有子节点，并将更新后的完整导图 Markdown 持久化到后端。
7. IF 用户尝试删除根节点，THEN THE MindMap_Editor SHALL 拒绝操作并提示"根节点不可删除"。
8. WHEN 导图结构发生变更时，THE MindMap_Editor SHALL 实时更新渲染视图，无需手动刷新。
9. THE Editable_MindMap SHALL 提供「撤销」操作，WHEN 用户触发撤销时，THE MindMap_Editor SHALL 回退到上一次持久化前的导图状态。
10. THE Editable_MindMap SHALL 对用户自建的节点与 AI 生成的原始节点在视觉上加以区分（如不同图标或颜色），以便用户识别节点来源。
11. FOR ALL 已生成讲义的节点，THE Editable_MindMap SHALL 在该节点上显示小书本图标，以区分已有讲义和未生成讲义的节点。

---

### 需求 4：大纲解析为学习路线树

**用户故事：** 作为学生，我希望系统能将大纲的节点结构解析为可交互的树形视图，以便按知识点逐一学习并标记进度。

#### 验收标准

1. THE MindMap_Parser SHALL 将 Markdown 格式的大纲文本按标题层级（`#` `##` `###` `####`）解析为树节点列表，每个节点包含：节点 ID（基于层级路径生成的稳定标识符）、节点文本、层级深度（1-4）、父节点 ID。
2. THE MindMap_Parser SHALL 将根节点（`#` 级别）作为树的根，其余节点按层级关系构建父子结构。
3. IF 导图文本中存在相同文本的兄弟节点，THEN THE MindMap_Parser SHALL 通过在节点 ID 中附加序号来保证每个节点 ID 的唯一性。
4. THE Editable_MindMap SHALL 支持节点折叠与展开：WHEN 用户点击有子节点的节点时，SHALL 切换该节点的子树展开/折叠状态。
5. FOR ALL 有效的 Markdown 大纲文本，THE MindMap_Parser 解析后再序列化回 Markdown 再解析，SHALL 产生与第一次解析相同的节点结构（往返一致性）。

---

### 需求 5：节点点亮——标记已学习

**用户故事：** 作为学生，我希望学完某个知识点后能将对应节点标记为已学习（点亮），通过视觉反馈感受学习进度，获得成就感。

#### 验收标准

1. WHEN 用户在大纲视图中长按某个节点时，THE Editable_MindMap SHALL 弹出操作菜单，提供「标记为已学习」和「取消标记」两个选项。
2. WHEN 用户选择「标记为已学习」时，THE Node_State_Manager SHALL 将该节点的点亮状态持久化保存，THE Editable_MindMap SHALL 将该节点渲染为高亮样式（填充主题色，文字变白）。
3. WHEN 用户选择「取消标记」时，THE Node_State_Manager SHALL 删除该节点的点亮记录，THE Editable_MindMap SHALL 将该节点恢复为未点亮样式。
4. WHILE 某个非叶子节点的所有直接子节点均已点亮时，THE Editable_MindMap SHALL 将该非叶子节点自动渲染为半点亮样式（填充浅主题色），以反映部分完成状态。
5. WHEN 用户重新进入某张大纲时，THE Node_State_Manager SHALL 恢复该大纲所有节点的点亮状态，保证状态持久化。
6. THE Node_State_Manager SHALL 将节点点亮状态存储在后端数据库中，以 `(user_id, session_id, node_id)` 作为唯一键。

---

### 需求 6：学习进度可视化

**用户故事：** 作为学生，我希望能在多个层级直观看到学习进度，了解已掌握的知识点比例，以便规划后续学习。

#### 验收标准

1. THE Editable_MindMap SHALL 在大纲页面顶部显示进度条和进度文字，格式为"已学习 N / 总计 M 个知识点（X%）"，其中 X 为百分比（向下取整）。
2. WHEN 用户点亮或取消点亮任意节点时，THE Progress_Tracker SHALL 实时更新进度条和进度文字，无需刷新页面。
3. THE Course_Space SHALL 在每条大纲列表项上显示该大纲的进度摘要，格式为"N / M"。
4. THE School SHALL 在课程卡片上显示该学科所有大纲汇总的整体进度百分比。
5. WHEN 用户完成某张大纲所有节点的点亮（N = M）时，THE Editable_MindMap SHALL 显示完成庆祝动画（撒花效果），并在进度文字旁显示"🎉 全部完成！"标识。
6. THE Progress_Tracker SHALL 保证进度计算的一致性：FOR ALL 大纲，已点亮节点数加上未点亮节点数 SHALL 等于总节点数。

---

### 需求 7：按需生成节点讲义

**用户故事：** 作为学生，我希望点击大纲中的任意节点后能按需生成该知识点的 AI 讲义，以便深入学习，同时避免一次性生成所有讲义浪费资源。

#### 验收标准

1. WHEN 用户在大纲视图中单击任意节点（包括根节点、中间节点和叶子节点）时，THE Editable_MindMap SHALL 在操作浮层中提供「生成讲义」入口（若该节点已有讲义则显示「查看讲义」）。
2. WHEN 用户触发「生成讲义」时，THE Lecture_Generator SHALL 仅为该节点生成讲义，其他未触发的节点不生成任何文档。
3. WHEN 讲义生成请求发起后，THE Lecture_Generator SHALL 在 Flutter 端显示生成中状态（加载动画），并在生成完成后自动跳转到讲义详情页。
4. IF 讲义生成过程中发生网络错误或 LLM 调用失败，THEN THE Lecture_Generator SHALL 返回错误提示并保留「重新生成」入口，不保存不完整的讲义内容。
5. THE Lecture_Generator SHALL 将已生成的讲义与对应的 `(session_id, node_id)` 关联存储，保证同一节点的讲义可被重复访问而无需重新生成。

---

### 需求 8：讲义内容生成质量

**用户故事：** 作为学生，我希望生成的讲义能结合我的学科资料、个人学习背景，并提供保姆级别的详细讲解，以便真正理解知识点。

#### 验收标准

1. WHEN THE Lecture_Generator 生成讲义时，THE RAG_Retriever SHALL 从当前学科的资料库中检索与该节点主题语义相关的上下文片段，并将检索结果作为 prompt 上下文传入 LLM。
2. WHEN THE Lecture_Generator 生成讲义时，THE Lecture_Generator SHALL 从 `UserMemory` 表中读取当前用户的学习偏好和知识背景，并将用户画像信息注入 prompt，以定制讲义的讲解深度和风格。
3. THE Lecture_Generator SHALL 在 prompt 中传入该节点在大纲中的完整层级路径（如"材料力学 > 应力分析 > 主应力"），以确保讲义内容聚焦于该节点在学科体系中的具体位置。
4. THE Lecture_Generator SHALL 生成的讲义内容包含以下结构：概念定义、核心原理、详细推导或说明、典型例题（含解析）、常见误区、小结，每个部分均有明确标题。
5. THE Lecture_Generator SHALL 使用 DeepSeek-V3（通过 SiliconFlow API）作为 LLM，prompt 中明确要求"保姆级别详细讲解，不跳步骤"。
6. WHEN 当前学科资料库中无相关检索结果时，THE Lecture_Generator SHALL 仍基于用户画像和 LLM 通用知识生成讲义，并在讲义顶部注明"本讲义未检索到相关资料，内容基于通用知识生成"。
7. THE Lecture_Generator SHALL 在为子节点生成讲义时，将父节点的讲义摘要（前 500 字）作为额外上下文注入 prompt，以保证子节点讲义与父节点内容的连贯性。

---

### 需求 9：讲义富文本编辑

**用户故事：** 作为学生，我希望能对 AI 生成的讲义进行编辑和补充，加入自己的笔记和理解，形成个性化的学习文档。

#### 验收标准

1. THE Lecture_Editor SHALL 在讲义详情页以富文本编辑器展示讲义内容，支持的格式包括：标题（H1-H3）、正文、加粗、斜体、行内代码、代码块、有序列表、无序列表、引用块。
2. WHEN 用户对讲义内容进行编辑时，THE Lecture_Editor SHALL 实时保存编辑内容（自动保存间隔不超过 5 秒），无需用户手动点击保存按钮。
3. THE Lecture_Editor SHALL 在编辑器顶部提供格式工具栏，包含上述所有支持格式的快捷操作按钮。
4. WHEN 用户完成编辑并离开讲义页面时，THE Lecture_Editor SHALL 确保所有未自动保存的变更已持久化到后端，不丢失编辑内容。
5. IF 自动保存请求失败，THEN THE Lecture_Editor SHALL 在编辑器顶部显示"保存失败，请检查网络"提示，并在网络恢复后自动重试保存。
6. THE Lecture_Editor SHALL 区分"AI 生成内容"和"用户编辑内容"的视觉样式，用户新增或修改的段落以不同背景色标注。

---

### 需求 10：讲义导出

**用户故事：** 作为学生，我希望能将讲义导出为常用文档格式，以便在其他设备或应用中查阅和分享。

#### 验收标准

1. THE Lecture_Exporter SHALL 在讲义详情页提供「导出」操作入口，支持导出为：Markdown（`.md`）、PDF（`.pdf`）、Word（`.docx`）三种格式。
2. WHEN 用户选择导出 Markdown 时，THE Lecture_Exporter SHALL 将讲义的富文本内容转换为标准 Markdown 语法文本，并触发 Android 系统的文件保存对话框。
3. WHEN 用户选择导出 PDF 时，THE Lecture_Exporter SHALL 将讲义内容渲染为 PDF 文档，保留标题层级、列表、代码块等格式，并触发 Android 系统的文件保存对话框。
4. WHEN 用户选择导出 Word 时，THE Lecture_Exporter SHALL 将讲义内容转换为 `.docx` 格式文档，保留标题层级、加粗、斜体、列表等基本格式，并触发 Android 系统的文件保存对话框。
5. IF 导出过程中发生错误，THEN THE Lecture_Exporter SHALL 显示错误提示并提供「重试」入口，不生成损坏的文件。
6. FOR ALL 导出格式，THE Lecture_Exporter 导出的文件内容 SHALL 与讲义编辑器中当前显示的内容一致，不丢失任何已保存的编辑内容。

---

### 需求 11：同一学科多张大纲独立讲义

**用户故事：** 作为学生，我希望同一学科下基于不同资料范围生成的多张大纲各自独立，每张都能作为框架生成讲义，以便针对不同考试范围或学习阶段分别备课。

#### 验收标准

1. THE Course_Space SHALL 允许同一学科下存在多张大纲，每张大纲对应独立的 `ConversationSession`，互不干扰。
2. WHEN 用户在大纲生成页选择不同的资料范围（Resource_Scope）时，THE Course_Space SHALL 将生成的大纲与所选资料范围关联存储，并在大纲列表项上显示资料范围标签。
3. THE Lecture_Generator SHALL 在为某张大纲的节点生成讲义时，RAG 检索范围 SHALL 限定在该大纲关联的资料范围内，不跨范围检索其他资料。
4. WHEN 用户删除某张大纲时，THE Course_Space SHALL 级联删除该大纲下所有节点的讲义内容和点亮状态，不影响同一学科其他大纲的数据。

---

### 需求 12：数据持久化

**用户故事：** 作为学生，我希望学校中的所有数据（大纲、讲义、学习进度）安全地存储在服务器端，以便随时访问和跨设备同步。

#### 验收标准

1. THE Node_State_Manager SHALL 在 PostgreSQL 数据库中创建 `mindmap_node_states` 表，包含字段：`id`、`user_id`、`session_id`（关联 `conversation_sessions.id`）、`node_id`（字符串）、`is_lit`（整数，1=已点亮）、`updated_at`；并对 `(user_id, session_id, node_id)` 建立唯一约束，对 `(user_id, session_id)` 建立复合索引。
2. THE Lecture_Generator SHALL 在 PostgreSQL 数据库中创建 `node_lectures` 表，包含字段：`id`、`user_id`、`session_id`（关联 `conversation_sessions.id`）、`node_id`（字符串）、`content`（富文本内容，JSON 格式）、`resource_scope`（资料范围标识）、`created_at`、`updated_at`；并对 `(user_id, session_id, node_id)` 建立唯一约束。
3. THE Lecture_Editor SHALL 通过 PATCH 接口增量更新 `node_lectures.content` 字段，不替换整条记录，以减少写入数据量。
4. WHEN 用户账号被删除时，SHALL 级联删除该用户的所有节点点亮状态和讲义记录。
5. WHEN 对应的 `ConversationSession` 被删除时，SHALL 级联删除该会话下所有节点的点亮状态和讲义记录。
6. THE Course_Space SHALL 复用现有的 `conversation_sessions` 和 `conversation_history` 表存储大纲数据，不新增冗余表。
7. FOR ALL 讲义内容，THE Lecture_Editor 自动保存后再读取的内容 SHALL 与保存前的内容完全一致（往返一致性）。

---

### 需求 13：学校与现有功能的集成

**用户故事：** 作为学生，我希望「学校」与现有的问答、解题等功能无缝衔接，以便在不同学习场景间自由切换。

#### 验收标准

1. WHEN 用户在原「导图」Tab（现「学校」Tab）的大纲生成页成功生成一张大纲时，THE Course_Space SHALL 自动将该大纲记录到对应学科的课程空间（复用现有 `ConversationSession` 存储机制，无需额外操作）。
2. THE School SHALL 在课程卡片上提供「去问答」快捷入口，点击后跳转到该学科的问答页并自动切换当前学科。
3. THE Course_Space SHALL 提供「资料库」快捷入口，点击后跳转到该学科的资料管理页（`/profile/resources/:id`）。
4. WHEN 用户从「学校」进入某个学科的课程空间时，THE School SHALL 自动将该学科设置为全局当前学科（更新 `currentSubjectProvider`），使问答、解题等功能页同步切换到该学科。
