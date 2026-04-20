# 需求文档：Learning OS 全链路生态架构（双引擎共生版）

## 简介

在现有 Flutter + FastAPI 全栈应用基础上，将学习助手升级为"双引擎共生"的学习操作系统生态。核心解决四大痛点：**模式碎片化**（自由学习与计划引导割裂）、**生态未闭环**（组件/Skill 无法互通复用）、**动态调整困难**（计划无法感知用户实际行为）、**共创兼容性差**（第三方 Skill 无法安全接入）。

架构分为六层：
- **统一用户交互层**（Flutter 全栈，含 UI 重设计导航结构）
- **双引擎调度枢纽**（Classmate_Agent 为核心，同时驱动自由操作引擎与 Agent 规划引擎）
- **分层 Skill 池**（Hub 层 / 规划控制层 / 学科能力层 / 工具原子层）
- **标准化组件池**（原子组件 + 复合组件，支持用户手动调用与 Skill 自动调用双路径）
- **核心基础设施层**（全局事件总线 + 统一用户学习数据中枢 + 标准化 Prompt 库 + 题库）
- **后端服务层**（FastAPI，现有路由渐进式扩展）

---

## 词汇表

- **Learning_OS**：整个系统的总称，类比操作系统的学习平台生态架构
- **Classmate_Agent**：调度枢纽 Agent，系统核心，负责需求理解、多轮对话、双引擎调度、组件/Skill 分发
- **ClassTeacher_Agent**：规划控制层 Agent，负责学习计划生成、进度管理、动态调整
- **SubjectTeacher_Agent**：学科能力层 Agent，负责知识点分解、讲义生成、出题/解题、错题分析
- **Free_Engine**：自由操作引擎，响应用户主动发起的指令，调度组件/Skill
- **Planning_Engine**：Agent 规划引擎，由 ClassTeacher_Agent 驱动，执行多 Agent 自动规划与进度管理
- **Dual_Engine_Hub**：双引擎调度枢纽，Classmate_Agent 同时驱动 Free_Engine 和 Planning_Engine 的调度层
- **Skill**：学习方法单元，封装一套 Prompt 链和调用逻辑，存储于 Skill_Pool 中
- **Skill_Pool**：分层 Skill 仓库，按 Hub 层 / 规划控制层 / 学科能力层 / 工具原子层四层组织
- **Skill_Manifest**：每个 Skill 必须携带的元数据清单，包含 ID、名称、描述、层级、权限声明、依赖声明、Prompt 模板包、测试用例
- **Atomic_Component**：原子组件，最小不可分割功能单元（OCR、PDF 解析、Markdown 渲染、公式识别），仅由复合组件或原子 Skill 调用
- **Composite_Component**：复合组件，带 UI 的完整功能模块（错题本、思维导图生成器、讲义编辑器、AI 出题器、问答室），支持用户手动调用与 Skill 自动调用双路径
- **Component_Contract**：复合组件标准契约，定义手动调用入口（Flutter Widget）、API 调用接口（RESTful/WebSocket）、完整生命周期事件钩子
- **Component_Registry**：管理所有已注册 Component 的注册表，提供统一发现与实例化接口
- **Event_Bus**：全局事件总线，实时监控所有学习行为事件，标准化事件集写入 Learning_Data_Hub
- **Learning_Event**：标准化学习事件，分为计划事件、学习行为事件、知识掌握事件、用户主动反馈事件四类
- **Learning_Data_Hub**：统一用户学习数据中枢，存储用户画像、学习进度、知识掌握度，双引擎共享同一数据源
- **Learning_Plan**：由 ClassTeacher_Agent 生成的"目标 + 时间窗口 + 优先级"弹性框架计划，非刚性时间表
- **Adjustment_Level**：梯度调整等级，分为轻度（自动应用）、中度（推送提案用户确认）、重度（多轮对话重新规划）三级
- **Interruption_Level**：打断等级，分为静默同步（仅数据同步）、弱提醒（退出组件时轻通知）、强交互（用户主动触发或严重偏离计划）三级
- **Prompt_Library**：标准化 Prompt 库，与代码解耦，Skill 的 Prompt 模板包从此处加载
- **Session**：一次完整的学习会话，包含引擎模式、使用的 Skill/Component 及产生的数据
- **User**：使用 Learning_OS 的学习者
- **Intent**：用户输入的自然语言学习需求，由 Classmate_Agent 解析为结构化调度指令
- **Prompt_Chain**：Skill 内部的有序 Prompt 序列，定义 AI 交互流程
- **SkillCreationAdapter**：统一 Skill 创建适配器接口，对话式创建、经验贴导入、手动编辑三种路径均通过该接口接入 Skill_Pool
- **SkillParser**：经验贴解析器接口，将非结构化文本解析为结构化 Skill 草稿，支持插拔不同 AI 模型实现
- **Skill_Marketplace**：Skill 共创市场，支持用户发布、浏览、订阅社区贡献的 Skill，含沙箱隔离与审核机制
- **Sandbox**：共创 Skill 运行沙箱，隔离第三方 Skill 的执行环境，防止越权访问数据或组件

