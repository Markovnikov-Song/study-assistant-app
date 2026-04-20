# 需求文档：Learning OS Component 生态完善与�?Agent 系统

## 简�?

本文档描述在现有 Learning OS 三层架构（AgentKernel / SkillLibrary / ComponentRegistry）基础上，
完善现有 Component 生态并构建�?Agent 协作系统的需求�?

**第一部分：完善现�?Components**

对现�?Component 进行补全和新增，使其具备完整的数�?API，能够被 Skill 通过 ComponentInterface 调用�?
同时也能作为独立功能供用户直接使用：

- **错题本（MistakeBook�?*：补全数�?API，支�?Skill 读取错题数据
- **日历（Calendar�?*：全�?Component，用于学习路线的时间规划
- **计时器（Timer�?*：全�?Component，番茄钟与专注记�?
- **费曼学习（Feynman�?*：全�?Component，AI 辅助的费曼学习法
- **学习数据统计（LearningStats�?*：全�?Component，汇总各 Component 使用数据

**第二部分：多 Agent 系统**

构建三个具有特定角色和职责的 Agent，形�?学科老师 �?班主�?�?同桌"的协作链路：

- **学科老师 Agent（SubjectTeacher�?*：深耕单一学科，分析薄弱点，输出学科分析报�?
- **班主�?Agent（ClassDirector�?*：统筹所有学科，生成跨科时间表，写入日历
- **同桌 Agent（Deskmate�?*：日常执行与陪伴，提醒任务，记录完成情况

**数据流总览�?*

```
用户学习材料（讲�?大纲/历年题）
        �?
SubjectTeacher Agent（各学科分析报告�?
        �?
ClassDirector Agent（跨科时间表）→ Calendar Component（写入任务）
        �?
Deskmate Agent（今日任务提醒）�?Timer Component（专注记录）
        �?
LearningStats Component（汇总数据）�?SubjectTeacher / ClassDirector（反馈调整）
```

---

## 词汇�?

- **Component**：独立可用的学习小应用，有完�?UI 和数�?API，实�?ComponentInterface（open/write/read/close），可被 Skill 调用，也可独立使�?
- **ComponentInterface**：Component 对外暴露的标准化调用接口，包�?`open(context)`、`write(data)`、`read(query)`、`close()` 四个方法（继承自 learning-os-architecture�?
- **ComponentRegistry**：管理所有已注册 Component 的注册表（继承自 learning-os-architecture�?
- **Skill**：调�?Components 的学习方法论，描�?如何�?，封装一�?Prompt 链和调用逻辑
- **Agent**：有特定角色和职责的 AI，可访问特定数据范围，与用户对话，也可被 Skill 自动调用
- **MistakeBook**：错题本 Component，存储用户做错的题目及分�?
- **Calendar**：日�?Component，管理学习任务的时间规划
- **Timer**：计时器 Component，记录专注学习时�?
- **Feynman**：费曼学�?Component，通过"向小白讲�?检验知识掌握程�?
- **LearningStats**：学习数据统�?Component，汇总各 Component 的使用数�?
- **SubjectTeacher**：学科老师 Agent，专注单一学科的分析与策略制定
- **ClassDirector**：班主任 Agent，统筹多学科时间分配与学习计�?
- **Deskmate**：同�?Agent，负责日常任务提醒与学习陪伴
- **SubjectAnalysisReport**：学科分析报告，�?SubjectTeacher 生成，包含薄弱章节、建议学习顺序、预计所需时间
- **ExamSchedule**：考试时间表，用户设置的各科考试日期
- **AvailableTimeConfig**：可用时间配置，用户设置的每日可用学习时�?
- **FocusSession**：一次完整的专注学习记录，包含学科、时长、开�?结束时间
- **FeynmanSession**：一次费曼学习会话，包含知识点、对话记录、AI 总结
- **PomodoroConfig**：番茄钟配置，包含专注时长和休息时长
- **LearningTask**：日历中的一条学习任务，包含任务名、学科、时长、截止时间、完成状�?
- **User**：使�?Learning OS 的学习者（继承�?learning-os-architecture�?
- **AgentKernel**：系统内核，负责意图解析、Skill 匹配与组件调度（继承�?learning-os-architecture�?
- **currentSubjectProvider**：全局学科状态（Riverpod `StateProvider<Subject?>`），所有功能页�?Component 通过�?Provider 读取当前选中学科，无需用户重复选择（继承自 ui-redesign�?

