# 软件工坊

## 基本信息

| 字段 | 内容 |
| --- | --- |
| 功能 ID | `workshop.mini_apps` |
| 当前状态 | 四入口 MVP、Scratch 风格积木底座、运行页、版本快照、运行绑定版本、自然语言 patch 预览确认流均已落地 |
| 主要入口 | `/workshop`、`/workshop/builder`、`/workshop/blocks`、`/workshop/apps/:appId` |
| 后端前缀 | `/api/mini-apps` |
| 积木清单 | `docs/manifests/workshop_blocks.json` |

## 产品定位

软件工坊不是无限能力的“任意软件生成器”。当前产品边界是：把可复用的学习方法做成可运行、可改造、可保存、可分享的小工具。

自然语言负责生成初稿和提出改造意图；积木负责精细控制。积木系统参考 Scratch 的底层逻辑：分类、形状、插槽、脚本栈、表达式、布尔条件、变量、自定义积木和运行舞台，但内容域换成学习资料、讲义、错题、笔记、复习计划和 LLM 调用。同一套积木既允许用户手动编辑，也允许系统和 AI 助教生成、改造和修复；每次改造都必须形成可追溯版本。

## 四个入口

| 入口 | 用户动作 | 当前实现 | 代码位置 |
| --- | --- | --- | --- |
| 生成小工具 | 输入学习工具需求，助教追问并生成草稿 | 已接入访谈接口和草稿生成 | `lib/features/workshop/workshop_builder_page.dart`、`POST /api/mini-apps/interview/start`、`POST /api/mini-apps/interview/{session_id}/answer` |
| 改造小工具 | 对已有小工具提出修改要求 | 首页和运行页接入 `revise`；积木页接入自然语言 workflow patch 预览确认 | `lib/features/workshop/workshop_page.dart`、`lib/features/workshop/mini_app_run_page.dart`、`lib/features/workshop/workshop_blocks_page.dart` |
| 运行小工具 | 打开小工具，完成一次学习互动 | 已接入运行页、run session、事件写入和运行绑定版本展示 | `lib/features/workshop/mini_app_run_page.dart`、`POST /api/mini-apps/{id}/runs/start`、`POST /api/mini-apps/runs/{run_id}/events` |
| 保存/分享小工具 | 保存配置和文档，复制分享文案 | 后端持久化；首页支持复制分享文案；运行页保存会生成新版本 | `lib/features/workshop/workshop_page.dart`、`PUT /api/mini-apps/{id}` |

## 已实现

- 工坊首页展示四入口和 Mini App 列表，卡片支持运行、改造、复制分享文案。
- 构建器支持从自然语言需求启动访谈，生成可保存草稿。
- 运行页支持根据 `runtime_config.json` 渲染闪卡式学习内容，记录答题事件。
- 运行页支持从资料生成卡片，并回写到小工具运行配置。
- 运行页支持保存文档、保存运行配置、请求助教改造。
- 运行页展示版本历史：版本号、来源、父版本、改动字段、摘要、当前版本标记和本次运行绑定版本。
- 运行页支持查看版本 diff，并能确认回滚到历史版本；回滚不会删除历史，而是创建新的 `rollback` 版本。
- 修改配置、AI 改造、访谈生成、资料生成卡片都会创建 Mini App version 快照。
- run session 会绑定当时的 `app_version_id`，并保存 `app_snapshot` 和 `graph_snapshot`，避免旧运行被新版本污染。
- 后端提供 Scratch 风格 workflow registry、资源角色类型、`workshop.workflow.v1` validator 和 workflow patch 接口。
- 积木脚本页支持查看分类、参数插槽和资源角色；支持加入积木、删除、上下移动、编辑积木 JSON、复制 workflow、调用 validator。
- 积木脚本页支持自然语言 patch 确认流：先请求后端生成结构化 patch operations，展示操作、目标路径、改动字段、原因和校验结果，用户点击“应用 patch”后才替换当前 workflow。
- workflow 和 invisible canvas validator 已拆分为更小的节点、边、插槽校验器，非法参数和 malformed graph 会给出明确错误。

## 关键数据

| 数据 | 说明 |
| --- | --- |
| `MiniAppRecord` | 小工具主记录，包含标题、类型、状态、文档、运行配置、图谱和校验结果 |
| `documents` | 人能读的设计文档、说明文档、`runtime_config.json`、`invisible_canvas.json` 等 |
| `spec` | 前端运行页实际使用的运行配置 |
| `graph` | 后端生成和校验的 invisible canvas 图谱 |
| `validation` | 配置和图谱是否可运行的校验结果 |
| `MiniAppVersion` | 可追溯版本快照，记录父版本、来源、改动字段、指令、摘要和 snapshot |
| `MiniAppRun` | 一次运行记录，绑定 `app_version_id` 并保存运行快照和事件 |
| `WorkflowPatch` | 自然语言改造得到的结构化 patch operations，应用前必须先预览和校验 |
| `ResourceActor` | 可被积木引用的资料角色，例如导图、错题、笔记、讲义、资料片段 |

## 技术结构

