# 需求文档：笔记本功能

## 简介

为学科学习助手 App 新增"笔记本"功能，允许用户将对话中的消息（AI 回答或用户提问）收藏到不同的笔记本中，并按学科自动分栏管理。笔记本支持系统预设本和用户自定义本，每条笔记可由 AI 生成标题提纲或用户手写，还可一键导入资料库参与 RAG 检索，形成"对话 → 笔记 → 资料库 → 更好的 RAG"的学习闭环。

---

## 词汇表

- **Notebook（笔记本）**：用于收藏和管理笔记的容器，分为系统预设本和用户自定义本。
- **Note（笔记）**：从对话消息中收藏的内容单元，包含原始消息内容、标题、提纲等元数据。
- **NoteSection（学科栏）**：笔记本内按学科自动生成的分组，每个笔记本自动包含用户所有学科的栏目及一个"通用"栏。
- **System_Notebook（系统预设本）**：由系统创建、不可删除的笔记本，包括"好题本"、"错题本"、"笔记"（原收藏夹）和"通用"本。
- **User_Notebook（用户自定义本）**：由用户创建的笔记本，支持归档、置顶、排序。
- **Notebook_Manager（笔记本管理器）**：负责笔记本的增删改查、排序、归档、置顶等管理操作的后端服务。
- **Note_Manager（笔记管理器）**：负责笔记的创建、编辑、删除、导入资料库等操作的后端服务。
- **AI_Title_Generator（AI 标题生成器）**：调用 LLM 为笔记内容生成标题和提纲的服务。
- **RAG_Importer（资料库导入器）**：将笔记内容转换为资料文档并导入 RAG 检索系统的服务。
- **Multi_Select_Mode（多选模式）**：聊天页长按消息后进入的状态，允许用户同时选中多条消息。
- **Message（消息）**：对话中的单条内容，包括用户提问（role=user）和 AI 回答（role=assistant）。
- **Subject（学科）**：用户创建的学习科目，笔记本内按学科自动分栏。

---

## 需求

### 需求 1：系统预设笔记本

**用户故事：** 作为学生，我希望系统自动提供"好题本"、"错题本"、"笔记"和"通用"四个预设笔记本，以便我无需手动创建即可立即开始收藏内容。

#### 验收标准

1. THE Notebook_Manager SHALL 在用户首次登录后自动为其创建"好题本"、"错题本"、"笔记"、"通用"四个系统预设本。
2. THE Notebook_Manager SHALL 将系统预设本的 `is_system` 标记为 `true`，使其不可被用户删除。
3. WHEN 用户尝试删除系统预设本时，THE Notebook_Manager SHALL 返回错误提示"系统预设本不可删除"。
4. THE Notebook_Manager SHALL 在笔记本列表中将系统预设本始终排列在用户自定义本之前。
5. THE Notebook_Manager SHALL 允许用户对系统预设本执行置顶和归档操作，但不允许删除。

---

### 需求 2：用户自定义笔记本管理

**用户故事：** 作为学生，我希望能自由新建笔记本，并对其进行置顶、归档和排序管理，以便按照自己的学习习惯组织笔记。

#### 验收标准

1. WHEN 用户提交新建笔记本请求并提供名称时，THE Notebook_Manager SHALL 创建一个新的用户自定义本，并将其 `is_system` 标记为 `false`。
2. IF 用户提交的笔记本名称为空或超过 64 个字符，THEN THE Notebook_Manager SHALL 返回校验错误，拒绝创建。
3. WHEN 用户对某个笔记本执行置顶操作时，THE Notebook_Manager SHALL 将该笔记本的 `is_pinned` 设为 `true`，并在列表中将其排列在未置顶笔记本之前。
4. WHEN 用户对某个笔记本执行归档操作时，THE Notebook_Manager SHALL 将该笔记本的 `is_archived` 设为 `true`，并将其从主列表中移出，折叠展示在"已归档"分组中。
5. WHEN 用户调整笔记本排序时，THE Notebook_Manager SHALL 更新受影响笔记本的 `sort_order` 字段，并在下次列表请求时按新顺序返回。
6. WHEN 用户删除用户自定义本时，THE Notebook_Manager SHALL 同时删除该笔记本下的所有笔记。
7. THE Notebook_Manager SHALL 按照"置顶优先、再按 `sort_order` 升序、最后按创建时间降序"的规则返回笔记本列表。

