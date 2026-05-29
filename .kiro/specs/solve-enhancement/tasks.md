# 实现计划：solve-enhancement

## 概述

本计划将解题模块（SolvePage）的三项增强功能分解为可增量执行的编码任务。后端任务优先于前端任务；三个子功能（历史记录、Python 计算引擎、图像预处理）互不依赖，可并行实现。

---

## 任务列表

- [x] 1. 后端基础配置与依赖更新
  - 在 `backend/backend_config.py` 中新增 `SOLVE_IMAGE_PREPROCESS_ENABLED` 配置项（默认 `False`）
  - 在 `backend/requirements.txt` 中新增 `opencv-python-headless`、`hypothesis`（测试依赖）
  - _需求：10.1、10.2、10.6_

---

### 子功能 A：解题历史记录（后端）

- [x] 2. 实现 SolveProblemExecutor 会话持久化逻辑
  - 在 `backend/cas/executors/solve_problem.py` 中实现 `_generate_title(ocr_text)` 纯函数：OCR 文本前 15 字符截断 + 省略号，空文本使用"解题记录 MM-DD HH:mm"格式
  - 实现 `_create_solve_session(user_id, ocr_text)` 异步函数：在 `conversation_sessions` 表中插入 `session_type='solve'` 记录，返回 `session_id`
  - 实现 `_persist_conversation(session_id, user_content, assistant_content, images)` 异步函数：向 `conversation_history` 写入 user 和 assistant 两条记录，图片存入 `sources` JSONB 字段
  - 改造 `solve_problem_executor` 主函数：首次解题时创建 session，追问时复用 session_id；SSE 流完成后通过 `asyncio.create_task` 异步持久化；数据库写入失败时仅记录错误日志，不中断 SSE 流；SSE 事件中携带 `session_id` 字段
  - _需求：1.1、1.2、1.3、1.4、1.5、1.6、11.1、11.2、11.3_

  - [ ]* 2.1 为 `_generate_title` 编写属性测试
    - **属性 1：会话标题截断不变性** — 对任意非空文本，标题长度 ≤ 16 字符
    - **属性 2：空文本标题格式正确性** — 对任意空白字符串，标题以"解题记录 "开头
    - 文件：`backend/tests/test_solve_history.py`
    - **验证：需求 11.1、11.2、11.3**

  - [ ]* 2.2 为图片 Base64 存储往返一致性编写属性测试
    - **属性 5：图片 Base64 存储往返一致性** — 对任意 Base64 列表，JSONB 序列化/反序列化后数据不变
    - 文件：`backend/tests/test_solve_history.py`
    - **验证：需求 1.4、3.2**

- [x] 3. 实现解题历史 REST API 路由
  - 新建 `backend/routers/solve.py`，实现三个端点：
    - `GET /sessions`：查询当前用户所有 `session_type='solve'` 会话，按 `created_at` 降序，附带首条用户消息第一张图片的缩略图（Base64 前 200 字符）
    - `GET /sessions/{session_id}`：返回指定会话的完整 `conversation_history`，含 `id`、`role`、`content`、`sources`、`created_at` 字段；非本人会话返回 HTTP 403
    - `DELETE /sessions/{session_id}`：删除会话及级联的历史消息；非本人会话返回 HTTP 403
  - 所有端点通过 `Depends(get_current_user)` 进行身份验证，未认证返回 HTTP 401
  - _需求：12.1、12.2、12.3、12.4、12.5_

  - [ ]* 3.1 为历史 API 返回字段完整性编写属性测试
    - **属性 4：历史 API 返回字段完整性** — 列表 API 每条记录含 `id`、`title`、`created_at`、`thumbnail`；详情 API 每条记录含 `id`、`role`、`content`、`sources`、`created_at`
    - 文件：`backend/tests/test_solve_history.py`
    - **验证：需求 12.1、12.2**

  - [ ]* 3.2 为会话所有权隔离编写属性测试
    - **属性 3：会话所有权隔离** — 用户 B 访问/删除用户 A 的会话时，后端返回 HTTP 403
    - 文件：`backend/tests/test_solve_history.py`
    - **验证：需求 12.4**

  - [ ]* 3.3 为历史列表仅返回 solve 类型会话编写属性测试
    - **属性 6：历史列表仅返回 solve 类型会话** — `GET /api/solve/sessions` 返回的所有记录 `session_type` 均为 `'solve'`
    - 文件：`backend/tests/test_solve_history.py`
    - **验证：需求 2.2**

  - [ ]* 3.4 为删除操作级联完整性编写属性测试
    - **属性 7：删除操作级联完整性** — 删除会话后，`conversation_sessions` 和所有关联 `conversation_history` 记录均消失
    - 文件：`backend/tests/test_solve_history.py`
    - **验证：需求 4.2、12.3**

