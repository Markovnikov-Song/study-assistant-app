# 实现计划：受控动作空间（Controlled Action Space）框架

## 概述

按「后端先行 → 前端基础设施 → UI 集成 → 注册接入」的顺序实现 CAS 框架。
后端复用 `SkillRegistry` 的单例 + 懒加载模式；前端在现有 `IntentDetector` 接口上叠加，不修改任何现有公开接口。

---

## 任务

- [x] 1. 创建后端 CAS 模块骨架与 Pydantic 模型
  - 新建 `backend/cas/` 目录，创建 `__init__.py`
  - 在 `backend/cas/models.py` 中定义：`ParamType`（枚举，6 种）、`ParamDef`、`ActionDef`、`ActionResult`、`RenderType`、`IntentMapResult`、`DispatchIn`、`ActionsListOut`
  - `ActionResult` 必须包含 `success`、`action_id`、`data`、`error_code`、`error_message`、`fallback_used` 六个字段
  - `ActionResult.data` 中 `render_type` 取值限定为 `{text, card, navigate, modal}`
  - _需求：1.1、2.1、5.1、5.4_

- [x] 2. 实现 ActionRegistry 单例
  - 新建 `backend/cas/action_registry.py`，复用 `SkillRegistry` 的单例 + 懒加载模式
  - 实现 `get_action(action_id)`、`list_actions()`、`summaries()`、`reload()` 四个方法
  - 加载时校验每个 Action 的五个必要字段（`action_id`、`name`、`description`、`param_schema`、`executor_ref`）
  - 校验 `param_schema` 中所有参数类型均属于 6 种合法 `ParamType`，校验失败的 Action 跳过并记录 `WARNING` 日志
  - 加载失败时以空注册表启动，不阻断服务
  - 模块级单例访问函数 `get_action_registry()`
  - _需求：1.1、1.2、1.3、1.4、1.5、1.6、2.7、5.6、10.1、10.4_

  - [ ]* 2.1 为 ActionRegistry 编写属性测试（Property 1）
    - **属性 1：ActionRegistry 查询封闭性**
    - 对任意字符串 `action_id`，`get_action()` 要么返回 `ActionDef`，要么返回 `None`，永不抛出异常
    - **验证：需求 1.4**

  - [ ]* 2.2 为 ActionRegistry 编写属性测试（Property 2）
    - **属性 2：Action 注册完整性**
    - 合法 YAML 条目写入并 `reload()` 后，`get_action()` 应返回该 Action，`list_actions()` 长度增加 1
    - **验证：需求 1.3、10.1**

  - [ ]* 2.3 为 ActionRegistry 编写属性测试（Property 3）
    - **属性 3：非法参数类型被拒绝**
    - 含非法 `param_type` 的 Action 加载后不出现在 `list_actions()` 中，且不影响其他合法 Action
    - **验证：需求 1.6、2.7**

  - [ ]* 2.4 为 ActionRegistry 编写属性测试（Property 4）
    - **属性 4：摘要列表与注册表一致**
    - N 个合法 Action 的注册表，`list_actions()` 长度等于 N，每个元素包含 `action_id`、`name`、`description`
    - **验证：需求 1.5**

- [x] 3. 实现 ExecutorRegistry 与注册装饰器
  - 新建 `backend/cas/executor_registry.py`
  - 实现模块级字典 `_executor_registry: dict[str, Callable]`
  - 实现 `@register_executor("action_id")` 装饰器，将函数注册到字典
  - 实现 `get_executor(action_id)` 返回 `Optional[Callable]`
  - 实现 `ExecutorRegistry.run(action_id, params, user_id)` 顶层方法，捕获 Executor 内部所有异常，返回 `ActionResult(success=False, fallback_used=True)`
  - _需求：5.2、5.3、5.4、5.5、10.2_

  - [ ]* 3.1 为 ExecutorRegistry 编写属性测试（Property 7）
    - **属性 7：Executor 异常隔离**
    - 对任意 Executor 抛出任意类型异常，`ExecutorRegistry.run()` 返回 `success=False, fallback_used=True`，`data` 含 `render_type`，不传播异常
    - **验证：需求 5.2、5.3、5.4**

  - [ ]* 3.2 为 ActionResult 编写属性测试（Property 8）
    - **属性 8：ActionResult 字段完整性**
    - 任意 Executor 执行结果必须包含 `success`、`action_id`、`data`、`fallback_used` 四个字段，`data` 中 `render_type` 属于合法枚举值
    - **验证：需求 5.1、5.4**

