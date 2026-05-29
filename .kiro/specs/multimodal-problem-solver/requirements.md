# 需求文档

## 简介

本功能将"伴学"应用中原有的"调用视觉大模型硬解"解题功能，重构为工业级的多模态（图+文）解题流水线。核心改造分四个阶段：前端多模态输入层改造、CAS 意图调度层升级、工业级解题执行器核心引擎重构、流式输出与前端渲染优化。同时修复历史遗留的类型转换异常。

**已确认的关键设计决策：**
- 双入口：SolvePage（解题专页）和 ChatPage（聊天流）均支持图文解题
- ChatPage 自动识别图片意图，走专用解题路径，与普通问答路径隔离
- 每次支持多张图片 + 可选补充文字（多模态混排）
- CoT 思维链双模式：默认折叠，用户可手动展开/收起
- 解题结果手动入库：用户自选收藏到笔记本或错题本
- 多轮追问：支持，追问上下文携带原始图片
- 进度展示：统一显示"解题中..."，不暴露 OCR/推理阶段细节

---

## 词汇表

- **SolvePage**：Flutter 解题专页（`lib/components/solve/solve_page.dart`）
- **ChatPage**：Flutter 聊天页面（`lib/features/chat/chat_page.dart`）
- **InputBar**：解题页面和聊天页面底部的输入栏组件
- **MultimodalPayload**：包含多张图片 Base64 数据列表和补充文本的 JSON 请求体
- **OCRService**：后端 OCR 服务（`backend/services/ocr_service.py`）
- **SolveProblemExecutor**：后端解题执行器（`backend/cas/executors/solve_problem.py`）
- **IntentMapper**：后端 CAS 意图映射模块（`backend/cas/intent_mapper.py`）
- **DispatchPipeline**：后端 CAS 分发管道（`backend/cas/dispatch_pipeline.py`）
- **MarkdownLatexView**：Flutter LaTeX + Markdown 渲染组件（`lib/widgets/markdown_latex_view.dart`）
- **SolveSession**：一次完整的解题会话，包含原始图片、OCR 文本、解题结果及后续追问历史
- **SSE**：Server-Sent Events，服务端推送事件协议
- **CoT**：Chain of Thought，思维链推理（DeepSeek-R1 等模型的 `<think>` 块）
- **PaddleOCR**：硅基流动（SiliconFlow）提供的 PaddlePaddle/PaddleOCR-VL-1.5 高精度 OCR 模型 API

---

## 需求

### 需求 1：前端多图文混排输入

**用户故事：** 作为学生，我希望在解题页面和聊天页面都能同时上传多张图片并输入补充文字，以便将题目图片和我的疑问一起发给 AI 解答。

#### 验收标准

1. THE **InputBar** SHALL 在输入框旁提供"拍照"和"图库"两个图片选取入口，支持一次选取多张图片（上限 4 张）。
2. WHEN 用户选取图片后，THE **InputBar** SHALL 在输入框上方以横向滚动缩略图列表展示已选图片，每张缩略图右上角有删除按钮，并允许用户继续在输入框中输入补充文字。
3. WHEN 用户点击发送，THE **SolvePage** / **ChatPage** SHALL 将每张图片压缩至长边不超过 1920px、JPEG 质量不低于 75，再编码为 Base64 字符串。
4. WHEN 用户点击发送，THE **SolvePage** / **ChatPage** SHALL 将 Base64 图片数据列表与补充文本组装为 **MultimodalPayload** JSON，通过 Dio 客户端发往后端 `/api/cas/dispatch` 接口。
5. IF 图片选取或压缩失败，THEN THE **InputBar** SHALL 以 SnackBar 提示用户"图片处理失败，请重试"，并保留输入框中已有文字和其他已选图片。
6. WHEN 图片发送成功后，THE **InputBar** SHALL 清除所有图片缩略图预览，并清空输入框。
7. IF 用户未选取任何图片且输入框为空，THEN THE **InputBar** SHALL 禁用发送按钮。

---

### 需求 2：前端多模态消息气泡展示

**用户故事：** 作为学生，我希望在对话列表中看到我发送的图片和文字，以便确认发送内容正确。

#### 验收标准