- [x] 4. 注册解题历史路由到应用
  - 在 `backend/app_routes.py` 中导入 `solve.router`，挂载到 `/api/solve`
  - _需求：12.1、12.2、12.3_

---

### 子功能 B：Python 计算引擎（后端）

- [x] 5. 实现 Python 执行器 MCP 服务器
  - 新建 `backend/mcp_servers/python_executor_server.py`
  - 实现 `_execute_sandboxed(code)` 函数：构建沙箱包装脚本（黑名单模块拦截、stdout/stderr 重定向、matplotlib 图表捕获），通过 `subprocess.run` 在子进程中执行，10 秒超时，256MB 内存限制（`resource.setrlimit`），解析 `__RESULT__:` 标记返回结构化结果
  - 实现 `list_tools` 和 `call_tool` MCP 端点，工具名 `execute`，输入参数 `code`（字符串），返回 `{"stdout", "stderr", "image_base64"}`
  - 黑名单模块：`os`、`sys`、`subprocess`、`socket`、`requests`、`urllib`
  - _需求：5.1、5.2、5.3、5.4、5.5、5.6、6.1、6.2、6.3、6.4_

  - [ ]* 5.1 为 Python 执行器返回格式不变性编写属性测试
    - **属性 8：Python 执行器返回格式不变性** — 对任意代码字符串（含空串、语法错误），返回结果均含 `stdout`、`stderr`、`image_base64` 字段，`image_base64` 为字符串或 `null`
    - 文件：`backend/tests/test_python_executor.py`
    - **验证：需求 5.3**

  - [ ]* 5.2 为黑名单模块导入拒绝编写属性测试
    - **属性 9：黑名单模块导入拒绝** — 对任意黑名单模块名，导入被拒绝，`stderr` 含禁止导入错误信息，`stdout` 为空
    - 文件：`backend/tests/test_python_executor.py`
    - **验证：需求 6.1**

  - [ ]* 5.3 为 matplotlib 图表 Base64 可解码性编写属性测试
    - **属性 13：matplotlib 图表 Base64 可解码性** — 含 matplotlib 绘图代码执行后，`image_base64` 非 null 时可解码为有效 PNG
    - 文件：`backend/tests/test_python_executor.py`
    - **验证：需求 5.5**

- [x] 6. 注册 Python 执行器 MCP 服务器配置
  - 新建 `backend/mcp_layer/server_configs/python_executor_server.py`：定义 `PYTHON_EXECUTOR_SERVER_CONFIG`（`MCPServerConfig`，`server_id="python_executor"`，指向 `python_executor_server.py` 脚本路径）
  - 在 `backend/app_lifecycle.py` 的 `_warm_action_registry` 中注册该配置
  - _需求：5.1_

- [x] 7. 在 SolveProblemExecutor 中集成 Python 计算工具
  - 在 `backend/cas/executors/solve_problem.py` 中追加 `_PYTHON_TOOL_PROMPT` 到系统提示词，说明 `python_executor.execute` 工具的调用格式和适用场景
  - 实现 `_handle_tool_call(chunk)` 异步函数：通过 `MCPRegistry.call_tool` 调用 `python_executor.execute`，工具失败时返回含降级提示的错误结构
  - 改造 `generate_sse` 生成器：处理 `function_call` 类型 chunk，调用工具后若 `image_base64` 非 null 则推送 `{"content": "[CHART]", "image_base64": "..."}` SSE 事件，将工具结果注入 messages 继续推理
  - _需求：7.1、7.2、7.3、7.4_

  - [ ]* 7.1 为工具调用失败降级编写单元测试
    - 测试 `_handle_tool_call` 在工具调用失败时返回含"请改用纯文字推理"的降级结构
    - 文件：`backend/tests/test_python_executor.py`
    - _需求：7.4_

---

### 子功能 C：图像预处理（后端）

- [x] 8. 实现 ImagePreprocessor 服务基础结构
  - 新建 `backend/services/image_preprocessor.py`
  - 定义 `StepLog` 和 `PreprocessResult` 数据类
  - 实现 `ImagePreprocessor.process(image_b64)` 主方法：Base64 解码 → 五步流水线 → JPEG 质量 90 编码 → 返回 `PreprocessResult`；图片解码失败时直接返回 `degraded=True` 的原始图片；完成后记录结构化性能日志（各步骤耗时、是否跳过、输入/输出尺寸、总耗时）
  - _需求：9.16、9.17、9.18、10.6_

