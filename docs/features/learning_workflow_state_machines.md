# 核心学习流程状态机

本文横向说明日历、番茄钟、出题、练习、解题、错题和笔记之间如何流转。它不是单个页面说明，而是给 AI 复原学习闭环用的流程图。

## 总体闭环

```text
科目/资料/对话
  -> 资料库与 RAG
  -> 思维导图/讲义/出题/解题
  -> 日历安排
  -> 番茄钟执行
  -> 练习或解题结果
  -> 错题、笔记、掌握度
  -> 复习队列和下一轮计划
```

## 日历事件状态机

| 状态 | 含义 |
| --- | --- |
| `draft` | 用户正在创建事件 |
| `scheduled` | 事件已保存 |
| `reminder_pending` | 已安排本地提醒 |
| `in_progress` | 用户开始学习或番茄钟 |
| `completed` | 用户完成学习 |
| `cancelled` | 用户删除或取消事件 |

关键转移：

- 保存事件：`draft -> scheduled`
- 开启提醒：`scheduled -> reminder_pending`
- 开始番茄钟：`scheduled/reminder_pending -> in_progress`
- 结束学习：`in_progress -> completed`
- 删除事件：任意未完成状态 -> `cancelled`

对应代码：

- `lib/features/calendar/calendar_page.dart`
- `lib/features/calendar/providers/calendar_providers.dart`
- `lib/features/calendar/widgets/event_form_sheet.dart`
- `backend/routers/calendar.py`

## 番茄钟状态机

| 状态 | 含义 |
| --- | --- |
| `idle` | 未开始 |
| `focus_running` | 专注计时中 |
| `paused` | 暂停 |
| `resting` | 休息中 |
| `completed` | 一轮完成 |
| `guard_active` | 防打扰服务生效 |
| `guard_blocked` | 权限不足，无法锁应用 |

关键转移：

- 启动：`idle -> focus_running`
- 暂停：`focus_running -> paused`
- 继续：`paused -> focus_running`
- 结束：`focus_running -> completed`
- 权限足够时：`focus_running -> guard_active`
- 权限不足时：`focus_running -> guard_blocked`

对应代码：

- `lib/features/calendar/widgets/pomodoro_timer.dart`
- `lib/features/calendar/providers/focus_guard_provider.dart`
- `lib/services/focus_guard_platform_service.dart`
- `android/app/src/main/kotlin/cn/studyassistant/app/FocusGuardService.kt`

## 练习与出题状态机

| 状态 | 含义 |
| --- | --- |
| `select_scope` | 选择科目、知识点或计划 |
| `generating` | 请求生成题目 |
| `answering` | 用户作答 |
| `submitted` | 已提交答案 |
| `review_created` | 错题或复习卡已创建 |
| `completed` | 本轮练习完成 |

关键转移：

- 进入 `/toolkit/practice`：`select_scope`
- 打开 `NodePracticeSheet`：`generating`
- 题目返回：`generating -> answering`
- 提交答案：`answering -> submitted`
- 答错并收录：`submitted -> review_created`
- 总结完成：`submitted/review_created -> completed`

对应代码：

- `lib/features/practice/practice_page.dart`
- `lib/components/quiz/node_practice_sheet.dart`
- `backend/routers/quiz.py`
- `backend/routers/review.py`

## 解题状态机

| 状态 | 含义 |
| --- | --- |
| `input` | 用户输入文本或图片 |
| `ocr` | 图片 OCR |
| `streaming` | SSE 返回解析 |
| `chart_rendering` | Python 图表渲染 |
| `saved_note` | 保存为笔记 |
| `saved_mistake` | 加入错题 |
| `history_restored` | 历史恢复 |
| `error_recoverable` | 错误但可继续输入 |

对应代码：

- `lib/components/solve/solve_page.dart`
- `lib/services/solve_sse_client.dart`
- `backend/cas/executors/solve_problem.py`
- `backend/routers/solve.py`

## 错题复盘状态机

| 状态 | 含义 |
| --- | --- |
| `pending` | 待复盘 |
| `reviewing` | 用户正在复盘 |
| `rated` | 用户提交复盘质量 |
| `reviewed` | 已复盘 |
| `queued` | 后端安排下次复习 |

关键转移：

- 创建错题：`pending`
- 打开错题：`pending -> reviewing`
- 提交评分：`reviewing -> rated`
- 后端更新：`rated -> reviewed/queued`

对应代码：

- `lib/components/mistake_book/mistake_book_page.dart`
- `lib/components/review/review_session_page.dart`
- `lib/providers/review_provider.dart`
- `backend/routers/review.py`

## 笔记状态机

| 状态 | 含义 |
| --- | --- |
| `created` | 笔记已创建 |
| `viewing` | 查看详情 |
| `editing` | 编辑中 |
| `polishing` | AI 润色中 |
| `importing_to_rag` | 导入资料库中 |
| `rag_imported` | 已导入资料库 |

对应代码：

- `lib/components/notebook/note_detail_page.dart`
- `lib/providers/notebook_provider.dart`
- `lib/services/notebook_service.dart`
- `backend/routers/notes.py`

## 验收矩阵

机器可读测试矩阵见：

- `docs/manifests/test_matrix.json`

核心自动化文件：

- `tests/playwright/calendar_flow.spec.ts`
- `tests/playwright/quiz_flow.spec.ts`
- `tests/playwright/practice_flow.spec.ts`
- `tests/playwright/mistake_flow.spec.ts`
- `tests/playwright/notebook_flow.spec.ts`
- `tests/playwright/solve_flow.spec.ts`
- `test/providers/chat_provider_sources_test.dart`
