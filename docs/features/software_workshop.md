# 软件工坊

## 基本信息

| 字段 | 内容 |
| --- | --- |
| 功能 ID | `workshop.mini_apps` |
| 当前状态 | MVP 已收敛为四个入口；Scratch 风格积木 registry、workflow validator、版本快照、workflow patch 和前端积木脚本编辑页已有底座 |
| 主要入口 | `/workshop`、`/workshop/builder`、`/workshop/blocks`、`/workshop/apps/:appId` |
| 后端前缀 | `/api/mini-apps` |
| 自动化覆盖 | 入口 smoke：`ENTRY-P1-07`；四入口 Widget：`WORKSHOP-P2-01` |
| 积木清单 | `docs/manifests/workshop_blocks.json` |

## 产品定位

软件工坊不是一个无限能力的“超级软件生成器”。当前版本只承担一件清晰的事：把可复用的学习方法做成小工具，让用户能生成、改造、运行、保存和分享。

自然语言用于生成初稿，积木用于精细控制。积木系统应参考 Scratch 的底层逻辑：分类、形状、插槽、脚本栈、表达式、布尔条件、变量和自定义积木，而不是普通流程图。同一套积木既允许用户手动编辑，也允许系统和 AI 助教生成、改造和修复；每次改造都应形成可追溯版本。详细设计见 `docs/features/software_workshop_blocks.md`。

## 四个入口

| 入口 | 用户动作 | 当前实现 | 代码位置 |
| --- | --- | --- | --- |
| 生成小工具 | 输入一句学习工具需求，助教追问并生成草稿 | 已接入访谈接口和草稿生成 | `lib/features/workshop/workshop_builder_page.dart`、`POST /api/mini-apps/interview/start`、`POST /api/mini-apps/interview/{session_id}/answer` |
| 改造小工具 | 对已有小工具提出修改要求 | 已在工坊首页和运行页接入 `revise` | `lib/features/workshop/workshop_page.dart`、`lib/features/workshop/mini_app_run_page.dart`、`POST /api/mini-apps/{id}/revise` |
| 运行小工具 | 打开小工具，完成一次学习互动 | 已接入运行页、run session 和事件写入 | `lib/features/workshop/mini_app_run_page.dart`、`POST /api/mini-apps/{id}/runs/start`、`POST /api/mini-apps/runs/{run_id}/events` |
| 保存/分享小工具 | 保存当前工具信息，复制给别人 | 首页支持复制分享文案；工具本体通过后端持久化 | `lib/features/workshop/workshop_page.dart`、`GET /api/mini-apps`、`GET /api/mini-apps/{id}` |

## 当前已实现

- 工坊首页展示小工具列表，并提供四个明确入口。
- 小工具卡片支持运行、改造、复制分享文案。
- 构建器支持从自然语言需求启动访谈，生成可保存草稿。
- 运行页支持根据 `runtime_config.json` 渲染学习内容。
- 运行页支持从资料生成卡片，并回写到小工具运行配置。
- 运行时会创建后端 run session，并记录答题事件。
- 运行页支持保存文档、保存运行配置、请求助教改造。
- 后端提供 Mini App CRUD、访谈、改造、图谱校验、运行记录和资料生成卡片接口。
- 后端提供 Scratch 风格 workflow registry、资源角色类型清单和 `workshop.workflow.v1` 校验器。
- 后端提供 Mini App version 快照：创建、访谈生成、保存配置、助教改造、资料生成卡片都会形成新版本，run session 会绑定当时的 `app_version_id` 和运行快照。
- 后端提供 workflow patch 合同：自然语言改造先生成结构化 patch operations，再返回 patched workflow 和校验结果。
- 前端提供积木脚本页，可查看积木分类、参数插槽和资源角色，并能基于示例 workflow 加入积木、删除、上下移动、编辑积木 JSON 参数、复制当前 workflow、调用后端校验。

## 关键数据

| 数据 | 说明 |
| --- | --- |
| Mini App record | 小工具主记录，包含标题、类型、状态、文档、运行配置、图谱和校验结果 |
| `documents` | 人能读的设计文档、说明文档、`runtime_config.json`、`invisible_canvas.json` 等 |
| `spec` | 前端运行页真正使用的运行配置 |
| `graph` | 后端生成和校验的隐形积木图谱 |
| `validation` | 校验结果，用于提示配置是否能安全运行 |
| run session | 一次运行记录，保存用户在运行页产生的事件，并绑定当时的 `app_version_id`、`spec` 和 `graph` 快照 |
| version history | 小工具版本历史，记录用户、系统或 AI 对配置、文档、图谱和 workflow 的改动 |
| workflow diff | 积木语义 diff，用于查看新增、删除、修改了哪些学习动作 |
| resource actor | 可被积木引用的资料角色，例如导图、错题、笔记、讲义、资料片段 |
| block params | 积木内部参数，包括字面量、表达式、资源引用、资源查询、LLM 配置和写回策略 |

