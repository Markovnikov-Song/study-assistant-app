# 实现计划：RAG 流水线架构升级

## 概述

按照执行优先级逐层改造：检索层（Rerank）→ 解析层（DocumentParser 防腐层）→ 切片层（HierarchicalChunker）→ 生成层（RecursiveSummarizer）→ MCP Tools 封装 → 配置项更新。每层改造均有降级路径，全程保持 `query` / `query_stream` 接口向后兼容。

## 任务

- [x] 1. 新增 RAG 升级配置项
  - 在 `backend/backend_config.py` 的 `AppConfig` dataclass 中追加以下字段（带默认值）：
    - 解析层：`DOCUMENT_PARSER_BACKEND`、`DOCUMENT_PARSER_TIMEOUT_SECONDS`
    - 检索层：`RECALL_TOP_K`、`RERANK_TOP_N`、`RERANK_THRESHOLD`、`RERANK_MODEL`、`RERANKER_MODE`、`RERANKER_API_URL`、`RERANKER_API_KEY`
    - 切片层：`CHUNK_MAX_TOKENS`、`CHUNK_OVERLAP_TOKENS`
    - 生成层：`MINDMAP_MAX_DEPTH`、`MINDMAP_LEAF_THRESHOLD`
  - 在 `get_config()` 工厂函数中用 `os.getenv()` 读取上述字段，缺失时使用设计文档中规定的默认值
  - 在启动日志中输出各配置项的实际值（WARNING 级别）
  - _需求：9.1、9.2、9.3、9.4_

- [x] 2. 实现 RerankService（检索层）
  - [x] 2.1 创建 `backend/services/rerank_service.py`，实现 `RerankResult` dataclass 和 `RerankService` 类
    - `RerankResult` 字段：`index`、`content`、`score`、`heading_path`、`chunk_index`、`filename`
    - `RerankService.__init__`：从配置读取 `RERANKER_MODE`（api | local）
    - `rerank(query, documents, top_n)` 方法：按 score 降序返回 `list[RerankResult]`，`top_n=None` 时返回全部
    - `is_available()` 方法：检查 Reranker 服务是否可用
    - `_rerank_via_api()`：调用 SiliconFlow/Jina 兼容 HTTP API（`RERANKER_API_URL`、`RERANKER_API_KEY`）
    - `_rerank_local()`：通过 `from FlagEmbedding import FlagReranker` 本地推理（MIT 许可，可直接 import）
    - _需求：3.3、3.4、3.7_

  - [ ]* 2.2 为 RerankService 编写属性测试（`backend/tests/test_rerank_service_property.py`）
    - **属性 5：Rerank 输出降序排列**
    - 使用 mock 后端，对任意 query 和 documents，验证 `results[i].score >= results[i+1].score`
    - **验证需求：3.4**
    - `# Feature: rag-pipeline-upgrade, Property 5: Rerank 输出降序排列`

  - [ ]* 2.3 为 RerankService 编写属性测试（续）
    - **属性 6：Rerank 结果数量上限**
    - 对任意 `top_n` 值，验证 `len(results) <= top_n`
    - **验证需求：3.5**
    - `# Feature: rag-pipeline-upgrade, Property 6: Rerank 结果数量上限`

- [x] 3. 改造 RAGPipeline 检索层为两阶段检索
  - [x] 3.1 修改 `backend/services/rag_pipeline.py`：
    - 在 `RAGResult` dataclass 中新增字段：`top_rerank_score: float = 0.0`、`fallback_triggered: bool = False`、`fallback_reason: str = ""`
    - 在 `query()` 方法中将单阶段向量检索替换为两阶段：
      - 阶段 1：`vector_store.similarity_search_with_score(question, k=cfg.RECALL_TOP_K)` 粗筛
      - 阶段 2：调用 `RerankService().rerank(question, doc_texts, top_n=cfg.RERANK_TOP_N)` 精排
      - Reranker 不可用时降级为向量 Top-K，设置 `fallback_triggered=True`
      - 最高 rerank score < `RERANK_THRESHOLD` 时切换 broad 模式，设置 `fallback_triggered=True` 和 `fallback_reason`
    - 在 `query_stream()` 方法中同步应用相同的两阶段检索逻辑
    - 保持 `query` 和 `query_stream` 方法签名不变（向后兼容）
    - _需求：3.1、3.2、3.4、3.6、3.7、3.8、3.9、3.10_

  - [ ]* 3.2 为两阶段检索编写属性测试（`backend/tests/test_rag_pipeline_property.py`）
    - **属性 7：低分触发 Fallback**
    - mock RerankService 返回低分结果，验证 `RAGResult.fallback_triggered == True` 且 `fallback_reason` 非空
    - **验证需求：3.6、3.9**
    - `# Feature: rag-pipeline-upgrade, Property 7: 低分触发 Fallback`

  - [ ]* 3.3 为两阶段检索编写属性测试（续）
    - **属性 8：top_rerank_score 等于最高得分**
    - 对任意 rerank 结果列表，验证 `RAGResult.top_rerank_score == max(r.score for r in results)`
    - **验证需求：3.8**
    - `# Feature: rag-pipeline-upgrade, Property 8: top_rerank_score 等于最高得分`

