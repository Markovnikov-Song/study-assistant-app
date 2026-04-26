# Missing Implementations Fix — Bugfix Design

## Overview

本项目存在 4 处"引用存在但实现缺失"的系统性缺陷，导致运行时 404、功能静默失效或歧义引用。
修复策略以最小改动为原则：

1. **OCR 路径不匹配**：修改 Flutter 端 `OcrApiClient` 调用路径，从 `/api/ocr/recognize` 改为 `/api/ocr/image`，不在后端加别名路由。
2. **`/api/skills/parse` 缺失**：在后端 `agent.py` 中新增该端点，接收文本并用 LLM 解析为 Skill 草稿结构。
3. **`SceneType.planning` 无跳转**：将 `break` 替换为 `context.push('/spec')`，跳转到规划页面。
4. **占位符 `SkillMarketplaceService` 共存**：直接删除 `lib/services/skill_marketplace_service.dart`，保留 `lib/core/skill/` 下的真实实现。

---

## Glossary

- **Bug_Condition (C)**：触发缺陷的输入条件集合
- **Property (P)**：对满足 C(X) 的输入，修复后函数应产生的正确行为
- **Preservation**：不满足 C(X) 的输入，修复前后行为必须完全一致
- **OcrApiClient**：`lib/tools/ocr/ocr_api_client.dart` 中负责调用后端 OCR 接口的客户端类
- **AiSkillParser**：`lib/core/skill/skill_parser_impl.dart` 中调用 `/api/skills/parse` 的 AI 解析器
- **SceneType.planning**：`chat_page.dart` switch 中代表"学习规划"场景的枚举值
- **SkillMarketplaceService（占位符）**：`lib/services/skill_marketplace_service.dart`，全部方法返回假数据
- **SkillMarketplaceService（真实）**：`lib/core/skill/skill_marketplace_service.dart`，调用真实 `/api/marketplace/` 端点

---

## Bug Details

### Bug 1：OCR 端点路径不匹配

**Bug Condition：**

```
FUNCTION isBugCondition_ocr(call)
  INPUT: call — Flutter 端发出的 HTTP 请求
  OUTPUT: boolean

  RETURN call.method == "POST"
         AND call.path == "/api/ocr/recognize"
         AND backend.routes NOT CONTAINS "/api/ocr/recognize"
END FUNCTION
```

**Examples：**
- 用户拍照上传题目 → `OcrApiClient.recognize()` 发出 `POST /api/ocr/recognize` → 后端返回 404，OCR 功能完全不可用
- 后端实际路由为 `POST /api/ocr/image`（`backend/routers/ocr.py` 第 `@router.post("/image")` 行）

---

### Bug 2：`/api/skills/parse` 端点缺失

**Bug Condition：**

```
FUNCTION isBugCondition_parse(call)
  INPUT: call — Flutter 端发出的 HTTP 请求
  OUTPUT: boolean

  RETURN call.method == "POST"
         AND call.path == "/api/skills/parse"
         AND backend.routes NOT CONTAINS "/api/agent/parse"
         AND backend.routes NOT CONTAINS "/api/skills/parse"
END FUNCTION
```

**Examples：**
- 用户粘贴学习经验文本，触发 `AiSkillParser.parse()` → `POST /api/skills/parse` → 404，文本解析创建 Skill 功能不可用
- `backend/routers/agent.py` 中存在 `/parser/config` 但无 `/parse` 端点

---

### Bug 3：`SceneType.planning` 确认后无跳转

**Bug Condition：**

```
FUNCTION isBugCondition_planning(event)
  INPUT: event — 用户点击 SceneCard 确认按钮的事件
  OUTPUT: boolean

  RETURN event.sceneType == SceneType.planning
         AND _handleSceneCardConfirm executes "break"
         AND NO navigation occurs
END FUNCTION
```

**Examples：**
- AI 返回 planning 类型场景卡片，用户点击"确认" → `case SceneType.planning: break` → 界面无任何响应，用户困惑
- 对比：`SceneType.spec` 正确执行 `context.push('/spec')`