---

### 需求 3：笔记本内学科自动分栏

**用户故事：** 作为学生，我希望每个笔记本内的笔记按学科自动分栏展示，以便快速定位某学科下的笔记。

#### 验收标准

1. WHEN 用户打开任意笔记本时，THE Notebook_Manager SHALL 自动为该用户当前所有未归档学科各生成一个学科栏，并额外提供一个"通用"栏。
2. THE Notebook_Manager SHALL 在学科栏列表中将"通用"栏始终排列在所有学科栏之前。
3. WHEN 用户新增一个学科时，THE Notebook_Manager SHALL 在该用户所有笔记本中自动新增对应的学科栏。
4. WHEN 用户归档一个学科时，THE Notebook_Manager SHALL 在笔记本内隐藏该学科栏，但保留该栏下已有的笔记，待学科取消归档后恢复显示。
5. THE Notebook_Manager SHALL 在学科栏内按笔记的 `created_at` 降序排列笔记。

---

### 需求 4：从聊天页长按进入多选模式

**用户故事：** 作为学生，我希望在聊天页长按消息后进入多选模式，可以同时选中多条消息（包括 AI 回答和用户提问），然后将它们一起收藏到指定笔记本，以便高效整理学习内容。

#### 验收标准

1. WHEN 用户在聊天页长按任意一条消息时，THE Chat_UI SHALL 进入多选模式，并将被长按的消息标记为已选中状态。
2. WHILE 处于多选模式时，THE Chat_UI SHALL 在页面顶部显示已选中消息数量，并在底部显示"收藏到笔记本"和"取消"操作按钮。
3. WHILE 处于多选模式时，THE Chat_UI SHALL 允许用户点击任意消息气泡以切换其选中/取消选中状态，且 AI 回答和用户提问均可被选中。
4. WHEN 用户在多选模式下点击"收藏到笔记本"时，THE Chat_UI SHALL 弹出笔记本选择面板，展示用户所有未归档笔记本列表。
5. WHEN 用户在多选模式下点击"取消"时，THE Chat_UI SHALL 退出多选模式并清除所有选中状态。
6. IF 用户在多选模式下未选中任何消息即点击"收藏到笔记本"，THEN THE Chat_UI SHALL 提示"请至少选择一条消息"。

---

### 需求 5：将消息收藏为笔记

**用户故事：** 作为学生，我希望在选择笔记本和学科栏后，将选中的消息保存为笔记，以便后续复习。

#### 验收标准

1. WHEN 用户在笔记本选择面板中选定笔记本和学科栏后确认时，THE Note_Manager SHALL 将每条选中消息的内容、角色（user/assistant）、来源会话 ID 和消息 ID 保存为独立的笔记记录。
2. THE Note_Manager SHALL 在笔记记录中保留消息的原始 `sources`（RAG 引用来源）字段，以便在笔记详情中展示参考来源。
3. WHEN 笔记创建成功后，THE Chat_UI SHALL 退出多选模式，并以 Toast 形式提示"已收藏 N 条笔记到《笔记本名称》"。
4. IF 笔记创建过程中发生网络或服务器错误，THEN THE Note_Manager SHALL 返回错误信息，THE Chat_UI SHALL 提示"收藏失败，请重试"并保持多选模式。
5. THE Note_Manager SHALL 允许同一条消息被多次收藏到不同笔记本，不做重复限制。

---

### 需求 6：笔记标题与提纲

**用户故事：** 作为学生，我希望每条笔记可以有标题和提纲，支持 AI 自动生成或手动编写，以便快速了解笔记内容。

#### 验收标准

