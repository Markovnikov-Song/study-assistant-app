# 需求文档

## 简介

本文档描述"伴学"项目解题模块（SolvePage）的三项增强功能：

1. **解题历史记录**：将纯内存的解题会话持久化到数据库，支持历史查看、恢复与删除。
2. **Python 计算引擎（MCP 工具）**：通过 MCP function calling 将精确数值计算卸载到后端 Python 沙箱，提升解题准确性。
3. **图像预处理优化（OpenCV 五步流水线）**：在 OCR 之前对题目图片进行语义无损的五步预处理——EXIF 方向矫正、2D 倾斜矫正（Canny + 霍夫变换）、Retinex 光照均衡 + CLAHE 对比度增强、NLM 去噪 + Unsharp Mask 锐化、摩尔纹去除（傅里叶滤波）——将手机拍摄的模糊、倾斜、光照不均的题目照片转化为 AI 可精准理解的标准文档图像。

三项功能共同作用于现有的多模态解题流水线，在不破坏现有接口的前提下渐进增强。

---

## 词汇表

- **SolvePage**：Flutter 端解题专页，用户在此拍照上传题目并获取 AI 解题结果。
- **SolveSession**：一次完整的解题会话，包含一张或多张题目图片及后续追问的全部消息。
- **SolveProblemExecutor**：后端解题执行器（`backend/cas/executors/solve_problem.py`），负责 OCR + 推理 + SSE 推送。
- **ConversationSession**：数据库中的会话记录表（`conversation_sessions`），通过 `session_type='solve'` 标识解题会话。
- **ConversationHistory**：数据库中的消息记录表（`conversation_history`），存储每轮对话的角色、内容和附件。
- **Python_Executor**：新建的 MCP 工具，在受限沙箱中执行 Python 代码并返回计算结果。
- **Image_Preprocessor**：新建的后端图像预处理服务（`backend/services/image_preprocessor.py`），在 OCR 前对图片进行增强处理。
- **MCP_Registry**：现有 MCP 工具注册表（`backend/mcp_layer/mcp_registry.py`），管理所有 MCP 工具的注册与调用。
- **OCRService**：现有 OCR 服务（`backend/services/ocr_service.py`），负责从 Base64 图片中提取文字。
- **CLAHE**：限制对比度自适应直方图均衡化（Contrast Limited Adaptive Histogram Equalization），用于增强低光照图片对比度。
- **EXIF**：图片文件中存储的元数据，包含拍摄方向等信息。
- **Retinex**：基于人眼视觉模型的光照分量剥离算法，分离光照与反射分量，解决光照不均问题。
- **NLM**：非局部均值去噪（Non-Local Means Denoising），在去除噪点的同时保留文字边缘细节。
- **Unsharp Mask**：反锐化掩码锐化算法，通过叠加高频细节增强文字和公式符号的边缘对比度。
- **霍夫变换**：用于检测图像中直线的经典算法，本项目用于计算图片倾斜角度。
- **摩尔纹**：拍摄屏幕题目时出现的周期性干扰条纹，通过傅里叶频域滤波去除。

---

## 需求

### 需求 1：解题会话持久化

**用户故事：** 作为学生，我希望解题记录能自动保存，以便退出页面后仍能查看历史解题过程和结果。

#### 验收标准

1. WHEN 用户发起首次解题请求，THE SolveProblemExecutor SHALL 在 `conversation_sessions` 表中创建一条 `session_type='solve'` 的记录，并将生成的 `session_id` 返回给前端。

2. WHEN 用户在同一解题会话中发起追问，THE SolveProblemExecutor SHALL 复用已有的 `conversation_sessions` 记录，不创建新记录。

3. WHEN 解题流式响应完成（收到 `[DONE]` 信号），THE SolveProblemExecutor SHALL 将本轮用户消息和 AI 回复分别写入 `conversation_history` 表，`role` 字段分别为 `'user'` 和 `'assistant'`。

4. WHEN 用户消息包含图片，THE SolveProblemExecutor SHALL 将图片的 Base64 数据以 `{"images": ["<base64_1>", ...]}` 格式存入对应 `conversation_history` 记录的 `sources` 字段（JSONB）。

