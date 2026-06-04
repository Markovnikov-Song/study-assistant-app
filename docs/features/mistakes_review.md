# 错题本与复习队列

## 基本信息

| 字段 | 内容 |
| --- | --- |
| 功能 ID | `review.mistakes` |
| 当前状态 | 已实现主流程 |
| 主要入口 | `/toolkit/mistake-book`、`/toolkit/review` |
| 后端前缀 | `/api/review` |
| 自动化覆盖 | `MISTAKE-P1-01`、`backend/tests/test_review_note_contracts.py` |

## 功能目标

错题本负责保存错误题目和复盘记录。复习队列负责根据掌握度、复盘结果和 SM-2 类调度逻辑安排下次复习。

产品心智：

- `去练习`：执行练习。
- `错题本`：查看和复盘错题。
- `复习队列`：后端调度机制，不作为工具箱主入口。
- `/toolkit/review`：历史兼容路由，打开错题本。

## 用户流程

1. 用户在练习、出题或解题中答错或手动加入错题。
2. 后端创建错题记录，并在条件满足时创建复习卡片。
3. 用户进入错题本，查看待复盘和已复盘错题。
4. 用户点开待复盘错题，按步骤查看题干、答案、解析、类似练习和复盘评分。
5. 用户提交复盘质量。
6. 后端更新错题状态、掌握度和下次复习时间。

## 技术结构

| 层级 | 文件 | 说明 |
| --- | --- | --- |
| 错题列表 | `lib/components/mistake_book/mistake_book_page.dart` | 待复盘/已复盘 Tab |
| 复盘页 | `lib/components/review/review_session_page.dart` | 多步骤复盘和质量提交 |
| Provider | `lib/providers/review_provider.dart` | pending/reviewed/queue Provider 和提交逻辑 |
| Service | `lib/services/review_service.dart` | Review API |
| 模型 | `lib/models/review.dart` | `Mistake`、`ReviewItem`、`ReviewSubmitResult` |
| 后端 | `backend/routers/review.py` | 错题、复习提交、队列、掌握度 |

## API 合同

核心端点：

- `GET /api/review/mistakes?status=pending`
- `GET /api/review/mistakes?status=reviewed`
- `POST /api/review/mistakes/from-practice`
- `POST /api/review/review/submit`
- `GET /api/review/review/queue`

`review/submit` 请求核心字段：

```json
{
  "note_id": 501,
  "quality": 3,
  "review_content": "",
  "practice_correct": null
}
```

## 行为边界

- 错题本不是“再做题”的主入口；练习入口在 `/toolkit/practice`。
- 复习队列不是工具箱主入口，而是后端调度与 Provider 数据源。
- 类似题练习可以继续深化，但不影响错题复盘主流程。

## 验证方式

- `npx playwright test tests/playwright/mistake_flow.spec.ts --reporter=list`
- `python -m pytest backend/tests/test_review_note_contracts.py`

验收点：

- 待复盘列表可打开复盘页。
- 复盘评分会提交到 `/api/review/review/submit`。
- 请求体包含 `note_id` 和合法 `quality`。
- 后端合同能创建错题、创建复习卡并维护 SM-2 相关字段。
