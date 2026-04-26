# Bugfix Requirements Document

## Introduction

本项目（Flutter + FastAPI 学习助手 App）存在多处"引用存在但实现缺失"的系统性问题，导致运行时出现 404 / ImportError / 功能静默失效。经全面扫描，共发现以下 4 类缺陷：

1. **OCR 端点路径不匹配**：Flutter 调用 `POST /api/ocr/recognize`，后端只有 `POST /api/ocr/image`，导致 404。
2. **`/api/skills/parse` 端点缺失**：`skill_parser_impl.dart` 调用该端点，后端无对应路由，导致 404。
3. **`SceneType.planning` 确认后无任何操作**：`chat_page.dart` 中 `case SceneType.planning: break`，用户点击确认后界面无响应。
4. **同名 `SkillMarketplaceService` 双文件共存**：`lib/services/skill_marketplace_service.dart`（全占位符）与 `lib/core/skill/skill_marketplace_service.dart`（真实实现）同名共存，易被错误引用。

---

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN Flutter 的 `OcrApiClient` 调用 `POST /api/ocr/recognize` THEN 后端返回 404，OCR 功能完全不可用

1.2 WHEN `AiSkillParser.parse()` 调用 `POST /api/skills/parse` THEN 后端返回 404，文本解析创建 Skill 功能完全不可用

1.3 WHEN 用户在聊天页面确认 `SceneType.planning` 类型的场景卡片 THEN 系统执行 `break` 后什么都不做，用户无任何反馈或跳转

1.4 WHEN 代码通过 `import '../services/skill_marketplace_service.dart'` 引用市场服务 THEN 实际使用的是全占位符实现，所有市场操作返回假数据而非真实 API 调用

### Expected Behavior (Correct)

2.1 WHEN Flutter 的 `OcrApiClient` 调用 `POST /api/ocr/recognize` THEN 后端 SHALL 正确响应（通过在 `ocr.py` 中添加 `/recognize` 别名路由，或修正 Flutter 端调用路径为 `/api/ocr/image`）

2.2 WHEN `AiSkillParser.parse()` 调用 `POST /api/skills/parse` THEN 后端 SHALL 返回解析后的 Skill 草稿结构（`{name, description, tags, steps}`），或 Flutter 端改为调用已存在的 `/api/agent/parser/config` 相关端点

2.3 WHEN 用户确认 `SceneType.planning` 类型的场景卡片 THEN 系统 SHALL 跳转到学习规划页面（`/toolkit/study-planner` 或通用对话页），给用户明确的视觉反馈

2.4 WHEN 代码需要使用 Skill 市场服务 THEN 系统 SHALL 只存在一个真实实现（`lib/core/skill/skill_marketplace_service.dart`），占位符文件 SHALL 被删除或重命名以消除歧义

### Unchanged Behavior (Regression Prevention)

3.1 WHEN Flutter 调用 `POST /api/ocr/image`（旧路径）THEN 系统 SHALL CONTINUE TO 正常识别图片文字（不破坏已有调用）

3.2 WHEN 用户确认 `SceneType.subject`、`SceneType.tool`、`SceneType.spec`、`SceneType.calendar` 类型的场景卡片 THEN 系统 SHALL CONTINUE TO 执行原有的跳转逻辑

3.3 WHEN `lib/core/skill/skill_marketplace_service.dart` 的现有调用方（`SkillMarketplacePage` 等）使用市场服务 THEN 系统 SHALL CONTINUE TO 正常调用真实 API 端点

3.4 WHEN 后端 `agent.py` 中的 `/api/agent/skills`、`/api/agent/execute-node` 等端点被调用 THEN 系统 SHALL CONTINUE TO 正常工作

3.5 WHEN 所有已挂载的 router（auth、subjects、sessions、chat 等）被调用 THEN 系统 SHALL CONTINUE TO 正常响应（已确认所有 router 均已在 `main.py` 中注册）

3.6 WHEN 后端代码引用 `PaymentOrder`、`MindmapKnowledgeLink` 等 ORM 模型 THEN 系统 SHALL CONTINUE TO 正常导入（已确认两者均已在 `database.py` 中定义）