1. WHEN 用户发送包含图片的消息，THE **SolvePage** / **ChatPage** SHALL 在消息列表中渲染一个用户气泡，气泡内包含图片缩略图网格（最多 2 列）和补充文字。
2. WHILE 后端正在处理多模态请求，THE **SolvePage** / **ChatPage** SHALL 显示打字指示器（TypingIndicator），文案为"解题中..."。
3. IF 用户消息仅包含图片而无补充文字，THEN THE **SolvePage** / **ChatPage** SHALL 在气泡中仅显示图片缩略图网格，不显示空白文字区域。
4. WHEN 用户点击气泡中的图片缩略图，THE **SolvePage** / **ChatPage** SHALL 以全屏查看器展示原图，支持双指缩放。

---

### 需求 3：ChatPage 自动解题路由

**用户故事：** 作为学生，我希望在聊天页面发送图片时，AI 能自动识别这是解题请求，走专用解题路径，而不是普通问答。

#### 验收标准

1. WHEN 用户在 **ChatPage** 发送包含图片的消息，THE **ChatPage** SHALL 优先走 CAS `/api/cas/dispatch` 接口，而非普通聊天接口。
2. WHEN CAS 将意图识别为 `solve_problem`，THE **ChatPage** SHALL 以解题气泡样式（区别于普通问答气泡）展示 AI 回复，包含"考点分析 / 解题步骤 / 最终答案"分节结构。
3. WHEN CAS 将意图识别为非 `solve_problem`（如用户发图片问"这是什么"），THE **ChatPage** SHALL 回退到普通问答路径，不触发解题流水线。
4. THE **ChatPage** SHALL 在解题气泡底部提供"收藏到笔记本"和"加入错题本"两个操作按钮，用户点击后弹出确认对话框完成入库。

---

### 需求 4：CAS 意图调度层多模态识别

**用户故事：** 作为系统，我希望 CAS 意图调度层能识别包含图片的解题请求，以便将图文数据完整路由到解题执行器。

#### 验收标准

1. WHEN 用户请求体中包含 `images` 字段（非空列表），THE **IntentMapper** SHALL 将意图识别为 `solve_problem`，置信度不低于 0.85，无需依赖文本关键词。
2. WHEN 意图被识别为 `solve_problem`，THE **DispatchPipeline** SHALL 将 `images`（Base64 列表）和 `supplement_text` 字段完整透传至 **SolveProblemExecutor** 的 `params` 字典。
3. THE **DispatchPipeline** SHALL 扩展 `DispatchIn` 模型，新增可选字段 `images: Optional[list[str]]`（Base64 列表）和 `supplement_text: Optional[str]`。
4. IF `images` 字段存在但 `supplement_text` 字段缺失，THEN THE **DispatchPipeline** SHALL 以空字符串填充 `supplement_text`，不返回参数缺失错误。
5. THE **IntentMapper** 的 RuleMapper 降级路径 SHALL 新增规则：当 `images` 非空时，直接映射为 `solve_problem`，置信度 0.9，不依赖 LLM。

---

### 需求 5：高精度 OCR 预处理

**用户故事：** 作为学生，我希望 AI 能准确识别题目图片中的数学公式和文字，以便解题结果精确。

#### 验收标准

1. WHEN **SolveProblemExecutor** 接收到包含 `images` 的请求，THE **OCRService** SHALL 对每张图片调用硅基流动 PaddleOCR-VL-1.5 模型 API 提取文本，并将多张图片的识别结果按顺序拼接（以 `\n---\n` 分隔）。
2. THE **OCRService** SHALL 在 OCR 提示词中要求模型将数学公式严格以 LaTeX 格式输出（行内用 `$...$`，独立公式用 `$$...$$`），禁止输出任何解答内容。
3. THE **OCRService** SHALL 提供 `extract_text_from_base64(image_b64: str) -> str` 方法，接受单张 Base64 编码图片并返回识别文本。
4. THE **OCRService** SHALL 提供 `extract_text_from_base64_list(images: list[str]) -> str` 方法，接受多张图片并返回拼接后的识别文本。
5. IF PaddleOCR API 调用失败（超时或 HTTP 错误），THEN THE **OCRService** SHALL 降级调用现有 LLM 视觉接口（`chat_with_vision`）进行 OCR，并记录 WARNING 日志。
6. IF PaddleOCR API 和 LLM 视觉接口均失败，THEN THE **OCRService** SHALL 抛出 `RuntimeError`，携带可读的错误描述。
7. FOR ALL 有效的 Base64 图片输入，THE **OCRService** 的 `extract_text_from_base64` 方法 SHALL 返回非空字符串（Round-Trip 属性：图片 → OCR → 文本不为空）。