- [x] 4. 创建内置 Action YAML 定义文件
  - 新建 `backend/prompts/actions/builtin.yaml`
  - 定义 9 个内置 Action：`make_quiz`、`make_plan`、`open_calendar`、`add_calendar_event`、`recommend_mistake_practice`、`open_notebook`、`explain_concept`、`solve_problem`、`unknown_intent`
  - `make_quiz` 参数：`subject`（radio，dynamic_source=user_subjects）、`question_type`（checkbox，选项「选择题/填空题/解答题」）、`count`（number，1–20，默认 5）
  - `make_plan` 参数：`subject`（radio）、`exam_date`（date）、`daily_hours`（number，0.5–8，步长 0.5）
  - `add_calendar_event` 参数：`title`（text，max_length=50）、`date`（date）
  - `recommend_mistake_practice` 参数：`subject`（radio）、`topic`（topic_tree）
  - `unknown_intent` 参数列表为空，`fallback_text` 为引导澄清文本
  - 每个 Action 包含 `version: "1.0.0"` 和 `fallback_text` 字段
  - _需求：7.1、7.2、7.3、7.4、7.5、7.6_

- [x] 5. 实现 9 个内置 Executor
  - 新建 `backend/cas/executors/` 目录，创建 `__init__.py`
  - [x] 5.1 实现 `unknown_intent.py`：返回引导澄清的文本消息，`render_type=text`
    - _需求：7.2_
  - [x] 5.2 实现 `open_calendar.py`：返回 `render_type=navigate`，`route` 为 `/toolkit/calendar`
    - _需求：6.4、7.1_
  - [x] 5.3 实现 `open_notebook.py`：返回 `render_type=navigate`，`route` 为 `/toolkit/notebooks`
    - _需求：6.4、7.1_
  - [x] 5.4 实现 `add_calendar_event.py`：调用日历后端接口创建事件，返回 `render_type=text` 确认消息；失败时返回 `fallback_used=True`
    - _需求：5.2、5.3、7.5_
  - [x] 5.5 实现 `make_quiz.py`：调用现有出题逻辑（参考 `quiz` router），返回 `render_type=card`；失败时返回 `fallback_used=True`
    - _需求：5.2、5.3、7.3_
  - [x] 5.6 实现 `make_plan.py`：调用 LLM 生成学习计划文本，返回 `render_type=text`；失败时返回 `fallback_used=True`
    - _需求：5.2、5.3、7.4_
  - [x] 5.7 实现 `recommend_mistake_practice.py`：查询错题库并推荐，返回 `render_type=card`；失败时返回 `fallback_used=True`
    - _需求：5.2、5.3、7.6_
  - [x] 5.8 实现 `explain_concept.py`：调用 LLM 解释概念，返回 `render_type=text`；失败时返回 `fallback_used=True`
    - _需求：5.2、5.3_
  - [x] 5.9 实现 `solve_problem.py`：调用 LLM 解题，返回 `render_type=text`；失败时返回 `fallback_used=True`
    - _需求：5.2、5.3_
  - 所有 Executor 均使用 `@register_executor("action_id")` 装饰器注册
  - 所有 Executor 均用 `try/except Exception` 包裹全部逻辑，捕获后返回 `ActionResult(success=False, fallback_used=True, data={"render_type": "text", "text": action.fallback_text})`
  - _需求：5.1、5.2、5.3、5.4、5.5、9.4_

