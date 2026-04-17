# Learning OS 技术文档

> 版本：架构第一阶段（骨架完成）
> 最后更新：2026-04-17

---

## 一、产品定位

Learning OS 是一个以学习方法为核心的 AI 学习平台，定位为"学习专用操作系统"。

核心理念：**工具归工具，方法归方法，用户说了算。**

系统支持四种使用模式，从完全手动到完全 AI 驱动，用户可以自由选择。**纯手动模式永远保留，任何 AI 功能都是叠加而非替代。**

---

## 二、四种使用模式

每种模式有独立的逻辑路径，UI 只是入口，不是逻辑起点。

### 2.1 纯手动模式

```
用户 → 直接进入任意 Component（问答/解题/导图/出题/笔记本/错题本/资料库）
     → 全程不经过 Agent 或 Skill
     → 与现有功能完全一致
```

适合：习惯自己安排学习、不需要 AI 介入的用户。这是系统的基础层，永远可用。

### 2.2 DIY 模式

```
用户 → 打开 Skill 库，手动选择一个 Skill
     → 手动选择需要的 Component 组合
     → 启动 Session（记录使用的 Skill 和 Component）
     → 执行过程由用户主导，AI 不自动调度
```

适合：有明确学习方法论、想要工具支持但不想被 AI 全程接管的用户。

### 2.3 Skill 驱动模式

```
用户输入 Intent（自然语言，如"帮我用费曼法复习今天的物理错题"）
  → AgentKernel.resolveIntent() 解析意图
  → 返回推荐 Skill 列表（最多3个，含推荐理由）
  → 用户确认 Skill
  → AgentKernel.dispatchSkill() 按 PromptChain 顺序执行
      PromptNode 1 → 调用 Component A → 输出传递给下一节点
      PromptNode 2 → 调用 Component B → 输出传递给下一节点
      ...
  → Session 结束，数据存储
```

适合：想要方法论指导、让 AI 帮忙串联工具的用户。

### 2.4 Multi-Agent 模式

```
用户设定学习目标（如"备战高考"）
  → AgentCouncil.convene() 召开战略会
      校长主持，班主任+各科老师列席
      各 Agent 提交 AgentOpinion
      Council 合成 CouncilDecision
  → 班主任生成 Plan（含各科 PlanEntry 和时间表）
  → Calendar Tool 写入提醒
  → 执行阶段：各科老师按 PlanEntry 执行 Subject-Skill
  → 同桌实时监控，按三级反馈路由信号
      fast  → 直接告诉当前科目老师（立即）
      medium → 告诉班主任（每天）
      slow  → 告诉校长（每周）
  → 触发新会议或直接调整
```

适合：需要全程陪伴、跨学科计划管理的用户。

---

## 三、竞品分析

### 3.1 主要竞品

**Cognito（cognito.homes）**
- 定位：内容驱动的 Skill Tree + 间隔重复
- 核心功能：上传 PDF/视频/笔记 → AI 生成 Skill Tree → 闪卡 + 间隔重复复习
- 优势：内容消化流程完整，间隔重复算法成熟
- 局限：Skill Tree 由 AI 自动生成，用户无法自定义学习方法论；没有多学科协调；没有 Multi-Agent；工具层单一（只有闪卡）；没有纯手动路径

**MindPal（mindpal.io）**
- 定位：专家知识 → 可分享的 AI Agent 工作流
- 核心功能：无代码构建多 Agent 工作流，支持 PDF/视频/音频输入
- 优势：Multi-Agent 工作流成熟，支持专家共创
- 局限：面向企业/教育机构，不面向个人学生；没有学习工具层（笔记本、错题本等）；没有学习计划和时间管理

**Classmates AI（classmates.ai）**
- 定位：用户教 AI，AI 成为学习伙伴
- 核心功能：用户上传资料"教"AI，AI 内化后作为交互式学习伙伴
- 优势：交互感强，有陪伴属性
- 局限：单一 Agent，没有角色分工；没有学习方法论（Skill）体系；没有工具层

**EduPlanner（arxiv 2504.05370）**
- 定位：学术研究项目，LLM 多 Agent 课程设计
- 核心功能：评估 Agent + 优化 Agent + 题目分析 Agent 协作生成课程设计
- 优势：Multi-Agent 协作机制有学术验证
- 局限：面向教师/机构，不面向学生；没有工具层；没有用户自定义能力

### 3.2 差异化对比