1. WHEN 用户在笔记详情页点击"AI 生成标题提纲"时，THE AI_Title_Generator SHALL 调用 LLM，基于笔记的原始内容生成一个不超过 30 字的标题和不超过 5 条的提纲要点，并将结果填入标题和提纲字段。
2. WHEN AI 生成完成后，THE Note_Manager SHALL 将生成的标题和提纲持久化保存到笔记记录中。
3. THE Note_Manager SHALL 允许用户在任意时刻手动编辑笔记的标题（不超过 64 字）和正文内容。
4. IF 调用 LLM 生成标题提纲时发生错误，THEN THE AI_Title_Generator SHALL 返回错误信息，THE Note_UI SHALL 提示"AI 生成失败，请手动填写或稍后重试"。
5. WHEN 笔记没有标题时，THE Note_UI SHALL 以笔记内容的前 20 个字符作为显示标题，并以灰色样式区分于用户设置的标题。

---

### 需求 7：笔记导入资料库

**用户故事：** 作为学生，我希望将笔记一键导入对应学科的资料库，使其参与 RAG 检索，从而让 AI 回答时能引用我整理的笔记内容。

#### 验收标准

1. WHEN 用户在笔记详情页点击"导入资料库"时，THE RAG_Importer SHALL 将该笔记的标题和内容合并为文本，以"笔记：{标题}"为文件名，创建一条 Document 记录并触发分块和向量化流程，关联到该笔记所属的学科。
2. WHEN 导入成功后，THE Note_Manager SHALL 将该笔记的 `imported_to_doc_id` 字段更新为新创建的 Document ID，THE Note_UI SHALL 将"导入资料库"按钮更新为"已导入（查看）"状态。
3. WHEN 用户点击"已导入（查看）"时，THE Note_UI SHALL 跳转到对应学科的资料库页面，并高亮显示该文档。
4. IF 笔记尚未设置标题且内容为空，THEN THE RAG_Importer SHALL 拒绝导入并提示"笔记内容为空，无法导入"。
5. WHEN 用户对已导入的笔记再次点击"导入资料库"时，THE RAG_Importer SHALL 删除旧的 Document 记录及其 Chunk，重新创建新的 Document 记录，以保持资料库内容与笔记同步。
6. IF 导入过程中发生错误，THEN THE RAG_Importer SHALL 回滚已创建的 Document 记录，并返回错误信息，THE Note_UI SHALL 提示"导入失败，请重试"。

---

### 需求 8：笔记本入口

**用户故事：** 作为学生，我希望能从"我的"页面和聊天页方便地进入笔记本功能，以便随时查看和管理笔记。

#### 验收标准

1. THE Profile_UI SHALL 在"我的"页面的功能列表中新增"笔记本"入口，点击后跳转到笔记本列表页。
2. WHEN 用户在聊天页多选消息并点击"收藏到笔记本"时，THE Chat_UI SHALL 弹出笔记本选择面板（不跳转页面），完成收藏后留在聊天页。
3. THE Notebook_UI SHALL 提供从笔记本列表页进入单个笔记本详情页（含学科分栏）的导航路径。
4. THE Notebook_UI SHALL 提供从笔记本详情页进入单条笔记详情页的导航路径。

---

### 需求 9：笔记本数据持久化

**用户故事：** 作为学生，我希望笔记本和笔记数据安全地存储在服务器端，以便在不同设备上访问。

#### 验收标准

1. THE Notebook_Manager SHALL 在 PostgreSQL 数据库中创建 `notebooks` 表，包含字段：`id`、`user_id`、`name`、`is_system`、`is_pinned`、`is_archived`、`sort_order`、`created_at`。
2. THE Note_Manager SHALL 在 PostgreSQL 数据库中创建 `notes` 表，包含字段：`id`、`notebook_id`、`subject_id`（可为 NULL，NULL 表示通用栏）、`source_session_id`、`source_message_id`、`role`、`original_content`、`title`、`outline`（JSONB）、`imported_to_doc_id`（可为 NULL）、`created_at`、`updated_at`。
3. THE Notebook_Manager SHALL 对 `notebooks` 表的 `user_id` 字段建立索引，以保证按用户查询的性能。
4. THE Note_Manager SHALL 对 `notes` 表的 `notebook_id` 和 `subject_id` 字段建立复合索引，以保证按笔记本和学科栏查询的性能。
5. WHEN 用户账号被删除时，THE Notebook_Manager SHALL 级联删除该用户的所有笔记本和笔记记录。
