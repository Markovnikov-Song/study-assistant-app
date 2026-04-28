# Bugfix Requirements Document

## Introduction

本文档系统性地整理了 Flutter + FastAPI 学习助手 App 中发现的多类 Bug，按 P0（致命）→ P1（严重）→ P2（一般）优先级组织。

**已有 Spec 覆盖的问题（本文档不重复）：**
- `missing-implementations-fix`：OCR 路径、parse 端点、planning 导航、占位符文件
- `calendar-tab-type-error`：日历 Tab 类型错误
- `notebook-type-error-and-ux-fix`：笔记本类型错误和 UX 修复

**本文档覆盖范围：** 34 个 Bug 中剩余的 30 个，合并同类项后形成 22 个修复组。

---

## Bug Analysis

---

## P0 致命级

### 当前行为（缺陷）

#### 安全类

1.1 WHEN 用户持有已过期的 JWT 令牌发起请求 THEN 系统抛出 jwt.ExpiredSignatureError 并返回 401，但 deps.py 中 get_current_user 未对令牌签名算法做白名单限制，攻击者可伪造 alg:none 令牌绕过验证

1.2 WHEN 用户 A 持有合法 JWT 访问 /api/subjects/{id}、/api/notebooks/{id} 等资源型接口，且该资源属于用户 B THEN 系统未校验资源归属，直接返回用户 B 的数据（横向越权）