5. WHEN 解题流式响应中途发生错误（收到 `[ERROR]` 信号），THE SolveProblemExecutor SHALL 跳过本轮消息的数据库写入，不写入不完整的 AI 回复。

6. THE SolveProblemExecutor SHALL 在数据库写入失败时记录错误日志，并继续正常返回 SSE 响应，不因持久化失败而中断解题流程。

---

### 需求 2：解题历史列表展示

**用户故事：** 作为学生，我希望在解题页顶部能看到历史解题记录入口，以便快速找到之前解过的题目。

#### 验收标准

1. THE SolvePage SHALL 在页面顶部提供"历史记录"入口按钮，点击后展示当前用户的历史解题会话列表。

2. WHEN 用户打开历史记录列表，THE SolvePage SHALL 从后端获取当前用户所有 `session_type='solve'` 的 `conversation_sessions` 记录，按 `created_at` 降序排列。

3. THE SolvePage SHALL 在历史记录列表中为每条会话展示：会话标题（取自 `conversation_sessions.title`）、创建时间、以及首条用户消息中的第一张图片缩略图（若存在）。

4. IF 历史记录列表为空，THEN THE SolvePage SHALL 展示"暂无历史记录"的空状态提示。

5. THE SolvePage SHALL 支持对历史记录列表进行下拉刷新，刷新后重新从后端获取最新数据。

---

### 需求 3：历史解题会话恢复

**用户故事：** 作为学生，我希望点击历史记录后能完整恢复当时的解题对话，包括题目图片和解题步骤。

#### 验收标准

1. WHEN 用户点击历史记录列表中的某条会话，THE SolvePage SHALL 从后端加载该会话的全部 `conversation_history` 记录，并在解题对话区域完整还原对话内容。

2. WHEN 恢复历史会话时，THE SolvePage SHALL 从 `conversation_history.sources` 字段中读取图片 Base64 数据，并以缩略图形式展示在对应的用户消息气泡中。

3. WHEN 历史会话恢复完成，THE SolvePage SHALL 允许用户在已恢复的会话上继续发起追问，追问消息写入同一 `conversation_sessions` 记录。

4. IF 历史会话数据加载失败，THEN THE SolvePage SHALL 展示错误提示，并提供重试按钮。

---

### 需求 4：历史解题会话删除

**用户故事：** 作为学生，我希望能删除不需要的历史解题记录，以保持列表整洁。

#### 验收标准

1. THE SolvePage SHALL 在历史记录列表的每条会话上提供删除操作入口（如长按或滑动删除）。

2. WHEN 用户确认删除某条历史会话，THE SolvePage SHALL 调用后端接口删除对应的 `conversation_sessions` 记录，级联删除所有关联的 `conversation_history` 记录。

3. WHEN 删除操作成功，THE SolvePage SHALL 从列表中移除该条目，并展示操作成功的反馈提示。

4. IF 删除操作失败，THEN THE SolvePage SHALL 展示错误提示，列表保持原状。

---

### 需求 5：Python 计算引擎 MCP 工具注册

**用户故事：** 作为系统，我希望有一个安全的 Python 代码执行工具，以便 AI 解题时能将精确数值计算卸载到后端执行。

#### 验收标准

1. THE MCP_Registry SHALL 注册名为 `python_executor` 的 MCP 工具，工具描述说明其用途为在受限沙箱中执行 Python 代码进行精确数值计算。

2. THE Python_Executor SHALL 接受以下输入参数：`code`（字符串，待执行的 Python 代码）。

3. WHEN `python_executor` 工具被调用，THE Python_Executor SHALL 在隔离的执行环境中运行代码，执行结果以 `{"stdout": "<标准输出>", "stderr": "<错误输出>", "image_base64": "<PNG图表Base64或null>"}` 格式返回。

4. THE Python_Executor SHALL 支持在代码中使用以下科学计算库：`sympy`（符号计算）、`numpy`（数值计算）、`scipy`（科学计算）、`matplotlib`（图表生成）。

5. WHEN 代码中使用 `matplotlib` 生成图表，THE Python_Executor SHALL 将图表渲染为 PNG 格式并以 Base64 编码后填入返回结果的 `image_base64` 字段；若无图表生成，该字段值为 `null`。

6. THE Python_Executor SHALL 在代码执行超时 10 秒时强制终止执行，并在 `stderr` 字段返回超时错误信息。

