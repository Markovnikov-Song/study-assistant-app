# 后端 API 清单

后端入口为 `backend/main.py`，Router 注册在 `backend/app_routes.py`。

## Router 前缀

| 前缀 | Router | 说明 |
| --- | --- | --- |
| `/api/auth` | `auth.py` | 注册、登录、登出 |
| `/api/users` | `users.py` | 当前用户资料、头像、密码 |
| `/api/token` | `token.py` | Token 配额、使用记录 |
| `/api/api-config` | `api_config.py` | 模型/API 配置 |
| `/api/subjects` | `subjects.py` | 科目 CRUD、置顶、归档 |
| `/api/documents` | `documents.py` | 学习资料上传、重建索引、知识库状态 |
| `/api/past-exams` | `past_exams.py` | 真题文件和题目 |
| `/api/library` | `library.py` | 科目空间、思维导图、讲义、掌握度、知识链接 |
| `/api/chat` | `chat.py` | 聊天、流式聊天、记忆、思维导图生成 |
| `/api/sessions` | `sessions.py` | 会话列表、历史、搜索 |
| `/api/agent` | `agent.py` | Skill、意图解析、节点执行、对话式 Skill 创建 |
| `/api/cas` | `cas.py` | 能力动作列表、调度、日志 |
| `/api/council` | `council.py` | 多专家协作决策 |
| `/api/capabilities` | `capabilities.py` | 能力定义、组合草稿 |
| `/api/study-planner` | `study_planner.py` | 学习计划、今日任务、重排计划、通知注册 |
| `/api/spec` | `spec_chat.py` | 学习计划聊天 |
| `/api/planning` | `planning.py` | 知识导航、计划、Skill 推荐 |
| `/api/calendar` | `calendar.py` | 日历事件、例程、学习会话、统计 |
| `/api/review` | `review.py` | 错题、复习队列、掌握度 |
| `/api/quiz` | `quiz.py` | 出题、题型、答题提交 |
| `/api/solve` | `solve.py` | 解题会话 |
| `/api/notebooks` | `notebooks.py` | 笔记本 |
| `/api` | `notes.py` | 笔记 CRUD、润色、导入 RAG |
| `/api/mini-apps` | `mini_apps.py` | Mini App 保存、校验、运行、访谈生成 |
| `/api/marketplace` | `marketplace.py` | Skill 市场 |
| `/api/mcp` | `mcp.py` | MCP 服务器与工具调用 |
| `/api/exam` | `exam_gen.py` | 预测卷、自定义题 |
| `/api/exam-prep` | `exam_prep.py` | 备考输入 |
| `/api/ocr` | `ocr.py` | OCR 图片识别 |
| `/api/hints` | `hints.py` | 学科提示 |
| `/api/feedback` | `feedback.py` | 反馈和趋势 |
| `/api/ops` | `ops.py` | 连通性守护、事件收件箱 |

## 关键端点摘要

### 学习日历

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/api/calendar/events` | 创建事件 |
| GET | `/api/calendar/events` | 按日期范围查询事件 |
| GET | `/api/calendar/events/today` | 今日事件和完成统计 |
| PATCH | `/api/calendar/events/{event_id}` | 更新事件 |
| DELETE | `/api/calendar/events/{event_id}` | 删除事件 |
| POST | `/api/calendar/events/batch` | 批量创建事件 |
| POST | `/api/calendar/routines` | 创建例程 |
| GET | `/api/calendar/routines` | 查询例程 |
| POST | `/api/calendar/sessions` | 写入学习会话 |
| GET | `/api/calendar/stats` | 查询学习统计 |

### 科目空间与资料

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/api/subjects` | 科目列表 |
| POST | `/api/subjects` | 创建科目 |
| GET | `/api/documents` | 文档列表 |
| POST | `/api/documents` | 上传文档 |
| GET | `/api/documents/knowledge-base` | 知识库状态 |
| GET | `/api/library/subjects` | 带进度的科目 |
| GET | `/api/library/subjects/{subject_id}/sessions` | 思维导图会话 |
| GET | `/api/library/sessions/{session_id}/nodes` | 节点树 |
| GET | `/api/library/lectures/{session_id}` | 讲义 |
| POST | `/api/library/lectures` | 创建/生成讲义 |

### 错题、复习、笔记、出题、解题

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/api/review/mistakes` | 错题列表 |
| POST | `/api/review/mistakes` | 创建错题 |
| GET | `/api/review/review/queue` | 复习队列 |
| POST | `/api/review/review/card/{card_id}/rate` | 复习评分 |
| GET | `/api/notebooks` | 笔记本列表 |
| GET | `/api/notebooks/{notebook_id}/notes` | 笔记本内笔记 |
| POST | `/api/notes` | 创建笔记 |
| POST | `/api/notes/{note_id}/polish` | 润色笔记 |
| POST | `/api/notes/{note_id}/import-to-rag` | 导入知识库 |
| POST | `/api/quiz/generate` | 生成题目 |
| POST | `/api/quiz/submit-answer` | 提交答案 |
| GET | `/api/solve/sessions` | 解题会话列表 |
| GET | `/api/solve/sessions/{session_id}` | 解题会话详情 |

### 软件工坊

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/api/mini-apps` | Mini App 列表 |
| POST | `/api/mini-apps` | 保存 Mini App |
| PUT | `/api/mini-apps/{app_id}` | 更新 Mini App |
| POST | `/api/mini-apps/validate` | 校验运行配置 |
| GET | `/api/mini-apps/blocks` | 可用积木块 |
| POST | `/api/mini-apps/generate-cards` | 生成卡片内容 |
| POST | `/api/mini-apps/{app_id}/runs/start` | 开始运行 |
| POST | `/api/mini-apps/runs/{run_id}/events` | 提交运行事件 |
| POST | `/api/mini-apps/interview/start` | 开始访谈式生成 |
| POST | `/api/mini-apps/interview/{session_id}/answer` | 继续访谈式生成 |

## 复原要求

- 每个端点都应有 Pydantic 请求/响应模型。
- 前端 service 方法名应和后端端点语义一致。
- API 文档应在后续补充请求/响应 JSON 示例。
- 涉及长任务的接口要说明任务状态、轮询方式和失败状态。
