# 实现计划：多模态解题系统重构

## 概述

将"伴学"现有的单图 OCR 解题功能，重构为工业级多模态（图+文）解题流水线。
实现顺序：后端基础层 → 后端核心引擎 → 前端服务层 → 前端 UI 组件 → 集成联调。

**防御性改进（来自架构师审查）已内嵌到对应任务中：**
- SSE 协议 JSON 化（Task 3.2）
- 视觉 API 并发限流 Semaphore(2)（Task 2.2）
- 意图短路豁免逻辑（Task 3.1）
- 追问跳过 OCR（Task 3.2）
- 图片压缩保持宽高比（Task 5.1）

---

## Tasks

- [x] 1. 后端基础层：配置与数据模型扩展
  - [x] 1.1 扩展 `backend/backend_config.py`，新增解题流水线配置项
    - 在 `AppConfig` dataclass 中新增以下字段（均带默认值，可通过环境变量覆盖）：
      - `SOLVE_OCR_TIMEOUT_SECONDS: int = 15`
      - `SOLVE_REASONING_MAX_TOKENS: int = 4096`
      - `SOLVE_MAX_IMAGES: int = 4`
      - `SOLVE_IMAGE_MAX_LONG_EDGE: int = 1920`
    - 在 `get_config()` 工厂函数中读取对应环境变量（`int(os.getenv(..., "默认值"))`）
    - _需求：13.1_

  - [x] 1.2 扩展 `backend/cas/models.py`，更新 CAS 数据模型
    - `DispatchIn` 新增两个可选字段：`images: Optional[list[str]] = None`、`supplement_text: Optional[str] = None`
    - `RenderType` 枚举新增 `stream = "stream"` 值，标识流式响应类型
    - _需求：4.3、7.1_

- [x] 2. 后端 OCR 服务重构
  - [x] 2.1 重构 `backend/services/ocr_service.py`，新增 Base64 接口并保持向后兼容
    - 保留现有 `extract_text(image_path: str) -> str` 和 `extract_text_from_pdf_page(pdf_path: str, page_num: int) -> str` 方法签名不变
    - 新增 `_OCR_PROMPT` 类常量，要求模型将数学公式以 LaTeX 格式输出（行内 `$...$`，块级 `$$...$$`），禁止输出解答内容
    - 新增异步方法 `extract_text_from_base64(self, image_b64: str) -> str`，接受单张 Base64 图片，调用 `LLMService` 的视觉接口（`model=config.LLM_VISION_MODEL`），超时时间为 `config.SOLVE_OCR_TIMEOUT_SECONDS`
    - 新增异步方法 `extract_text_from_base64_list(self, images: list[str]) -> str`，用 `asyncio.gather` 并发调用 `extract_text_from_base64`，结果以 `\n---\n` 拼接
    - OCR 失败降级策略：主模型超时/异常 → 降级到 `LLM_CHAT_MODEL` 视觉能力 → 均失败则抛 `RuntimeError`，记录 WARNING 日志
    - _需求：5.1、5.2、5.3、5.4、5.5、5.6、12.1、12.2、12.3_

  - [x] 2.2 在 `OCRService` 中添加并发限流 Semaphore（防御性改进）
    - 在类级别声明 `_semaphore = asyncio.Semaphore(2)`，限制同时调用视觉 API 的并发数为 2
    - 在 `extract_text_from_base64` 方法体内用 `async with self._semaphore:` 包裹 API 调用
    - 目的：防止多张图片并发 OCR 时触发 SiliconFlow 429 速率限制
    - _需求：5.1（防御性）_

  - [ ]* 2.3 为 OCR 服务编写属性测试（PBT）
    - **属性 1：OCR Round-Trip（任意有效 Base64 输入 → 返回非空字符串）**
    - 使用 `hypothesis` 库，`@given(st.binary(min_size=100))` 生成模拟图片字节
    - Mock `LLMService.chat` 返回固定非空文本，验证 `extract_text_from_base64` 返回值 `len(result) > 0`
    - 测试文件：`backend/tests/test_ocr_service_pbt.py`
    - **验证：需求 5.7**