1.3 WHEN 普通用户调用管理员级接口（如 /api/token/admin/*）THEN 系统仅依赖 JWT 中的 user_id 字段，无角色/权限字段，无法区分普通用户与管理员

1.4 WHEN 后端接口发生未捕获异常 THEN FastAPI 默认返回包含完整异常堆栈的 500 响应，可能泄露数据库路径、密钥名称等敏感信息

#### 崩溃类

1.5 WHEN CAS 对话流返回参数补全卡片（param_fill），且后端 missing_params 中某个 ParamDef 的 input_type 为 radio 但 options 字段为空列表或 null THEN Flutter 渲染参数补全卡片时访问 options[0] 导致 RangeError，APP 红屏崩溃

1.6 WHEN CAS 对话流返回思维导图卡片或错题卡片，且后端响应 JSON 缺少必填字段（如 route、node_id、question_text）THEN Flutter 解析 ActionResult 时执行非空断言，抛出 Null check operator used on a null value，APP 红屏崩溃

1.7 WHEN LLM 返回的 JSON 包含 markdown 代码块包裹（`json ... `）、多余说明文字或格式错误 THEN 后端直接调用 json.loads(raw) 抛出 json.JSONDecodeError，接口返回 500

1.8 WHEN 前端提交参数类型错误（如将字符串传入期望 int 的字段）或缺少必填字段 THEN 部分路由未使用 Pydantic 模型接收请求体，直接 request.json() 后用 dict["key"] 访问，触发 KeyError 或 TypeError，接口返回 500

#### CAS 框架

1.9 WHEN LLM 意图映射返回一个未在 ActionRegistry 中注册的 action_id（如 delete_user、admin_reset）THEN IntentMapper 本身未对 LLM 输出的 action_id 做白名单过滤，恶意 prompt 注入可能诱导 LLM 输出危险指令名

#### 服务可用性

1.10 WHEN 阿里云轻量服务器重启后 THEN uvicorn/Nginx/PostgreSQL 均无 systemd service 文件，服务不会自动启动，App 完全不可用直到人工介入

1.11 WHEN 高并发请求到达时 THEN 部分旧代码路径（如 services/ 下的同步服务）直接调用 create_engine 而非 get_engine()，导致额外连接池实例，连接数超限后接口全量超时

---

### 期望行为（正确）

2.1 WHEN 用户持有已过期的 JWT 令牌发起请求 THEN 系统 SHALL 返回 401 并拒绝请求；jwt.decode SHALL 强制指定 algorithms=["HS256"]，拒绝 alg:none 及其他算法

2.2 WHEN 用户 A 访问属于用户 B 的资源型接口 THEN 系统 SHALL 校验资源的 user_id 与当前登录用户一致，不一致时返回 403 或 404

2.3 WHEN 普通用户调用需要管理员权限的接口 THEN 系统 SHALL 在 deps.py 中提供 require_admin 依赖，检查 JWT payload 中的 role 字段，普通用户调用时返回 403

2.4 WHEN 后端发生任何未捕获异常 THEN 系统 SHALL 通过全局异常中间件拦截，返回统一格式 {"detail": "服务器内部错误"} 而不暴露堆栈、密钥或数据库路径

2.5 WHEN CAS 返回 param_fill 卡片且某参数 input_type 为 radio 但 options 为空 THEN 系统 SHALL 在后端 DispatchPipeline 中校验 radio 类型必须有至少一个 option，不满足时降级为 text 类型；Flutter 端渲染前 SHALL 对 options 做空值兜底

2.6 WHEN CAS 返回任意卡片类型，且后端响应缺少某必填字段 THEN Flutter 解析 ActionResult 时 SHALL 使用可空解析，缺失字段使用默认值，不使用非空断言

2.7 WHEN LLM 返回包含 markdown 代码块或额外文字的响应 THEN 后端 SHALL 使用统一的 extract_json(raw) 工具函数，先剥离包裹，再尝试 json.loads，失败时返回结构化错误响应而非 500

2.8 WHEN 前端提交参数类型错误或缺少必填字段 THEN 所有路由 SHALL 使用 Pydantic BaseModel 接收请求体，FastAPI 自动返回 422 Unprocessable Entity，不触发 KeyError/TypeError

2.9 WHEN IntentMapper 从 LLM 获取 action_id THEN 系统 SHALL 在 IntentMapper.map() 中对 LLM 返回的 action_id 做白名单校验（与 ActionRegistry 注册列表比对），不在白名单内的 action_id SHALL 被替换为 unknown_intent

2.10 WHEN 服务器重启后 THEN uvicorn、Nginx、PostgreSQL SHALL 通过 systemd service 文件自动启动，deploy.sh SHALL 包含 systemctl enable 命令

2.11 WHEN 高并发请求到达时 THEN 所有代码路径 SHALL 通过 database.get_engine() 获取同一个连接池实例，services/ 下不得直接调用 create_engine

---

### 不变行为（回归防护）

3.1 WHEN 用户持有合法未过期的 JWT 令牌 THEN 系统 SHALL CONTINUE TO 正常验证并返回用户信息，所有已有接口的认证流程不受影响

3.2 WHEN 用户 A 访问自己的资源（subject_id、notebook_id 等归属于自己）THEN 系统 SHALL CONTINUE TO 正常返回数据，无误报 403

3.3 WHEN CAS 返回格式正确的 param_fill 卡片（radio 类型含有效 options）THEN Flutter SHALL CONTINUE TO 正常渲染参数补全卡片

3.4 WHEN LLM 直接返回合法 JSON 字符串（无 markdown 包裹）THEN extract_json 工具函数 SHALL CONTINUE TO 正确解析，不破坏现有行为

3.5 WHEN 所有已有 Pydantic 模型的路由被调用 THEN 系统 SHALL CONTINUE TO 正常工作，422 校验逻辑不变

3.6 WHEN ActionRegistry 中已注册的合法 action_id 被 LLM 返回 THEN IntentMapper SHALL CONTINUE TO 正常路由到对应 Executor

---

## P1 严重级

### 当前行为（缺陷）

#### 核心业务逻辑

4.1 WHEN 用户快速重复点击发送按钮或网络超时后前端自动重试 THEN 后端未做幂等处理，同一条消息被多次写入 conversation_history，同一个计划被多次生成，同一道错题被多次添加

4.2 WHEN 后端调用 LLM API 且 LLM 响应超时（超过 30 秒）THEN 请求 hang 住占用数据库连接和线程，最终触发 504 Gateway Timeout，无中断机制

4.3 WHEN LLM API 返回 429（限流）、401（密钥失效）或 500（服务端错误）THEN 后端 LLMService.chat() 未捕获这些 HTTP 错误，直接向上抛出，接口返回 500

4.4 WHEN 对话历史条数超过模型上下文窗口 THEN 后端将全量历史注入 LLM，触发 context_length_exceeded 错误，接口 500

4.5 WHEN CAS Executor 内部发生任意异常（如数据库查询失败、外部 API 超时）THEN 部分 Executor 未包裹 try/except，异常向上传播，违背 CAS 永不报错设计目标

4.6 WHEN 班主任 Agent 异步生成计划或讲义任务失败 THEN 后台线程静默失败，无重试机制，任务状态永远停留在 pending，用户无法感知

#### 数据同步

4.7 WHEN 用户切换学科或修改学习目标后 THEN 各页面（日历、错题本、计划页）的 Provider 未监听全局学科变更事件，仍使用旧的 subject_id 执行查询

4.8 WHEN 多步数据库操作（如创建计划 + 批量插入 PlanItem）中某步失败 THEN 部分服务层代码在 with get_session() 外部手动操作 session，导致事务边界不一致，产生脏数据

4.9 WHEN 班主任生成学习计划时 THEN LLM 生成的每日任务量未与用户 daily_minutes 字段做约束校验，可能生成每日 300 分钟的计划；知识点优先级未参考 ReviewCard.mastery_score，弱项未优先排列

#### 前端交互

4.10 WHEN 用户快速连续点击发送按钮 THEN Flutter 未在发送期间禁用按钮或去抖，同一条消息被多次提交

4.11 WHEN 参数补全卡片中数字输入框的值超出 min/max 范围，或必填参数未填写 THEN 确认按钮未置灰，用户可提交非法参数，后端收到越界值

4.12 WHEN 用户从对话页唤起 MiniApp（如出题、费曼）并关闭 THEN 导航栈未正确 pop，用户被带到首页而非原对话页

4.13 WHEN 移动端聊天页弹出软键盘 THEN 输入框被软键盘遮挡，Scaffold 未设置 resizeToAvoidBottomInset:true 或 MediaQuery.viewInsetsOf 适配

#### 权限与安全

4.14 WHEN Web 端发起跨域请求，且请求方法为 OPTIONS（预检）THEN main.py 中 CORS 配置未包含 OPTIONS 方法，预检请求失败，偶发跨域报错

---

### 期望行为（正确）

5.1 WHEN 用户重复发送相同请求 THEN 系统 SHALL 通过请求去重机制（前端发送时禁用按钮 + 后端基于 X-Request-ID 头做幂等校验）防止重复写入

5.2 WHEN 后端调用 LLM API THEN 系统 SHALL 为所有 LLM 调用设置 timeout 参数（默认 60 秒），超时后返回结构化错误响应，不 hang 住连接

5.3 WHEN LLM API 返回 429/401/500 THEN LLMService.chat() SHALL 捕获这些错误，429 时做指数退避重试（最多 2 次），401/500 时返回用户友好的错误消息

5.4 WHEN 对话历史超过配置的 CHAT_HISTORY_WINDOW THEN 后端 SHALL 截断历史，只注入最近 N 条，CHAT_HISTORY_WINDOW 配置 SHALL 被所有 LLM 调用路径遵守

5.5 WHEN CAS Executor 内部发生任意异常 THEN 每个 Executor SHALL 包裹完整的 try/except，捕获后返回 ActionResult.fallback()，不向外传播异常

5.6 WHEN 班主任异步任务失败 THEN 系统 SHALL 更新任务状态为 failed，记录错误原因，并在下次用户访问时展示失败提示

5.7 WHEN 用户切换学科或修改目标 THEN 全局状态变更 SHALL 通过事件总线广播，相关 Provider SHALL 监听并重新拉取数据

5.8 WHEN 多步数据库操作执行 THEN 所有操作 SHALL 在同一个 with get_session() as db 上下文内完成，确保事务原子性

5.9 WHEN 班主任生成计划 THEN 系统 SHALL 校验每日任务总时长不超过 daily_minutes，并按 mastery_score 升序排列知识点优先级（弱项优先）

5.10 WHEN 用户点击发送按钮 THEN Flutter SHALL 在请求进行中禁用发送按钮，请求完成后恢复，防止重复提交

5.11 WHEN 参数补全卡片渲染时 THEN Flutter SHALL 实时校验数字输入是否在 min/max 范围内，必填参数未填时确认按钮 SHALL 置灰

5.12 WHEN 用户关闭 MiniApp THEN 导航栈 SHALL 正确 pop 回原对话页，不跳转到首页

5.13 WHEN 移动端软键盘弹出 THEN 聊天页 Scaffold SHALL 设置 resizeToAvoidBottomInset:true，输入框 SHALL 随键盘高度上移

5.14 WHEN Web 端发起 OPTIONS 预检请求 THEN CORS 中间件 SHALL 正确响应，allow_methods SHALL 包含 OPTIONS

---

### 不变行为（回归防护）

6.1 WHEN 用户正常单次发送消息 THEN 系统 SHALL CONTINUE TO 正常写入一条历史记录，不受幂等机制影响

6.2 WHEN LLM API 正常响应（200）THEN LLMService.chat() SHALL CONTINUE TO 正常返回文本，超时和重试逻辑不影响正常路径

6.3 WHEN 对话历史条数在 CHAT_HISTORY_WINDOW 以内 THEN 系统 SHALL CONTINUE TO 注入全量历史，截断逻辑不影响短对话

6.4 WHEN CAS Executor 正常执行 THEN ActionResult.ok() SHALL CONTINUE TO 正常返回，try/except 包裹不影响成功路径

6.5 WHEN 用户在 MiniApp 内正常操作 THEN 导航行为 SHALL CONTINUE TO 正常工作，关闭修复不影响 MiniApp 内部导航

6.6 WHEN 桌面端（Web 宽屏）使用聊天页 THEN resizeToAvoidBottomInset 修改 SHALL CONTINUE TO 不影响桌面端布局

---

## P2 一般级

### 当前行为（缺陷）

#### 布局与渲染

7.1 WHEN 移动端固定宽高的组件（如卡片、对话气泡）在 Web 端宽屏下渲染 THEN RenderFlex 溢出，控制台报 A RenderFlex overflowed by X pixels

7.2 WHEN 对话列表收到新消息 THEN 自动滚动到底部的逻辑失效；加载历史消息时滚动位置跳变

7.3 WHEN 用户完成打卡或修改计划后 THEN 日历组件和错题本组件的 Provider 未收到失效通知，需退出重进才能看到最新数据

#### 业务逻辑

7.4 WHEN LLM 解析错题的知识点和学科归属 THEN 解析结果与实际学科不符，导致错题归类错乱（LLM prompt 未提供用户已有学科列表作为约束）

7.5 WHEN 用户多次执行出题命令 THEN 后端未记录已出过的题目，重复生成相同题目，无去重逻辑

7.6 WHEN 用户做对题目后系统更新掌握度 THEN mastery_score 反而下降，计算逻辑中正确答题的分支与错误答题的分支写反

#### 性能与内存

7.7 WHEN MiniApp 页面关闭后 THEN Flutter 中的定时器（Timer）和未完成的网络请求未在 dispose() 中取消，导致内存泄漏和 setState called after dispose 错误

7.8 WHEN 历史消息列表或错题本数据量超过 100 条 THEN 列表未使用 ListView.builder 懒加载，一次性渲染全部条目，帧率暴跌

---

### 期望行为（正确）

8.1 WHEN 移动端固定宽高组件在 Web 端宽屏渲染 THEN 系统 SHALL 使用 LayoutBuilder 或 ConstrainedBox 限制最大宽度，防止 RenderFlex 溢出

8.2 WHEN 对话列表收到新消息 THEN 系统 SHALL 在消息写入后调用 WidgetsBinding.instance.addPostFrameCallback 确保滚动到底部；加载历史消息时 SHALL 保持当前滚动位置

8.3 WHEN 用户完成打卡或修改计划 THEN 相关操作 SHALL 通过事件总线发布 CalendarEventCompleted / PlanUpdated 事件，日历和错题本 Provider SHALL 监听并自动刷新

8.4 WHEN LLM 解析错题知识点和学科 THEN prompt SHALL 包含用户已有学科列表，要求 LLM 从列表中选择最匹配的学科，减少归类错误

8.5 WHEN 出题命令执行时 THEN 后端 SHALL 查询该用户该学科最近 N 道已出题目的 node_id，在 prompt 中排除这些节点，减少重复出题

8.6 WHEN 用户做对题目后 THEN mastery_score 计算逻辑 SHALL 正确：答对时分数增加（+1，上限 5），答错时分数减少（-1，下限 0）

8.7 WHEN MiniApp 页面销毁时 THEN dispose() SHALL 取消所有 Timer 和未完成的 CancelToken/StreamSubscription

8.8 WHEN 历史消息列表或错题本列表渲染 THEN SHALL 使用 ListView.builder 懒加载，仅渲染可见区域的条目

---

### 不变行为（回归防护）

9.1 WHEN 移动端渲染固定宽高组件 THEN 系统 SHALL CONTINUE TO 正常显示，LayoutBuilder 修改不影响移动端布局

9.2 WHEN 对话列表在正常情况下渲染 THEN 系统 SHALL CONTINUE TO 正确显示消息，滚动修复不影响正常渲染逻辑

9.3 WHEN 用户未做任何打卡或计划修改 THEN Provider SHALL CONTINUE TO 不触发不必要的刷新，事件监听不引入性能回归

9.4 WHEN 出题命令首次执行（无历史题目）THEN 系统 SHALL CONTINUE TO 正常出题，去重逻辑在无历史时不影响出题结果

9.5 WHEN 用户答错题目 THEN mastery_score SHALL CONTINUE TO 正确减少，修复不影响答错分支

9.6 WHEN MiniApp 正常运行期间 THEN 定时器和网络请求 SHALL CONTINUE TO 正常工作，dispose 修复不影响运行期行为

---

## Bug Condition 伪代码

### P0 安全类（Bug 1.1-1.4）

FUNCTION isBugCondition_Security(request)
  INPUT: request of type HTTPRequest
  OUTPUT: boolean

  RETURN (request.jwt.alg != HS256)
      OR (request.resource.owner_id != request.jwt.user_id)
      OR (request.requires_admin AND request.jwt.role IS NULL)
      OR (response.body CONTAINS stack_trace OR secret_key)
END FUNCTION

Property: Fix Checking
FOR ALL request WHERE isBugCondition_Security(request) DO
  response <- handle_fixed(request)
  ASSERT response.status IN {401, 403, 404}
  ASSERT response.body NOT CONTAINS stack_trace
  ASSERT response.body NOT CONTAINS password_hash
END FOR

Property: Preservation Checking
FOR ALL request WHERE NOT isBugCondition_Security(request) DO
  ASSERT handle(request) = handle_fixed(request)
END FOR


### P0 崩溃类（Bug 1.5-1.8）

FUNCTION isBugCondition_Crash(data)
  INPUT: data of type ActionResult OR LLMResponse OR RequestBody
  OUTPUT: boolean

  RETURN (data.type = param_fill AND data.missing_params EXISTS p WHERE p.input_type = radio AND p.options IS EMPTY)
      OR (data.type IN {navigate, mindmap, mistake} AND data.route IS NULL)
      OR (data IS LLMResponse AND data.text STARTS_WITH markdown_fence)
      OR (data IS RequestBody AND data MISSING required_field)
END FUNCTION

Property: Fix Checking
FOR ALL data WHERE isBugCondition_Crash(data) DO
  result <- process_fixed(data)
  ASSERT no_crash(result)
  ASSERT result IS valid_response
END FOR


### P0 CAS 白名单（Bug 1.9）

FUNCTION isBugCondition_ActionWhitelist(llm_output)
  INPUT: llm_output of type IntentResult
  OUTPUT: boolean

  RETURN llm_output.action_id NOT IN ActionRegistry.registered_ids
END FUNCTION

Property: Fix Checking
FOR ALL llm_output WHERE isBugCondition_ActionWhitelist(llm_output) DO
  result <- IntentMapper.map_fixed(llm_output)
  ASSERT result.action_id = unknown_intent
END FOR

Property: Preservation Checking
FOR ALL llm_output WHERE NOT isBugCondition_ActionWhitelist(llm_output) DO
  ASSERT IntentMapper.map(llm_output) = IntentMapper.map_fixed(llm_output)
END FOR


### P1 LLM 异常兜底（Bug 4.2-4.3）

FUNCTION isBugCondition_LLMError(api_response)
  INPUT: api_response of type HTTPResponse
  OUTPUT: boolean

  RETURN api_response.status IN {429, 401, 500}
      OR api_response.elapsed > LLM_TIMEOUT_SECONDS
END FUNCTION

Property: Fix Checking
FOR ALL api_response WHERE isBugCondition_LLMError(api_response) DO
  result <- LLMService.chat_fixed(api_response)
  ASSERT no_crash(result)
  ASSERT result IS structured_error_response
END FOR

Property: Preservation Checking
FOR ALL api_response WHERE NOT isBugCondition_LLMError(api_response) DO
  ASSERT LLMService.chat(api_response) = LLMService.chat_fixed(api_response)
END FOR


### P2 掌握度计算（Bug 7.6）

FUNCTION isBugCondition_MasteryCalc(review_result)
  INPUT: review_result of type ReviewResult
  OUTPUT: boolean

  RETURN review_result.is_correct = true AND mastery_score_after < mastery_score_before
END FUNCTION

Property: Fix Checking
FOR ALL review_result WHERE isBugCondition_MasteryCalc(review_result) DO
  score_after <- updateMastery_fixed(review_result)
  ASSERT score_after >= review_result.score_before
  ASSERT score_after <= 5
END FOR

Property: Preservation Checking
FOR ALL review_result WHERE review_result.is_correct = false DO
  ASSERT updateMastery(review_result) = updateMastery_fixed(review_result)
  ASSERT score_after <= review_result.score_before
END FOR
