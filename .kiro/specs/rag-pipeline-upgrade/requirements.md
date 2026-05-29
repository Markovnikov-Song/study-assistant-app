# 需求文档：RAG 流水线架构升级

## 简介

"伴学"项目当前的 RAG 检索流水线将课本 PDF 作为扁平纯文本处理，导致检索精度低、思维导图层次混乱。本次升级将彻底重构四个核心层：解析层（Parsing）、存储层（Chunking）、检索层（Retrieval）和生成层（Generation），并将新能力封装为 MCP Tools，供大模型自主调用。同时扩展多格式支持（PDF/PPTX/DOCX），允许用户上传多个文件并跨文件检索。

**执行优先级**：优先改造检索层（Rerank 重排机制），再逐步改造解析层、切片层和生成层。

---

## 词汇表

- **RAG_Pipeline**：检索增强生成流水线，位于 `backend/services/rag_pipeline.py`
- **Document_Parser**：文档解析器防腐层，位于 `backend/services/document_parser.py`，通过抽象接口隔离第三方库
- **Embedding_Service**：向量嵌入服务，位于 `backend/services/embedding_service.py`
- **Reranker**：重排序模型（如 BGE-Reranker），对粗筛结果按精确相关度重新排序
- **Chunker**：文本切片器，负责将解析后的文档切分为知识块
- **MCP_Tool**：注册在 `backend/mcp_layer/` 下、可被大模型自主调用的原子能力单元
- **MCP_Registry**：MCP 工具注册表，位于 `backend/mcp_layer/mcp_registry.py`
- **Structured_Markdown**：带有 H1/H2/H3 层级标题、保留表格和 LaTeX 公式的 Markdown 文本
- **Semantic_Chunk**：基于语义边界或 Markdown 标题树切分的知识块，上下文完整不被截断
- **Hierarchical_Outline**：严格层级 JSON 结构，专供思维导图渲染使用
- **Top_K_Recall**：向量检索或 BM25 粗筛阶段召回的候选片段集合（默认 Top-50）
- **Top_N_Rerank**：经 Reranker 精排后喂给 LLM 的最终片段集合（默认 Top-5）
- **Rerank_Threshold**：Reranker 得分阈值，低于此值时触发路由兜底逻辑
- **Fallback_Router**：路由兜底组件，在 Rerank 得分不足时切换至通用知识库或告知用户
- **Heading_Path**：知识块在文档中的层级位置路径，如 `"第三章 > 3.2 牛顿第二定律"`，用于回答时标注来源
- **Multi_File_Subject**：同一学科下用户上传的多个文件（PDF/PPTX/DOCX），统一存入同一向量库，检索时跨文件搜索

---

## 需求

### 需求 1：多格式文档结构化解析（解析层）

**用户故事**：作为学生，我希望上传的课本 PDF、PPT 讲义和 Word 文档都能被准确识别章节层级、表格和公式，以便后续检索和思维导图生成能够利用完整的结构信息。

#### 验收标准

1. WHEN 用户上传 PDF 文件，THE Document_Parser SHALL 调用版面分析引擎（MinerU 或 Marker，通过子进程隔离调用，规避 AGPL/GPL License 传染）将其转换为 Structured_Markdown，保留 H1/H2/H3 标题层级、表格结构（Markdown 表格格式）和数学公式（LaTeX 格式，行内 `$...$`，块级 `$$...$$`）
2. WHEN 用户上传 PPTX 文件，THE Document_Parser SHALL 将每张幻灯片的标题转换为 H2 标题，幻灯片内容转换为正文，幻灯片序号作为 Heading_Path 的一部分（如 `"Slide 3 > 牛顿第二定律"`）
3. WHEN 用户上传 DOCX 文件，THE Document_Parser SHALL 识别 Word 文档的标题样式（Heading 1/2/3），将其转换为对应的 H1/H2/H3 Markdown 标题
4. THE Document_Parser SHALL 支持同一学科下上传多个文件（Multi_File_Subject），每个文件的 Chunk 携带 `filename` 元数据，检索时跨文件搜索，回答时在来源标注中包含文件名
5. IF 版面分析引擎（MinerU/Marker）调用失败，THEN THE Document_Parser SHALL 按降级链依次尝试：MarkItDown（MIT 许可，直接 import）→ 原生库（python-pptx/python-docx/pdfplumber），并在返回结果中附加降级标记 `degraded=True`
6. THE Document_Parser SHALL 将解析结果以 Structured_Markdown 字符串形式返回，不依赖特定存储格式
7. WHEN 解析完成，THE Document_Parser SHALL 在日志中记录文件名、格式、页数/幻灯片数、检测到的标题数量和公式数量
8. THE Document_Parser SHALL 对不支持的文件格式返回明确错误，不静默失败