- [x] 3. 后端 CAS 意图调度层升级
  - [x] 3.1 升级 `backend/cas/intent_mapper.py`，新增多模态短路规则（含豁免逻辑）
    - 在文件顶部定义 `_NON_SOLVE_KEYWORDS` 列表：`["日历", "导图", "思维导图", "笔记", "计划", "出题", "错题", "讲义", "课程"]`
    - 修改 `RuleMapper.map(self, text: str, images: list[str] | None = None)` 签名，新增 `images` 参数
    - 在 `RuleMapper.map()` 方法**最前面**插入优先规则：
      - 若 `images` 非空，检查 `text` 是否包含 `_NON_SOLVE_KEYWORDS` 中任意关键词
      - 若不包含（无其他意图词）→ 直接返回 `IntentMapResult(action_id="solve_problem", confidence=0.9, degraded=True)`
      - 若包含（有其他意图词）→ 跳过短路，继续走原有关键词规则（豁免逻辑，防止误判）
    - 修改 `IntentMapper.map()` 签名，新增 `images: list[str] | None = None` 参数，并透传给 `RuleMapper.map()`
    - _需求：4.1、4.5_

  - [x] 3.2 升级 `backend/cas/dispatch_pipeline.py`，支持多模态参数透传和流式响应
    - 修改 `DispatchPipeline.run()` 和 `_run_inner()` 签名，新增 `images: list[str] | None = None` 和 `supplement_text: str | None = None` 参数
    - 在意图映射后，将 `images` 和 `supplement_text` 注入 `intent.params` 字典
    - 若 `images` 存在但 `supplement_text` 为 `None`，自动填充为空字符串（需求 4.4）
    - 修改返回类型注解为 `ActionResult | StreamingResponse`，executor 返回 `StreamingResponse` 时直接透传，不再包装为 `ActionResult`
    - 透传 `images` 给 `IntentMapper.map()` 调用
    - _需求：4.2、4.3、4.4_

  - [x] 3.3 重构 `backend/cas/executors/solve_problem.py`，实现流式解题执行器核心引擎
    - 将现有的导航跳转实现完全替换为流式解题执行器
    - **OCR 阶段**（仅首次解题，`history` 为空时执行）：
      - 调用 `OCRService().extract_text_from_base64_list(images)` 提取文本
      - 记录 `ocr_duration_ms` 到结构化日志（INFO 级别）
    - **追问跳过 OCR（防御性改进）**：当 `params.get("history")` 非空时，直接跳过 OCR 步骤，复用历史上下文中的原题信息，节省 Token 成本
    - **Prompt 组装**：
      - 有 `supplement_text` 时：`"【题目图片识别内容】\n{ocr_text}\n\n【补充说明】\n{supplement_text}"`
      - 无 `supplement_text` 时：仅保留 `"【题目图片识别内容】\n{ocr_text}"`（需求 6.2）
    - **系统提示词**：要求按 `## 考点分析` / `## 解题步骤` / `## 最终答案` 三节输出，数学公式使用 LaTeX
    - **流式推理**：调用 `LLMService().stream_chat(messages, model=heavy_model, max_tokens=config.SOLVE_REASONING_MAX_TOKENS)`
    - **SSE JSON 化（防御性改进）**：所有 token 推送强制 `json.dumps({'content': token}, ensure_ascii=False)`，防止 token 内含换行符导致 SSE 协议截断
    - 结束标志：`json.dumps({'content': '[DONE]'})`；异常标志：`json.dumps({'content': '[ERROR]', 'error': str(e)})`
    - 完成后记录结构化日志：`ocr_duration_ms`、`reasoning_duration_ms`、`image_count`、`token_count`
    - 返回 `StreamingResponse(generate_sse(), media_type="text/event-stream")`
    - _需求：6.1、6.2、6.3、6.4、6.5、7.1、7.2、7.3、13.2_

  - [ ]* 3.4 为 Prompt 组装逻辑编写属性测试（PBT）
    - 从 `solve_problem.py` 中提取 `build_solve_prompt(ocr_text, supplement_text)` 为可测试的纯函数
    - **属性 2：supplement_text 为空时 Prompt 不含"补充说明"**
      - `@given(st.text(), st.just(""))` → `assert "补充说明" not in prompt`
    - **属性 3：supplement_text 非空时 Prompt 包含"补充说明"**
      - `@given(st.text(), st.text(min_size=1))` → `assert "补充说明" in prompt`
    - 测试文件：`backend/tests/test_solve_prompt_pbt.py`
    - **验证：需求 6.1、6.2**

