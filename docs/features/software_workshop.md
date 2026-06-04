# 软件工坊

## 基本信息

| 字段 | 内容 |
| --- | --- |
| 功能 ID | `workshop.mini_apps` |
| 当前状态 | 部分实现，入口和基础模型存在，核心构建流未完成 |
| 主要入口 | `/workshop`、`/workshop/builder`、`/workshop/apps/:appId` |
| 后端前缀 | `/api/mini-apps` |
| 自动化覆盖 | 入口 smoke：`ENTRY-P1-07` |

## 功能目标

软件工坊的目标是让用户用自然语言、资料和积木式配置生成小学习软件，例如闪卡、测验、错题训练、资料问答小应用等。

## 当前已实现

- 工坊入口页面。
- 构建器页面基础结构。
- Mini App 运行页基础结构。
- Mini App 模型、Provider 和 Service。
- 资料生成闪卡等部分运行页逻辑。
- runtime schema 文档：`docs/features/software_workshop_runtime_schema.md`。

## 技术结构

| 层级 | 文件 | 说明 |
| --- | --- | --- |
| 工坊首页 | `lib/features/workshop/workshop_page.dart` | Mini App 列表和创建入口 |
| 构建器 | `lib/features/workshop/workshop_builder_page.dart` | 创建/配置 Mini App |
| 运行页 | `lib/features/workshop/mini_app_run_page.dart` | 运行 Mini App |
| Provider | `lib/features/workshop/mini_app_providers.dart` | Mini App 状态 |
| Service | `lib/features/workshop/mini_app_service.dart` | `/api/mini-apps` |
| 模型 | `lib/features/workshop/mini_app_models.dart` | MiniApp、runtime config |
| 后端 | `backend/routers/mini_apps.py` | Mini App CRUD |

## 仍未完成的核心能力

- 从用户需求生成可运行 Mini App 的端到端构建流。
- 积木管线的稳定 schema 校验和错误提示。
- 发布、复制、版本管理、回滚。
- 运行时安全边界。
- 与资料库、题库、错题、计划的统一能力注册。
- 端到端 Playwright 业务验收。

## 行为边界

- 当前只能说“入口和部分运行框架存在”，不能说软件工坊完整可用。
- `p1_shell_flow.spec.ts` 只证明 `/workshop` 能打开，不证明能生成软件。
- 涉及执行用户生成配置时必须考虑安全和资源限制。

## 下一步验收建议

新增 `WORKSHOP-P2-01`：

1. 打开 `/workshop/builder`。
2. 输入一个明确需求，例如“用代数资料生成 10 张闪卡”。
3. 选择科目或资料范围。
4. 生成 runtime config。
5. 保存 Mini App。
6. 打开 `/workshop/apps/:appId`。
7. 从资料生成内容。
8. 运行并完成一次互动。

验收重点：

- `/api/mini-apps` 创建/更新请求体。
- runtime config schema 合法。
- 运行页能根据 config 渲染真实交互。
- 错误状态可见且可恢复。