## 技术结构

| 层级 | 文件 | 说明 |
| --- | --- | --- |
| 工坊首页 | `lib/features/workshop/workshop_page.dart` | 四入口、Mini App 列表、卡片动作、复制分享、首页改造弹窗 |
| 构建器 | `lib/features/workshop/workshop_builder_page.dart` | 自然语言访谈和草稿生成 |
| 积木脚本页 | `lib/features/workshop/workshop_blocks_page.dart` | 查看 registry、资源角色和当前脚本栈；支持加入积木、调整顺序、编辑积木 JSON、复制 workflow、调用 workflow validator |
| 运行页 | `lib/features/workshop/mini_app_run_page.dart` | Mini App 运行、文档编辑、配置保存、资料生成卡片、运行事件 |
| Provider | `lib/features/workshop/mini_app_providers.dart` | Mini App 列表、详情、版本历史和积木注册表状态 |
| Service | `lib/features/workshop/mini_app_service.dart` | `/api/mini-apps` 前端接口封装，包含版本和 workflow patch |
| 模型 | `lib/features/workshop/mini_app_models.dart` | Mini App、Mini App version、workflow patch、访谈 turn、生成卡片结果 |
| 后端路由 | `backend/routers/mini_apps.py` | Mini App API |
| 后端存储 | `backend/mini_apps/store.py` | Mini App、版本快照、访谈 session、run session 持久化 |
| 后端构建 | `backend/mini_apps/builder.py`、`backend/mini_apps/content_pipeline.py` | 草稿构建、资料到卡片 |
| 积木图谱 | `backend/mini_apps/canvas.py` | Block registry、图谱编译和校验 |
| 积木设计 | `docs/features/software_workshop_blocks.md` | Scratch 风格学习智能体积木分类、形状、颗粒度和版本规则 |
| 积木清单 | `docs/manifests/workshop_blocks.json` | 机器可读的 shape、slot、resource actor、block 和示例 workflow |
| workflow 底座 | `backend/mini_apps/workflow.py` | registry 加载、资源角色模型、workflow validator、结构化 patch |

## 行为边界

- 当前软件工坊只能生成和运行学习型小工具，不能生成任意桌面软件、浏览器插件或系统级程序。
- 当前分享是复制小工具说明和入口路径，不是公开发布市场。
- 当前改造会生成新版本快照，但还不做分支、回滚和冲突合并。
- 当前运行器主要覆盖闪卡/背记式内容，测验、错题训练和资料问答还需要继续扩展 runtime renderer。
- 当前前端已有第一版积木脚本编辑器，但还不是完整拖拽编辑器；现阶段支持编辑第一个脚本栈和 JSON 参数，资源角色实例选择、嵌套积木可视化编辑、版本历史页面、回滚和 Git 式 diff 仍需继续实现。

## 下一步优先级

1. 做版本历史 UI：展示版本号、来源、改动字段、运行绑定版本和 snapshot。
2. 做 Git 式追溯：workflow 文件树、commit 信息、版本 diff。
3. 把 workflow patch 接到前端：自然语言改造先展示 patch，再允许用户应用。
4. 扩展积木编辑器：从 JSON 参数编辑升级为拖拽、嵌套积木、表达式插槽和资源角色实例选择。
5. 扩展运行器类型：把选择题、错题训练、资料问答从配置真正渲染成可交互页面。
6. 做资源库联动：小工具生成的讲义、卡片、错题结果写回资料库分类。
7. 做分享实体：从“复制说明”升级为导出包、局域网分享或服务器分享链接。
8. 做业务 E2E：覆盖生成、改造、运行、事件写入、资料生成卡片、复制分享、积木编辑校验。

## 验收建议

`WORKSHOP-P2-01`：生成并运行一个背记小工具。

1. 打开 `/workshop/builder`。
2. 输入“做一个高一英语单词背记小工具，每轮 10 张卡片”。
3. 完成访谈问题。
4. 生成草稿并回到 `/workshop`。
5. 在首页看到新小工具。
6. 点击“运行”，进入 `/workshop/apps/:appId`。
7. 完成至少一次“已会/待复习”交互。
8. 后端产生 run session 和事件记录。

`WORKSHOP-P2-02`：改造一个已有小工具。

1. 在 `/workshop` 选择一个小工具。
2. 点击“改造”。
3. 输入“每轮题量减半，答错后先给提示，再给完整解释”。
4. 提交后打开运行页。
5. 小工具配置已更新，并显示校验结果。

`WORKSHOP-P2-03`：复制分享文案。

1. 在 `/workshop` 选择一个小工具。
2. 点击“分享”。
3. 剪贴板包含标题、类型、状态、说明和入口路径。