| 维度 | Cognito | MindPal | Classmates AI | Learning OS |
|---|---|---|---|---|
| 纯手动工具使用 | ✗ | ✗ | ✗ | ✓ |
| 用户自定义 Skill | ✗ | 部分 | ✗ | ✓ |
| 经验贴转化 Skill | ✗ | ✗ | ✗ | ✓（规划中）|
| 多学科协调计划 | ✗ | ✗ | ✗ | ✓ |
| Multi-Agent 角色分工 | ✗ | ✓（企业向）| ✗ | ✓（学生向）|
| 分级负反馈闭环 | ✗ | ✗ | ✗ | ✓（规划中）|
| 工具层（笔记/错题/导图）| 部分 | ✗ | ✗ | ✓ |
| RAG 知识库 | ✗ | ✗ | 部分 | ✓ |
| 面向中国学生场景 | ✗ | ✗ | ✗ | ✓ |

---

## 四、系统架构

### 4.1 分层模型

```
用户选择模式
  │
  ├── 纯手动 ──────────────────────────────────────────────────────┐
  │                                                                │
  ├── DIY ──────────────────────────────────────────────────────┐  │
  │                                                             │  │
  ├── Skill 驱动 → AgentKernel ──────────────────────────────┐  │  │
  │                                                          │  │  │
  └── Multi-Agent → AgentCouncil ─────────────────────────┐  │  │  │
                                                          ↓  ↓  ↓  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    Skill / Plan 层                                   │
│  Plan（班主任级）：跨学科时间表，含多个 PlanEntry                    │
│  Skill（各科老师级）：单一学习方法论，含 PromptChain                 │
│  SkillLibrary / SkillCreationAdapter / SkillParser                  │
└──────────────────────────────┬──────────────────────────────────────┘
                               ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    Component 层（功能模块）                          │
│  chat  solve  quiz  mindmap  notebook  mistake_book  library        │
│  统一接口：ComponentInterface.open / write / read / close           │
└──────────────────────────────┬──────────────────────────────────────┘
                               ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    Tool 层（原子能力，无独立 UI）                    │
│  document：block_converter / lecture_exporter / book_export_service │
│  mindmap：parser / serializer / painter / export / import           │
│  ocr：ocr_api_client / ocr_service                                  │
│  network：sse_client（流式输出，stub/web/native 平台适配）           │
└──────────────────────────────┬──────────────────────────────────────┘
                               ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    Service / Data 层                                 │
│  services/：HTTP API 封装（chat/notebook/library/document/...）     │
│  providers/：Riverpod 状态管理                                      │
│  models/：数据模型                                                  │
│  core/storage/：本地持久化（token 等）                              │
└─────────────────────────────────────────────────────────────────────┘
```

调用方向单向向下：`模式逻辑 → Skill/Plan → Component → Tool → Service/Data`

`core/` 被所有层引用，但不依赖任何层。

### 4.2 Multi-Agent Council 结构

```
AgentCouncil（议事会）
  ├── AgentRegistry（Agent 注册表）
  ├── PrincipalAgent（校长）    ← 战略层，慢反馈（周级）
  ├── ClassAdvisorAgent（班主任）← 计划层，中反馈（天级）
  ├── SubjectAgent × N（各科老师）← 执行层，被动响应
  └── CompanionAgent（同桌）    ← 监控层，三级反馈路由

分级负反馈（甲状腺轴模型）：
  同桌观察 → FeedbackSignal
    fast（立即）  → SubjectAgent.onFastFeedback()   → 老师调整讲解方式
    medium（每天）→ ClassAdvisorAgent.onMediumFeedback() → 班主任调整计划
    slow（每周）  → PrincipalAgent.onSlowFeedback()  → 校长评估策略
```

---

## 五、RAG 实现

### 5.1 RAG 架构

RAG（Retrieval-Augmented Generation）是系统的核心能力之一。实现分为客户端和后端两部分：

**客户端负责：**
- 资料上传（DocumentService.uploadDocument）
- 触发索引/重建索引（reindexDocument / reindexAll）
- 在问答/解题/导图生成时传入 subject_id 和可选的 doc_id，后端据此检索相关文档片段
- 展示 RAG 来源（ChatMessage.sources，含文件名和片段）

**后端负责（客户端不感知）：**
- 文档解析和向量化
- 向量检索
- 将检索结果注入 LLM Prompt

### 5.2 RAG 查询模式

问答（Chat）支持三种模式，通过 `mode` 参数控制：

| 模式 | 参数值 | 行为 |
|---|---|---|
| strict | `qa` | 只检索学科资料库，找不到相关内容时提示用户 |
| hybrid | `hybrid` | 优先检索资料库，失败时降级到通用知识 |
| broad | `broad` | 资料库 + 通用知识混合（旧模式，保留兼容）|