- [x] 6. 实现 IntentMapper（LLM + RuleMapper 双路）
  - 新建 `backend/cas/intent_mapper.py`
  - 实现 `RuleMapper.map(text)` 基于关键词匹配，返回 `IntentMapResult`，`confidence` 固定 0.5，`degraded=True`
  - 实现 `IntentMapper.map(text, session_id, timeout_seconds=3.0)`：
    - 构建包含 `ActionRegistry.summaries()` 的 LLM 提示词
    - 调用 LLM，解析 JSON 返回 `{ action_id, params, confidence }`
    - 验证 `action_id` 存在于 `ActionRegistry`，否则返回 `unknown_intent`
    - 超时（>3s）或 LLM 不可用时自动降级为 `RuleMapper`
    - LLM 返回非法 JSON 时捕获 `JSONDecodeError`，降级为 `RuleMapper`
    - 任何路径均不向调用方传播异常
  - _需求：3.1、3.2、3.3、3.4、3.5、6.3_

  - [ ]* 6.1 为 IntentMapper 编写属性测试（Property 5）
    - **属性 5：意图映射结果合法性**
    - 对任意非空输入字符串，`IntentMapper.map()` 返回的 `action_id` 必须存在于 `ActionRegistry`，`confidence` 在 `[0.0, 1.0]`，不抛出异常
    - **验证：需求 3.1、3.5**

  - [ ]* 6.2 为 IntentMapper 编写属性测试（Property 6）
    - **属性 6：LLM 非法返回的降级不变性**
    - 对任意随机字符串（含非 JSON、含不存在 `action_id` 的 JSON）作为 LLM 模拟返回，`IntentMapper` 应返回合法 `IntentMapResult`，不传播异常
    - **验证：需求 3.3、3.4**

- [x] 7. 实现 DispatchPipeline 编排器
  - 新建 `backend/cas/dispatch_pipeline.py`
  - 实现 `DispatchPipeline.run(text, session_id, user_id)` 完整处理链路：
    - 调用 `IntentMapper.map()` 获取 `IntentMapResult`
    - 调用 `_validate_params(action, params)` 校验参数完整性，返回 `(is_complete, missing_params)`
    - 参数完整时调用 `ExecutorRegistry.run()`
    - 参数不完整时返回 `render_type=param_fill` 的特殊 `ActionResult`（含 `missing_params`、`collected_params`）
    - 顶层 `try/except` 捕获所有未处理异常，返回 `action_id=system_error` 的 Fallback_Response
  - 实现 `_validate_params`：额外参数不影响完整性判断（属性 11）
  - 记录结构化执行日志（`action_id`、`success`、`duration_ms`、`fallback_used`、`degraded`、`error_code`、`session_id`、`user_id`），循环缓冲区保留最近 1000 条
  - _需求：6.1、6.2、6.3、6.8、9.6_

  - [ ]* 7.1 为 DispatchPipeline 编写属性测试（Property 9）
    - **属性 9：Dispatch 端点 HTTP 200 不变性**
    - 对任意非空输入，`POST /api/cas/dispatch` 始终返回 HTTP 200，错误通过 `success=False` 传递
    - **验证：需求 6.8**

  - [ ]* 7.2 为参数校验编写属性测试（Property 11）
    - **属性 11：参数完整性校验单调性**
    - 若 `_validate_params` 返回 `(True, [])`，在 `params` 中追加任意额外键值对后结果仍为 `(True, [])`
    - **验证：需求 4.1、4.9**

