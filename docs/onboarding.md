# 新协作者入门指南

> 写给第一次接触这个项目的人。
> 读完这份文档，你应该能理解：这是什么、为什么这样设计、从哪里开始。

---

## 一、这是什么项目

**Learning OS** 是一个面向中国学生的 AI 学习平台，定位是"学习专用操作系统"。

不是又一个 AI 聊天工具，也不是题库 App。核心差异在于：

- **工具层**：问答、解题、思维导图、出题、笔记本、错题本——这些是"工具"，用户可以直接用，不需要 AI 介入
- **方法层**：Skill（学习方法论单元）——把"费曼法"、"错题复习法"这类经验贴变成可执行的 AI 工作流
- **协调层**：Multi-Agent——校长/班主任/各科老师/同桌，分工协作，管理跨学科学习计划

**最重要的设计原则：纯手动永远可用。** AI 是叠加，不是替代。用户可以完全不用 Skill 和 Agent，直接用工具。

---

## 二、技术栈一览

| 端 | 技术 | 说明 |
|---|---|---|
| 前端 | Flutter + Riverpod + GoRouter | 跨平台（Android/iOS/Web） |
| 后端 | FastAPI + PostgreSQL + PGVector | Python，支持向量检索（RAG） |
| AI | 多模型（Qwen 系列为主） | 聊天/嵌入/视觉，可插拔 |
| 工具协议 | MCP（Model Context Protocol） | 标准化外部工具调用 |

---

## 三、仓库结构

```
study_assistant_app/
├── lib/                    Flutter 前端
│   ├── core/               接口契约层（不依赖任何其他层）
│   ├── components/         功能模块（有完整 UI）
│   ├── tools/              原子能力（无独立 UI）
│   ├── features/           页面和导航（UI 入口）
│   ├── services/           HTTP API 封装
│   ├── providers/          Riverpod 全局状态
│   ├── models/             数据模型
│   └── routes/             GoRouter 路由
│
├── backend/                Python 后端（主服务）
│   ├── main.py             FastAPI 入口
│   ├── routers/            API 路由（18 个模块）
│   ├── book_services/      讲义导出（PDF/Word）
│   ├── mcp_layer/          MCP 工具集成
│   └── skill_ecosystem/    Skill 生态系统
│
├── api/                    轻量 API 层（早期遗留，部分功能仍在用）
│
├── docs/                   文档
│   ├── onboarding.md       本文件（新协作者入门）
│   └── technical_overview.md  架构详细文档
│
└── .kiro/specs/            功能规格文档（需求 + 设计 + 任务）
    ├── learning-os-architecture/
    ├── lecture-book-export/
    ├── mindmap-editor/
    ├── ecosystem-integration/
    └── component-ecosystem/
```

---

## 四、设计思想

### 4.1 为什么要分层

前端分四层，调用方向单向向下：

```
features（页面）
    ↓
components（功能模块，有 UI）
    ↓
tools（原子能力，无 UI）
    ↓
services / providers（数据和状态）
```

**为什么这样分？**

`components` 是可以被 Skill 调度的最小功能单元。一个 Skill（比如"费曼法"）可能需要依次调用"笔记本"和"问答"两个 Component。如果把 UI 和业务逻辑混在一起，Skill 就没法调度。

`tools` 是更细粒度的能力，比如 OCR、SSE 流式输出、Markdown 解析。它们没有自己的 UI，被 components 和 services 调用。

`core/` 是接口契约层，定义所有接口但不实现任何业务逻辑。它不依赖任何其他层，所有层都可以依赖它。

### 4.2 为什么用 Riverpod

状态管理选 Riverpod 而不是 Provider 或 BLoC，主要原因：

- **类型安全**：编译期检查，不会在运行时出现 `ProviderNotFoundException`
- **Family Provider**：`chatProvider(subjectId)` 这种按参数分组的状态，Riverpod 原生支持
- **全局学科状态**：`currentSubjectProvider` 需要在所有功能页共享，Riverpod 的全局 Provider 机制很适合

### 4.3 为什么学科是"上下文"而不是"入口"

旧设计：首页是学科列表 → 点进去才能用功能。

新设计（ui-redesign.md 规范）：底部导航直接是功能（问答/解题/导图/出题），顶部有一个学科切换栏，学科是全局上下文。

**原因**：用户的目标是"做题"或"问问题"，不是"进入某个学科"。学科只是过滤条件，不应该是入口。

### 4.4 为什么 RAG 而不是直接问 LLM

用户上传的讲义、大纲、历年题是私有知识，LLM 不知道。RAG（检索增强生成）的流程：

1. 用户上传文件 → 后端解析 → 向量化存入 PGVector
2. 用户提问 → 向量检索相关片段 → 注入 LLM Prompt → 生成回答

这样 LLM 的回答是基于用户自己的资料，而不是通用知识。

问答支持三种模式：
- `strict`：只用学科资料库，找不到就说找不到
- `hybrid`：优先资料库，失败降级到通用知识
- `broad`：资料库 + 通用知识混合

### 4.5 为什么要有 Skill 体系