---

### 需求 2：语义切片（存储层）

**用户故事**：作为学生，我希望课本内容被按语义完整性切分，而不是按固定字符数截断，以便每个知识块都包含完整的上下文。

#### 验收标准

1. THE Chunker SHALL 支持两种切片策略：基于 Markdown 标题树的层级切片（Hierarchical Chunking）和语义切片（Semantic Chunking）
2. WHEN 输入文本为 Structured_Markdown，THE Chunker SHALL 优先使用层级切片策略，按 H1/H2/H3 边界切分
3. WHEN 输入文本不含 Markdown 标题，THE Chunker SHALL 回退至语义切片策略
4. THE Chunker SHALL 确保每个 Semantic_Chunk 的长度不超过配置项 `CHUNK_MAX_TOKENS`（默认 512 tokens）
5. THE Chunker SHALL 确保相邻 Semantic_Chunk 之间存在不少于配置项 `CHUNK_OVERLAP_TOKENS`（默认 64 tokens）的重叠内容，以保留上下文连续性
6. THE Chunker SHALL 在每个 Semantic_Chunk 的元数据中记录其所属的 Heading_Path（如 `"第三章 > 3.2 牛顿第二定律"`）和来源文件名（`filename`）
7. IF 单个标题节点下的内容超过 `CHUNK_MAX_TOKENS`，THEN THE Chunker SHALL 对该节点内容进行二次切片，并在元数据中标注切片序号
8. THE Chunker SHALL 废弃固定长度（Fixed-size）切片逻辑，不再使用按字符数均匀切分的方式

---

### 需求 3：重排序检索（检索层）——优先实现

**用户故事**：作为学生，我希望系统能从课本中找到与我的问题最精确相关的知识片段，并在回答中告知我这个知识点来自哪个章节，而不是仅凭向量相似度返回模糊结果。

#### 验收标准

1. WHEN 用户提交问题且 `subject_id` 有效，THE RAG_Pipeline SHALL 执行两阶段检索：先粗筛再精排
2. THE RAG_Pipeline SHALL 在粗筛阶段使用向量检索（Embedding 相似度）召回 Top-50 候选片段（`RECALL_TOP_K`，默认 50），跨该学科下所有已上传文件搜索
3. THE Reranker SHALL 对粗筛召回的候选片段按问题相关度重新计算精确得分，并按得分降序排列
4. THE RAG_Pipeline SHALL 取 Reranker 输出的前 `RERANK_TOP_N`（默认 5）个片段作为最终上下文喂给 LLM
5. THE RAG_Pipeline SHALL 在 LLM 回答中附带来源标注，格式为 `"来源：{filename} > {heading_path}"`，让用户知道知识点出处
6. IF Reranker 输出的最高得分低于 `RERANK_THRESHOLD`（默认 0.4），THEN THE Fallback_Router SHALL 停止课本检索，切换至通用知识库模式（broad 模式），并在回答中告知用户"课本中未找到相关内容，以下为通用知识"
7. IF Reranker 服务不可用，THEN THE RAG_Pipeline SHALL 降级为仅使用向量检索的 Top-K 结果，并在日志中记录降级事件
8. THE RAG_Pipeline SHALL 在每次检索完成后，将 Reranker 得分最高的片段得分记录到 `RAGResult.top_rerank_score` 字段
9. WHEN Fallback_Router 触发通用知识库切换，THE RAG_Pipeline SHALL 在返回结果中设置 `RAGResult.fallback_triggered = True` 并附加原因说明
10. THE RAG_Pipeline SHALL 保持与现有 `query` 和 `query_stream` 接口的向后兼容性，不改变调用方签名