---

### 需求 6：多模态 Prompt 组装与推理

**用户故事：** 作为学生，我希望 AI 解题时综合考虑图片内容和我的补充说明，以便得到针对性的解答。

#### 验收标准

1. WHEN **SolveProblemExecutor** 完成 OCR 后，THE **SolveProblemExecutor** SHALL 将 OCR 识别文本与 `supplement_text` 组装为统一的解题 Prompt，格式为：
   ```
   【题目图片识别内容】
   {ocr_text}

   【补充说明】
   {supplement_text}
   ```
2. IF `supplement_text` 为空，THEN THE **SolveProblemExecutor** SHALL 省略"补充说明"段落，仅保留"题目图片识别内容"段落。
3. THE **SolveProblemExecutor** SHALL 在系统提示词中要求推理模型强制输出 CoT 思维链，并按以下 Markdown 结构分节：`## 考点分析`、`## 解题步骤`、`## 最终答案`。
4. THE **SolveProblemExecutor** SHALL 调用后端已有的 `LLMService` 进行推理，优先使用 `LLM_HEAVY_MODEL`（如 DeepSeek-R1），不配置时回退到 `LLM_CHAT_MODEL`，不引入新的 LLM 客户端依赖。
5. WHEN 用户在 **SolveSession** 中发起追问，THE **SolveProblemExecutor** SHALL 将原始 OCR 文本和历史对话一并注入上下文，使追问能引用原题内容。

---

### 需求 7：流式输出（SSE）

**用户故事：** 作为学生，我希望解题过程能逐字流式显示，以便实时看到 AI 的推理过程，减少等待焦虑。

#### 验收标准

1. THE **SolveProblemExecutor** SHALL 使用 FastAPI `StreamingResponse` 以 SSE 格式逐 Token 推送解题内容，Content-Type 为 `text/event-stream`。
2. WHEN 流式推送完成，THE **SolveProblemExecutor** SHALL 发送 `data: [DONE]\n\n` 作为结束标志。
3. IF 推理过程中发生异常，THEN THE **SolveProblemExecutor** SHALL 发送 `data: [ERROR] {error_message}\n\n` 并关闭流，不静默丢弃错误。
4. THE **SolvePage** / **ChatPage** SHALL 通过 SSE 客户端接收流式 Token，并实时追加到当前 AI 消息气泡的内容中。
5. WHILE 流式接收进行中，THE **SolvePage** / **ChatPage** SHALL 持续滚动到消息列表底部（除非用户主动上翻）。
6. THE SSE 流 SHALL 在 OCR 完成后立即开始推送推理 Token，OCR 阶段前端仅显示"解题中..."打字指示器，不推送 OCR 中间结果。

---

### 需求 8：CoT 思维链双模式展示

**用户故事：** 作为学生，我希望能选择是否查看 AI 的完整推理过程，以便在需要时深入理解解题思路。

#### 验收标准

1. WHEN 解题结果包含 `<think>...</think>` 块（DeepSeek-R1 等模型的思维链），THE **SolvePage** / **ChatPage** SHALL 默认将思维链内容折叠，仅显示折叠标题"查看推理过程 ▶"。
2. WHEN 用户点击"查看推理过程"，THE **SolvePage** / **ChatPage** SHALL 展开思维链内容，标题变为"收起推理过程 ▼"。
3. THE 思维链展开/折叠状态 SHALL 在同一会话内持久化（用户展开后，追问时不自动重新折叠）。
4. IF 模型未输出 `<think>` 块，THEN THE **SolvePage** / **ChatPage** SHALL 不显示"查看推理过程"入口。

---

### 需求 9：前端 LaTeX 流式断词容错渲染

**用户故事：** 作为学生，我希望流式输出时 LaTeX 公式不会显示乱码，以便阅读体验流畅。

#### 验收标准

1. WHILE 流式接收进行中，THE **MarkdownLatexView** SHALL 检测当前累积文本中是否存在未闭合的 LaTeX 定界符（`$`、`$$`、`\(`、`\[`、`\begin{`）。
2. IF 存在未闭合的 LaTeX 定界符，THEN THE **MarkdownLatexView** SHALL 将该未闭合片段作为普通文本渲染，不触发 `Math.tex()` 解析。
3. WHEN 流式接收完成后，THE **MarkdownLatexView** SHALL 对完整文本重新执行完整的 LaTeX 解析和渲染。
4. FOR ALL 合法的 LaTeX 公式字符串，THE **MarkdownLatexView** 的容错逻辑 SHALL 在流式完成后产生与非流式渲染等价的输出（幂等性属性）。