- [x] 8. 实现 CAS Router
  - 新建 `backend/routers/cas.py`
  - 实现 `GET /api/cas/actions`：返回 `ActionsListOut`（所有 Action 摘要列表）
  - 实现 `POST /api/cas/dispatch`：接收 `DispatchIn { text, session_id? }`，`text` 为空时返回 HTTP 400，否则调用 `DispatchPipeline.run()` 并始终返回 HTTP 200
  - 实现 `GET /api/cas/logs`（仅管理员）：返回最近 1000 条执行日志
  - _需求：1.7、3.6、3.7、6.8、9.6_

- [ ] 9. 检查点 — 后端单元测试
  - 确保所有属性测试和单元测试通过，向用户确认后继续。

- [x] 10. 注册 CAS Router 到 `backend/main.py`
  - 在 `main.py` 中 `import` `backend/routers/cas.py` 的 `router`
  - 添加 `app.include_router(cas.router, prefix="/api/cas", tags=["cas"])`
  - 在 `_startup()` 中预热 `ActionRegistry`（调用 `get_action_registry()`）
  - _需求：1.2、1.7_

- [x] 11. 创建前端 ActionResult Dart 模型
  - 新建 `lib/features/cas/models/action_result.dart`
  - 定义 `RenderType` 枚举（`text`、`card`、`navigate`、`modal`、`paramFill`）
  - 定义 `ActionResult` 类，包含 `success`、`actionId`、`data`、`errorCode`、`errorMessage`、`fallbackUsed` 字段
  - 实现 `renderType` getter（`data['render_type']` 解析，`orElse` 返回 `RenderType.text`）
  - 实现 `ActionResult.fromJson()`：所有字段用默认值填充缺失项，不抛出解析异常
  - 实现 `ActionResult.localFallback({String? message})`：网络失败时的本地兜底构造
  - 定义 `ParamRequest` 类（`name`、`type`、`label`、`required`、`options`、`min`、`max`、`step`、`maxLength`、`dynamicSource` 等字段）
  - _需求：5.1、8.1、9.1、9.2、9.3_

  - [ ]* 11.1 为 ActionResult.fromJson 编写属性测试（Property 10）
    - **属性 10：前端 ActionResult 解析健壮性**
    - 对任意缺少部分字段的 JSON，`fromJson()` 成功解析并用默认值填充，`renderType` 始终返回合法枚举值，不抛出异常
    - **验证：需求 9.3**
    - 注：Dart 属性测试可使用 `package:test` + 手动随机化，或跳过改为覆盖边界值的单元测试

- [x] 12. 实现 CasService（HTTP 客户端）
  - 新建 `lib/features/cas/cas_service.dart`
  - 实现 `CasService.dispatch(String text, {String? sessionId})`：
    - `POST /api/cas/dispatch`，超时 10 秒
    - 网络失败 / HTTP 5xx 时 `catch` 并返回 `ActionResult.localFallback()`
    - 超时时返回 `ActionResult.localFallback(message: '请求超时，请稍后再试')`
  - 实现 `CasService.listActions()`：`GET /api/cas/actions`
  - _需求：8.1、9.1、9.2、9.5_

- [x] 13. 实现 CasDispatchProvider（Riverpod StateNotifier）
  - 新建 `lib/features/cas/cas_dispatch_provider.dart`
  - 定义 `CasDispatchState { isLoading, lastResult, pendingParams }`
  - 实现 `CasDispatchNotifier extends StateNotifier<CasDispatchState>`：
    - `dispatch(String text, {Map<String, dynamic> collectedParams = const {}})` 方法
    - 收到 `render_type=param_fill` 时解析 `missing_params` 并设置 `pendingParams`
    - `fillParam(String name, dynamic value)` 方法：追加到 `collectedParams`，所有必填参数完成后自动重新调用 `dispatch`
    - `cancelFill()` 方法：清空 `pendingParams`，`lastResult` 设为取消消息
  - 暴露 `final casDispatchProvider = StateNotifierProvider<CasDispatchNotifier, CasDispatchState>(...)`
  - _需求：4.1、4.2、4.9、4.10、8.1、8.2_