---

### 需求 4：递归摘要与层级大纲生成（生成层）

**用户故事**：作为学生，我希望系统生成的思维导图能准确反映课本的章节层次，而不是将所有内容平铺在同一层级。

#### 验收标准

1. WHEN 用户请求生成思维导图，THE RAG_Pipeline SHALL 采用递归摘要策略，而非将完整章节文本一次性提交给 LLM
2. THE RAG_Pipeline SHALL 在第一轮调用 LLM 时，仅生成全局一级大纲（根节点及其直接子节点列表）
3. THE RAG_Pipeline SHALL 在后续轮次中，对每个一级子节点递归调用 LLM，生成该节点的二级子节点
4. THE RAG_Pipeline SHALL 将递归生成的结果组装为 Hierarchical_Outline（严格层级 JSON 结构），格式如下：
   ```json
   {
     "title": "章节标题",
     "children": [
       {
         "title": "一级节点",
         "summary": "摘要文本",
         "children": [...]
       }
     ]
   }
   ```
5. THE RAG_Pipeline SHALL 将递归深度限制在配置项 `MINDMAP_MAX_DEPTH`（默认 3 层）以内，防止无限递归
6. IF 某节点的输入文本长度低于 `MINDMAP_LEAF_THRESHOLD`（默认 200 tokens），THEN THE RAG_Pipeline SHALL 将该节点标记为叶节点，不再递归展开
7. THE RAG_Pipeline SHALL 确保 Hierarchical_Outline 中每个节点的 `title` 字段非空且长度不超过 50 个字符

---

### 需求 5：`parse_document_to_markdown` MCP Tool

**用户故事**：作为大模型，我需要一个可调用的工具，将 PDF/PPTX/DOCX 文件转换为带层级的 Markdown 文本，以便在对话中直接处理课本内容。

#### 验收标准

1. THE MCP_Registry SHALL 注册名为 `parse_document_to_markdown` 的 MCP_Tool
2. WHEN `parse_document_to_markdown` 被调用且输入参数 `file_path` 指向有效文件（PDF/PPTX/DOCX），THE MCP_Tool SHALL 返回包含 `markdown_content`、`heading_count`、`formula_count` 和 `degraded` 字段的成功结果
3. IF 输入的 `file_path` 不存在或格式不受支持，THEN THE MCP_Tool SHALL 返回 `success=False` 并附带描述性错误信息
4. THE MCP_Tool SHALL 在 `backend/mcp_layer/server_configs/` 下注册对应的服务器配置

---

### 需求 6：`search_textbook_with_rerank` MCP Tool

**用户故事**：作为大模型，我需要一个可调用的工具，对指定课本执行"向量召回 + 重排序"流水线，以获取最高精度的知识片段及其来源位置。

#### 验收标准

1. THE MCP_Registry SHALL 注册名为 `search_textbook_with_rerank` 的 MCP_Tool
2. WHEN `search_textbook_with_rerank` 被调用，THE MCP_Tool SHALL 接受 `query`（问题文本）和 `subject_id`（课本 ID）作为必填参数
3. WHEN `search_textbook_with_rerank` 被调用，THE MCP_Tool SHALL 执行需求 3 中定义的两阶段检索流程，并返回 Top_N_Rerank 片段列表
4. THE MCP_Tool SHALL 在返回结果中为每个片段包含 `content`、`rerank_score`、`heading_path`、`filename` 和 `chunk_index` 字段
5. IF `subject_id` 对应的向量库不存在，THEN THE MCP_Tool SHALL 返回 `success=False` 并附带错误信息 `"指定课本的向量库不存在"`
6. THE MCP_Tool 的单次调用响应时间 SHALL 不超过 10 秒（含向量检索和 Rerank 耗时）