学生在网上能找到大量"学习方法论"（费曼法、间隔重复、思维导图法……），但这些方法论是文字描述，不是可执行的工作流。

Skill 的本质是：**把一篇经验贴变成一个可以被 AI 执行的 PromptChain**。

每个 Skill 包含：
- 名称和描述
- 适用场景（什么时候用这个方法）
- PromptChain（一系列步骤，每步调用哪个 Component，用什么 Prompt）

用户可以自己创建 Skill，也可以从 Skill 市场下载别人分享的 Skill。

### 4.6 为什么 Multi-Agent 要分角色

单一 Agent 的问题：什么都管，什么都管不好。

分角色的设计参考了"学校"这个现实模型：
- **校长**：战略层，关注长期目标，慢反馈（周级）
- **班主任**：计划层，跨学科协调，中反馈（天级）
- **各科老师**：执行层，专注单科，快反馈（立即）
- **同桌**：监控层，实时观察，把反馈路由给对应角色

这个分级反馈机制（fast/medium/slow）参考了生物学中的甲状腺轴模型——不同时间尺度的调节机制分开处理，避免过度反应。

---

## 五、当前状态

### 已完成
- 完整的工具层功能（问答/解题/导图/出题/笔记本/错题本/资料库）
- 三层架构目录结构（core/components/tools）
- 所有接口骨架文件（接口定义完毕，业务逻辑待填充）
- Plan/Skill 数据模型
- Multi-Agent 角色接口和 Prompt 模板

### 进行中
- UI 重设计（底部导航 5 Tab + 顶部学科切换栏）
- 讲义导出为 PDF/Word（含中文字体、目录、LaTeX 公式）
- 思维导图手动编辑器

### 规划中
- ComponentInterface 实现（为各 Component 加标准接口包装）
- SkillLibrary 实现
- AgentCouncil 实现
- Skill 市场
- 分级反馈路由

---

## 六、从哪里开始

### 如果你负责前端

1. 先读 `docs/technical_overview.md` 了解整体架构
2. 看 `lib/routes/app_router.dart` 理解路由结构
3. 看 `lib/providers/` 理解全局状态
4. 看 `.kiro/specs/learning-os-architecture/design.md` 理解分层设计
5. 看 `.kiro/steering/ui-redesign.md` 理解 UI 规范

### 如果你负责后端

1. 看 `backend/backend_config.py` 了解所有配置项
2. 看 `backend/main.py` 了解路由注册
3. 看 `backend/routers/` 找到你负责的模块
4. 看 `.kiro/specs/` 下对应功能的规格文档

### 如果你负责 AI / Skill 体系

1. 先读 `docs/technical_overview.md` 第二节（四种使用模式）
2. 看 `lib/core/skill/` 理解 Skill 数据模型
3. 看 `lib/core/agent/` 理解 AgentKernel 和 AgentCouncil 接口
4. 看 `.kiro/specs/learning-os-architecture/` 完整规格
5. 看 `.kiro/specs/ecosystem-integration/` 了解 MCP 和 Skill 市场

### 如果你想快速跑起来

**后端：**
```bash
cd backend
cp .env.example .env   # 填入 LLM_API_KEY 和 DATABASE_URL
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

**前端：**
```bash
flutter pub get
flutter run
```

前端默认连接 `http://localhost:8000`，在 `lib/core/constants/` 里可以修改。

---

## 七、规格文档说明

`.kiro/specs/` 下的文档是功能规格，每个功能有三个文件：

- `requirements.md`：需求（用户故事 + 验收标准 + 正确性属性）
- `design.md`：设计（数据模型 + 接口 + 实现方案）
- `tasks.md`：任务列表（可直接按任务实现）

**正确性属性**（requirements.md 末尾）是形式化的可验证命题，用于属性测试（Property-Based Testing）。实现时可以用 Hypothesis（Python）或 dart_test 验证这些属性。

---

## 八、常见问题

**Q：`api/` 和 `backend/` 有什么区别？**

`api/` 是早期的轻量 API 层，部分功能仍在用。`backend/` 是主服务，新功能都在这里。长期目标是把 `api/` 的功能迁移到 `backend/`，但目前两者并存。

**Q：为什么有些接口是空实现？**

架构采用"骨架优先"策略：接口在第一阶段全部定义完毕，业务逻辑在后续阶段填充。空实现（stub）是占位符，不是遗漏。

**Q：Skill 和 Component 的区别是什么？**

Component 是工具（笔记本、问答框），有自己的 UI，用户可以直接用。Skill 是方法论（费曼法、错题复习法），是一个 PromptChain，描述"按什么顺序、用什么 Prompt 调用哪些 Component"。Skill 本身没有 UI，它通过调度 Component 来执行。

**Q：MCP 是什么？**

Model Context Protocol，一个标准化的工具调用协议。后端通过 MCP 调用外部服务（文件系统、OCR、日历、网络搜索等），而不是直接硬编码 API 调用。好处是工具可以热插拔，不需要修改核心代码。

---

> 更多架构细节见 `docs/technical_overview.md`。
> 功能规格见 `.kiro/specs/` 下各目录。