---

### 需求 6：Python 计算引擎安全限制

**用户故事：** 作为系统管理员，我希望 Python 沙箱有严格的安全限制，以防止恶意代码访问文件系统或网络。

#### 验收标准

1. THE Python_Executor SHALL 禁止在执行代码中导入 `os`、`sys`、`subprocess` 模块，IF 代码尝试导入上述模块，THEN THE Python_Executor SHALL 在 `stderr` 字段返回禁止导入的错误信息，不执行该代码。

2. THE Python_Executor SHALL 禁止代码执行期间的文件系统写入操作；IF 代码尝试写入文件，THEN THE Python_Executor SHALL 在 `stderr` 字段返回权限拒绝错误。

3. THE Python_Executor SHALL 禁止代码执行期间的网络访问；IF 代码尝试建立网络连接，THEN THE Python_Executor SHALL 在 `stderr` 字段返回网络访问被禁止的错误信息。

4. THE Python_Executor SHALL 将单次代码执行的内存使用限制在 256MB 以内；IF 代码执行超出内存限制，THEN THE Python_Executor SHALL 强制终止执行并在 `stderr` 字段返回内存超限错误。

---

### 需求 7：解题执行器集成 Python 计算工具

**用户故事：** 作为学生，我希望 AI 解题时能自动调用精确计算工具，以减少数值计算错误。

#### 验收标准

1. THE SolveProblemExecutor SHALL 在系统提示词中告知 AI 可以调用 `python_executor` 工具进行精确数值计算，并说明调用格式和适用场景（如积分、方程求解、矩阵运算等）。

2. WHEN AI 在解题过程中通过 function calling 调用 `python_executor`，THE SolveProblemExecutor SHALL 通过 MCP_Registry 执行该工具调用，并将执行结果注入后续推理上下文。

3. WHEN `python_executor` 返回 `image_base64` 不为 `null`，THE SolveProblemExecutor SHALL 在 SSE 流中推送一条 `{"content": "[CHART]", "image_base64": "<base64>"}` 格式的特殊事件。

4. IF `python_executor` 工具调用失败或超时，THEN THE SolveProblemExecutor SHALL 在系统提示词中注入错误信息，提示 AI 改用纯文字推理方式继续解题，不中断解题流程。

---

### 需求 8：前端展示 Python 计算图表

**用户故事：** 作为学生，我希望解题结果中的 matplotlib 图表能直接内嵌显示，以便直观理解计算结果。

#### 验收标准

1. WHEN SolvePage 收到 SSE 流中的 `[CHART]` 事件，THE SolvePage SHALL 将 `image_base64` 字段解码并以 `Image.memory` 组件渲染，内嵌在当前解题消息气泡中。

2. THE SolvePage SHALL 支持对内嵌图表进行点击放大查看（全屏预览）。

3. IF `image_base64` 数据解码失败，THEN THE SolvePage SHALL 展示图表加载失败的占位提示，不影响其余解题文字内容的显示。

---

### 需求 9：图像预处理服务（OpenCV 五步流水线）

**用户故事：** 作为系统，我希望在 OCR 之前对题目图片进行语义无损的预处理，将手机拍摄的模糊、倾斜、光照不均的题目照片转化为 AI 可精准理解的标准文档图像，提升识别率。

**设计原则：** 语义绝对保真——所有处理步骤只增强图像可读性，绝不修改公式结构、文字内容、几何图形的语义信息。

#### 验收标准

**步骤一：EXIF 方向矫正**

1. WHEN 图片包含 EXIF 方向标签（Orientation tag），THE Image_Preprocessor SHALL 使用 `Pillow` 读取 EXIF 信息，按照标准 EXIF 方向映射表将图片旋转/翻转到正向（0°），再执行后续步骤。
2. WHEN 图片不含 EXIF 信息或方向标签值为 1（正向），THE Image_Preprocessor SHALL 跳过旋转步骤，直接执行后续步骤。
3. THE Image_Preprocessor SHALL 在 EXIF 矫正后丢弃原始 EXIF 方向标签，避免后续处理重复旋转。

**步骤二：2D 倾斜矫正（Canny + 霍夫变换）**