---

### Bug 4：占位符 `SkillMarketplaceService` 共存

**Bug Condition：**

```
FUNCTION isBugCondition_placeholder(import)
  INPUT: import — Dart import 语句
  OUTPUT: boolean

  RETURN import.path == "lib/services/skill_marketplace_service.dart"
         AND SkillMarketplaceService.methods ALL RETURN placeholder_data
         AND real_implementation EXISTS AT "lib/core/skill/skill_marketplace_service.dart"
END FUNCTION
```

**Examples：**
- 若某文件误 import `../services/skill_marketplace_service.dart` → 所有市场操作返回假数据，无真实 API 调用
- 当前 `marketplace_page.dart` 和 `skill_detail_page.dart` 已正确 import `core/skill/` 版本，但占位符文件的存在是持续的歧义风险

---

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors：**
- `POST /api/ocr/image` 端点继续正常工作（不破坏任何已有调用）
- `SceneType.subject`、`SceneType.tool`、`SceneType.spec`、`SceneType.calendar` 的跳转逻辑完全不变
- `lib/core/skill/skill_marketplace_service.dart` 的现有调用方（`marketplace_page.dart`、`skill_detail_page.dart`）继续正常使用真实 API
- `backend/routers/agent.py` 中已有端点（`/resolve-intent`、`/execute-node`、`/skills`、`/parser/config` 等）继续正常工作
- 所有已挂载的 router（auth、subjects、sessions、chat 等）继续正常响应

**Scope：**
不满足上述 4 个 Bug Condition 的所有输入，修复前后行为必须完全一致，包括：
- 其他 HTTP 端点调用
- 其他 SceneType 的场景卡片确认
- 所有非 `lib/services/skill_marketplace_service.dart` 的 import

---

## Hypothesized Root Cause

### Bug 1：OCR 路径不匹配
1. **命名不一致**：后端路由命名为 `/image`（描述输入类型），Flutter 端命名为 `/recognize`（描述操作），两者在不同时期独立开发，未对齐
2. **无集中路径常量**：`api_constants.dart` 中 `ocrImage = '/api/ocr/image'` 已定义正确路径，但 `OcrApiClient` 硬编码了 `/api/ocr/recognize` 而未使用该常量

### Bug 2：`/api/skills/parse` 端点缺失
1. **前后端开发顺序问题**：Flutter 端 `AiSkillParser` 先于后端实现编写，端点路径 `/api/skills/parse` 是预期设计但后端从未实现
2. **后端路由挂载在 `/api/agent`**：即使后端有类似功能，路径也是 `/api/agent/...`，与 Flutter 期望的 `/api/skills/parse` 不匹配

### Bug 3：`SceneType.planning` 无跳转
1. **TODO 遗留**：注释"暂时跳转到通用对话，后续实现规划流程"表明这是已知的未完成实现，`break` 是临时占位
2. **`/spec` 路由已存在**：`SceneType.spec` 已正确跳转到 `/spec`，planning 场景同样应跳转到该规划页面

### Bug 4：占位符文件共存
1. **分阶段开发遗留**：Phase 3 先创建了骨架占位符 `lib/services/skill_marketplace_service.dart`，后续 Phase N 在 `lib/core/skill/` 实现了真实版本，但占位符未被清理
2. **同名类**：两个文件都定义了 `class SkillMarketplaceService`，Dart 不会报错（不同路径），但极易被错误引用

---

## Correctness Properties

Property 1: Bug Condition — OCR 调用路径修正

_For any_ `OcrApiClient.recognize()` 调用，修复后的函数 SHALL 向 `POST /api/ocr/image` 发送请求，后端 SHALL 返回 `{"text": "..."}` 而非 404。

**Validates: Requirements 2.1**

Property 2: Bug Condition — `/api/skills/parse` 端点响应

_For any_ `AiSkillParser.parse(text)` 调用（`text.length >= 50`），修复后后端 SHALL 返回包含 `{name, description, tags, steps}` 的 Skill 草稿结构，HTTP 状态码 200。