---

## 需求

### 需求 1：双引擎共生架构——同源数据与无缝切换

**用户故事：** 作为用户，我希望自由学习和计划引导两种模式共享同一套数据和组件，以便我无需手动切换模式，系统能无缝地在两种模式间协同工作。

#### 验收标准

1. THE Dual_Engine_Hub SHALL 使 Free_Engine 和 Planning_Engine 共享同一个 Learning_Data_Hub 实例，任何一方写入的数据对另一方立即可见，不存在数据副本或同步延迟。
2. THE Dual_Engine_Hub SHALL 使 Free_Engine 和 Planning_Engine 共享同一个 Skill_Pool 和 Component_Registry，两个引擎调用相同 Skill/Component 时使用相同的实现。
3. WHEN 用户在 Free_Engine 模式下完成一个学习任务时，THE Planning_Engine SHALL 通过 Event_Bus 感知该事件，并在 30 秒内更新对应 Learning_Plan 中的任务状态，无需用户手动标记。
4. WHEN Planning_Engine 检测到用户正在使用 Free_Engine 进行学习时，THE Dual_Engine_Hub SHALL 根据当前 Interruption_Level 决定是否打断用户：静默同步时不发出任何通知，弱提醒时仅在用户退出当前组件后显示轻量通知，强交互时才主动弹出对话。
5. THE Learning_Plan SHALL 采用"目标 + 时间窗口 + 优先级"弹性框架，不绑定固定时间点，允许任务在时间窗口内以任意顺序完成。
6. IF 用户的实际学习行为与 Learning_Plan 的时间窗口严重偏离（连续 3 天未完成任何计划任务），THEN THE Planning_Engine SHALL 将 Interruption_Level 升级为强交互，通过 Classmate_Agent 发起多轮对话询问用户是否需要调整计划。

---

### 需求 2：标准化复合组件契约

**用户故事：** 作为开发者，我希望所有复合组件遵循统一的标准契约，以便用户可以手动调用组件，Skill 也可以通过 API 自动调用同一组件，且所有调用行为都被事件总线记录。

#### 验收标准

1. THE Component_Contract SHALL 要求每个 Composite_Component 同时提供以下三项：标准 Flutter Widget 手动调用入口、标准化 RESTful 或 WebSocket API 调用接口、完整生命周期事件钩子（pre_call、executing、completed、failed）。
2. WHEN 任意 Composite_Component 的生命周期事件被触发时，THE Component_Contract SHALL 将该事件写入 Event_Bus，事件载荷包含：组件标识符、事件类型、触发时间戳、调用来源（用户手动 / Skill 自动）、关联的 Session 标识符。
3. WHEN 一个新 Composite_Component 被注册到 Component_Registry 时，THE Component_Registry SHALL 验证该组件实现了完整的 Component_Contract（三项均满足），验证失败则拒绝注册并返回缺失项列表。
4. THE Component_Registry SHALL 为每个已注册 Composite_Component 存储：组件标识符、组件名称、版本号、支持的数据类型列表、调用方式（手动/自动/双路径）、是否为系统内置标志。
5. IF 被调用的 Composite_Component 在 Component_Registry 中不存在，THEN THE Component_Registry SHALL 返回包含组件标识符的"组件未找到"错误，不抛出未处理异常。
6. THE Learning_OS SHALL 内置以下 Composite_Component 并完成注册，均支持双路径调用：错题本（MistakeBook）、思维导图生成器（MindMapGenerator）、讲义编辑器（LectureEditor）、AI 出题器（QuizGenerator）、问答室（QARoom）。
7. THE Learning_OS SHALL 内置以下 Atomic_Component 并完成注册，仅供复合组件或原子 Skill 调用：OCR 识别（OcrComponent）、PDF 解析（PdfParser）、Markdown 渲染（MarkdownRenderer）、公式识别（FormulaRecognizer）。