4. THE Image_Preprocessor SHALL 将图片转为灰度图，使用 Canny 边缘检测提取文本行/纸张边缘，再通过概率霍夫直线变换（`cv2.HoughLinesP`）检测主要直线方向。
5. THE Image_Preprocessor SHALL 计算检测到的直线与水平方向的夹角中位数，作为图片倾斜角度；WHEN 倾斜角度绝对值在 0.5° 到 15° 之间，THE Image_Preprocessor SHALL 通过仿射变换（`cv2.warpAffine`）将图片旋转矫正到水平，旋转中心为图片中心，边缘填充白色（255）。
6. WHEN 倾斜角度绝对值小于 0.5°（视为无倾斜）或大于 15°（可能是竖排文字或特殊版式），THE Image_Preprocessor SHALL 跳过倾斜矫正步骤，不做旋转处理。

**步骤三：Retinex 光照均衡 + CLAHE 对比度增强**

7. THE Image_Preprocessor SHALL 先对图片执行单尺度 Retinex（SSR）光照分量剥离：将图片转为对数域，用高斯模糊（sigma=80）估计光照分量，从原图中减去光照分量，还原纸张和文字的原始反射信息，解决半边亮半边暗、局部阴影问题。
8. THE Image_Preprocessor SHALL 在 Retinex 处理后，对图片的亮度通道（LAB 色彩空间的 L 通道）执行 CLAHE 自适应对比度增强，`clipLimit` 默认为 2.0，`tileGridSize` 默认为 (8, 8)，增强局部对比度同时避免放大噪点。
9. WHEN 图片整体亮度均匀（标准差 < 20），THE Image_Preprocessor SHALL 跳过 Retinex 步骤，仅执行 CLAHE 增强，避免对已均匀图片过度处理。

**步骤四：NLM 去噪 + Unsharp Mask 锐化**

10. THE Image_Preprocessor SHALL 使用非局部均值去噪（`cv2.fastNlMeansDenoising`，`h=10`，`templateWindowSize=7`，`searchWindowSize=21`）替代高斯滤波，在去除手机拍照噪点的同时完整保留文字、公式符号的边缘细节，避免笔画糊化。
11. THE Image_Preprocessor SHALL 在去噪后执行 Unsharp Mask 锐化：用高斯模糊（sigma=1.0）生成模糊版本，计算原图与模糊版本的差值（锐化掩码），将锐化掩码以权重 1.5 叠加回原图，强化文字和公式符号的边缘对比度。
12. WHEN 图片清晰度评分（拉普拉斯方差）高于阈值 500，THE Image_Preprocessor SHALL 跳过去噪步骤，仅执行 Unsharp Mask 锐化，避免对清晰图片过度去噪导致细节损失。

**步骤五：摩尔纹检测与去除（傅里叶滤波）**

13. THE Image_Preprocessor SHALL 对图片执行摩尔纹检测：将灰度图转换到频域（`np.fft.fft2`），检测频谱中是否存在周期性高频峰值（排除直流分量后，峰值能量占比 > 5% 视为存在摩尔纹）。
14. WHEN 检测到摩尔纹，THE Image_Preprocessor SHALL 在频域中构建陷波滤波器，过滤掉摩尔纹对应的周期性高频分量，再通过逆傅里叶变换（`np.fft.ifft2`）还原到空间域，完整保留文字边缘。
15. WHEN 未检测到摩尔纹，THE Image_Preprocessor SHALL 跳过此步骤，不做频域处理。

**通用要求**

16. THE Image_Preprocessor SHALL 将预处理后的图片重新编码为 JPEG 格式（质量 90）的 Base64 字符串作为处理结果返回；编码质量不低于原始输入质量，避免二次压缩损失。
17. IF 任意预处理步骤发生异常，THEN THE Image_Preprocessor SHALL 记录包含步骤名称和异常信息的 WARNING 日志，跳过该步骤继续执行后续步骤；IF 所有步骤均失败，THEN THE Image_Preprocessor SHALL 返回原始 Base64 图片，不中断 OCR 流程。
18. THE Image_Preprocessor SHALL 在完成全部步骤后，记录结构化性能日志，包含：各步骤耗时（ms）、是否跳过、输入/输出图片尺寸、总耗时。
19. FOR ALL 输入图片，THE Image_Preprocessor 的预处理结果 SHALL 保持原始图片的宽高比不变（等比缩放属性）。