解题（Solve）固定使用 solve 模式，不支持 broad。

思维导图生成支持指定 `doc_id`，只基于特定文档生成。

### 5.3 可以导入资料库的内容

目前有以下入口可以将内容写入 RAG 知识库：

**1. 直接上传文件（资料库 Component）**
- 入口：学科详情页 → 资料库 Tab
- 支持格式：PDF、文档
- 实现：`DocumentService.uploadDocument()` → 后端解析 → 向量化
- 可触发重建索引：`reindexDocument()` / `reindexAll()`

**2. 笔记导入资料库（Notebook Component）**
- 入口：笔记详情页 → 菜单 → "导入资料库"
- 实现：`NoteDetailPage._importToRag()` → `noteDetailProvider.importToRag()` → `NotebookService.importToRag()` → POST `/api/notes/{noteId}/import-to-rag`
- 返回 `doc_id`，笔记模型中记录 `importedToDocId` 字段
- 导入前会先保存最新内容，确保导入的是最新版本

**3. 历年题上传（ExamService）**
- 入口：学科详情页 → 历年题 Tab
- 实现：`ExamService.uploadExam()` → 后端解析结构化题目
- 历年题是特殊资料，后端会做结构化解析（题目/答案分离）

**目前没有导入资料库入口的内容：**
- 思维导图（只在本地/后端存储，不进 RAG）
- 错题本（只记录错题，不进 RAG）
- 讲义（生成后存在后端，但没有显式的"导入 RAG"操作）

讲义和思维导图理论上可以加导入入口，是后续可以补充的功能点。

---

## 六、功能清单

### 6.1 已实现功能

**问答（Chat）**
- 基于学科资料库的 RAG 问答（strict 模式）
- 结合通用知识的混合问答（hybrid 模式）
- 流式输出（SSE）
- 会话历史管理
- 图片 OCR 识别后提问

**解题（Solve）**
- 结构化解题输出：考点 → 解题思路 → 解题步骤 → 踩分点 → 易错点
- 图片 OCR 识别题目

**思维导图（MindMap）**
- 基于资料库生成思维导图（Markdown 格式，RAG 驱动）
- 可视化编辑（节点增删改、拖拽、缩放）
- 导入/导出（Markdown）
- OCR 识别手写导图并导入
- 历史导图管理

**出题（Quiz）**
- 预测试卷（一键生成，RAG 驱动）
- 自定义出题（题型/数量/分值/难度/考点）

**笔记本（Notebook）**
- 富文本笔记（flutter_quill）
- 按学科分组
- AI 生成标题和大纲
- 导入 RAG 知识库（`importToRag`）
- AI 润色

**错题本（MistakeBook）**
- 错题记录和管理

**资料库（Library）**
- 资料上传（PDF/文档），触发 RAG 索引
- 讲义生成（基于资料库，流式输出，SSE）
- 讲义富文本编辑（flutter_quill）
- 讲义导出（docx/pdf，调后端 API）
- 思维导图生成（基于讲义节点）
- 历年题上传和管理

**学科管理**
- 学科创建/编辑/删除
- 全局学科切换（`currentSubjectProvider`，Riverpod 全局状态）

**用户系统**
- 注册/登录（JWT token，存 flutter_secure_storage）
- 个人信息编辑
- 头像上传

### 6.2 架构骨架（已建，待实现）

**Skill 体系**
- `SkillLibrary`：Skill 存储、查询、验证接口
- `SkillCreationAdapter`：三种创建路径接口（对话式/经验贴/手动）
- `SkillParser`：经验贴解析接口（`DefaultSkillParser` 为空实现占位）
- `Plan` / `PlanLibrary`：跨学科学习计划数据模型

**Multi-Agent Council**
- `AgentCouncil`：议事会接口（`convene` / `routeFeedback`）
- `AgentRegistry`：Agent 注册表
- `PrincipalAgent`：校长接口（`formulateStrategy` / `scaffoldResource` / `onSlowFeedback`）
- `ClassAdvisorAgent`：班主任接口（`buildSchedule` / `onMediumFeedback`）
- `SubjectAgent`：各科老师接口（`executeSkill` / `onFastFeedback`）
- `CompanionAgent`：同桌接口（`observe` / `emitFast` / `emitMedium` / `emitSlow`）
- `FeedbackSignal`：三级反馈信号模型（fast/medium/slow）
- `AgentPromptTemplate`：四个角色的 Prompt 模板（含占位符，待填充）