- [x] 4. 检查点 — 检索层验证
  - 确保所有测试通过，向后兼容性验证：现有 `query` / `query_stream` 调用方无需修改。如有问题请向用户确认。

- [x] 5. 实现 DocumentParser 防腐层（解析层）
  - [x] 5.1 创建 `backend/services/document_parser.py`，实现数据模型和后端协议
    - `ParseResult` dataclass：`markdown`、`heading_count`、`formula_count`、`page_count`、`degraded`、`backend_used`
    - `DocumentParserBackend` Protocol：`parse(file_path) -> ParseResult`、`is_available() -> bool`
    - _需求：1.6_

  - [x] 5.2 实现四个后端类
    - `MinerUBackend`：通过 `subprocess` 调用 `mineru parse --input <file_path> --output-format json`，超时 `DOCUMENT_PARSER_TIMEOUT_SECONDS`，解析 stdout JSON；主进程不 import mineru（AGPL-3.0 隔离）
    - `MarkerBackend`：通过 `subprocess` 调用 marker CLI；主进程不 import marker（GPL-3.0 隔离）
    - `MarkItDownBackend`：直接 `import markitdown`（MIT 许可），解析 PDF/PPTX/DOCX
    - `PdfplumberBackend`：直接 `import pdfplumber`（MIT 许可），作为最终降级后端
    - 每个后端的 `is_available()` 检查 CLI 是否在 PATH 中（subprocess 后端）或包是否可 import（直接后端）
    - _需求：1.1、1.5_

  - [x] 5.3 实现 `DocumentParser` 主类
    - `__init__(backend=None)`：从 `DOCUMENT_PARSER_BACKEND` 配置读取首选后端
    - `parse(file_path)`：按降级链 mineru → marker → markitdown → pdfplumber 依次尝试
    - `_try_backend(backend, file_path)`：尝试单个后端，失败返回 `None`，记录 WARNING 日志
    - 文件不存在时抛出 `FileNotFoundError`；不支持的格式返回明确错误
    - 解析完成后记录文件名、格式、页数、标题数、公式数（INFO 日志）
    - _需求：1.1、1.2、1.3、1.5、1.7、1.8_

  - [ ]* 5.4 为 DocumentParser 编写属性测试（`backend/tests/test_document_parser_property.py`）
    - **属性 1：解析降级保证**
    - mock 所有后端均失败，验证 `parse()` 仍返回 `ParseResult`，且 `degraded=True`，`markdown` 非空
    - **验证需求：1.5**
    - `# Feature: rag-pipeline-upgrade, Property 1: 解析降级保证`

  - [ ]* 5.5 为 DocumentParser 编写属性测试（续）
    - **属性 2：ParseResult 类型不变量**
    - 对任意文件路径输入，验证返回值始终是 `ParseResult` 实例，`markdown` 为 str，`heading_count` 和 `formula_count` 为非负整数
    - **验证需求：1.6**
    - `# Feature: rag-pipeline-upgrade, Property 2: ParseResult 类型不变量`

- [x] 6. 改造 file_parser.py 调用 DocumentParser 防腐层
  - 修改 `backend/services/file_parser.py` 中的 `parse_file()` 函数：
    - 对 PDF/PPTX/DOCX 文件，优先调用 `DocumentParser().parse(tmp_path)` 并返回 `ParseResult.markdown`
    - 对 `.txt` / `.md` 文件，保持原有 `_parse_text()` 逻辑不变
    - 降级时（`ParseResult.degraded=True`）记录 WARNING 日志，但不中断流程
    - 保持 `parse_file(tmp_path, filename) -> str` 签名不变（向后兼容）
  - _需求：1.1、1.2、1.3、1.4、1.5_

