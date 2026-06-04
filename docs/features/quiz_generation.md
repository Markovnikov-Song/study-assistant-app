# 出题与去练习

## 基本信息

| 字段 | 内容 |
| --- | --- |
| 功能 ID | `quiz.generation_practice` |
| 当前状态 | 已实现主流程 |
| 主要入口 | `/toolkit/quiz`、`/toolkit/practice` |
| 后端前缀 | `/api/exam`、`/api/quiz` |
| 自动化覆盖 | `QUIZ-P1-01`、`PRACTICE-P1-01`、`backend/tests/test_review_note_contracts.py` |

## 功能目标

出题负责根据科目、资料、题型和难度生成题目。去练习负责让用户从科目、知识点或计划进入真实作答流程，并把答案提交给后端判题。错误答案可以进入错题系统。

## 产品边界

- `/toolkit/quiz`：偏“我要生成一套题”。
- `/toolkit/practice`：偏“我要开始练习”。
- 错题复盘不放在去练习一级入口，避免和错题本/复习队列冲突。
- 计划中的 `quiz.generate` 能力会跳到 `/toolkit/practice`，再进入练习。

## 用户流程

1. 用户进入出题或去练习。
2. 出题页选择科目、资料模式、题型、难度和题量。
3. 去练习页可以按科目、知识点或计划开始。
4. 系统调用出题接口生成题目。
5. 用户选择答案并提交。
6. 后端返回判题结果；错误时可收录错题并创建复习卡。

## 技术结构

| 层级 | 文件 | 说明 |
| --- | --- | --- |
| 出题页 | `lib/components/quiz/quiz_page.dart` | 自定义出题、科目选择、题型配置 |
| 练习页 | `lib/features/practice/practice_page.dart` | 按科目/知识点/计划组织练习 |
| 练习弹层 | `lib/components/quiz/node_practice_sheet.dart` | 生成题目、逐题作答、提交答案、汇总 |
| 能力上下文 | `lib/core/capability/capability_execution_contract.dart` | 计划参数转 query |
| 能力跳转 | `lib/features/spec/services/capability_launch_service.dart` | `quiz.generate` 跳到 `/toolkit/practice` |
| 后端 | `backend/routers/quiz.py` | 出题和判题 |
| 后端 | `backend/routers/review.py` | 错题收录和复习卡 |

## API 合同

核心端点：

- `POST /api/exam/custom`
- `POST /api/quiz/generate`
- `POST /api/quiz/submit-answer`

练习生成请求示例：

```json
{
  "node_id": "subject-11",
  "node_title": "Playwright Algebra",
  "question_count": 3,
  "subject_id": 11
}
```

答案提交请求示例：

```json
{
  "question_id": "practice-q1",
  "user_answer": "B",
  "node_id": "subject-11",
  "node_title": "Playwright Algebra",
  "question_type": "choice",
  "subject_id": 11
}
```

## 行为边界

- 生成题目失败时不应创建错题。
- 判题失败时应允许用户重试提交。
- 计划任务完成回写只在练习完成回调中触发。
- 题型 schema 仍需继续扩展到更多题型 UI。

## 验证方式

- `npx playwright test tests/playwright/quiz_flow.spec.ts tests/playwright/practice_flow.spec.ts --reporter=list`
- `python -m pytest backend/tests/test_review_note_contracts.py`

验收点：

- 自定义出题请求体包含科目、资料模式、题型和难度。
- 按科目练习能生成题目并提交答案。
- 提交答案时保留 `subject_id/node_id/node_title`。
- 后端合同能判题、收录错题并创建复习卡。