---

### 需求 3：分层 Skill 系统与标准封装规范

**用户故事：** 作为开发者，我希望 Skill 按四层分类并遵循标准封装规范，以便不同层级的 Agent 能够调用权限范围内的 Skill，且 Skill 的 Prompt 模板与代码完全解耦。

#### 验收标准

1. THE Skill_Pool SHALL 将所有 Skill 按以下四层分类存储，并在 Skill_Manifest 中标注层级：Hub 层（仅 Classmate_Agent 可调用）、规划控制层（仅 ClassTeacher_Agent 可调用）、学科能力层（仅 SubjectTeacher_Agent 可调用）、工具原子层（任意 Agent 可调用）。
2. WHEN 一个 Agent 尝试调用不属于其权限层级的 Skill 时，THE Skill_Pool SHALL 拒绝该调用并返回包含调用方 Agent 标识符和目标 Skill 层级的权限错误，不执行 Skill 逻辑。
3. THE Skill_Manifest SHALL 为每个 Skill 包含以下六项：元数据（ID、名称、描述、版本、层级）、接口契约（标准化输入/输出 schema）、权限声明（可访问的数据范围）、依赖声明（所需 Component 和其他 Skill 列表）、Prompt 模板包引用（指向 Prompt_Library 中的模板 ID）、测试用例（至少一个输入/输出示例）。
4. WHEN 一个 Skill 被保存到 Skill_Pool 时，THE Skill_Pool SHALL 验证其 Skill_Manifest 包含全部六项且 Prompt 模板包引用在 Prompt_Library 中存在，验证失败则拒绝保存并返回缺失项列表。
5. THE Skill_Pool SHALL 将 Skill 的 Prompt 模板与 Skill 执行代码分离存储，Skill 执行时从 Prompt_Library 动态加载模板，修改 Prompt 模板不需要重新部署 Skill 代码。
6. THE Skill_Pool SHALL 支持按层级、学科标签、Skill 名称关键词对 Skill 列表进行过滤查询，查询结果包含 Skill_Manifest 的完整元数据部分。
7. FOR ALL 合法的 Skill JSON 导出文件，导出后再导入 SHALL 产生与原 Skill 的 Skill_Manifest 字段完全一致的 Skill 对象（往返属性）。

---

### 需求 4：全局事件总线与标准化学习事件集

**用户故事：** 作为系统，我希望所有学习行为都通过标准化事件写入全局事件总线，以便 Planning_Engine 能够实时感知用户行为并触发动态调整。

#### 验收标准

1. THE Event_Bus SHALL 定义以下四类标准 Learning_Event，每类事件包含事件类型、时间戳、用户标识符、关联 Session 标识符、事件载荷：
   - 计划事件：task_completed、task_overdue、task_early_completed、plan_modified
   - 学习行为事件：component_called、lecture_generated、mindmap_created、mistake_entered、quiz_answered
   - 知识掌握事件：question_accuracy_updated、knowledge_point_annotated、mistake_corrected
   - 用户主动反馈事件：plan_adjustment_requested、mastery_feedback_submitted、difficulty_feedback_submitted
2. WHEN 任意 Composite_Component 的生命周期钩子触发时，THE Event_Bus SHALL 在 500 毫秒内接收并持久化对应的 Learning_Event，不丢失事件。
3. THE Event_Bus SHALL 支持订阅者模式，Planning_Engine 和 Classmate_Agent 可注册为订阅者，接收指定类型的 Learning_Event 推送。
4. WHEN Planning_Engine 接收到 task_overdue 事件时，THE Planning_Engine SHALL 记录该事件并累计连续逾期次数，用于触发梯度调整策略。
5. IF Event_Bus 的持久化写入失败，THEN THE Event_Bus SHALL 将失败事件写入本地重试队列，并在网络恢复后自动重试，重试间隔不超过 60 秒。
6. THE Event_Bus SHALL 支持按用户标识符、事件类型、时间范围查询历史 Learning_Event 列表，用于学习行为分析。

---

### 需求 5：统一用户学习数据中枢

**用户故事：** 作为用户，我希望我的用户画像、学习进度和知识掌握度被统一管理，以便双引擎都能基于同一份数据做出决策，我也能查看完整的学习历史。

#### 验收标准