---

## 需�?

---

## 第一部分：完善现�?Components

---

### 需�?1：错题本 Component 完善——完整数�?API

**用户故事�?* 作为用户，我希望错题本不仅有 UI 界面，还能被 Skill �?Agent 读取我的错题数据，以便系统能根据我的薄弱点自动制定学习策略�?

**独立使用场景�?* 用户�?文具�?页面进入错题�?Component，手动添加错题、查看错题列表、标记已掌握；默认展示全局 `currentSubjectProvider` 对应学科的错题，可手动切换学科筛选�?

**�?Skill 调用场景�?* Skill 通过 ComponentInterface �?`read(query)` 方法查询指定学科/章节的错题，用于生成针对性练习或分析报告�?

#### 验收标准

1. THE MistakeBook SHALL 实现完整�?ComponentInterface，包�?`open(context)`、`write(data)`、`read(query)`、`close()` 四个方法，并�?ComponentRegistry 中完成注册�?
2. THE MistakeBook SHALL 为每条错题存储以下字段：唯一标识符、学科、章节、错误类型（概念错误/计算错误/审题错误/其他）、题目内容、用户答案、正确答案、错误分析、创建时间、最近复习时间、掌握状态（未掌�?复习�?已掌握）�?
3. WHEN 用户通过 UI 添加一条错题时，THE MistakeBook SHALL 将错题数据持久化存储，并在列表中立即显示新增条目�?
4. WHEN Skill 通过 `read(query)` 调用 MistakeBook 时，THE MistakeBook SHALL 支持以下查询参数的任意组合：学科、章节、错误类型、掌握状态、时间范围，并返回符合条件的错题列表�?
5. THE MistakeBook SHALL 支持按学科、章节、错误类型、掌握状态对错题列表进行筛选和排序�?
6. WHEN 用户将一条错题标记为"已掌�?时，THE MistakeBook SHALL 更新该错题的掌握状态，并记录标记时间�?
7. IF Skill 通过 `write(data)` �?MistakeBook 写入错题时，THEN THE MistakeBook SHALL 验证数据包含必填字段（学科、题目内容、正确答案），验证失败时返回包含缺失字段名称的错误信息�?
8. THE MistakeBook SHALL 提供统计接口，返回各学科的错题数量、各错误类型的分布、近 7 天新增错题数，供 LearningStats Component 汇总使用�?

---

### 需�?2：日�?Component——学习任务时间规�?

**用户故事�?* 作为用户，我希望有一个学习日历来管理我的学习任务，以便清楚地知道每天需要完成哪些学习内容，并在任务到来时收到提醒�?

**独立使用场景�?* 用户�?文具�?页面进入日历 Component，手动创建学习任务、查看今�?本周任务、标记任务完成�?

**�?Skill 调用场景�?* ClassDirector Agent 通过 `write(data)` 批量写入跨科学习时间表；Skill 通过 `read(query)` 查询某日的任务完成情况，用于调整后续计划�?

#### 验收标准

1. THE Calendar SHALL 实现完整�?ComponentInterface，并�?ComponentRegistry 中完成注册�?
2. THE Calendar SHALL 为每�?LearningTask 存储以下字段：唯一标识符、任务名称、学科、预计时长（分钟）、截止时间、完成状态（待完�?进行�?已完�?已跳过）、创建来源（用户手动/Skill 写入）、创建时间、完成时间�?
3. WHEN 用户�?Skill 创建一�?LearningTask 时，THE Calendar SHALL 验证任务名称和截止时间为必填字段，验证失败时返回包含缺失字段名称的错误信息�?
4. THE Calendar SHALL 提供"今日视图"�?本周视图"，分别展示当日和本周的所�?LearningTask，按截止时间升序排列�?
5. WHEN 用户将一�?LearningTask 标记�?已完�?时，THE Calendar SHALL 记录完成时间，并更新任务状态�?
6. WHEN 一�?LearningTask 的截止时间到来前 30 分钟时，THE Calendar SHALL 向用户发�?App 内消息提醒，提醒内容包含任务名称、学科和预计时长�?
7. WHEN Skill 通过 `write(data)` 批量写入 LearningTask 列表时，THE Calendar SHALL 支持一次写入最�?50 条任务，并返回成功写入的任务 ID 列表�?
8. WHEN Skill 通过 `read(query)` 查询任务时，THE Calendar SHALL 支持按日期范围、学科、完成状态过滤，并返回符合条件的 LearningTask 列表及各状态的数量统计�?
9. IF 用户尝试创建与已有任务时间段完全重叠�?LearningTask，THEN THE Calendar SHALL 提示用户存在时间冲突，并允许用户选择继续创建或取消�?