---

### 需求 10：解题结果手动入库

**用户故事：** 作为学生，我希望能将解题结果手动保存到笔记本或错题本，以便后续复习。

#### 验收标准

1. WHEN 解题流式输出完成，THE **SolvePage** / **ChatPage** SHALL 在解题结果气泡底部显示"收藏到笔记本"和"加入错题本"两个操作按钮。
2. WHEN 用户点击"收藏到笔记本"，THE **SolvePage** / **ChatPage** SHALL 弹出笔记本选择对话框，用户确认后将题目图片、OCR 文本和解题结果保存为一条笔记。
3. WHEN 用户点击"加入错题本"，THE **SolvePage** / **ChatPage** SHALL 弹出确认对话框，用户确认后将题目图片和解题结果保存为一条错题记录。
4. WHEN 入库成功，THE **SolvePage** / **ChatPage** SHALL 以 SnackBar 提示"已保存"，并将对应按钮变为已选中状态（防止重复入库）。
5. IF 入库失败（网络错误等），THEN THE **SolvePage** / **ChatPage** SHALL 以 SnackBar 提示"保存失败，请重试"，按钮恢复可点击状态。

---

### 需求 11：历史遗留 Bug 修复——类型安全解析

**用户故事：** 作为开发者，我希望消除 `type 'String' is not a subtype of type 'int' of 'index'` 异常，以便应用稳定运行。

#### 验收标准

1. THE **ChatProvider**（或相关网络层）SHALL 在解析 Dio `response.data` 前，使用 `is List` 和 `is Map` 进行严格类型判定，不直接强制转型。
2. WHEN FastAPI 返回 HTTP 422 Validation Error 时，THE **ChatProvider** SHALL 识别响应体为 `List` 类型（FastAPI 422 的 `detail` 字段为列表），并将其格式化为可读的错误提示字符串展示给用户。
3. IF `response.data` 既不是 `List` 也不是 `Map`，THEN THE **ChatProvider** SHALL 将其转为字符串后作为错误消息处理，不抛出未捕获异常。
4. FOR ALL 合法的后端响应格式（`Map`、`List`、纯字符串），THE **ChatProvider** 的解析逻辑 SHALL 不抛出 `TypeError` 或 `CastError`（属性：对任意响应格式的类型安全性）。

---

### 需求 12：OCR 服务接口向后兼容

**用户故事：** 作为开发者，我希望 OCR 服务的改造不破坏现有调用方，以便其他功能（如 PDF 解析）继续正常工作。

#### 验收标准

1. THE **OCRService** SHALL 保留现有的 `extract_text(image_path: str) -> str` 和 `extract_text_from_pdf_page(pdf_path: str, page_num: int) -> str` 方法签名不变。
2. THE **OCRService** SHALL 新增 `extract_text_from_base64(image_b64: str) -> str` 和 `extract_text_from_base64_list(images: list[str]) -> str` 方法，供 **SolveProblemExecutor** 调用。
3. FOR ALL 现有调用 `extract_text` 的代码路径，THE **OCRService** 的改造 SHALL 不改变其返回值语义（向后兼容属性）。

---

### 需求 13：解题配置可观测性

**用户故事：** 作为开发者，我希望解题流水线的关键参数可通过环境变量配置，以便在不同环境下调优。

#### 验收标准

1. THE **AppConfig** SHALL 新增以下配置项，均可通过环境变量覆盖：
   - `SOLVE_OCR_TIMEOUT_SECONDS`（默认 15）：OCR API 调用超时
   - `SOLVE_REASONING_MAX_TOKENS`（默认 4096）：解题推理最大 Token 数
   - `SOLVE_MAX_IMAGES`（默认 4）：单次解题最大图片数量
   - `SOLVE_IMAGE_MAX_LONG_EDGE`（默认 1920）：图片压缩长边上限（px）
2. THE **SolveProblemExecutor** SHALL 在每次解题完成后，将 `ocr_duration_ms`、`reasoning_duration_ms`、`image_count`、`token_count` 写入结构化日志（INFO 级别），供后续性能分析。