1. THE Learning_Data_Hub SHALL 统一存储以下三类数据，并通过单一访问接口对双引擎暴露：用户画像（学习偏好、历史 Skill 使用记录、各学科学习时长）、学习进度（Learning_Plan 任务完成状态、各学科进度百分比）、知识掌握度（各知识点的正确率、错题记录、标注情况）。
2. WHEN 一个 Session 结束时，THE Learning_Data_Hub SHALL 将本次 Session 产生的所有数据关联到同一个 Session 标识符下存储，包括使用的 Skill、Component 及各组件产生的内容。
3. THE Learning_Data_Hub SHALL 支持按 Session 标识符、日期范围、学科、引擎模式查询历史 Session 列表，查询响应时间不超过 2 秒。
4. WHEN Classmate_Agent 或 ClassTeacher_Agent 需要读取用户数据时，THE Learning_Data_Hub SHALL 根据调用方的权限声明返回对应范围的数据，不返回超出权限范围的字段。
5. IF 数据写入操作失败，THEN THE Learning_Data_Hub SHALL 记录失败日志并向调用方返回写入失败错误，不丢弃待写入数据，并触发 Event_Bus 的重试机制。
6. THE Learning_Data_Hub SHALL 保证同一 User 的数据在多设备间通过云端同步保持一致，同步延迟不超过 10 秒。

---

### 需求 6：全链路反馈与梯度动态调整策略

**用户故事：** 作为用户，我希望系统能根据我的实际学习行为自动调整计划，轻微偏差自动处理，重大偏差才来询问我，以便我不被频繁打扰的同时计划始终保持合理。

#### 验收标准

1. THE Planning_Engine SHALL 实现被动监控循环：持续订阅 Event_Bus 的 Learning_Event，在无需用户反馈的情况下自动执行轻度调整。
2. THE Planning_Engine SHALL 实现主动反馈循环：当用户通过 Classmate_Agent 主动发起计划调整请求时，执行精确的中度或重度调整。
3. WHEN Planning_Engine 检测到单次任务提前完成（task_early_completed）或单次任务逾期（task_overdue）时，THE Planning_Engine SHALL 执行轻度调整：仅调整任务顺序或频率，自动应用，同时在 Learning_Data_Hub 中记录调整历史，用户可在 24 小时内一键回滚。
4. WHEN Planning_Engine 检测到连续 2-3 次任务逾期时，THE Planning_Engine SHALL 执行中度调整：生成调整时长或优先级的提案，通过 Classmate_Agent 以弱提醒方式推送给用户，用户确认后应用，拒绝则保持原计划。
5. WHEN Planning_Engine 检测到多日连续失败或用户主动提交 plan_adjustment_requested 事件时，THE Planning_Engine SHALL 执行重度调整：通过 Classmate_Agent 发起多轮对话，收集用户反馈后由 ClassTeacher_Agent 重新生成 Learning_Plan，用户可对比新旧版本后确认，确认前可随时回滚到任意历史版本。
6. THE Planning_Engine SHALL 在执行任意级别调整前，将调整触发原因、调整内容、调整时间记录到 Learning_Data_Hub 的调整历史中，支持用户查询。
7. IF 用户在 24 小时内回滚轻度调整，THEN THE Planning_Engine SHALL 恢复调整前的任务顺序和频率，并将回滚事件写入 Event_Bus。

---

### 需求 7：Classmate_Agent 双引擎调度枢纽

**用户故事：** 作为用户，我希望通过与 Classmate_Agent 对话就能完成所有学习操作，无论是自由学习还是计划引导，都由同一个 Agent 统一响应。

#### 验收标准

1. WHEN 用户提交一条 Intent 文本时，THE Classmate_Agent SHALL 在 3 秒内返回解析结果，包含：识别到的学习目标、推荐的 Skill 列表（最多 3 个，按匹配度排序，每个附不超过 50 字的推荐理由）、推荐的 Component 列表。
2. WHEN Classmate_Agent 判断用户意图属于自由学习时，THE Free_Engine SHALL 响应该 Intent，直接调度对应 Skill 或 Component，不创建或修改 Learning_Plan。
3. WHEN Classmate_Agent 判断用户意图属于计划管理时，THE Planning_Engine SHALL 响应该 Intent，由 ClassTeacher_Agent 处理计划生成或调整逻辑。
4. WHILE 一个 Session 处于活跃状态，THE Classmate_Agent SHALL 保持该 Session 的上下文，使后续 Intent 能引用本次 Session 中已产生的内容。
5. IF Classmate_Agent 无法从 Skill_Pool 中找到匹配度高于阈值的 Skill，THEN THE Classmate_Agent SHALL 提示用户当前无匹配 Skill，并提供进入 DIY 创建 Skill 的入口。
6. IF 在 Skill 执行过程中某个 Prompt 节点调用失败，THEN THE Classmate_Agent SHALL 记录失败节点信息，终止当前 Skill 执行，并向用户展示可读的错误说明，不暴露内部技术细节。