---

### 需�?3：计时器 Component——番茄钟与专注记�?

**用户故事�?* 作为用户，我希望有一个计时器来帮助我专注学习，并自动记录每次专注的学科和时长，以便了解自己的学习时间分布�?

**独立使用场景�?* 用户�?文具�?页面进入计时�?Component，启动番茄钟或自定义时长计时，查看历史专注记录；学科自动读取全局 `currentSubjectProvider`，无需重新选择�?

**�?Skill 调用场景�?* Skill 通过 `open(context)` 启动指定学科的计时器；通过 `read(query)` 查询某学科的历史专注时长，用于统计学习投入�?

#### 验收标准

1. THE Timer SHALL 实现完整�?ComponentInterface，并�?ComponentRegistry 中完成注册�?
2. THE Timer SHALL 支持两种计时模式：番茄钟模式（默认专�?25 分钟 + 休息 5 分钟，可通过 PomodoroConfig 自定义时长）和自定义模式（用户手动输入专注时长，范围 1 �?180 分钟）�?
3. WHEN 用户启动一次计时时，THE Timer SHALL 优先读取全局 `currentSubjectProvider` 作为当前学科，若全局学科未设置则提示用户选择学科，并将学科信息关联到本次 FocusSession�?
4. WHEN 一次专注计时结束时，THE Timer SHALL 自动将本�?FocusSession（学科、实际专注时长、开始时间、结束时间）持久化存储�?
5. WHEN 番茄钟专注阶段结束时，THE Timer SHALL 向用户发�?App 内消息提醒，提示进入休息阶段；休息阶段结束时，THE Timer SHALL 再次提醒用户可以开始下一个番茄钟�?
6. IF 用户在计时进行中手动停止计时，THEN THE Timer SHALL 将已经过的时长（不少�?1 分钟）记录为一�?FocusSession，不�?1 分钟则丢弃�?
7. WHEN Skill 通过 `open(context)` 启动计时器时，THE Timer SHALL 接受 context 中的学科参数，自动预填学科选择，无需用户再次选择�?
8. WHEN Skill 通过 `read(query)` 查询历史记录时，THE Timer SHALL 支持按学科、日期范围过滤，返回 FocusSession 列表及该范围内的总专注时长（分钟）�?
9. THE Timer SHALL �?UI 中展示当日各学科的专注时长分布（饼图或条形图），数据来源为当日所�?FocusSession�?

---

### 需�?4：费曼学�?Component——AI 辅助知识讲解

**用户故事�?* 作为用户，我希望通过�?AI 扮演�?小白"讲解知识点来检验自己的理解，以便发现知识盲区并加深记忆�?

**独立使用场景�?* 用户�?文具�?页面进入费曼学习 Component，选择知识点，�?AI 小白进行对话式讲解，最后获�?AI 老师的总结反馈；知识点所属学科自动读取全局 `currentSubjectProvider`�?

**�?Skill 调用场景�?* Skill 通过 `open(context)` 启动费曼学习，传入指定知识点和背景材料；通过 `read(query)` 获取历史 FeynmanSession 的总结，用于分析知识掌握情况�?

#### 验收标准

1. THE Feynman SHALL 实现完整�?ComponentInterface，并�?ComponentRegistry 中完成注册�?
2. WHEN 用户启动一次费曼学习时，THE Feynman SHALL 要求用户输入或选择一个知识点，并可选择关联一份已有讲�?大纲作为背景知识�?
3. WHEN 费曼学习开始后，THE Feynman SHALL 启动"小白"角色�?AI，该 AI 以不懂该知识点的学生身份与用户对话，实际上基于背景知识（若有）对用户讲解中的漏洞进行针对性提问�?
4. WHILE 用户处于讲解阶段，THE Feynman SHALL 保证"小白"AI 的提问方式为引导性提问（�?那如�?..呢？""你说�?..是什么意思？"），不直接指出用户的错误或给出正确答案�?
5. WHEN 用户主动结束讲解或讲解轮次达到上限（默认 10 轮）时，THE Feynman SHALL 切换�?老师"角色，生成总结报告，内容包含：讲解得好的部分、存在的知识盲区、建议复习的内容�?
6. WHEN 费曼学习总结生成后，THE Feynman SHALL 提供"保存到笔记本"按钮，用户确认后将总结内容写入 Notebook Component�?
7. IF 用户选择了背景讲义，THEN THE Feynman SHALL �?老师"总结中对照讲义内容，指出用户讲解中遗漏的重要知识点�?
8. WHEN Skill 通过 `open(context)` 启动费曼学习时，THE Feynman SHALL 接受 context 中的知识点和背景材料参数，自动预填相关信息�?
9. WHEN Skill 通过 `read(query)` 查询历史 FeynmanSession 时，THE Feynman SHALL 支持按知识点、学科、日期范围过滤，返回 FeynmanSession 列表（含总结内容）�?
10. THE Feynman SHALL 为每�?FeynmanSession 存储以下字段：唯一标识符、知识点名称、学科、关联讲�?ID（可选）、对话记录、AI 总结、创建时间�?

