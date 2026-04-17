# 需求文档：Learning OS 架构

## 简介

将现有学习 App 重构为类比"操作系统"的分层架构。系统由三层构成：

- **内核层（Agent）**：巨型 Agent，负责解析用户学习意图、匹配 Skill、调度组件
- **应用层（Skill）**：以学习方法为核心的可插拔单元，每个 Skill 封装一套 Prompt 链
- **工具层（组件）**：笔记本、错题本、日历、计时器、思维导图等可复用功能模块

在此基础上，系统支持四种使用模式：Skill 驱动模式、多课学习模式、DIY 模式、纯手动模式。

---

## 词汇表

- **Learning_OS**：整个系统的总称，类比操作系统的学习平台架构
- **Agent**：系统内核，负责意图解析、Skill 匹配与组件调度的核心 AI 模块
- **Skill**：学习方法单元，封装一套 Prompt 链和调用逻辑，存储于 Skill 库中
- **Skill_Library**：存储所有可用 Skill 定义的仓库，支持内置和用户自定义
- **Component**：可插拔功能模块（如笔记本、错题本、日历、计时器、思维导图）
- **Component_Registry**：管理所有已注册 Component 的注册表，提供统一发现接口
- **Session**：一次完整的学习会话，包含模式、使用的 Skill/组件及产生的数据
- **Learning_Plan**：由 Agent 或用户创建的跨学科学习计划，包含任务列表和时间安排
- **User**：使用 Learning_OS 的学习者
- **Skill_Driver**：Skill 驱动模式，由 Agent 选择并执行 Skill 完成学习任务
- **Multi_Subject_Skill**：多课学习 Skill，一种高层 Skill，统筹多个学科、协调多个 Component，形成完整的跨学科学习计划闭环（例如"备战高考"Skill 自动创建语文、数学、英语等学科并生成时间表）
- **DIY_Mode**：DIY 模式，用户手动组合 Skill 和组件
- **Manual_Mode**：纯手动模式，用户直接使用组件，不依赖 Skill 或 Agent
- **Intent**：用户输入的自然语言学习需求，由 Agent 解析为结构化调度指令
- **Prompt_Chain**：Skill 内部的有序 Prompt 序列，定义 AI 交互流程
- **Component_Interface**：组件对外暴露的标准化调用接口规范
- **SkillCreationAdapter**：统一的 Skill 创建适配器接口，对话式创建、经验贴导入、手动编辑三种创建路径均通过该接口接入 Skill_Library，当前阶段仅预留接口骨架
- **SkillParser**：经验贴解析器接口，负责将非结构化文本（如学习经验文章）解析为结构化 Skill 草稿，支持插入不同 AI 模型实现，当前阶段仅预留接口骨架
- **Skill_Marketplace**：Skill 共创市场，支持用户发布、浏览和订阅社区贡献的 Skill，当前阶段仅预留开放 API 骨架

---

## 需求

### 需求 1：Skill 定义与结构

**用户故事：** 作为开发者，我希望 Skill 有清晰的结构定义，以便能够创建、存储和复用学习方法单元。

#### 验收标准

1. THE Skill_Library SHALL 为每个 Skill 存储以下字段：唯一标识符、名称、描述、适用学科标签、Prompt_Chain 列表、所需 Component 列表、版本号、创建时间。
2. WHEN 一个 Skill 被定义时，THE Skill_Library SHALL 验证其 Prompt_Chain 至少包含一个 Prompt 节点。
3. IF 一个 Skill 引用了未在 Component_Registry 中注册的 Component，THEN THE Skill_Library SHALL 拒绝保存并返回包含缺失组件名称的错误信息。
4. THE Skill_Library SHALL 支持内置 Skill 和用户自定义 Skill 两种类型，并在查询结果中标注类型。
5. WHEN 用户自定义 Skill 被保存时，THE Skill_Library SHALL 将其与创建该 Skill 的 User 标识符关联存储。
6. THE Skill_Library SHALL 支持按学科标签、Skill 名称关键词对 Skill 列表进行过滤查询。

---

### 需求 2：Agent 内核的意图解析与调度

**用户故事：** 作为用户，我希望用自然语言描述学习需求，由系统自动匹配合适的 Skill 和组件，以便我无需手动配置即可开始学习。

#### 验收标准