- [x] 9. 实现步骤一：EXIF 方向矫正
  - 在 `backend/services/image_preprocessor.py` 中实现 `_step_exif_correct(img)` 方法
  - 使用 Pillow 读取 EXIF Orientation 标签，按标准映射表旋转/翻转图片到正向（0°）
  - 矫正后丢弃 EXIF 方向标签；无 EXIF 信息或方向值为 1 时跳过；步骤异常时记录 WARNING 日志并跳过
  - 受 `PREPROCESS_EXIF_CORRECT` 环境变量控制（默认 `True`）
  - _需求：9.1、9.2、9.3、10.3_

- [x] 10. 实现步骤二：2D 倾斜矫正
  - 在 `backend/services/image_preprocessor.py` 中实现 `_step_deskew(img)` 方法
  - 灰度化 → Canny 边缘检测（阈值 50/150）→ `cv2.HoughLinesP`（minLineLength=100）→ 计算直线角度中位数
  - 倾斜角绝对值在 0.5°~15° 之间时执行 `cv2.warpAffine` 仿射旋转，旋转中心为图片中心，边缘填充白色（255）
  - 倾斜角 < 0.5° 或 > 15° 时跳过；步骤异常时记录 WARNING 日志并跳过
  - 受 `PREPROCESS_DESKEW` 环境变量控制（默认 `True`）
  - _需求：9.4、9.5、9.6、10.3_

- [x] 11. 实现步骤三：Retinex 光照均衡 + CLAHE
  - 在 `backend/services/image_preprocessor.py` 中实现 `_step_retinex_clahe(img)` 方法
  - 计算灰度图标准差：≥ 20 时执行单尺度 Retinex（SSR，sigma=80 高斯模糊估计光照分量，对数域相减后归一化）；< 20 时跳过 Retinex
  - 对 LAB 色彩空间 L 通道执行 CLAHE（`clipLimit=2.0`，`tileGridSize=(8,8)`）
  - 步骤异常时记录 WARNING 日志并跳过；受 `PREPROCESS_RETINEX_CLAHE` 环境变量控制（默认 `True`）
  - _需求：9.7、9.8、9.9、10.3_

- [x] 12. 实现步骤四：NLM 去噪 + Unsharp Mask 锐化
  - 在 `backend/services/image_preprocessor.py` 中实现 `_step_nlm_sharpen(img)` 方法
  - 计算拉普拉斯方差：≤ 500 时执行 `cv2.fastNlMeansDenoisingColored`（h=10，hColor=10，templateWindowSize=7，searchWindowSize=21）；> 500 时跳过去噪
  - 执行 Unsharp Mask 锐化：高斯模糊（sigma=1.0）生成模糊版本，`cv2.addWeighted(img, 2.5, blur, -1.5, 0)` 叠加锐化掩码
  - 步骤异常时记录 WARNING 日志并跳过；受 `PREPROCESS_NLM_SHARPEN` 环境变量控制（默认 `True`）
  - _需求：9.10、9.11、9.12、10.3_

- [x] 13. 实现步骤五：摩尔纹检测与去除
  - 在 `backend/services/image_preprocessor.py` 中实现 `_step_moire_remove(img)` 方法
  - 灰度图 → `np.fft.fft2` → `np.fft.fftshift` → 排除直流分量（中心 20×20 区域）→ 计算 99 百分位阈值 → 峰值能量占比 > 5% 时判定存在摩尔纹
  - 检测到摩尔纹时构建陷波滤波器（峰值坐标周围 7×7 区域置 0）→ `np.fft.ifft2` 还原到空间域
  - 未检测到摩尔纹时跳过；步骤异常时记录 WARNING 日志并跳过；受 `PREPROCESS_MOIRE_REMOVE` 环境变量控制（默认 `True`）
  - _需求：9.13、9.14、9.15、10.3_

  - [ ]* 13.1 为图像预处理宽高比不变性编写属性测试
    - **属性 10：图像预处理宽高比不变性** — 对任意尺寸输入图片，预处理后宽高比误差 < 1%
    - 文件：`backend/tests/test_image_preprocessor.py`
    - **验证：需求 9.19**

  - [ ]* 13.2 为图像预处理输出为有效 JPEG 编写属性测试
    - **属性 11：图像预处理输出为有效 JPEG** — 对任意输入图片，`process` 返回的 `image_b64` 可解码为有效 JPEG
    - 文件：`backend/tests/test_image_preprocessor.py`
    - **验证：需求 9.16**

  - [ ]* 13.3 为步骤开关控制有效性编写属性测试
    - **属性 12：步骤开关控制有效性** — 对任意步骤，当对应环境变量设为 `false` 时，`StepLog.skipped` 为 `True` 且 `reason` 含"配置禁用"
    - 文件：`backend/tests/test_image_preprocessor.py`
    - **验证：需求 10.3**