- [x] 4. 后端路由层扩展
  - [x] 4.1 升级 `backend/routers/cas.py`，支持多模态请求和流式响应透传
    - 移除 `/dispatch` 端点的 `response_model=ActionResult` 约束（流式响应无法用 Pydantic 模型描述）
    - 修改 `dispatch()` 函数，将 `body.images` 和 `body.supplement_text` 传入 `pipeline.run()`
    - 当 `body.images` 非空时，允许 `body.text` 为空（不再强制要求 text 非空）
    - 当 `pipeline.run()` 返回 `StreamingResponse` 时，直接 `return result`（FastAPI 自动处理流式响应）
    - _需求：4.2、7.1_

- [x] 5. 前端服务层：图片压缩与 SSE 客户端
  - [x] 5.1 新建 `lib/services/image_compress_service.dart`，实现图片压缩服务（含宽高比保持）
    - 在 `pubspec.yaml` 中新增依赖：`flutter_image_compress: ^2.3.0`（运行 `flutter pub get`）
    - 实现 `ImageCompressService` 类，提供静态方法 `compressToBase64List(List<XFile> images, {int maxLongEdge = 1920, int quality = 75}) -> Future<List<String>>`
    - **保持宽高比（防御性改进）**：读取原图尺寸（`ui.instantiateImageCodec`），计算等比缩放后的目标宽高，仅将长边限制在 `maxLongEdge`，短边按比例缩放，**不硬编码** `minWidth`/`minHeight` 为相同值，防止公式图片变形
    - 使用 `FlutterImageCompress.compressWithList(bytes, minWidth: targetWidth, minHeight: targetHeight, quality: quality, format: CompressFormat.jpeg)`
    - 压缩后用 `base64Encode` 转为字符串
    - _需求：1.3、1.5_

  - [x] 5.2 新建 `lib/services/solve_sse_client.dart`，实现基于 Dio 的 SSE 客户端
    - 实现 `SolveSSEClient` 类，使用 `Dio` 的 `ResponseType.stream` 模式，不引入新包
    - 定义密封类 `SolveSSEEvent`，包含三个子类：`SolveTokenEvent(String text)`、`SolveDoneEvent`、`SolveErrorEvent(String message)`
    - `connect()` 方法返回 `Stream<SolveSSEEvent>`，解析 `data: ` 行
    - **JSON 解析（配合后端 JSON 化推送）**：用 `jsonDecode(rawData)['content']` 提取内容，而非直接使用裸字符串
    - 降级兼容：JSON 解析失败时回退到裸字符串解析（兼容旧格式）
    - 处理 `[DONE]`、`[ERROR]` 特殊标志
    - 维护行缓冲区，处理跨 chunk 的不完整行
    - _需求：7.4、7.5_

- [x] 6. 前端数据模型
  - [x] 6.1 新建 `lib/models/solve_session_model.dart`，定义解题会话数据模型
    - 定义 `SolveSessionModel`（使用 `freezed` 或手写不可变类），包含字段：
      - `sessionId: String`
      - `imageBase64List: List<String>`（原始图片，追问时复用）
      - `ocrText: String`（OCR 结果缓存）
      - `messages: List<SolveMessage>`（对话历史）
      - `isThinkingExpanded: bool`（CoT 展开状态，默认 false）
      - `isStreaming: bool`（默认 false）
    - 定义 `SolveMessage`，包含字段：`role: String`、`content: String`、`imageBase64List: List<String>?`、`isSaved: bool`
    - _需求：8.3、10.4_