---

### 需求 10：图像预处理集成到 OCR 流水线

**用户故事：** 作为系统，我希望图像预处理能透明地集成到现有 OCR 流程中，支持通过配置开关控制，并能对各步骤效果进行独立调优。

#### 验收标准

1. WHEN `SOLVE_IMAGE_PREPROCESS_ENABLED` 配置项为 `True`，THE OCRService SHALL 在调用视觉 API 之前，先将每张图片传入 Image_Preprocessor 进行五步预处理，使用预处理后的图片执行 OCR。

2. WHEN `SOLVE_IMAGE_PREPROCESS_ENABLED` 配置项为 `False`，THE OCRService SHALL 跳过图像预处理步骤，直接使用原始图片执行 OCR，行为与现有版本完全一致（向后兼容）。

3. THE Image_Preprocessor SHALL 支持通过以下环境变量独立控制各步骤的开关，默认均为 `True`：
   - `PREPROCESS_EXIF_CORRECT`：EXIF 方向矫正
   - `PREPROCESS_DESKEW`：2D 倾斜矫正
   - `PREPROCESS_RETINEX_CLAHE`：Retinex + CLAHE 光照增强
   - `PREPROCESS_NLM_SHARPEN`：NLM 去噪 + Unsharp Mask 锐化
   - `PREPROCESS_MOIRE_REMOVE`：摩尔纹去除

4. IF Image_Preprocessor 处理失败并降级返回原始图片，THEN THE OCRService SHALL 使用原始图片继续执行 OCR，在日志中记录 `preprocess_degraded=True` 事件，不向用户暴露预处理失败信息。

5. THE Image_Preprocessor SHALL 在处理完成后记录结构化性能日志（各步骤耗时、是否跳过、总耗时），供后续性能分析和调优使用。

6. THE Image_Preprocessor 的依赖库 SHALL 限定为：`opencv-python-headless`、`Pillow`、`numpy`，不引入需要 GPU 的深度学习框架，确保在标准 CPU 环境下可运行。

---

### 需求 11：解题会话标题自动生成

**用户故事：** 作为学生，我希望历史记录中的每条解题会话有一个有意义的标题，以便快速识别题目内容。

#### 验收标准

1. WHEN 解题会话首次创建时，THE SolveProblemExecutor SHALL 根据 OCR 识别文本的前 15 个字符自动生成会话标题，并写入 `conversation_sessions.title` 字段。

2. WHEN OCR 识别文本为空（如纯图片无文字），THE SolveProblemExecutor SHALL 使用"解题记录 {创建时间 MM-DD HH:mm}"格式作为会话标题。

3. THE SolveProblemExecutor SHALL 在会话标题超过 15 个字符时截断并追加"…"，确保标题长度不超过 16 个字符。

---

### 需求 12：后端解题历史 API

**用户故事：** 作为前端，我需要后端提供标准的 REST API 来管理解题历史，以支持列表查询、详情加载和删除操作。

#### 验收标准

1. THE 后端 SHALL 提供 `GET /api/solve/sessions` 接口，返回当前用户所有 `session_type='solve'` 的会话列表，每条记录包含 `id`、`title`、`created_at` 和首条用户消息的第一张图片缩略图 Base64（字段名 `thumbnail`）。

2. THE 后端 SHALL 提供 `GET /api/solve/sessions/{session_id}` 接口，返回指定会话的完整 `conversation_history` 记录列表，每条记录包含 `id`、`role`、`content`、`sources`、`created_at`。

3. THE 后端 SHALL 提供 `DELETE /api/solve/sessions/{session_id}` 接口，删除指定会话及其所有关联的历史消息记录。

4. WHEN 请求的 `session_id` 不属于当前用户，THE 后端 SHALL 返回 HTTP 403 状态码，不执行删除操作。

5. THE 后端 SHALL 对所有解题历史 API 进行身份验证，WHEN 请求未携带有效 JWT Token，THE 后端 SHALL 返回 HTTP 401 状态码。

6. FOR ALL 解题历史 API 请求，THE 后端 SHALL 在响应时间超过 2 秒时记录慢查询日志。