- [x] 7. 实现 HierarchicalChunker（切片层）
  - [x] 7.1 创建 `backend/services/chunker.py`，实现数据模型
    - `HeadingNode` dataclass：`level`、`title`、`content`、`heading_path`
    - `Chunk` dataclass：`content`、`heading_path`、`chunk_index`、`filename`、`is_secondary`、`token_count`
    - _需求：2.6_

  - [x] 7.2 实现 `HierarchicalChunker` 类
    - `chunk(markdown, metadata) -> list[Chunk]`：主入口，有标题走层级切片，无标题走语义切片
    - `_extract_heading_tree(markdown) -> list[HeadingNode]`：用正则提取 `# ## ###` 标题，构建标题树，计算 `heading_path`（如 `"第三章 > 3.2 牛顿第二定律"`）
    - `_hierarchical_chunk(nodes, filename) -> list[Chunk]`：按标题边界切分，每个节点为一个 Chunk，超长节点调用 `_secondary_chunk()`
    - `_secondary_chunk(content, heading_path, filename, start_index) -> list[Chunk]`：滑动窗口二次切片，`is_secondary=True`，步长 = `CHUNK_MAX_TOKENS - CHUNK_OVERLAP_TOKENS`
    - `_semantic_chunk(text, filename) -> list[Chunk]`：按句子边界切片，使用 `CHUNK_SIZE` / `CHUNK_OVERLAP` 配置
    - token 估算：`len(text) // 4`（简单估算，无需 tokenizer 依赖）
    - 废弃固定字符数切片逻辑
    - _需求：2.1、2.2、2.3、2.4、2.5、2.6、2.7、2.8_

  - [ ]* 7.3 为 HierarchicalChunker 编写属性测试（`backend/tests/test_chunker_property.py`）
    - **属性 3：Chunk 大小上限不变量**
    - 对任意 markdown 文本和任意 `max_tokens` 值，验证所有 Chunk 的 `token_count <= max_tokens`
    - **验证需求：2.4、2.7**
    - `# Feature: rag-pipeline-upgrade, Property 3: Chunk 大小上限不变量`

  - [ ]* 7.4 为 HierarchicalChunker 编写属性测试（续）
    - **属性 4：层级切片携带标题路径**
    - 对任意包含 H1/H2/H3 标题的 Markdown 文本，验证所有 Chunk 的 `heading_path` 为非空字符串
    - **验证需求：2.2、2.6**
    - `# Feature: rag-pipeline-upgrade, Property 4: 层级切片携带标题路径`

- [x] 8. 检查点 — 解析层与切片层验证
  - 确保所有测试通过，验证 `file_parser.py` 向后兼容性（现有上传流程不受影响）。如有问题请向用户确认。

- [x] 9. 实现 RecursiveSummarizer（生成层）
  - [x] 9.1 创建 `backend/services/recursive_summarizer.py`，实现 `HierarchicalOutline` dataclass
    - 字段：`title: str`、`summary: str = ""`、`children: list[HierarchicalOutline] = field(default_factory=list)`
    - 方法：`to_dict() -> dict`（递归序列化，包含 `title`、`summary`、`children`）
    - 方法：`depth() -> int`（递归计算最大嵌套深度）
    - 方法：`all_nodes() -> list[HierarchicalOutline]`（递归遍历所有节点）
    - _需求：4.4_

  - [x] 9.2 实现 `RecursiveSummarizer` 类
    - `async generate_outline(document_text, max_depth=3) -> HierarchicalOutline`：主入口
    - `async _generate_root(document_text) -> HierarchicalOutline`：第一轮 LLM 调用，生成根节点 + 一级子节点列表（JSON 格式）
    - `async _expand_node(node, section_text, current_depth, max_depth) -> None`：递归展开单个节点，原地修改 `node.children`
    - 深度限制：`current_depth >= max_depth` 时停止递归
    - 叶节点判断：`token_count(section_text) < MINDMAP_LEAF_THRESHOLD` 时停止递归
    - LLM 返回非法 JSON 时重试一次，失败则返回空 children（WARNING 日志）
    - `title` 超过 50 字符时截断（WARNING 日志）
    - _需求：4.1、4.2、4.3、4.5、4.6、4.7_

  - [ ]* 9.3 为 RecursiveSummarizer 编写属性测试（`backend/tests/test_recursive_summarizer_property.py`）
    - **属性 9：大纲深度不超过上限**
    - mock LLM 调用，对任意 `max_depth` 值，验证 `outline.depth() <= max_depth`
    - **验证需求：4.5**
    - `# Feature: rag-pipeline-upgrade, Property 9: 大纲深度不超过上限`

  - [ ]* 9.4 为 RecursiveSummarizer 编写属性测试（续）
    - **属性 10：大纲节点标题合法性**
    - 对任意生成的 `HierarchicalOutline`，验证所有节点 `title` 非空且 `len(title) <= 50`
    - **验证需求：4.7**
    - `# Feature: rag-pipeline-upgrade, Property 10: 大纲节点标题合法性`

  - [ ]* 9.5 为 RecursiveSummarizer 编写属性测试（续）
    - **属性 11：HierarchicalOutline 序列化往返**
    - 对任意 `HierarchicalOutline` 实例，验证 `to_dict()` 可被 `json.dumps()` 序列化，且包含 `title` 和 `children` 字段
    - **验证需求：4.4、7.4**
    - `# Feature: rag-pipeline-upgrade, Property 11: HierarchicalOutline 序列化往返`