---

### 需�?5：学习数据统�?Component——跨 Component 数据汇�?

**用户故事�?* 作为用户，我希望在一个地方看到我所有学习活动的数据汇总，以便了解自己的学习状态和进步趋势�?

**独立使用场景�?* 用户�?文具�?页面进入学习数据统计 Component，查看各维度的学习数据可视化图表�?

**�?Agent 调用场景�?* SubjectTeacher �?ClassDirector Agent 通过 `read(query)` 获取用户的学习数据，用于分析学习状态和调整计划�?

#### 验收标准

1. THE LearningStats SHALL 实现完整�?ComponentInterface，并�?ComponentRegistry 中完成注册�?
2. THE LearningStats SHALL 从以�?Component 汇总数据：Timer（各学科专注时长）、MistakeBook（错题数量与趋势）、Calendar（任务完成率）、Feynman（知识点掌握情况）�?
3. THE LearningStats SHALL �?UI 中展示以下统计维度：每日学习时长（近 7 天折线图）、各学科时间分布（饼图）、错题趋势（�?7 天新�?已掌握数量对比）、任务完成率（近 7 天）�?
4. WHEN Agent 通过 `read(query)` 查询学习数据时，THE LearningStats SHALL 支持以下查询参数：学科、时间范围、数据类型（专注时长/错题统计/任务完成�?知识点掌握），并返回结构化的统计数据�?
5. THE LearningStats SHALL 每次打开时自动从�?Component 拉取最新数据，数据刷新时间不超�?3 秒�?
6. IF 某个 Component 数据拉取失败，THEN THE LearningStats SHALL 展示�?Component 对应维度的数据为"暂无数据"，不影响其他维度的正常展示�?
7. THE LearningStats SHALL 提供"知识点掌握度"视图，汇�?Feynman 历史 Session 中各知识点的总结评价，以列表形式展示各知识点的掌握状态（待学�?学习�?已掌握）�?
8. WHEN Agent 请求某学科的完整学习数据时，THE LearningStats SHALL 返回该学科的：总专注时长、错题数量及掌握率、任务完成率、费曼学习次数，数据格式为结构化 JSON�?

---

## 第二部分：多 Agent 系统

---

### 需�?6：学科老师 Agent——单科深度分析与策略制定

**用户故事�?* 作为用户，我希望有一个专注于某一学科�?AI 老师，能分析我的学习材料和薄弱点，给出针对性的学科学习策略，以便我知道这门课该怎么学、先学什么�?

**用户直接使用场景�?* 用户�?我的" �?学科管理 �?学科资料页进入对应学科的 SubjectTeacher 对话界面，直接与老师对话，询问学习建议、让老师分析材料、请老师出针对性练习题；学科上下文由当前学科资料页自动传入，无需重新选择�?

**�?Skill 自动调用场景�?* 学习路线 Skill 在执行时自动调用各科 SubjectTeacher，收集分析报告后传递给 ClassDirector�?

#### 验收标准