1. WHEN 用户提交一条 Intent 文本时，THE Agent SHALL 在 3 秒内返回解析结果，包含：识别到的学习目标、推荐的 Skill 列表（最多 3 个）、推荐的 Component 列表。
2. WHEN Agent 推荐 Skill 时，THE Agent SHALL 按匹配度从高到低排序，并为每个推荐 Skill 提供不超过 50 字的推荐理由。
3. IF Agent 无法从 Skill_Library 中找到匹配度高于阈值的 Skill，THEN THE Agent SHALL 提示用户当前无匹配 Skill，并提供进入 DIY_Mode 的入口。
4. WHEN 用户确认 Agent 推荐的 Skill 后，THE Agent SHALL 按 Skill 的 Prompt_Chain 顺序依次调用各 Prompt 节点，并将每步输出传递给下一节点。
5. WHILE 一个 Session 处于活跃状态，THE Agent SHALL 保持该 Session 的上下文，使后续 Intent 能引用本次 Session 中已产生的内容。
6. IF 在 Skill 执行过程中某个 Prompt 节点调用失败，THEN THE Agent SHALL 记录失败节点信息，终止当前 Skill 执行，并向用户展示可读的错误说明。

---

### 需求 3：组件标准化接口与注册机制

**用户故事：** 作为开发者，我希望所有组件遵循统一接口规范，以便 Agent 和 Skill 能够以一致的方式调用任意组件。

#### 验收标准

1. THE Component_Interface SHALL 定义以下标准方法：`open(context)`、`write(data)`、`read(query)`、`close()`，所有 Component 必须实现这四个方法。
2. WHEN 一个新 Component 被注册到 Component_Registry 时，THE Component_Registry SHALL 验证该 Component 实现了完整的 Component_Interface，验证失败则拒绝注册。
3. THE Component_Registry SHALL 为每个已注册 Component 存储：组件标识符、组件名称、版本号、支持的数据类型列表、是否为系统内置标志。
4. WHEN Agent 或 Skill 调用某个 Component 时，THE Component_Registry SHALL 提供该 Component 的实例，调用方无需关心 Component 的内部实现。
5. IF 被调用的 Component 在 Component_Registry 中不存在，THEN THE Component_Registry SHALL 返回包含组件标识符的"组件未找到"错误，而非抛出未处理异常。
6. THE Learning_OS SHALL 内置以下 Component 并完成注册：笔记本（Notebook）、错题本（MistakeBook）、日历（Calendar）、计时器（Timer）、思维导图（MindMap）。

---

### 需求 4：四种使用模式

**用户故事：** 作为用户，我希望能在 Skill 驱动、多课学习、DIY、纯手动四种模式间自由切换，以适应不同的学习场景。

#### 验收标准

1. THE Learning_OS SHALL 在主界面提供模式选择入口，支持用户切换至以下四种模式：Skill_Driver、多课学习模式、DIY_Mode、Manual_Mode。
2. WHEN 用户进入 Skill_Driver 模式时，THE Agent SHALL 接收用户的 Intent 输入，并按需求 2 的调度流程执行。
3. WHEN 用户选择一个多课学习 Skill（例如"备战高考"）时，THE Agent SHALL 根据该 Skill 的定义自动创建对应的多个学科实例，调用 Calendar Component 生成跨学科时间表（包含各学科的学习时段分配），并调用出题、解题、问答、讲义等 Component 为各学科提供学习辅助，形成完整的 Learning_Plan 闭环。
4. WHEN 多课学习 Skill 生成 Learning_Plan 后，THE Calendar Component SHALL 在计划时段到来前向用户发送提醒，提醒内容包含当前时段对应的学科和学习任务。
5. WHEN 用户进入 DIY_Mode 时，THE Learning_OS SHALL 展示 Skill_Library 和 Component_Registry 的完整列表，允许用户手动选择并组合 Skill 和 Component 启动 Session。
6. WHEN 用户进入 Manual_Mode 时，THE Learning_OS SHALL 直接展示所有已注册 Component 的入口，用户可直接打开任意 Component，不经过 Agent 或 Skill。
7. WHEN 用户在任意模式下完成或中断一个 Session 时，THE Learning_OS SHALL 将该 Session 的模式类型、使用的 Skill/Component、开始和结束时间记录到数据层。
8. IF 用户在 Session 进行中切换模式，THEN THE Learning_OS SHALL 提示用户当前 Session 将被暂停，并在用户确认后保存 Session 状态再切换。

---

### 需求 5：数据层统一存储

**用户故事：** 作为用户，我希望我的学习数据、Skill 运行记录和组件使用数据被统一管理，以便我能查看完整的学习历史。

