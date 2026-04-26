# Implementation Plan

- [x] 1. 编写 Bug Condition 探索性测试
  - **Property 1: Bug Condition** - 四处缺失实现的根因确认
  - **CRITICAL**: 这些测试必须在未修复代码上运行并 FAIL — 失败即证明 Bug 存在
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: 测试编码了期望行为 — 修复后测试通过即验证修复有效
  - **GOAL**: 产生反例，确认根因分析
  - **Scoped PBT Approach**: 针对确定性 Bug，将属性范围限定到具体失败用例以确保可复现性
  - **Bug 1 — OCR 路径**：Mock Dio，调用 `OcrApiClient.recognize()`，断言请求路径为 `/api/ocr/image`（未修复时路径为 `/api/ocr/recognize`，断言失败）
  - **Bug 2 — Parse 端点**：向后端发送 `POST /api/agent/parse`，断言返回 200（未修复时 404，失败）
  - **Bug 3 — Planning 导航**：Mock `BuildContext`，触发 `SceneType.planning` 确认，断言 `context.push('/spec')` 被调用（未修复时 `break`，失败）
  - **Bug 4 — 占位符文件**：断言 `lib/services/skill_marketplace_service.dart` 不存在（未修复时文件存在，失败）
  - 运行测试，记录反例：
    - OCR 请求路径为 `/api/ocr/recognize` 而非 `/api/ocr/image`
    - `POST /api/agent/parse` 返回 404
    - `context.push` 未被调用
    - 占位符文件存在
  - **EXPECTED OUTCOME**: 测试 FAIL（这是正确的 — 证明 Bug 存在）
  - 标记任务完成：测试已编写、已运行、失败已记录
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 2. 编写 Preservation 属性测试（在实现修复之前）
  - **Property 2: Preservation** - 非 Bug 输入行为不变
  - **IMPORTANT**: 遵循观察优先方法论
  - 在未修复代码上观察非 Bug 输入的行为：
    - 观察：`POST /api/ocr/image` 在未修复代码上正常返回 200
    - 观察：`SceneType.subject`、`tool`、`spec`、`calendar` 的跳转逻辑正常执行
    - 观察：`lib/core/skill/skill_marketplace_service.dart` 的调用方正常使用真实 API
    - 观察：`/api/agent/resolve-intent`、`/api/agent/execute-node` 等端点正常响应
  - 编写属性测试，捕获上述观察到的行为模式（来自 design.md Preservation Requirements）：
    - 对所有非 `planning` 的 `SceneType`，跳转逻辑与修复前完全一致
    - `POST /api/ocr/image` 继续正常工作
    - `agent.py` 已有端点继续正常响应
  - 在未修复代码上运行测试
  - **EXPECTED OUTCOME**: 测试 PASS（确认基线行为，供后续回归检查）
  - 标记任务完成：测试已编写、已运行、在未修复代码上通过
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [-] 3. 修复四处缺失实现

  - [x] 3.1 修复 Bug 1：修改 `OcrApiClient` 调用路径与请求格式
    - 将 `lib/tools/ocr/ocr_api_client.dart` 中 `_dio.post('/api/ocr/recognize', ...)` 改为 `_dio.post('/api/ocr/image', ...)`
    - 将请求体从 `FormData`（multipart）改为 JSON `{"image": base64String}`，以匹配后端 `OcrIn(image: str)` 模型
    - 将响应解析从 `{"lines": [...]}` 改为 `{"text": "..."}` 以匹配后端 `OcrOut(text: str)`
    - 可引用 `api_constants.dart` 中已有的 `ocrImage = '/api/ocr/image'` 常量
    - _Bug_Condition: `isBugCondition_ocr(call)` — `call.path == "/api/ocr/recognize"` 且后端无该路由_
    - _Expected_Behavior: `OcrApiClient.recognize()` 向 `POST /api/ocr/image` 发送 JSON 请求，后端返回 `{"text": "..."}`_
    - _Preservation: `POST /api/ocr/image` 端点继续正常工作，不破坏任何已有调用_
    - _Requirements: 2.1, 3.1_

  - [x] 3.2 修复 Bug 2：在 `agent.py` 新增 `/parse` 端点并修正 Flutter 调用路径
    - 在 `backend/routers/agent.py` 中新增 `SkillParseIn(BaseModel)`（含 `text: str`）和 `SkillParseOut(BaseModel)`（含 `name`, `description`, `tags`, `steps`）
    - 新增 `@router.post("/parse", response_model=SkillParseOut)` 端点，挂载后路径为 `/api/agent/parse`
    - 端点内部使用 LLM 解析文本，提取步骤、名称、描述、标签；对空文本返回 400
    - 修改 `lib/core/skill/skill_parser_impl.dart`，将调用路径从 `/api/skills/parse` 改为 `/api/agent/parse`
    - _Bug_Condition: `isBugCondition_parse(call)` — `call.path == "/api/skills/parse"` 且后端无该路由_
    - _Expected_Behavior: `POST /api/agent/parse` 返回 200 及 `{name, description, tags, steps}` 结构_
    - _Preservation: `agent.py` 中已有端点（`/resolve-intent`、`/execute-node` 等）继续正常工作_
    - _Requirements: 2.2, 3.4_

  - [x] 3.3 修复 Bug 3：修改 `SceneType.planning` case 触发导航
    - 在 `lib/features/chat/chat_page.dart` 中将 `case SceneType.planning: break;` 替换为 `case SceneType.planning: context.push('/spec');`
    - 删除注释"暂时跳转到通用对话，后续实现规划流程"
    - _Bug_Condition: `isBugCondition_planning(event)` — `event.sceneType == SceneType.planning` 且执行 `break` 无导航_
    - _Expected_Behavior: `_handleSceneCardConfirm` 执行 `context.push('/spec')`，触发页面跳转_
    - _Preservation: `SceneType.subject`、`tool`、`spec`、`calendar` 的跳转逻辑完全不变_
    - _Requirements: 2.3, 3.2_

  - [x] 3.4 修复 Bug 4：删除占位符 `SkillMarketplaceService` 文件
    - 确认无任何文件 import `../services/skill_marketplace_service.dart`（`marketplace_page.dart` 和 `skill_detail_page.dart` 均已 import `core/skill/` 版本）
    - 直接删除 `lib/services/skill_marketplace_service.dart`
    - _Bug_Condition: `isBugCondition_placeholder(import)` — import 路径为 `lib/services/skill_marketplace_service.dart` 且该文件全部方法返回假数据_
    - _Expected_Behavior: 占位符文件不存在，消除歧义引用风险_
    - _Preservation: `lib/core/skill/skill_marketplace_service.dart` 的现有调用方继续正常使用真实 API_
    - _Requirements: 2.4, 3.3_

  - [-] 3.5 验证 Bug Condition 探索性测试现在通过
    - **Property 1: Expected Behavior** - 四处缺失实现已修复
    - **IMPORTANT**: 重新运行任务 1 中的相同测试 — 不要编写新测试
    - 任务 1 的测试编码了期望行为，测试通过即确认期望行为已满足
    - 运行任务 1 中的 Bug Condition 探索性测试
    - **EXPECTED OUTCOME**: 测试 PASS（确认 Bug 已修复）
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

  - [ ] 3.6 验证 Preservation 测试仍然通过
    - **Property 2: Preservation** - 非 Bug 输入行为不变
    - **IMPORTANT**: 重新运行任务 2 中的相同测试 — 不要编写新测试
    - 运行任务 2 中的 Preservation 属性测试
    - **EXPECTED OUTCOME**: 测试 PASS（确认无回归）
    - 确认修复后所有保留行为测试仍然通过

- [ ] 4. Checkpoint — 确保所有测试通过
  - 运行完整测试套件，确保所有测试通过
  - 运行 `dart analyze` 确认删除占位符文件后无编译错误
  - 如有疑问，询问用户