1. THE SubjectTeacher SHALL 支持用户在启动时选择或指定学科，优先读取调用方传入的学科上下文（如从学科资料页进入时自动传入当前学科），同一用户可以为不同学科分别创�?SubjectTeacher 实例，各实例的数据访问范围相互隔离�?
2. THE SubjectTeacher SHALL 能访问以下数据范围（仅限当前学科，学科上下文由调用方传入或从 `currentSubjectProvider` 读取）：用户上传的讲义和大纲、历年题库、MistakeBook 中该学科的错题、与该学科相关的历史对话记录�?
3. WHEN 用户�?SubjectTeacher 对话时，THE SubjectTeacher SHALL 基于用户的学习材料和错题数据回答问题，回答中引用具体材料内容时需标注来源（如"根据你上传的�?章讲�?）�?
4. WHEN 用户请求 SubjectTeacher 进行学科分析时，THE SubjectTeacher SHALL 生成结构化的 SubjectAnalysisReport，包含以下字段：薄弱章节列表（按薄弱程度排序）、建议学习顺序、各章节预计所需时间（小时）、重点复习题型、整体掌握度评估（百分比）�?
5. WHEN SubjectTeacher 生成 SubjectAnalysisReport 时，THE SubjectTeacher SHALL 将报告持久化存储，并关联到对应学科和生成时间，供 ClassDirector 读取�?
6. THE SubjectTeacher SHALL 支持主动向用户提问，了解用户的薄弱点，提问方式为单次单问，不同时提出多个问题�?
7. WHEN Skill 通过 AgentKernel 调用 SubjectTeacher 时，THE SubjectTeacher SHALL 接受结构化的分析请求（包含学科和分析维度），直接返回 SubjectAnalysisReport，不需要用户交互�?
8. THE SubjectTeacher SHALL �?UI 中以对话界面呈现，入口位�?我的" �?学科管理 �?学科资料页内，顶部显示当前学科名称，侧边栏提�?生成分析报告"�?查看历史报告"的快捷入口�?

---

### 需�?7：班主任 Agent——跨科统筹与时间表生�?

**用户故事�?* 作为用户，我希望有一个班主任 AI 来统筹我所有学科的学习计划，根据考试时间和我的可用时间生成合理的跨科时间表，以便我不需要自己手动规划每天学什么�?

**用户直接使用场景�?* 用户�?我的"页面进入"班主�?对话界面，查看当前学习计划、请班主任调整某科的时间分配、了解整体备考进度�?

**�?Skill 自动调用场景�?* 学习路线 Skill 自动触发班主任收集各科报告、生成时间表并写入日历�?

#### 验收标准

1. THE ClassDirector SHALL 能访问以下数据：所有学科的 SubjectAnalysisReport（最新版本）、用户设置的 ExamSchedule、用户设置的 AvailableTimeConfig、Calendar Component 中的现有任务�?
2. WHEN 用户�?Skill 触发"生成学习时间�?时，THE ClassDirector SHALL 读取所有学科的 SubjectAnalysisReport，结�?ExamSchedule �?AvailableTimeConfig，生成跨科学习时间表，并通过 Calendar Component �?`write(data)` 接口批量写入 LearningTask�?
3. WHEN ClassDirector 生成时间表时，THE ClassDirector SHALL 根据各科考试距今天数和各科预计所需时间计算时间权重，考试越近、所需时间越多的学科分配更多时间�?
4. WHEN ClassDirector 检测到某学科的实际完成进度（来�?Calendar 任务完成率）落后于计划进度超�?20% 时，THE ClassDirector SHALL 自动重新计算时间分配，生成调整后的时间表，并通知用户�?
5. WHEN 用户�?ClassDirector 对话时，THE ClassDirector SHALL 能回答以下类型的问题：当前各科时间分配比例、某科的备考进度、距各科考试的剩余天数和建议学习时长�?
6. THE ClassDirector SHALL �?UI 中以对话界面呈现，入口位�?我的"页面，顶部显�?距最近考试 X �?的提示，提供"查看当前时间�?�?重新生成时间�?的快捷入口�?
7. IF 某学科尚未生�?SubjectAnalysisReport，THEN THE ClassDirector SHALL 在生成时间表前提示用户先让对应学科的 SubjectTeacher 完成分析，并提供跳转入口�?
8. WHEN Skill 通过 AgentKernel 调用 ClassDirector 时，THE ClassDirector SHALL 接受结构化的调度请求，执行时间表生成流程并返回写�?Calendar 的任务数量，不需要用户交互�?

---

### 需�?8：同�?Agent——日常执行与学习陪伴

**用户故事�?* 作为用户，我希望有一个像真实同桌一样的 AI 陪伴我日常学习，提醒我今天要做什么、在我学习时适时互动，以便我保持学习节奏而不感到孤独�?

**用户直接使用场景�?* 用户打开 App 时，同桌主动推送今日任务提醒；用户在学习时可以随时打开同桌对话，聊学习进度、请同桌提醒休息�?