| 层级 | 文件 | 说明 |
| --- | --- | --- |
| 工坊首页 | `lib/features/workshop/workshop_page.dart` | 四入口、Mini App 列表、卡片动作、复制分享、首页改造弹窗 |
| 构建器 | `lib/features/workshop/workshop_builder_page.dart` | 自然语言访谈和草稿生成 |
| 积木脚本页 | `lib/features/workshop/workshop_blocks_page.dart` | 积木 registry、脚本栈编辑、JSON 参数编辑、validator、patch 预览确认 |
| 运行页 | `lib/features/workshop/mini_app_run_page.dart` | 小工具运行、文档编辑、配置保存、资料生成卡片、运行事件、版本历史、diff 查看、回滚确认 |
| Provider | `lib/features/workshop/mini_app_providers.dart` | Mini App 列表、详情、版本历史、积木注册表状态 |
| Service | `lib/features/workshop/mini_app_service.dart` | `/api/mini-apps` 前端接口封装，包含版本和 workflow patch |
| 模型 | `lib/features/workshop/mini_app_models.dart` | Mini App、version、workflow patch、访谈 turn、生成卡片结果 |
| 后端路由 | `backend/routers/mini_apps.py` | Mini App API |
| 后端存储 | `backend/mini_apps/store.py` | Mini App、version、访谈 session、run session 持久化 |
| workflow | `backend/mini_apps/workflow.py` | registry 加载、资源角色模型、workflow validator、结构化 patch |
| invisible canvas | `backend/mini_apps/canvas.py` | Block registry、图谱编译和校验 |

## 行为边界

- 当前只能生成和运行学习型小工具，不能生成任意桌面软件、浏览器插件或系统级程序。
- 当前分享是复制说明和入口路径，不是公开市场发布。
- 当前版本历史支持查看、运行绑定标记、路径级 diff 和回滚确认；分支、冲突合并和 Git 文件树式 diff 仍未实现。
- 当前运行器主要覆盖闪卡背记式内容，选择题、错题训练、资料问答等 renderer 需要继续扩展。
- 当前积木编辑器是第一版：支持脚本栈、JSON 参数和 patch 确认，但还不是完整拖拽积木画布。
- 资源角色目前以类型和默认参数展示为主，尚未做真实资源实例选择器。

## 测试覆盖

| 测试 | 覆盖 |
| --- | --- |
| `test/features/workshop/workshop_page_test.dart` | 四入口展示、运行最近小工具、从首页改造已有小工具 |
| `test/features/workshop/workshop_blocks_page_test.dart` | registry 加载、加积木、编辑 JSON、校验 workflow、自然语言 patch 预览并应用 |
| `test/features/workshop/mini_app_run_page_test.dart` | 运行页版本历史、父版本、改动字段、本次运行绑定版本、diff 弹窗、回滚确认 |
| `backend/tests/test_workshop_workflow.py` | workflow registry、validator、插槽错误、LLM 失败策略、patch 合同 |
| `backend/tests/test_mini_app_versions.py` | Mini App 版本快照、run session 绑定版本、版本 diff、rollback 新版本 |
| `backend/tests/test_mini_app_card_pipeline.py` | invisible canvas graph 校验和资料生成卡片管线 |

## 下一步优先级

1. 做真正的 Git 文件树追溯：workflow 文件树、commit 信息、语义 diff、冲突提示。
2. 把积木编辑器从“列表 + JSON 参数”升级为拖拽画布：嵌套积木、表达式插槽、资源实例选择器。
3. 扩展运行器类型：选择题、错题训练、资料问答、讲义生成和复习队列动作都要能由配置驱动。
4. 做资源库联动：小工具生成的讲义、卡片、错题结果写回资源库分类，并保留来源指针。
5. 做分享实体：从“复制说明”升级为导出包、局域网分享或服务器分享链接。
6. 做业务 E2E：覆盖生成、改造、运行、事件写入、资料生成卡片、复制分享、积木编辑、patch 确认和版本历史。

## 验收建议

`WORKSHOP-P2-01`：生成并运行一个背记小工具。

1. 打开 `/workshop/builder`。
2. 输入“做一个高一英语单词背记小工具，每轮 10 张卡片”。
3. 完成访谈问题。
4. 生成草稿并回到 `/workshop`。
5. 在首页看到新小工具。
6. 点击运行，进入 `/workshop/apps/:appId`。
7. 完成至少一次“已会 / 待复习”交互。
8. 后端产生 run session、事件记录和运行绑定版本。

`WORKSHOP-P2-02`：改造一个已有小工具。

1. 在 `/workshop` 选择一个小工具。
2. 点击改造，输入“每轮题量减半，答错后先给提示，再给完整解释”。
3. 提交后打开运行页。
4. 小工具配置已更新，并产生新版本。
5. 版本历史显示父版本、改动字段和本次运行绑定版本，并支持查看 diff 或回滚到历史版本。

`WORKSHOP-BLOCKS-01`：自然语言改积木必须先确认 patch。

1. 打开 `/workshop/blocks`。
2. 输入“资料最多查 5 条，并把生成题目改成复习队列用”。
3. 点击“预览 patch”。
4. 页面显示结构化 patch operations、目标路径、改动字段和校验结果。
5. 未点击“应用 patch”前，当前 workflow 不应被替换。
6. 点击“应用 patch”后，当前 workflow 替换为 patched workflow，并保留 validator 结果。