#### 验收标准

1. THE Learning_OS SHALL 使用统一的数据层存储以下三类数据：用户学习数据（笔记、错题、计划等）、Skill 运行数据（执行记录、Prompt 输出）、组件使用数据（各组件的操作日志）。
2. WHEN 一个 Session 结束时，THE Learning_OS SHALL 将本次 Session 产生的所有数据关联到同一个 Session 标识符下存储。
3. THE Learning_OS SHALL 支持按 Session 标识符、日期范围、学科、模式类型查询历史 Session 列表。
4. WHEN 用户查询某个历史 Session 时，THE Learning_OS SHALL 返回该 Session 的完整数据，包括使用的 Skill、Component 及各组件产生的内容。
5. IF 数据写入操作失败，THEN THE Learning_OS SHALL 记录失败日志并向调用方返回写入失败错误，不丢弃待写入数据。
6. THE Learning_OS SHALL 保证同一 User 的数据在多设备间通过云端同步保持一致，同步延迟不超过 10 秒。

---

### 需求 6：渐进式重构与现有功能兼容

**用户故事：** 作为开发者，我希望 Learning OS 架构能在现有 Flutter 代码基础上渐进式引入，以便在不中断现有功能的前提下完成重构。

#### 约束说明

渐进式重构的核心原则是**只调整形式，不改变功能**：现有 chat、solve、mindmap、quiz、notebook 的业务逻辑保持不变，重构工作仅限于将这些模块按新架构归类、调整文件目录结构和命名规范，搭建骨架后再逐步完善。

#### 验收标准

1. THE Learning_OS SHALL 将现有功能模块（chat、solve、mindmap、quiz、notebook）按新架构归类到对应层级（Component/Skill/数据层），仅调整文件目录结构和命名，不重写任何现有业务逻辑。
2. WHEN 重构某个现有模块时，THE Learning_OS SHALL 保持该模块的所有原有功能在重构前后行为一致，不引入功能退化。
3. WHEN 新架构的某个模块骨架尚未完善时，THE Learning_OS SHALL 允许对应功能以原有方式运行，新旧实现可共存于同一版本中。
4. THE Learning_OS SHALL 复用 ui-redesign.md 中定义的底部导航结构（问答、解题、导图、出题、我的），在此基础上叠加 Learning OS 的模式切换入口，不替换现有导航。
5. THE Learning_OS SHALL 复用 `currentSubjectProvider` 作为全局学科上下文，Skill 和 Agent 调度时可读取当前学科信息。
6. WHEN 开发者为现有模块挂载 Component_Interface 时，THE Component_Registry SHALL 接受现有 Flutter Widget 作为 Component 实现，不要求重写 UI 层。
7. THE Learning_OS SHALL 提供迁移映射表，列出现有各 feature 模块在新架构中的对应层级（内核/Skill/Component/数据层）及重构后的目标路径。

---

### 需求 7：Skill 的创建与编辑（DIY 模式支持）

**用户故事：** 作为用户，我希望能自定义 Skill，将自己熟悉的学习方法固化为可复用的 Skill，以便在未来的学习中直接调用。

#### 验收标准

1. WHEN 用户在 DIY_Mode 中选择"创建 Skill"时，THE Learning_OS SHALL 提供 Skill 编辑界面，允许用户填写名称、描述、学科标签，并添加至少一个 Prompt 节点。
2. THE Skill_Library SHALL 支持用户对自己创建的 Skill 进行编辑和删除，不允许用户修改或删除内置 Skill。
3. WHEN 用户保存自定义 Skill 时，THE Skill_Library SHALL 为该 Skill 分配唯一标识符并记录创建时间，保存成功后该 Skill 立即出现在 Skill 列表中。
4. IF 用户尝试删除一个当前正在 Session 中使用的 Skill，THEN THE Skill_Library SHALL 拒绝删除并提示用户该 Skill 正在使用中。
5. THE Learning_OS SHALL 支持用户将自定义 Skill 导出为 JSON 格式文件，以及从 JSON 文件导入 Skill，导入时执行与需求 1 相同的结构验证。
6. FOR ALL 合法的自定义 Skill JSON 文件，导出后再导入 SHALL 产生与原 Skill 字段完全一致的 Skill 对象（往返属性）。

---

### 需求 8：Skill 共创生态与低门槛创建

#### 8.1 对话式 Skill 创建

