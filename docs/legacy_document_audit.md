# 旧文档审计与蒸馏报告

## 结论

`.kiro/specs/` 和根目录旧 Markdown 中有大量有价值的需求、设计和修复背景，但它们混合了三类内容：

- 已实现但表述过期。
- 当时计划实现但后来没有完整落地。
- 被后续架构替换或命名变化的旧概念。

因此，旧文档不应再作为 AI 的默认上下文。当前权威入口是 `docs/README.md`，旧文档只作为历史材料使用。

## .kiro 规格分类

| 旧规格 | 建议处理 | 可保留精华 | 主要风险 |
| --- | --- | --- | --- |
| `automated-learning-pipeline` | 蒸馏进项目蓝图和计划/日历文档 | 自动学习闭环、计划、日历、通知、错题反馈 | 多阶段任务可能被误读为已完成 |
| `calendar-planner` | 蒸馏进 `features/calendar.md` | 事件、例程、学习会话、统计、日历视图 | 通知和番茄钟已有新实现，旧设计不完整 |
| `calendar-tab-type-error` | 归档为历史修复 | 类型错误分析方式 | 修复类文档不应作为功能规格 |
| `component-ecosystem` | 蒸馏进能力生态/软件工坊 | 组件注册、能力生态、工具化思想 | 容易与当前 Mini App/Capability 命名混淆 |
| `knowledge-graph-evolution` | 蒸馏进科目空间和数据模型 | 节点状态、掌握度、学习路径、知识关联 | 很多高级图谱能力仍是规划 |
| `lecture-book-export` | 蒸馏进科目空间文档 | 讲义导出、书籍化导出 | 导出能力需以当前代码为准 |
| `mindmap-editor` | 蒸馏进科目空间文档 | 导图编辑、节点操作、交互 | 当前导图能力和旧编辑器设计可能不一致 |
| `mindmap-knowledge-graph` | 蒸馏进科目空间/数据模型 | 节点关系、知识链接 | 不能当成完整知识图谱系统已实现 |
| `missing-implementations-fix` | 归档为历史修复 | OCR 路径、技能解析、场景跳转等问题意识 | 旧 bug 状态可能已变化 |
| `multimodal-problem-solver` | 蒸馏进解题助手文档 | 多模态输入、保存、思维过程折叠、非解题意图拦截 | 不代表所有前端体验已落地 |
| `notebook-type-error-and-ux-fix` | 归档为历史修复 | 笔记类型和 UX 修复点 | 修复记录不是功能规格 |
| `rag-pipeline-upgrade` | 蒸馏进科目空间/RAG 文档 | 解析、切片、重排、严格教材问答 | 工具名和 MCP 方案需核验 |
| `solve-enhancement` | 蒸馏进解题助手文档 | 解题历史、Python 计算、图像预处理、测试属性 | Python 执行器和图像预处理不应默认视为已完成 |
| `study-planner` | 蒸馏进学习计划和日历文档 | 三阶段计划页、计划项、状态机、今日任务 | Agent 名称、Level 监控、推送占位易误导 |
| `systematic-bug-fix` | 归档为历史修复 | 系统性排查方法 | 旧问题状态需重新验证 |

## 根目录旧文档分类

| 文档类型 | 示例 | 建议处理 |
| --- | --- | --- |
| 发布/部署 | `HOW_TO_RELEASE.md`、`RELEASE_GUIDE.md`、`快速部署v1.2.0.md` | 后续蒸馏到 `docs/ops/release.md` |
| 修复总结 | `修复总结.md`、`快速修复指南.md`、`本次更新总结.md` | 作为历史，不给 AI 默认阅读 |
| 后台保活 | `后台保活完整方案.md`、`防止后台被杀说明.md` | 蒸馏到平台权限文档 |
| API 配置 | `手动修复API配置.md` | 蒸馏到配置文档 |
| 日历通知 | `日历通知功能说明.md` | 已被 `features/calendar.md` 和 `pomodoro_focus_guard.md` 替代 |
| 迁移说明 | `PAYMENT_TO_OPENSOURCE_MIGRATION.md`、`PROMPT_MIGRATION_GUIDE.md` | 作为历史架构背景 |

## 已蒸馏进权威文档的内容

- 学习闭环：进入 `docs/project_blueprint.md`。
- 文档复原顺序：进入 `docs/reconstruction_guide.md`。
- 模块边界：进入 `docs/inventory/module_inventory.md`。
- 路由：进入 `docs/inventory/route_inventory.md`。
- API 前缀和关键端点：进入 `docs/inventory/api_inventory.md`。
- 日历和通知：进入 `docs/features/calendar.md`。
- 番茄钟和防打扰：进入 `docs/features/pomodoro_focus_guard.md`。
- 软件工坊：进入 `docs/features/software_workshop.md`。
- 解题增强：进入 `docs/features/solve_assistant.md`，已区分历史、Python 计算、图像预处理的真实状态。
- RAG 流水线升级：进入 `docs/features/course_space_mindmap.md`，已区分解析、切片、精排、递归大纲的真实状态。

## 仍需继续蒸馏的内容

- RAG 流水线的端到端验收状态。
- 讲义/书籍导出的真实实现状态。
- Mindmap 编辑能力的真实实现状态。
- 解题助手中错题/笔记保存、历史恢复追问、Python 沙箱安全的验收状态。
- 发布部署文档的统一版本。
- 后台保活和平台权限的统一说明。

## 禁止直接继承的旧说法

这些说法在旧文档中出现过，但后续文档和代码必须重新核验：

- “后端完整，前端待实现”
- “已完整实现”
- “Level 3 推送通知”
- “Multi-Agent 已闭环调度计划”
- “Python 计算引擎已集成”
- “图像预处理五步流水线已接入”
- “Skill 执行引擎完整”
- “知识图谱进化已完成”

正确写法应是：

```text
当前状态：partial。
已实现：列出具体代码/API/UI。
未实现：列出缺口。
验证方式：列出可运行命令或手动路径。
```
