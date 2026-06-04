# 文档成熟度状态

最后更新：2026-06-04

## 总体判断

文档已经从“零散说明”升级为“可复原骨架 + 功能说明 + 机器可读索引”。目前可以支持 AI 快速理解项目结构、主要功能、核心 API、关键类和测试覆盖。

但它还不是满分规格书。真实文件上传、真机系统权限、软件工坊完整构建流、所有 API 错误态和数据库字段级约束仍需要后续持续补齐。

## 完成度分层

| 层级 | 状态 | 说明 |
| --- | --- | --- |
| 文档入口 | 高 | `docs/README.md` 已说明阅读顺序、权威来源和风险 |
| 文档治理 | 高 | `.kiro/` 已降级为历史来源，旧文档不能直接作为事实 |
| 人类可读功能文档 | 中高 | 核心功能域均有 Markdown，重点说明用户流程和边界 |
| 机器可读清单 | 中高 | 已新增 `docs/manifests/*.json`，覆盖功能、代码、路由、API、模型、测试 |
| API 合同 | 中 | 关键 API 有清单和示例，尚未覆盖所有错误态、分页、权限 |
| 数据模型 | 中 | 核心表和模型已列，字段级约束和迁移恢复仍需加强 |
| 测试文档 | 中高 | Playwright 和合同测试已成矩阵，L5 真机验收仍需人工脚本 |
| 软件工坊 | 中 | 有设计和 runtime schema，但核心业务仍待完成 |

## 已补齐的关键文档

- `docs/features/subjects_resources_rag.md`
- `docs/features/calendar.md`
- `docs/features/pomodoro_focus_guard.md`
- `docs/features/solve_assistant.md`
- `docs/features/quiz_generation.md`
- `docs/features/mistakes_review.md`
- `docs/features/notes.md`
- `docs/features/chat_and_cas.md`
- `docs/features/course_space_mindmap.md`
- `docs/features/software_workshop.md`
- `docs/manifests/features.json`
- `docs/manifests/code_map.json`
- `docs/manifests/routes.json`
- `docs/manifests/apis.json`
- `docs/manifests/data_models.json`
- `docs/manifests/test_matrix.json`

## 仍需继续补齐

1. 为所有 API 补充错误响应、权限要求、分页和幂等规则。
2. 为数据库补字段级说明、索引、唯一约束、迁移顺序和空库恢复验证。
3. 为真机通知、Android 应用锁、iOS Screen Time 能力补人工验收脚本。
4. 为文件上传和单文档菜单补 Flutter 语义 key 后升级 Playwright。
5. 软件工坊完成后，补构建、发布、运行、调试、数据持久化和安全边界文档。
6. 将根目录部署脚本、运维说明统一收进 `docs/ops/`。

## 旧文档状态

| 来源 | 当前定位 | 处理方式 |
| --- | --- | --- |
| `.kiro/specs/` | 历史规划和设计草稿 | 只在需要背景时读取，不作为当前事实 |
| `docs/项目需求功能技术分析.md` | 历史需求快照 | 需要继续蒸馏，不能覆盖新文档 |
| 旧 `.docx` 比赛/设计文档 | 对外材料或历史材料 | 保留，不作为实现事实 |
| 新 `docs/manifests/*.json` | 机器可读事实索引 | 当前优先级高于旧文档 |

## AI 使用建议

AI 接手项目时优先读取：

1. `docs/README.md`
2. `docs/manifests/features.json`
3. `docs/manifests/code_map.json`
4. `docs/manifests/apis.json`
5. 相关 `docs/features/*.md`
6. 对应测试文件

不要优先读取 `.kiro/specs/`，除非明确需要历史背景。
