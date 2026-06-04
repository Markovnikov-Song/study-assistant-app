# 文档治理规则

## 权威顺序

当文档之间冲突时，按以下顺序判断：

1. 当前代码和通过的测试。
2. `docs/manifests/*.json`。
3. `docs/features/*.md`。
4. `docs/inventory/*.md`。
5. `docs/testing/*.md`。
6. 根目录 README、历史设计文档、`.docx`。
7. `.kiro/specs/`。

`.kiro/specs/` 是历史材料，不是当前事实。

## 旧文档处理

旧文档可能包含：

- 已经实现但名字变化的功能。
- 曾计划但没有实现的功能。
- 已被新架构替代的旧路由、旧 Agent、旧接口。
- 占位端点或占位文件。

处理规则：

- 有效的用户故事可以蒸馏到 `docs/features/`。
- 有效的技术事实可以蒸馏到 `docs/inventory/` 或 `docs/manifests/`。
- 未实现设想必须标成 `planned` 或 `partial`。
- 过时内容不要直接复制进新文档。

## 文档更新触发条件

以下改动必须同步更新文档：

- 新增、删除或重命名路由。
- 新增或修改 API 请求/响应。
- 新增或修改数据库字段。
- 新增平台权限或原生通道。
- 改变用户可见流程。
- 新增或删除测试用例。
- 将占位功能改成真实功能。

## AI 阅读规则

AI 接手任务时：

- 先读 `docs/README.md`。
- 再读 `docs/manifests/code_map.json` 找代码入口。
- 再读对应 `docs/features/*.md`。
- 不要先读 `.kiro/specs/`。
- 如果旧文档和新 manifest 冲突，以 manifest 和当前测试为准。

## 状态定义

| 状态 | 含义 |
| --- | --- |
| `planned` | 已规划，未实现 |
| `prototype` | 有 UI 或 demo，但未接真实数据 |
| `partial` | 部分可用，还有关键缺口 |
| `implemented` | 主流程已实现并有测试或合同支撑 |
| `blocked` | 受平台、权限、政策或依赖限制 |
| `deprecated` | 已废弃，不应继续开发 |