**用户故事：** 作为用户，我希望通过与 AI 对话的方式创建 Skill，以便在完全不了解任何技术概念的情况下，将自己的学习方法固化为可复用的 Skill。

#### 验收标准

1. WHEN 用户选择"对话式创建 Skill"入口时，THE SkillCreationAdapter SHALL 启动引导对话流程，由 Agent 依次向用户提问以收集 Skill 的步骤、条件和工具信息，每次提问聚焦单一信息点。
2. WHEN Agent 在引导对话中收集到足够信息时，THE SkillCreationAdapter SHALL 自动生成 Skill 草稿，草稿包含名称、描述、学科标签和 Prompt_Chain，并以可读形式呈现给用户确认。
3. WHEN 用户对 Skill 草稿提出修改意见时，THE SkillCreationAdapter SHALL 根据用户的自然语言反馈更新草稿内容，并重新呈现修改后的版本供用户确认。
4. WHEN 用户确认 Skill 草稿时，THE SkillCreationAdapter SHALL 调用 Skill_Library 的保存接口，执行与需求 1 相同的结构验证后完成发布。
5. IF 用户在对话过程中中途退出，THEN THE SkillCreationAdapter SHALL 保存当前对话进度为草稿状态，用户下次进入时可选择继续或放弃该草稿。
6. THE SkillCreationAdapter SHALL 在整个对话式创建流程中不向用户展示任何技术术语（如 Prompt_Chain、Component_Interface 等内部概念）。

---

#### 8.2 经验贴转化为 Skill

**用户故事：** 作为用户，我希望将一篇学习经验文章粘贴给系统，由 AI 自动解析并生成 Skill 草稿，以便我无需手动整理即可将他人经验转化为可复用的 Skill。

#### 验收标准

1. WHEN 用户粘贴一段学习经验文本并触发解析时，THE SkillParser SHALL 从文本中提取步骤列表、涉及工具、时间安排等结构化信息，并生成 Skill 草稿。
2. WHEN SkillParser 完成解析时，THE SkillCreationAdapter SHALL 将解析结果以 Skill 草稿形式呈现给用户，用户可对名称、描述、步骤顺序进行微调后发布。
3. IF SkillParser 无法从输入文本中提取有效步骤（文本过短或内容与学习无关），THEN THE SkillParser SHALL 向用户返回可读的提示信息，说明无法解析的原因，并建议用户补充内容或改用对话式创建。
4. THE SkillParser SHALL 定义为可插拔接口，支持在不修改 SkillCreationAdapter 的前提下替换底层 AI 模型实现。
5. WHEN 经验贴转化生成的 Skill 草稿被用户确认发布时，THE SkillCreationAdapter SHALL 在 Skill 元数据中标注创建来源为"经验贴导入"，并记录原始文本的字符数。
6. FOR ALL 包含有效步骤结构的学习经验文本，SkillParser 解析后生成的 Skill 草稿 SHALL 包含至少一个 Prompt 节点，满足需求 1 的最低结构要求。

---

#### 8.3 开放 API 与接口骨架预留

> **阶段说明：当前阶段仅预留接口骨架，不要求完整实现。** 以下验收标准描述的是接口契约和骨架结构，具体业务逻辑将在后续迭代中填充。

**用户故事：** 作为第三方开发者，我希望通过开放 API 向 Skill_Marketplace 贡献 Skill，以便社区能够共同丰富 Skill 生态。

#### 验收标准

1. THE Skill_Marketplace SHALL 预留以下开放 API 骨架端点：`POST /api/skills`（提交 Skill）、`GET /api/skills`（查询 Skill 列表）、`GET /api/skills/{id}`（获取单个 Skill 详情），当前阶段各端点返回固定的占位响应。
2. THE SkillCreationAdapter SHALL 定义统一适配器接口，声明 `createFromDialog()`、`createFromText(String text)`、`createManually()` 三个方法签名，当前阶段提供空实现骨架，不要求业务逻辑。
3. THE SkillParser SHALL 定义解析器接口，声明 `parse(String text): SkillDraft` 方法签名，当前阶段提供返回空草稿的默认实现，支持后续注入不同 AI 模型。
4. WHEN 第三方通过开放 API 提交 Skill 时，THE Skill_Marketplace SHALL 对提交内容执行与需求 1 相同的结构验证，验证失败时返回包含字段级错误描述的响应。
5. THE Skill_Marketplace SHALL 在 Skill 元数据中记录来源标识（内置 / 用户创建 / 第三方 API 提交），支持按来源类型过滤查询。