- [x] 14. 实现 CasIntentDetector
  - 新建 `lib/features/cas/cas_intent_detector.dart`
  - 实现 `CasIntentDetector implements IntentDetector`
  - `detect(userInput, {subjects})` 方法：
    - 优先调用 `CasService.dispatch(userInput)`，超时 10 秒
    - 成功时调用 `_toDetectedIntent(ActionResult)` 转换为 `DetectedIntent`
    - 失败 / 超时时降级为 `RuleBasedIntentDetector().detect(userInput, subjects: subjects)`
  - 实现 `_toDetectedIntent(ActionResult)`：将 `ActionResult` 映射到 `DetectedIntent`（`type` 根据 `actionId` 推断，`params` 透传 `data`）
  - _需求：8.4、8.5_

- [x] 15. 实现 ParamFillCard Widget
  - 新建 `lib/features/cas/widgets/param_fill_card.dart`
  - 实现 `ParamFillCard extends ConsumerWidget`，接收 `ParamRequest param`、`ValueChanged<dynamic> onFilled`、`VoidCallback onCancel`
  - 复用 `SceneCard` 的视觉样式（圆角卡片、左侧彩色竖条、主题色按钮）
  - 根据 `ParamRequest.type` 渲染对应控件：
    - `radio` → 单选按钮组（只能选 `options` 中的值）
    - `checkbox` → 多选复选框组（只能选 `options` 中的值）
    - `number` → 带加减按钮的数字步进器（限制在 `min`–`max` 范围内）
    - `date` → 日历日期选择器（`showDatePicker`，范围由 `min_date`/`max_date` 限定）
    - `topic_tree` → 可折叠的知识点多选树（树数据来自用户学科知识点）
    - `text` → 单行/多行文本输入框（`maxLength` 限制）
  - 底部提供「取消」按钮，触发 `onCancel`
  - _需求：4.2、4.3、4.4、4.5、4.6、4.7、4.8、8.2、8.3_

- [ ] 16. 检查点 — 前端基础设施
  - 确保 `ActionResult`、`CasService`、`CasDispatchProvider`、`CasIntentDetector`、`ParamFillCard` 编译无错误，向用户确认后继续。

- [x] 17. 集成到 ChatPage
  - 修改 `lib/features/chat/chat_page.dart`（或其 Provider 层），将 `RuleBasedIntentDetector` 替换为 `CasIntentDetector`
  - 在消息列表渲染逻辑中新增对 `render_type=param_fill` 的处理：当 `casDispatchProvider.pendingParams` 非空时，在对话流末尾插入 `ParamFillCard`，并禁用输入框
  - 处理 `render_type=navigate`：调用 `context.push(data['route'])`，路径必须存在于 `R` 类中
  - 处理 `render_type=modal`：调用 `showModalBottomSheet`，内容为 `data['content']`
  - 处理 `render_type=card`：在对话流中插入结构化卡片消息（复用现有 `SceneCard` 或新建卡片 Widget）
  - 处理 `render_type=text`：在对话流中插入普通文本消息
  - 不修改 `ChatPage`、`SceneCard`、`chatProvider` 的任何现有公开接口
  - _需求：6.4、6.5、6.6、6.7、8.2、8.4、8.6_

- [x] 18. 最终检查点 — 端到端验证
  - 确保所有测试通过，端到端流程（用户输入 → CAS 分发 → 渲染）可正常运行，向用户确认后完成。

---

## 备注

- 标有 `*` 的子任务为可选项，可跳过以加快 MVP 交付
- 每个任务均引用具体需求条款，保证可追溯性
- 检查点任务（9、16、18）用于阶段性验证，确保增量集成不引入回归
- 属性测试使用 Hypothesis（Python 后端），每个属性最少运行 100 次
- 前端 Dart 属性测试（任务 11.1）可用覆盖边界值的单元测试替代