**�?Skill 自动调用场景�?* 学习路线 Skill 在每日开始时自动触发同桌发送今日任务摘要；学习结束后自动触发同桌记录完成情况�?

#### 验收标准

1. THE Deskmate SHALL 能访问以下数据：Calendar Component 中当日的 LearningTask 列表、用户当日的 FocusSession 记录（来�?Timer）、LearningStats 中的当日学习进度�?
2. WHEN 每天首次打开 App 时，THE Deskmate SHALL 主动向用户发送今日学习任务摘要，内容包含：今日任务数量、各任务名称和预计时长、今日总计划学习时长�?
3. WHEN 用户�?Deskmate 对话时，THE Deskmate SHALL 使用轻松、口语化的语气，像真实同桌一样交流，不使用正式的报告式语言�?
4. WHEN 用户完成一�?LearningTask 后，THE Deskmate SHALL 给予鼓励性反馈，并告知用户今日剩余任务数量�?
5. WHEN 用户连续专注学习超过 50 分钟（来�?Timer 数据）且未主动休息时，THE Deskmate SHALL 发�?App 内消息提醒用户休息，提醒内容语气轻松（如"已经学了 50 分钟了，要不要起来活动一下？"）�?
6. WHEN 当日所�?LearningTask 均已完成时，THE Deskmate SHALL 向用户发送今日学习总结，内容包含：完成任务数、总专注时长、鼓励性评语，并将完成情况数据写入 LearningStats�?
7. WHEN Skill 通过 AgentKernel 调用 Deskmate 记录完成情况时，THE Deskmate SHALL 将指定任务的完成状态和实际用时写入 Calendar Component，并将数据汇报给 ClassDirector（通过 LearningStats 数据共享）�?
8. THE Deskmate SHALL �?UI 中以悬浮气泡或侧边栏形式呈现，不占用主功能区域，用户可随时展开或收起�?
9. IF 当日没有任何 LearningTask，THEN THE Deskmate SHALL 在早晨提醒用户尚未安排今日学习计划，并提供跳转到 ClassDirector �?Calendar 的入口�?

---

### 需�?9：用户设置——考试时间表与可用时间配置

**用户故事�?* 作为用户，我希望能设置各科考试日期和每天可用的学习时间，以便班主任 Agent 能据此生成合理的学习计划�?

#### 验收标准

1. THE Learning_OS SHALL �?我的"页面提供"学习计划设置"入口，包�?考试时间�?�?可用时间"两个配置项�?
2. THE ExamSchedule SHALL 支持用户为每个已创建的学科设置考试日期，每个学科最多设置一个考试日期，考试日期必须晚于当前日期�?
3. WHEN 用户修改某学科的考试日期时，THE Learning_OS SHALL 保存新的考试日期，并通知 ClassDirector 重新评估时间分配（若当前存在有效时间表）�?
4. THE AvailableTimeConfig SHALL 支持用户分别设置工作日和周末的每日可用学习时长（单位：分钟，范围 30 �?480 分钟），也支持为特定日期设置例外时长�?
5. WHEN 用户保存 AvailableTimeConfig 时，THE Learning_OS SHALL 验证工作日和周末的时长均已填写，验证通过后立即生效，ClassDirector 下次生成时间表时使用新配置�?
6. THE Learning_OS SHALL 在考试时间表界面展示距各科考试的剩余天数，考试日期�?7 天以内时以醒目颜色标注�?
7. IF 用户未设置任何考试日期，THEN THE ClassDirector SHALL 在被调用时提示用户先完成考试时间表设置，并提供跳转入口，不生成空时间表�?
8. IF 用户未设置可用时间配置，THEN THE ClassDirector SHALL 使用默认值（工作�?120 分钟、周�?240 分钟）生成时间表，并在生成结果中提示用户当前使用的是默认配置�?

---

## 数据流关系说�?

### Component 间数据流

```
Timer（FocusSession�?
    �?read(query)
LearningStats（汇总各学科专注时长�?

MistakeBook（错题数据）
    �?read(query)
LearningStats（汇总错题趋势）

Calendar（LearningTask 完成情况�?
    �?read(query)
LearningStats（汇总任务完成率�?

Feynman（FeynmanSession 总结�?
    �?read(query)
LearningStats（汇总知识点掌握度）
    �?write(data)
Notebook（保存费曼总结�?
```

### Agent 间数据流