- [x] 7. 前端 UI 组件层
  - [x] 7.1 新建 `lib/widgets/multimodal_input_bar.dart`，实现多模态输入栏组件
    - 实现 `MultimodalInputBar` StatefulWidget，管理 `List<XFile> _selectedImages`（上限 4 张）
    - 提供"拍照"和"图库"两个图片选取入口（`ImagePicker`）
    - 图片选取后，在输入框上方渲染横向滚动缩略图列表，每张右上角有 `×` 删除按钮
    - 发送按钮禁用条件：`_selectedImages.isEmpty && controller.text.trim().isEmpty`
    - 发送时：调用 `ImageCompressService.compressToBase64List` 压缩图片，失败时 SnackBar 提示"图片处理失败，请重试"，保留其他已选图片
    - 发送成功后清除所有缩略图预览和输入框内容
    - 通过 `onSend(MultimodalPayload payload)` 回调将数据传出
    - _需求：1.1、1.2、1.3、1.4、1.5、1.6、1.7_

  - [x] 7.2 新建 `lib/widgets/cot_collapsible_view.dart`，实现 CoT 思维链折叠组件
    - 实现 `CoTCollapsibleView` StatelessWidget，接受参数：`thinkingContent: String`、`isExpanded: bool`、`onToggle: VoidCallback`
    - 折叠时显示"查看推理过程 ▶"，展开时显示"收起推理过程 ▼"
    - 展开时用 `MarkdownLatexView` 渲染思维链内容
    - 若 `thinkingContent` 为空，不渲染任何内容（需求 8.4）
    - _需求：8.1、8.2、8.4_

  - [x] 7.3 新建 `lib/widgets/solve_result_action_bar.dart`，实现解题结果操作栏
    - 实现 `SolveResultActionBar` StatelessWidget，接受参数：`message: SolveMessage`、`onSaveToNotebook: VoidCallback`、`onSaveToMistakes: VoidCallback`
    - 提供"收藏到笔记本"和"加入错题本"两个按钮
    - 已保存状态（`message.isSaved == true`）时按钮变为已选中样式，防止重复入库
    - _需求：3.4、10.1、10.4_

  - [x] 7.4 增强 `lib/widgets/markdown_latex_view.dart`，新增流式容错渲染能力
    - 新增可选参数 `isStreaming: bool = false`
    - 实现私有方法 `_hasUnclosedLatex(String text) -> bool`，检测 `$`、`$$`、`\(`、`\[`、`\begin{` 是否成对闭合（奇数次出现视为未闭合）
    - 实现私有方法 `_truncateAtLastSafePoint(String text) -> String`，截断到最后一个安全位置（最后一个完整段落或句子）
    - 在 `build()` 中：`isStreaming && _hasUnclosedLatex(content)` 时，调用 `_buildSafeMarkdown(_truncateAtLastSafePoint(content))` 作普通文本渲染，避免 `Math.tex()` 解析崩溃
    - 流式完成后（`isStreaming == false`）执行完整 LaTeX 解析和渲染
    - _需求：9.1、9.2、9.3_

  - [ ]* 7.5 为 LaTeX 容错渲染编写属性测试（PBT）
    - **属性 5：LaTeX 幂等性（流式完成后渲染结果 == 非流式直接渲染）**
    - 使用 `flutter_test` 编写 widget 测试，对一组合法 LaTeX 字符串验证：`renderAfterStreaming(latex) == renderDirect(latex)`
    - 测试文件：`test/widgets/markdown_latex_view_pbt_test.dart`
    - **验证：需求 9.4**

- [x] 8. 前端 Bug 修复：类型安全响应解析
  - [x] 8.1 修复 `lib/providers/chat_provider.dart` 中的类型安全解析问题
    - 在 `ChatService` 或 `ChatNotifier` 的响应解析处，用 `is List` 和 `is Map` 进行严格类型判定，不直接强制转型
    - 当 `response.data is List` 时（FastAPI 422 的 `detail` 字段），将列表格式化为可读错误字符串展示给用户
    - 当 `response.data` 既不是 `List` 也不是 `Map` 时，转为字符串后作为错误消息处理，不抛出未捕获异常
    - _需求：11.1、11.2、11.3_

  - [ ]* 8.2 为类型安全解析编写属性测试（PBT）
    - **属性 4：对任意响应格式不抛 TypeError（类型安全性）**
    - 测试输入覆盖：`Map`、`List`、纯字符串、整数、`null`
    - 验证 `parseResponseData(data)` 对所有输入均不抛出 `TypeError` 或 `CastError`
    - 测试文件：`test/providers/chat_provider_type_safety_test.dart`
    - **验证：需求 11.4**