- [x] 10. 实现 MCP Tools 封装
  - [x] 10.1 创建 `backend/mcp_layer/server_configs/rag_tools_server.py`，注册四个 RAG MCP Tool
    - 使用 `MCPToolDef.create()` 工厂方法注册以下工具：
      - `parse_document_to_markdown`：参数 `file_path: str`；成功返回 `markdown_content`、`heading_count`、`formula_count`、`degraded`；失败返回 `success=False` + 错误信息
      - `search_textbook_with_rerank`：参数 `query: str`、`subject_id: int`；成功返回 `results[{content, rerank_score, heading_path, filename, chunk_index}]`；失败返回 `success=False` + 错误信息
      - `generate_hierarchical_outline`：参数 `document_text: str`、`max_depth: int = 3`；成功返回 `outline`（Hierarchical_Outline JSON）；失败返回 `success=False` + 错误信息
      - `strict_textbook_qa`：参数 `question: str`、`subject_id: int`；成功返回 `answer`、`sources`、`rerank_top_score`；失败返回 `success=False` + 错误信息
    - 定义 `RAG_TOOLS_SERVER_CONFIG`（`MCPServerConfig`，`type=MCPServerType.local`）
    - _需求：5.1、5.4、6.1、6.2、6.3、6.4、7.1、7.2、7.3、7.4、8.1、8.2、8.3_

  - [x] 10.2 实现四个 MCP Tool 的处理函数
    - `handle_parse_document_to_markdown(file_path)`：调用 `DocumentParser().parse()`，文件不存在或格式不支持时返回 `MCPToolResult(success=False)`
    - `handle_search_textbook_with_rerank(query, subject_id)`：执行两阶段检索（`RAGPipeline` + `RerankService`），`subject_id` 对应向量库不存在时返回 `success=False`，响应时间不超过 10 秒
    - `handle_generate_hierarchical_outline(document_text, max_depth)`：调用 `RecursiveSummarizer().generate_outline()`，`document_text` 为空时返回 `success=False` + `"输入文档文本不能为空"`
    - `handle_strict_textbook_qa(question, subject_id)`：先执行 `search_textbook_with_rerank`，再附加严格系统提示词调用 LLM；rerank 最高分 < `RERANK_THRESHOLD` 时直接返回固定回答，不调用 LLM
    - 所有 Tool 遵循统一错误返回格式：`MCPToolResult(success=False, error_message="...")`
    - _需求：5.2、5.3、6.2、6.3、6.4、6.5、7.3、7.4、7.5、8.3、8.4、8.5、8.6_

  - [ ]* 10.3 为 MCP Tools 编写单元测试（`backend/tests/test_rag_tools_server.py`）
    - 测试四个 Tool 的成功路径和失败路径（mock 底层服务）
    - 验证 `parse_document_to_markdown` 在文件不存在时返回 `success=False`
    - 验证 `generate_hierarchical_outline` 在 `document_text` 为空时返回 `success=False`
    - 验证 `strict_textbook_qa` 在低分时不调用 LLM
    - _需求：5.3、6.5、7.5、8.5_

- [x] 11. 最终检查点 — 全链路验证
  - 确保所有测试通过（单元测试 + 属性测试）
  - 验证 `query` 和 `query_stream` 接口向后兼容性：现有调用方签名不变
  - 验证四个 MCP Tool 均已注册（可通过 `MCPRegistry.list_tools()` 枚举）
  - 验证每个 Chunk 携带 `heading_path` 和 `filename` 元数据
  - 如有问题请向用户确认。

## 备注

- 标有 `*` 的子任务为可选测试任务，可在 MVP 阶段跳过
- MinerU（AGPL）和 Marker（GPL）**必须**通过 subprocess 子进程调用，主进程不得直接 import
- BGE-Reranker（MIT）可直接 `from FlagEmbedding import FlagReranker` 导入
- 所有属性测试使用 Hypothesis，配置 `@settings(max_examples=100, deadline=None)`
- 每个属性测试注释格式：`# Feature: rag-pipeline-upgrade, Property {N}: {属性名}`
- token 估算统一使用 `len(text) // 4`，无需引入 tokenizer 依赖