```
用户学习材料（讲�?大纲/历年题）+ MistakeBook + 对话历史
    �?访问
SubjectTeacher（各学科）→ 生成 SubjectAnalysisReport

SubjectAnalysisReport（所有学科）+ ExamSchedule + AvailableTimeConfig
    �?读取
ClassDirector �?生成跨科时间�?�?write(data) �?Calendar

Calendar（今�?LearningTask�? Timer（FocusSession�? LearningStats
    �?读取
Deskmate �?今日提醒 + 学习陪伴 + 完成情况记录

LearningStats（学习数据）
    �?read(query)
SubjectTeacher（调整分析）/ ClassDirector（调整时间分配）
```

### Component 独立使用与被 Skill 调用对比

| Component | 独立使用入口 | �?Skill 调用方式 | 主要调用�?|
|-----------|------------|-----------------|-----------|
| MistakeBook | 文具�?�?错题�?| `read(query)` 查询错题 | SubjectTeacher、学科分�?Skill |
| Calendar | 文具�?�?日历 | `write(data)` 写入任务；`read(query)` 查询完成情况 | ClassDirector、学习路�?Skill |
| Timer | 文具�?�?计时�?| `open(context)` 启动；`read(query)` 查询历史 | 学习陪伴 Skill、Deskmate |
| Feynman | 文具�?�?费曼学习 | `open(context)` 启动；`read(query)` 查询总结 | 知识检�?Skill、SubjectTeacher |
| LearningStats | 文具�?�?学习统计 | `read(query)` 获取结构化数�?| SubjectTeacher、ClassDirector、Deskmate |

---

## 第三部分：Skill 两层次架构与 Agent 调用关系

---

### 需�?10：Skill 两层次架构——学习方法与学习路线的分层设�?

**用户故事�?* 作为用户，我希望系统能区�?如何学某个知识点"�?整体备考计划怎么安排"这两种不同层次的需求，以便系统能在正确的层次上帮助我�?

#### 架构说明

Skill 分为两个层次，职责完全不同：

```
学习路线 Skill（Learning Route Skill�?
  ├── 是时间的函数，描�?什么时候学什�?
  ├── �?ClassDirector Agent 调用和管�?
  ├── 用户可以 DIY 组合（今天费曼法，明天刷题，后天间隔复习...�?
  ├── 用户可以选择已有路线模板�?30天备考模�?�?期末冲刺模板"�?
  └── ClassDirector 也可以根据分析自动生�?

学习方法 Skill（Learning Method Skill�?
  ├── 描述"用什么方法学某个知识�?
  ├── �?SubjectTeacher Agent 调用和推�?
  ├── 封装具体�?Component 调用序列（如费曼�?= 启动 Feynman Component�?
  └── 执行时调用对�?Component 完成学习任务
```

#### 验收标准

1. THE Learning_OS SHALL 在数据模型层面区�?LearningRouteSkill �?LearningMethodSkill 两种 Skill 类型，两者均继承自基础 Skill 结构，但用途和调用方不同�?
2. THE LearningRouteSkill SHALL 包含以下额外字段：时间跨度（天数）、每日任务模板列表（每个模板包含学科、学习方�?Skill 引用、预计时长）、适用场景标签（如"期末备�?�?日常学习"）�?
3. THE LearningMethodSkill SHALL 包含以下额外字段：适用知识点类型（概念理解/计算练习/记忆背诵）、所需 Component 列表、预计单次执行时长�?
4. WHEN ClassDirector 生成学习时间表时，THE ClassDirector SHALL �?LearningRouteSkill 库中选择或生成路线，将路线中的每日任务模板实例化为具体的 LearningTask 写入 Calendar�?
5. WHEN SubjectTeacher 为用户推荐学习方法时，THE SubjectTeacher SHALL �?LearningMethodSkill 库中根据当前知识点类型和用户薄弱点匹配合适的方法，并启动对应 Component 执行�?
6. THE Learning_OS SHALL �?文具�?页面提供"学习方法�?入口，展示所有可用的 LearningMethodSkill 列表（含内置和用户自定义），用户可以直接启动某个学习方法，或将其加入自定义学习路线；学习路线的管理入口位�?我的"页面的班主任入口内�?
7. THE Learning_OS SHALL 内置至少以下学习路线模板�?0天备考冲刺、日常稳步学习、错题专项突破；内置至少以下学习方法 Skill：费曼学习法、间隔重复复习、错题针对练习、思维导图梳理�?
8. WHEN 用户在班主任界面 DIY 学习路线时，THE Learning_OS SHALL 展示所有可用的 LearningMethodSkill 供用户选择，用户可以为每天的不同时段分配不同的学习方法�?