---

### 需求 8：UI 导航结构与全局学科上下文

**用户故事：** 作为用户，我希望通过底部 5 个 Tab 快速访问所有功能，并通过顶部学科切换栏随时切换当前学科，以便所有功能页都在同一学科上下文下工作。

#### 验收标准

1. THE Learning_OS SHALL 实现底部导航栏，包含以下 5 个 Tab（按顺序）：问答（/chat）、解题（/solve）、导图（/mindmap）、出题（/quiz）、我的（/profile），使用 ShellRoute 实现，切换 Tab 时保持各页面状态。
2. THE Learning_OS SHALL 在问答、解题、导图、出题四个功能页顶部统一显示 SubjectBar，SubjectBar 展示当前选中学科名称，点击后弹出底部抽屉列出所有学科，支持切换、新建、管理操作。
3. THE Learning_OS SHALL 使用 `currentSubjectProvider`（`StateProvider<Subject?>`）作为全局学科上下文，所有功能页、Skill 调度、Agent 调用均读取该 Provider 获取当前学科，不允许各页面维护独立的学科状态副本。
4. WHEN 用户在 SubjectBar 切换学科时，THE Learning_OS SHALL 更新 `currentSubjectProvider` 的值，所有订阅该 Provider 的功能页在 500 毫秒内响应学科切换，刷新页面内容。
5. WHILE 未选择学科时，THE Learning_OS SHALL 在功能页内容区域显示"请先选择学科"引导提示，不展示功能内容，SubjectBar 显示"请选择学科"占位文本。
6. THE Learning_OS SHALL 实现以下路由结构：`/login`、`/register`、`/`（Shell）、`/chat`、`/solve`、`/mindmap`、`/quiz`、`/profile`、`/profile/subjects`、`/profile/subjects/:id`、`/profile/history`，路由配置集中在 `lib/routes/app_router.dart`。
7. THE Learning_OS SHALL 在"我的"页面（/profile）提供学科管理入口（跳转 /profile/subjects）和对话历史入口（跳转 /profile/history），学科管理页保留现有学科列表 UI，每个学科卡片点击进入含资料库和历年题两个 Tab 的学科资料页。

---

### 需求 9：渐进式重构与现有功能兼容

**用户故事：** 作为开发者，我希望 Learning OS 架构能在现有 Flutter + FastAPI 代码基础上渐进式引入，以便在不中断现有功能的前提下完成重构。

#### 约束说明

渐进式重构的核心原则是**只调整形式，不改变功能**：现有 chat、solve、mindmap、quiz、notebook 的业务逻辑保持不变，重构工作仅限于将这些模块按新架构归类、调整文件目录结构和命名规范，搭建骨架后再逐步完善。

#### 验收标准

1. THE Learning_OS SHALL 将现有功能模块（chat、solve、mindmap、quiz、notebook）按新架构归类到对应层级（Composite_Component / Skill / 数据层），仅调整文件目录结构和命名，不重写任何现有业务逻辑。
2. WHEN 重构某个现有模块时，THE Learning_OS SHALL 保持该模块的所有原有功能在重构前后行为一致，不引入功能退化。
3. WHEN 新架构的某个模块骨架尚未完善时，THE Learning_OS SHALL 允许对应功能以原有方式运行，新旧实现可共存于同一版本中。
4. THE Learning_OS SHALL 提供迁移映射表，列出现有各 feature 模块在新架构中的对应层级（Classmate_Agent / Skill_Pool 层级 / Composite_Component / 数据层）及重构后的目标路径。
5. WHEN 开发者为现有模块挂载 Component_Contract 时，THE Component_Registry SHALL 接受现有 Flutter Widget 作为 Composite_Component 的手动调用入口实现，不要求重写 UI 层。
6. THE Learning_OS SHALL 复用现有 FastAPI 路由（`/api/chat`、`/api/exam`、`/api/notebooks` 等）作为 Composite_Component 的 API 调用接口，通过在现有路由上添加生命周期事件钩子完成 Component_Contract 适配，不重写路由逻辑。

