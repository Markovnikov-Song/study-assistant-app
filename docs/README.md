# 伴学项目文档中心

`docs/` 是当前项目的权威文档目录。目标不是写零散说明，而是让未来开发者或 AI 在代码缺失、上下文丢失时，仍能按文档复原产品结构、功能边界、关键代码入口、接口合同和测试方法。

## 文档原则

- Markdown 写给人看：解释用户流程、设计边界、平台限制、异常处理和验收方法。
- JSON 写给 AI/程序看：记录功能清单、路由、API、数据模型、代码映射、测试矩阵。
- `.kiro/` 只作为历史材料，不作为当前实现事实来源。
- 改动功能行为、API、数据结构、权限或测试时，必须同步更新本文档体系。
- “已实现”“部分实现”“计划中”“受平台限制”必须分开写，不能把计划写成事实。

## 推荐阅读顺序

1. `reconstruction_guide.md`：如何仅靠文档复原项目。
2. `project_blueprint.md`：产品目标和学习闭环。
3. `architecture.md`、`technical_overview.md`：整体技术结构。
4. `inventory/`：模块、路由、API、数据模型和数据库迁移清单。
5. `features/`：按功能阅读人类可读说明。
6. `manifests/`：按机器可读 JSON 建立代码映射和测试矩阵。
7. `testing/playwright_acceptance_plan.md`：自动化验收现状。
8. `document_governance.md`、`legacy_document_audit.md`：旧文档治理规则。

## 目录结构

```text
docs/
  README.md
  reconstruction_guide.md
  project_blueprint.md
  architecture.md
  technical_overview.md
  documentation_status.md
  document_governance.md
  feature_documentation_standard.md
  legacy_document_audit.md
  platform_capabilities.md

  features/
    onboarding_demo.md
    subjects_resources_rag.md
    course_space_mindmap.md
    chat_and_cas.md
    calendar.md
    pomodoro_focus_guard.md
    solve_assistant.md
    quiz_generation.md
    mistakes_review.md
    notes.md
    software_workshop.md
    software_workshop_runtime_schema.md
    learning_workflow_state_machines.md
    feature_manifest.json

  manifests/
    features.json
    code_map.json
    routes.json
    apis.json
    data_models.json
    test_matrix.json

  inventory/
    module_inventory.md
    route_inventory.md
    api_inventory.md
    api_contract_examples.md
    data_model_inventory.md
    database_migrations.md

  testing/
    playwright_acceptance_plan.md
```

## 当前权威 JSON

- `manifests/features.json`：功能状态、平台能力、权限、入口文档。
- `manifests/code_map.json`：每个功能对应的 Flutter 页面、Provider、Service、后端 router、模型和测试。
- `manifests/routes.json`：路由、页面类、登录要求和说明。
- `manifests/apis.json`：关键 API、方法、请求/响应概要和测试覆盖。
- `manifests/data_models.json`：核心数据表、Dart 模型和用途。
- `manifests/test_matrix.json`：业务验收用例、测试文件、层级和状态。

## 当前结论

核心学习闭环已经有文档和自动化测试支撑：解题、出题、去练习、错题复盘、笔记润色/导入、科目/资源、RAG 来源、日历和番茄钟均已覆盖主要入口或业务合同。

剩余主要风险：

- 软件工坊仍是最大未完成域。
- Android/iOS 通知、应用锁、白名单等需要真机 L5 验收。
- 文件上传真实选择器和单文档菜单需要补稳定语义 key 后继续升级测试。
- 部分历史大文档保留为背景材料，不能当作当前实现事实。