---

## 第四部分：MCP 外部工具接入

---

### 需�?11：MCP 日历同步——学习计划同步到系统日历

> **优先级：中等**（核心功能完成后实现�?

**用户故事�?* 作为用户，我希望班主任生成的学习计划能自动同步到我手机的系统日历，以便我不打开 App 也能看到今天的学习任务提醒�?

#### 验收标准

1. THE Calendar Component SHALL 支持通过 MCP 协议连接系统日历服务（Google Calendar 或设备本地日历），连接配置在"我的"�?设置"中管理�?
2. WHEN ClassDirector 通过 Calendar Component 写入 LearningTask 时，IF 用户已启用日历同步，THEN THE Calendar SHALL 同时通过 MCP 将该任务写入系统日历，系统日历事件包含任务名称、学科、时长和提醒时间�?
3. WHEN 用户�?App 内将 LearningTask 标记为已完成时，THE Calendar SHALL 同步更新系统日历中对应事件的状态（若系统日历支持）�?
4. IF MCP 日历服务连接失败或不可用，THEN THE Calendar SHALL 降级为仅 App 内提醒，不影�?App 内日历功能的正常使用，并�?UI 中显�?日历同步已断开"的状态提示�?
5. THE Learning_OS SHALL �?MCP 状态指示器中展示日历同步的连接状态，区分"已同�?�?同步�?�?未连�?三种状态�?
6. WHEN 用户首次启用日历同步时，THE Learning_OS SHALL 引导用户完成 MCP 日历服务的授权流程，授权成功后自动将未来 7 天的 LearningTask 批量同步到系统日历�?

---

## 第五部分：AI 伴侣

---

### 需�?12：AI 伴侣 Component——情绪价值与日常陪伴

> **优先级：最�?*（所有其他功能完成后实现�?

**用户故事�?* 作为用户，我希望有一�?AI 伴侣陪伴我的学习生活，在我压力大时给予情绪支持，在我孤独时有人聊天，以便学习不只是枯燥的任务，而是有温度的体验�?

**与同�?Agent 的区别：** 同桌 Agent 专注于学习任务的执行和提醒，是功能性的；AI 伴侣专注于情感陪伴，是情感性的。两者可以共存，用户可以选择是否启用 AI 伴侣�?

**独立使用场景�?* 用户随时打开 AI 伴侣，聊天、倾诉、寻求鼓励，不限于学习话题�?

#### 验收标准

1. THE AICompanion SHALL 作为独立 Component 实现，用户可以在"我的"页面选择是否启用，默认关闭�?
2. THE AICompanion SHALL 支持与用户进行开放式对话，话题不限于学习，包括但不限于：学习压力、日常生活、情绪倾诉、闲聊�?
3. WHEN 用户表达负面情绪（如"好累"�?学不进去"�?好烦"）时，THE AICompanion SHALL 优先给予情感回应和共情，不立即给出建议或解决方案，除非用户主动请求�?
4. THE AICompanion SHALL 具有持续的记忆能力，能记住用户在之前对话中提到的重要信息（如用户的名字、学习目标、近期压力来源），在后续对话中自然引用�?
5. THE AICompanion SHALL 支持用户自定义伴侣的名字和性格风格（如温柔体贴型、活泼开朗型、理性冷静型），设置后在所有对话中保持一致�?
6. WHEN 用户长时间未打开 App（超�?3 天）时，THE AICompanion SHALL 发送一条关心消息（App 内通知），内容根据用户最近的学习状态个性化生成（如"好久没见你了，最近还好吗�?）�?
7. THE AICompanion SHALL 能感知用户的学习数据（来�?LearningStats），在对话中自然地提及用户的学习进展（如"我看你今天学了两个小时，辛苦�?），但不主动催促学习任务�?
8. IF 用户在对话中表达严重的心理健康问题（如极度焦虑、抑郁倾向），THEN THE AICompanion SHALL 在给予情感支持的同时，温和地建议用户寻求专业帮助，并提供相关资源链接�?
9. THE AICompanion SHALL �?UI 中以独立页面呈现，有专属的视觉形象（可自定义头像），与其他功能页面风格有所区分，营造温暖的氛围�?
10. THE AICompanion SHALL 严格保护对话隐私，对话内容不用于任何分析或训练，不与其他 Agent 共享，用户可以随时清空所有对话记录�?