**Validates: Requirements 2.2**

Property 3: Bug Condition — `SceneType.planning` 触发导航

_For any_ 用户确认 `SceneType.planning` 场景卡片的事件，修复后 `_handleSceneCardConfirm` SHALL 执行 `context.push('/spec')`，触发页面跳转。

**Validates: Requirements 2.3**

Property 4: Bug Condition — 占位符文件不存在

_For any_ 代码库状态，修复后 `lib/services/skill_marketplace_service.dart` SHALL NOT 存在，消除歧义引用风险。

**Validates: Requirements 2.4**

Property 5: Preservation — 非 Bug 输入行为不变

_For any_ 输入不满足上述 4 个 Bug Condition（其他 OCR 调用、其他 SceneType、其他 import），修复后代码 SHALL 产生与修复前完全相同的行为。

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**

---

## Fix Implementation

### Bug 1：修改 `OcrApiClient` 调用路径

**File**: `lib/tools/ocr/ocr_api_client.dart`

**Specific Changes**:
1. 将 `_dio.post('/api/ocr/recognize', ...)` 改为 `_dio.post('/api/ocr/image', ...)`
2. 将请求体从 `FormData`（multipart）改为 JSON `{"image": base64String}`，以匹配后端 `OcrIn(image: str)` 模型
3. 将响应解析从 `{"lines": [...]}` 改为 `{"text": "..."}` 以匹配后端 `OcrOut(text: str)`

**Note**: `api_constants.dart` 中已有 `ocrImage = '/api/ocr/image'`，可直接引用。

---

### Bug 2：在 `agent.py` 新增 `/parse` 端点

**File**: `backend/routers/agent.py`

**Specific Changes**:
1. 新增 `SkillParseIn(BaseModel)` 包含 `text: str` 字段
2. 新增 `SkillParseOut(BaseModel)` 包含 `name`, `description`, `tags`, `steps` 字段
3. 新增 `@router.post("/parse", response_model=SkillParseOut)` 端点，挂载后路径为 `/api/agent/parse`
4. **同时**修改 Flutter 端 `skill_parser_impl.dart`，将调用路径从 `/api/skills/parse` 改为 `/api/agent/parse`
5. 端点内部使用 `LLMService` 解析文本，提取步骤、名称、描述、标签

---

### Bug 3：修改 `SceneType.planning` case

**File**: `lib/features/chat/chat_page.dart`

**Specific Changes**:
1. 将 `case SceneType.planning: break;` 替换为 `case SceneType.planning: context.push('/spec');`
2. 删除注释"暂时跳转到通用对话，后续实现规划流程"

---

### Bug 4：删除占位符文件

**File**: `lib/services/skill_marketplace_service.dart`

**Specific Changes**:
1. 直接删除该文件
2. 确认无任何文件 import `../services/skill_marketplace_service.dart`（已验证：`marketplace_page.dart` 和 `skill_detail_page.dart` 均 import `core/skill/` 版本）

---

## Testing Strategy

### Validation Approach

测试分两阶段：先在未修复代码上运行探索性测试，确认 Bug Condition 并验证根因分析；再在修复后运行 Fix Checking 和 Preservation Checking。

---

### Exploratory Bug Condition Checking

**Goal**: 在未修复代码上产生反例，确认根因分析。

**Test Plan**: 对每个 Bug 编写最小化测试，在未修复代码上运行，观察失败模式。

**Test Cases**:
1. **OCR 路径测试**：Mock Dio，调用 `OcrApiClient.recognize()`，断言请求路径为 `/api/ocr/image`（未修复时将断言 `/api/ocr/recognize`，失败）
2. **Skills Parse 端点测试**：向后端发送 `POST /api/agent/parse`，断言返回 200（未修复时 404，失败）
3. **Planning 导航测试**：Mock `BuildContext`，触发 `SceneType.planning` 确认，断言 `context.push` 被调用（未修复时 `break`，失败）
4. **占位符文件存在性测试**：断言 `lib/services/skill_marketplace_service.dart` 不存在（未修复时文件存在，失败）

