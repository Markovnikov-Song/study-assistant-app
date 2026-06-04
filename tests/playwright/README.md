# Playwright Tests

本目录存放 Web 端业务验收用例。权威测试计划见
`docs/testing/playwright_acceptance_plan.md`。

## 常用命令

```powershell
npm run web:build
npm run test:web-smoke
npx playwright test tests/playwright/quiz_flow.spec.ts tests/playwright/practice_flow.spec.ts tests/playwright/mistake_flow.spec.ts tests/playwright/notebook_flow.spec.ts --reporter=list
```

## 当前业务用例

- `solve_flow.spec.ts`: 解题助手主闭环、保存笔记、加入错题。
- `quiz_flow.spec.ts`: 出题入口选择科目并生成题目。
- `practice_flow.spec.ts`: 去练习按科目进入真实做题弹层并提交答案。
- `mistake_flow.spec.ts`: 错题本待复盘列表进入复盘流程并提交复盘质量。
- `notebook_flow.spec.ts`: 笔记详情执行 AI 润色与导入资料库。
- `calendar_flow.spec.ts`: 日历、提醒测试面板、番茄钟与防打扰入口。
- `subject_resource_flow.spec.ts`: 创建科目、资料库状态读取与全量重建索引。
- `p1_shell_flow.spec.ts`: 主导航与工具入口 smoke，包括历史兼容路由。

## 编写约定

- 阻断主流程的 bug 立即修复后再继续测。
- Mock UI 用例验证前端状态、请求体和关键交互；真实后端 E2E 另设测试数据。
- Flutter Web 难以定位的控件可以补稳定语义或 key，不把坐标测试扩散到复杂业务逻辑里。