- [x] 14. 将 ImagePreprocessor 集成到 OCRService
  - 改造 `backend/services/ocr_service.py` 的 `extract_text_from_base64` 方法
  - 当 `SOLVE_IMAGE_PREPROCESS_ENABLED=True` 时，在调用视觉 API 前先调用 `ImagePreprocessor().process(image_b64)`，使用预处理后的图片执行 OCR
  - 当 `SOLVE_IMAGE_PREPROCESS_ENABLED=False` 时，跳过预处理，行为与现有版本完全一致
  - 预处理失败（`result.degraded=True`）时使用原始图片继续 OCR，日志记录 `preprocess_degraded=True`
  - _需求：10.1、10.2、10.4、10.5_

  - [ ]* 14.1 为 OCRService 集成编写单元测试
    - 测试预处理开关控制（开启/关闭时的行为差异）
    - 测试预处理失败降级（`degraded=True` 时使用原始图片）
    - 文件：`backend/tests/test_image_preprocessor.py`
    - _需求：10.1、10.2、10.4_

- [x] 15. 后端检查点 — 确保所有后端测试通过
  - 确保所有测试通过，向用户询问是否有疑问。

---

### 子功能 D：前端实现（Flutter）

- [x] 16. 实现解题历史 API 客户端与数据模型
  - 在 Flutter 项目中新建 `lib/features/solve/models/solve_session.dart`：定义 `SolveSession`（含 `id`、`title`、`createdAt`、`thumbnail`）和 `SolveMessage`（含 `id`、`role`、`content`、`sources`、`createdAt`）数据模型
  - 新建 `lib/features/solve/services/solve_history_service.dart`：实现 `fetchSessions()`、`fetchSession(sessionId)`、`deleteSession(sessionId)` 三个方法，对应后端三个 REST API
  - _需求：2.2、3.1、4.2、12.1、12.2、12.3_

- [x] 17. 实现历史记录列表 UI
  - 在 `lib/features/solve/widgets/solve_history_sheet.dart` 中实现历史记录底部弹出面板（`BottomSheet`）
  - 展示会话列表：每条显示缩略图（`Image.memory`，若有）、标题、创建时间
  - 支持下拉刷新（`RefreshIndicator`）
  - 列表为空时展示"暂无历史记录"空状态提示
  - 每条会话支持滑动删除（`Dismissible`）或长按删除，删除前弹出确认对话框；删除成功后从列表移除并显示成功提示；删除失败时显示错误提示，列表保持原状
  - _需求：2.1、2.3、2.4、2.5、4.1、4.3、4.4_

- [x] 18. 在 SolvePage 集成历史记录入口与会话恢复
  - 在 `lib/features/solve/pages/solve_page.dart` 顶部添加"历史记录"入口按钮，点击后打开 `SolveHistorySheet`
  - 实现会话恢复逻辑：点击历史列表中的会话时，调用 `fetchSession(sessionId)` 加载完整历史消息，在解题对话区域还原对话内容（含图片缩略图）
  - 恢复后设置 `session_id`，后续追问复用同一会话
  - 历史数据加载失败时展示错误提示和重试按钮
  - _需求：2.1、3.1、3.2、3.3、3.4_

- [x] 19. 实现 SSE 流中 session_id 接收与图表渲染
  - 在 `lib/features/solve/pages/solve_page.dart` 的 SSE 解析逻辑中，处理 `session_id` 字段：首次解题时从 SSE 响应中提取并保存 `session_id`
  - 处理 `[CHART]` 特殊 SSE 事件：解码 `image_base64` 字段，使用 `Image.memory` 组件将图表内嵌渲染在当前解题消息气泡中
  - 支持点击图表全屏预览（`InteractiveViewer` 或 `showDialog`）
  - `image_base64` 解码失败时展示图表加载失败占位提示，不影响其余文字内容显示
  - _需求：8.1、8.2、8.3、1.1_

  - [ ]* 19.1 为图表渲染编写 Widget 测试
    - 测试 `[CHART]` 事件触发 `Image.memory` 渲染
    - 测试 `image_base64` 解码失败时显示占位提示
    - _需求：8.1、8.3_

- [x] 20. 最终集成检查点 — 确保所有测试通过
  - 确保所有后端和前端测试通过，向用户询问是否有疑问。

---

## 备注

- 标记 `*` 的子任务为可选项，可跳过以加快 MVP 交付
- 每个任务均引用具体需求条款，确保可追溯性
- 属性测试使用 `hypothesis` 库，每个属性独立为一个子任务
- 后端三个子功能（任务 2-4、5-7、8-14）互不依赖，可并行实现
- 前端任务（16-19）依赖后端 API 完成后进行
