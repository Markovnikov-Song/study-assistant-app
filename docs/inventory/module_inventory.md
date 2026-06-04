# 模块清单

## 前端目录

| 路径 | 职责 |
| --- | --- |
| `lib/core/` | 核心基础设施：网络、主题、组件契约、能力系统、事件总线、Skill/Agent 内核 |
| `lib/components/` | 可复用业务组件：思维导图、题目、笔记、复习、解题、规划、资料库 |
| `lib/features/` | 页面级功能模块 |
| `lib/models/` | 前端领域模型和 JSON 解析 |
| `lib/providers/` | 跨模块 Riverpod 状态 |
| `lib/routes/` | GoRouter 路由定义和路径常量 |
| `lib/services/` | 前端 API service、平台 service、本地能力 service |
| `lib/tools/` | OCR、文档导出、网络工具等工具层 |
| `android/` | Android 原生工程、权限、MethodChannel、前台服务 |
| `ios/` | iOS 原生工程、MethodChannel、平台能力占位 |

## 前端功能模块

| 模块 | 路径 | 说明 | 状态 |
| --- | --- | --- | --- |
| 认证 | `lib/features/auth` | 登录、注册、鉴权状态 | 已实现 |
| 引导 | `lib/features/onboarding` | 引导页、示例资源包创建 | 部分实现 |
| 首页 Shell | `lib/features/home` | 响应式主框架、Tab 导航 | 已实现 |
| 聊天 | `lib/features/chat` | 对话、RAG、能力入口 | 已实现/需串联 |
| 科目空间 | `lib/features/subjects`、`lib/components/library` | 学科、资料、思维导图、讲义 | 部分实现 |
| 学习计划 | `lib/features/spec` | 目标拆解、计划生成、计划聊天 | 部分实现 |
| 日历 | `lib/features/calendar` | 事件、日历视图、提醒、番茄钟 | 部分实现 |
| 错题/复习 | `lib/components/mistake_book`、`lib/components/review` | 错题记录、复习队列 | 部分实现 |
| 笔记 | `lib/components/notebook` | 笔记本、笔记详情、导入知识库 | 部分实现 |
| 出题 | `lib/components/quiz` | 预测卷、自定义题、答题提交 | 部分实现 |
| 解题 | `lib/features/solve`、`lib/components/solve` | 解题会话、图片/文本解题 | 部分实现 |
| 软件工坊 | `lib/features/workshop` | Mini App 生成、编辑、运行 | 部分实现 |
| Skill 市场 | `lib/features/skill_marketplace` | Skill 浏览、下载 | 部分实现 |
| Skill 创建 | `lib/features/skill_creation` | 对话式创建 Skill | 部分实现 |
| Skill 运行 | `lib/features/skill_runner` | 已安装 Skill 运行 | 部分实现 |
| 个人中心 | `lib/features/profile` | 设置、资源、通知、Token、日志 | 已实现/持续扩展 |
| 更新 | `lib/features/update` | 应用内更新 | 部分实现 |

## 前端服务层

| 文件 | 职责 |
| --- | --- |
| `auth_service.dart` | 登录、注册、登出 |
| `subject_service.dart` | 学科 CRUD |
| `document_service.dart` | 文档上传、知识库状态、重建索引 |
| `library_service.dart` | 科目空间、思维导图、讲义、掌握度 |
| `chat_service.dart` | 聊天请求 |
| `calendar_service.dart` | 系统日历写入和学习计划提醒 |
| `notification_service.dart` | 本地通知、提醒权限、定时通知 |
| `focus_guard_platform_service.dart` | Android/iOS 专注防打扰平台桥 |
| `notebook_service.dart` | 笔记本和笔记 |
| `review_service.dart` | 错题和复习 |
| `exam_service.dart` | 试卷生成与真题相关能力 |
| `solve_sse_client.dart` | 解题流式客户端 |
| `token_service.dart` | Token 配额和使用统计 |
| `api_config_service.dart` | API Key 和共享配置 |
| `update_service.dart` | 版本检查和 APK 安装 |
| `incident_report_service.dart` | 反馈和错误上报 |

## 后端模块

| 路径 | 职责 |
| --- | --- |
| `backend/main.py` | FastAPI 入口 |
| `backend/app_routes.py` | Router 注册 |
| `backend/routers/` | API 路由层 |
| `backend/services/` | 业务服务层 |
| `backend/models/` | 数据模型层 |
| `backend/ops/` | 运维、API 连通性、事件收件箱 |
| `backend/tests/` | 后端测试 |

## 后端 Router 分组

| 分组 | Router | 说明 |
| --- | --- | --- |
| 账户 | `auth.py`、`users.py`、`token.py`、`api_config.py` | 登录、用户、额度、模型配置 |
| 学科资源 | `subjects.py`、`documents.py`、`past_exams.py`、`library.py` | 学科、资源、真题、知识库 |
| 对话与 AI | `chat.py`、`agent.py`、`cas.py`、`council.py`、`capabilities.py` | 对话、能力调度、专家组 |
| 学习计划 | `study_planner.py`、`spec_chat.py`、`planning.py` | 计划生成、计划聊天、知识导航 |
| 执行与工具 | `calendar.py`、`review.py`、`quiz.py`、`solve.py`、`notebooks.py`、`notes.py` | 日历、复习、出题、解题、笔记 |
| 软件工坊 | `mini_apps.py`、`marketplace.py`、`mcp.py` | Mini App、市场、MCP 工具 |
| 系统 | `ops.py`、`feedback.py`、`ocr.py`、`hints.py` | 运维、反馈、OCR、提示 |

## 复原注意

- 前端功能文档不能替代 API 文档；两者必须一起看。
- `components/` 中有大量业务页面，不要只看 `features/`。
- 日历、番茄钟、通知、防打扰涉及 Flutter、Android、iOS 三层。
- 软件工坊涉及 Markdown 设计文档、JSON 运行配置和图结构，必须单独复原。