---

### 需求 7：`generate_hierarchical_outline` MCP Tool

**用户故事**：作为大模型，我需要一个可调用的工具，将长篇章节文档转换为严格层级 JSON 结构，专供思维导图渲染使用。

#### 验收标准

1. THE MCP_Registry SHALL 注册名为 `generate_hierarchical_outline` 的 MCP_Tool
2. WHEN `generate_hierarchical_outline` 被调用，THE MCP_Tool SHALL 接受 `document_text`（章节文本）和可选的 `max_depth`（最大递归深度，默认 3）作为参数
3. WHEN `generate_hierarchical_outline` 被调用，THE MCP_Tool SHALL 返回符合需求 4 中定义的 Hierarchical_Outline JSON 格式的结果
4. THE MCP_Tool SHALL 确保返回的 JSON 结构可被直接解析，不包含多余的 Markdown 代码块包裹
5. IF `document_text` 为空字符串，THEN THE MCP_Tool SHALL 返回 `success=False` 并附带错误信息 `"输入文档文本不能为空"`

---

### 需求 8：`strict_textbook_qa` MCP Tool

**用户故事**：作为大模型，我需要一个附带强力系统提示词约束的专用解疑工具，确保回答严格基于课本参考资料，不引入外部知识，并标注知识点来源章节。

#### 验收标准

1. THE MCP_Registry SHALL 注册名为 `strict_textbook_qa` 的 MCP_Tool
2. WHEN `strict_textbook_qa` 被调用，THE MCP_Tool SHALL 接受 `question`（问题文本）和 `subject_id`（课本 ID）作为必填参数
3. WHEN `strict_textbook_qa` 被调用，THE MCP_Tool SHALL 先执行 `search_textbook_with_rerank` 获取 Top_N_Rerank 片段，再附加严格系统提示词调用 LLM
4. THE MCP_Tool 使用的系统提示词 SHALL 包含明确约束："仅限使用给定参考资料回答，若参考资料中未提及相关内容，则回答'参考资料中未提及此内容'"
5. IF Reranker 最高得分低于 `RERANK_THRESHOLD`，THEN THE MCP_Tool SHALL 直接返回固定回答 `"参考资料中未找到与该问题相关的内容"` 而不调用 LLM
6. THE MCP_Tool SHALL 在返回结果中包含 `answer`、`sources`（含 `filename` 和 `heading_path` 的引用片段列表）和 `rerank_top_score` 字段

---

### 需求 9：配置项管理

**用户故事**：作为后端开发者，我希望所有 RAG 流水线的关键参数都通过统一配置项管理，以便在不修改代码的情况下调整系统行为。

#### 验收标准

1. THE RAG_Pipeline SHALL 从 `config.py` 读取以下配置项，而非硬编码：`RECALL_TOP_K`（粗筛召回数，默认 50）、`RERANK_TOP_N`（精排保留数，默认 5）、`RERANK_THRESHOLD`（重排阈值，默认 0.4）、`RERANK_MODEL`（重排模型名称，默认 `"BAAI/bge-reranker-v2-m3"`）
2. THE RAG_Pipeline SHALL 从 `config.py` 读取以下配置项：`CHUNK_MAX_TOKENS`（默认 512）、`CHUNK_OVERLAP_TOKENS`（默认 64）、`MINDMAP_MAX_DEPTH`（默认 3）、`MINDMAP_LEAF_THRESHOLD`（默认 200）
3. THE RAG_Pipeline SHALL 从 `config.py` 读取 `RERANKER_API_URL`（Reranker 服务地址）、`RERANKER_API_KEY`（Reranker 服务密钥，可为空）和 `DOCUMENT_PARSER_BACKEND`（解析后端，默认 `"mineru"`）
4. IF 配置项缺失，THEN THE RAG_Pipeline SHALL 使用上述默认值，并在启动日志中输出警告信息