**Expected Counterexamples**:
- OCR 请求路径为 `/api/ocr/recognize` 而非 `/api/ocr/image`
- `/api/agent/parse` 返回 404
- `context.push` 未被调用
- 占位符文件存在

---

### Fix Checking

**Goal**: 验证对所有满足 Bug Condition 的输入，修复后函数产生正确行为。

**Pseudocode:**
```
FOR ALL call WHERE isBugCondition_ocr(call) DO
  result := OcrApiClient_fixed.recognize(imageBytes, filename)
  ASSERT result.requestPath == "/api/ocr/image"
  ASSERT result.statusCode == 200
END FOR

FOR ALL text WHERE isBugCondition_parse(text) AND len(text) >= 50 DO
  result := POST /api/agent/parse {"text": text}
  ASSERT result.statusCode == 200
  ASSERT result.body CONTAINS "steps"
  ASSERT len(result.body["steps"]) >= 1
END FOR

FOR ALL event WHERE isBugCondition_planning(event) DO
  _handleSceneCardConfirm_fixed(event)
  ASSERT context.push WAS CALLED WITH "/spec"
END FOR

ASSERT NOT EXISTS "lib/services/skill_marketplace_service.dart"
```

---

### Preservation Checking

**Goal**: 验证对所有不满足 Bug Condition 的输入，修复前后行为完全一致。

**Pseudocode:**
```
FOR ALL call WHERE NOT isBugCondition_ocr(call) DO
  ASSERT OcrApiClient_original(call) == OcrApiClient_fixed(call)
END FOR

FOR ALL event WHERE event.sceneType != SceneType.planning DO
  ASSERT _handleSceneCardConfirm_original(event) == _handleSceneCardConfirm_fixed(event)
END FOR

FOR ALL import WHERE import.path != "lib/services/skill_marketplace_service.dart" DO
  ASSERT behavior_original(import) == behavior_fixed(import)
END FOR
```

**Testing Approach**: 属性测试适合 Preservation Checking，因为它能自动生成大量输入覆盖边界情况，提供强保证。

**Test Cases**:
1. **OCR 保留测试**：验证 `POST /api/ocr/image` 在修复后继续正常工作
2. **其他 SceneType 保留测试**：验证 `subject`、`tool`、`spec`、`calendar` 的跳转逻辑不变
3. **真实 SkillMarketplaceService 保留测试**：验证 `marketplace_page.dart` 调用 `core/skill/` 版本后行为不变
4. **Agent 端点保留测试**：验证 `/api/agent/resolve-intent`、`/api/agent/execute-node` 等端点继续正常工作

---

### Unit Tests

- 测试 `OcrApiClient.recognize()` 发出的请求路径和请求体格式
- 测试 `POST /api/agent/parse` 对合法文本（≥50字）返回正确结构
- 测试 `POST /api/agent/parse` 对空文本返回 400
- 测试 `_handleSceneCardConfirm` 对 `SceneType.planning` 触发 `context.push('/spec')`
- 测试删除占位符文件后无编译错误（`dart analyze`）

### Property-Based Tests

- 生成随机合法图片字节，验证 `OcrApiClient` 始终调用 `/api/ocr/image`
- 生成随机长度 ≥50 的文本，验证 `/api/agent/parse` 始终返回含 `steps` 的结构
- 生成随机非 `planning` 的 `SceneType`，验证跳转逻辑与修复前完全一致

### Integration Tests

- 完整 OCR 流程：拍照 → `OcrApiClient` → 后端 → 返回识别文本
- 完整 Skill 解析流程：粘贴文本 → `AiSkillParser.parse()` → `/api/agent/parse` → 返回草稿
- 完整规划跳转流程：AI 返回 planning 场景卡片 → 用户确认 → 跳转到 `/spec`
- Skill 市场页面加载：`marketplace_page.dart` 调用 `core/skill/SkillMarketplaceService` → 真实 API 响应