- [x] 9. 前端页面集成：SolvePage 多模态改造
  - [x] 9.1 改造 `lib/components/solve/solve_page.dart`，集成多模态输入和解题流水线
    - 将现有 `_InputBar` 替换为 `MultimodalInputBar`，接收 `MultimodalPayload`
    - 新增 `SolveSSEClient` 实例，处理流式响应
    - 用户消息气泡：包含图片缩略图网格（最多 2 列）和补充文字（需求 2.1）
    - 点击图片缩略图时，用 `photo_view` 打开全屏查看器（在 `pubspec.yaml` 新增 `photo_view: ^0.15.0`）
    - 流式接收时：持续滚动到消息列表底部（除非用户主动上翻）（需求 7.5）
    - 集成 `CoTCollapsibleView`：解析 `<think>...</think>` 块，默认折叠，展开/折叠状态在会话内持久化（需求 8.3）
    - 流式完成后：在 AI 消息气泡底部显示 `SolveResultActionBar`（需求 10.1）
    - 追问时：`history` 非空，`images` 传空列表，后端自动跳过 OCR
    - _需求：1.4、2.1、2.2、2.3、2.4、7.4、7.5、8.1、8.2、8.3、8.4、10.1_

  - [x] 9.2 实现解题结果入库功能（笔记本 / 错题本）
    - "收藏到笔记本"：弹出笔记本选择对话框，确认后调用 `NotebookService` 保存题目图片、OCR 文本和解题结果
    - "加入错题本"：弹出确认对话框，确认后调用相应 API 保存错题记录
    - 入库成功：SnackBar 提示"已保存"，按钮变为已选中状态
    - 入库失败：SnackBar 提示"保存失败，请重试"，按钮恢复可点击状态
    - _需求：10.2、10.3、10.4、10.5_

- [x] 10. 前端页面集成：ChatPage 自动解题路由
  - [x] 10.1 改造 `lib/features/chat/chat_page.dart`，集成多模态输入和自动解题路由
    - 将 ChatPage 底部输入栏替换为 `MultimodalInputBar`
    - 当用户发送包含图片的消息时，优先走 `/api/cas/dispatch` 接口（CAS 路径），而非普通聊天接口
    - 当 CAS 返回 `action_id == "solve_problem"` 且响应为流式时，以解题气泡样式（区别于普通问答气泡）展示 AI 回复，包含"考点分析 / 解题步骤 / 最终答案"分节结构
    - 当 CAS 返回非 `solve_problem` 意图时，回退到普通问答路径，不触发解题流水线（需求 3.3）
    - 在解题气泡底部提供"收藏到笔记本"和"加入错题本"操作按钮（需求 3.4）
    - _需求：3.1、3.2、3.3、3.4_

- [x] 11. 检查点 — 后端集成验证
  - 确保所有后端测试通过（`pytest backend/tests/ -v`）
  - 验证 `/api/cas/dispatch` 接口能正确接收 `images` 字段并返回 SSE 流
  - 验证 OCR 服务的向后兼容性（现有 PDF 解析等调用路径不受影响）
  - 确保所有测试通过，如有问题请向用户反馈。

- [x] 12. 检查点 — 前端集成验证
  - 确保所有 Flutter 测试通过（`flutter test --run`）
  - 验证 `pubspec.yaml` 中新增的两个依赖（`flutter_image_compress`、`photo_view`）已正确添加
  - 验证图片压缩后宽高比正确（公式图片不变形）
  - 验证 SSE 流式接收和 LaTeX 渲染无乱码
  - 确保所有测试通过，如有问题请向用户反馈。

---

## Notes

- 标有 `*` 的子任务为可选测试任务，可跳过以加快 MVP 交付
- 后端任务（1-4）必须先于前端任务（5-10）完成，确保 API 契约稳定
- 每个任务均引用了具体需求编号，便于追溯
- 属性测试（PBT）验证系统级不变量，单元测试验证具体示例和边界条件，两者互补
- 5 项防御性改进已内嵌到对应实现任务中，不作为独立任务，确保与主体逻辑一起实现
