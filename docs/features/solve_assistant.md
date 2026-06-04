# 解题助手

## 基本信息

| 字段 | 内容 |
| --- | --- |
| 功能 ID | `solve.assistant` |
| 当前状态 | 已实现主流程 |
| 主要入口 | `/toolkit/solve` |
| 后端前缀 | `/api/cas`、`/api/solve`、`/api/ocr` |
| 自动化覆盖 | `SA-P0-01..08`、`backend/tests/test_solve_history.py` |

## 功能目标

解题助手帮助用户输入题目文本或图片，获得分步解析、知识点提示和可追问内容。解题结果可以保存为笔记，也可以加入错题本，成为后续复习和练习的输入。

## 用户流程

1. 用户打开解题助手。
2. 用户输入题目文本，或上传/拍摄题目图片。
3. 图片题先经过 OCR。
4. 前端通过 CAS/解题 SSE 接收模型输出。
5. 如果模型触发 Python 计算或图表，后端通过工具执行并把结果注入回答。
6. 用户可以保存为笔记。
7. 用户可以加入错题本，并选择科目/错误原因。
8. 用户可以打开历史记录并恢复会话继续追问。

## 技术结构

| 层级 | 文件 | 说明 |
| --- | --- | --- |
| 页面 | `lib/components/solve/solve_page.dart` | 解题主页面、SSE 消费、保存/错题入口、历史恢复 |
| 操作条 | `lib/widgets/solve_result_action_bar.dart` | 保存笔记和加入错题 |
| 历史 UI | `lib/features/solve/widgets/solve_history_sheet.dart` | 历史列表、详情、删除 |
| 历史模型 | `lib/features/solve/models/solve_session.dart` | 解题历史数据 |
| 历史服务 | `lib/features/solve/services/solve_history_service.dart` | `/api/solve/sessions` |
| SSE 客户端 | `lib/services/solve_sse_client.dart` | `[DONE]`、`[ERROR]`、`[CHART]` 解析 |
| 后端执行器 | `backend/cas/executors/solve_problem.py` | OCR、Prompt、SSE、持久化、工具调用 |
| OCR | `backend/services/ocr_service.py` | 图片识别 |
| 图像预处理 | `backend/services/image_preprocessor.py` | 可选预处理，默认关闭 |
| Python 工具 | `backend/mcp_servers/python_executor_server.py` | 受限 Python 执行和图表 |

## API 与事件

核心端点：

- `POST /api/cas/dispatch`
- `GET /api/solve/sessions`
- `GET /api/solve/sessions/{id}`
- `DELETE /api/solve/sessions/{id}`
- `POST /api/notes`
- `POST /api/review/mistakes/from-practice`

SSE 事件：

- 普通 token：追加到当前答案。
- `[DONE]`：完成，通常携带 `session_id`。
- `[ERROR]`：错误，不应破坏已输入题目。
- `[CHART]`：Python 图表，包含 `image_base64`。

## 数据流

- `conversation_sessions.session_type = "solve"`。
- 用户图片保存在 `conversation_history.sources.images`。
- AI 解题内容写入 `conversation_history.content`。
- 保存笔记时写入 `notes`。
- 加入错题时写入 `notes` 的 mistake 字段，并可创建 `review_cards`。

## 行为边界

- OCR 失败时应允许用户继续手动输入。
- 图表解码失败时只显示图表失败提示，不影响文字解析。
- Python 执行必须继续做沙箱安全审计，不能把模型输出的任意代码无限制执行。
- 图片预处理默认关闭，打开后需要真机性能验证。

## 验证方式

- `npx playwright test tests/playwright/solve_flow.spec.ts --reporter=list`
- `python -m pytest backend/tests/test_solve_history.py`

验收点：

- 文本题能流式返回。
- 保存笔记请求包含 `sources.type=solve`。
- 加入错题请求走 `/api/review/mistakes/from-practice`。
- 历史列表和详情可恢复。
- 错误态不锁死输入框。