**Component 接口**
- `ComponentInterface`：open/write/read/close 标准接口
- `ComponentRegistry`：组件注册表接口

---

## 七、技术栈

| 层级 | 技术 |
|---|---|
| 客户端框架 | Flutter（跨平台：Android/iOS/Web）|
| 状态管理 | Riverpod 2.x |
| 路由 | go_router |
| HTTP 客户端 | Dio |
| 流式输出 | SSE（Server-Sent Events，平台适配：native/web/stub）|
| 富文本编辑 | flutter_quill |
| 本地存储 | flutter_secure_storage + shared_preferences |
| 思维导图渲染 | 自研 Canvas 绘制（MindMapPainter）|
| Markdown 渲染 | flutter_markdown + LaTeX 支持 |
| 文件导出 | file_saver + book_export_service（调后端）|
| OCR | 后端 API（ocr_api_client）|

---

## 八、目录结构

```
lib/
├── core/                    接口契约层（不依赖任何其他层）
│   ├── agent/               AgentKernel / AgentCouncil / 四角色接口 / Prompt 模板
│   ├── skill/               Skill / Plan 数据模型 / SkillLibrary / SkillParser 接口
│   ├── component/           ComponentInterface / ComponentRegistry 接口
│   ├── network/             DioClient / ApiException
│   ├── storage/             StorageService
│   └── constants/           ApiConstants
│
├── components/              功能模块层（有完整 UI，待实现 ComponentInterface）
│   ├── chat/                问答
│   ├── solve/               解题
│   ├── quiz/                出题
│   ├── mindmap/             思维导图（data/domain/models/providers/widgets）
│   ├── notebook/            笔记本（widgets/）
│   ├── mistake_book/        错题本
│   └── library/             资料库（lecture/）
│
├── tools/                   原子能力层（无独立 UI，被 components/services 调用）
│   ├── document/            block_converter / lecture_exporter / book_export_service
│   ├── mindmap/             parser / serializer / painter / export / import
│   ├── ocr/                 ocr_api_client / ocr_service
│   └── network/             sse_client（stub/web/native）
│
├── features/                UI 入口层（页面和导航）
│   ├── auth/                登录/注册
│   ├── home/                底部导航 Shell
│   ├── classroom/           答疑室（整合 chat/solve/mindmap/quiz）
│   ├── profile/             个人中心
│   ├── subjects/            学科管理
│   ├── subject_detail/      学科详情（资料库+历年题）
│   ├── resources/           资料
│   └── history/             历史记录
│
├── services/                API 服务层（HTTP 请求封装，按业务域划分）
├── providers/               状态管理（Riverpod）
├── models/                  数据模型
├── routes/                  路由（go_router）
└── widgets/                 公共 Widget
```

---

## 九、路线图

### 第一阶段（已完成）
- 完整功能模块（问答/解题/导图/出题/笔记本/错题本/资料库）
- 三层架构目录结构（core/components/tools）
- 所有接口骨架文件
- Plan/Skill 数据模型
- Multi-Agent 角色接口和 Prompt 模板
- 分级反馈信号模型（FeedbackSignal）

### 第二阶段（待实现）
- 为各 Component 实现 ComponentInterface（open/write/read/close 包装）
- ComponentRegistry 实现，注册内置 Component
- SkillLibrary 实现（保存/查询/验证/过滤）
- 模式切换 UI 入口（叠加在现有导航之上）

### 第三阶段（待实现）
- AgentCouncil 实现（convene 开会机制）
- 四个 Agent 角色实现（接入 LLM，填充 Prompt 模板）
- SkillCreationAdapter 三条路径实现
- SkillParser 接入 AI 模型
- Plan 生成和执行流程
- 分级反馈路由实现
- Skill_Marketplace 开放 API 骨架
- 讲义/思维导图导入 RAG 入口

---

## 十、设计原则

1. **纯手动永远可用**：用户可以完全不用 Skill 和 Agent，直接使用工具。AI 功能是叠加，不是替代。

2. **模式逻辑独立**：四种模式有各自独立的逻辑路径，UI 是入口而非逻辑起点。

3. **骨架优先**：接口先于实现。所有接口在第一阶段定义完毕，业务逻辑在后续阶段填充，不破坏现有功能。

4. **单向依赖**：`模式逻辑 → Skill/Plan → Component → Tool → Service`，不反向依赖。

5. **可插拔**：SkillParser、各 Agent 的 LLM 实现均为可替换接口，不锁定特定模型。

6. **渐进式重构**：现有功能代码不重写，只搬家+改名+建骨架，功能行为不变。