---

### 需求 10：Skill 定义、创建与 DIY 支持

**用户故事：** 作为用户，我希望能自定义 Skill 或通过 AI 对话创建 Skill，将自己熟悉的学习方法固化为可复用的 Skill，以便在未来的学习中直接调用。

#### 验收标准

1. THE Skill_Pool SHALL 为每个 Skill 存储完整的 Skill_Manifest（六项，见需求 3），并支持内置 Skill 和用户自定义 Skill 两种类型，在查询结果中标注类型。
2. WHEN 用户选择"对话式创建 Skill"入口时，THE SkillCreationAdapter SHALL 启动引导对话流程，由 Classmate_Agent 依次向用户提问以收集 Skill 的步骤、条件和工具信息，每次提问聚焦单一信息点，全程不向用户展示任何技术术语。
3. WHEN Classmate_Agent 在引导对话中收集到足够信息时，THE SkillCreationAdapter SHALL 自动生成 Skill 草稿，草稿包含名称、描述、学科标签和 Prompt_Chain，并以可读形式呈现给用户确认。
4. WHEN 用户粘贴一段学习经验文本并触发解析时，THE SkillParser SHALL 从文本中提取步骤列表、涉及工具、时间安排等结构化信息，并生成 Skill 草稿；IF SkillParser 无法提取有效步骤，THEN THE SkillParser SHALL 返回可读提示并建议改用对话式创建。
5. THE SkillParser SHALL 定义为可插拔接口，支持在不修改 SkillCreationAdapter 的前提下替换底层 AI 模型实现。
6. THE Skill_Pool SHALL 支持用户对自己创建的 Skill 进行编辑和删除，不允许用户修改或删除内置 Skill；IF 用户尝试删除一个当前正在 Session 中使用的 Skill，THEN THE Skill_Pool SHALL 拒绝删除并提示用户该 Skill 正在使用中。
7. IF 用户在对话式创建过程中中途退出，THEN THE SkillCreationAdapter SHALL 保存当前对话进度为草稿状态，用户下次进入时可选择继续或放弃该草稿。
8. FOR ALL 包含有效步骤结构的学习经验文本，SkillParser 解析后生成的 Skill 草稿 SHALL 包含至少一个 Prompt 节点，满足 Skill_Manifest 的最低结构要求。

---

### 需求 11：Skill 共创市场与沙箱安全机制

> **阶段说明：当前阶段仅预留接口骨架，不要求完整实现。** 以下验收标准描述接口契约和骨架结构，具体业务逻辑将在后续迭代中填充。

**用户故事：** 作为第三方开发者，我希望通过开放 API 向 Skill_Marketplace 贡献 Skill，并通过沙箱机制保证社区 Skill 的安全性，以便用户可以放心使用社区贡献的 Skill。

#### 验收标准

1. THE Skill_Marketplace SHALL 预留以下开放 API 骨架端点：`POST /api/marketplace/skills`（提交 Skill）、`GET /api/marketplace/skills`（查询列表）、`GET /api/marketplace/skills/{id}`（获取详情），当前阶段各端点返回固定的占位响应。
2. WHEN 第三方通过开放 API 提交 Skill 时，THE Skill_Marketplace SHALL 对提交内容执行与需求 3 相同的 Skill_Manifest 结构验证，验证失败时返回包含字段级错误描述的响应。
3. THE Skill_Marketplace SHALL 在 Skill 元数据中记录来源标识（内置 / 用户创建 / 第三方 API 提交 / 经验贴导入），支持按来源类型过滤查询。
4. WHEN 用户从 Skill_Marketplace 导入第三方 Skill 时，THE Sandbox SHALL 在隔离环境中执行该 Skill，隔离环境仅允许访问该 Skill 权限声明中列出的 Component 和数据范围，不允许访问其他用户数据或系统级 API。
5. THE SkillCreationAdapter SHALL 定义统一适配器接口，声明 `createFromDialog()`、`createFromText(String text)`、`createManually()` 三个方法签名，当前阶段提供空实现骨架，不要求业务逻辑。
6. THE SkillParser SHALL 定义解析器接口，声明 `parse(String text): SkillDraft` 方法签名，当前阶段提供返回空草稿的默认实现，支持后续注入不同 AI 模型。
