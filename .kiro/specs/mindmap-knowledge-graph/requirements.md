# Requirements Document

## Introduction

本功能在现有思维导图学习系统（skill_mindmap_learning v3.0）的基础上，新增两项能力：

1. **节点性质颜色渲染**：MindMapPainter 解析节点文本中的 ⭐⚠️🎯📌 前缀，并以对应颜色渲染节点背景，使学习者在浏览思维导图时能直观区分重点、难点、考点与基础知识。

2. **知识关联图**：在 EditableMindMapPage 的「知识关联图」Tab 中，替换现有占位符 `_KnowledgeGraphPlaceholder`，实现基于 LLM 提取的跨节点关联关系可视化图谱，展示因果、依赖、对比、演进四种关系类型，并将关联数据持久化到数据库。

---

## Glossary

- **MindMap_Painter**：`lib/tools/mindmap/mindmap_painter.dart` 中的 `MindMapPainter` 类，负责在 Canvas 上绘制思维导图节点与连线。
- **Knowledge_Graph_View**：替换 `_KnowledgeGraphPlaceholder` 的新 Flutter Widget，负责渲染知识关联图。
- **Knowledge_Graph_Service**：后端 Python 服务，负责调用 LLM 从思维导图 Markdown 中提取跨节点关联关系。
- **Library_Router**：`backend/routers/library.py`，FastAPI 路由模块，挂载在 `/api/library`。
- **Node_Property**：节点文本前缀所表示的知识性质，共四种：⭐ 重点、⚠️ 难点/易错、🎯 考点、📌 基础。
- **Knowledge_Link**：一条跨节点关联记录，包含源节点 ID、目标节点 ID、关联类型（因果/依赖/对比/演进）及依据文本。
- **Session**：`ConversationSession` 数据库记录，`session_type = "mindmap"`，代表一次思维导图学习会话。
- **Node_Id**：节点的唯一字符串标识符，格式为 `L{depth}_{ancestor_path}_{text}`，由后端 `_build_node_tree` 生成。
- **Markmap_Markdown**：以 `#`/`##`/`###`/`####` 标题层级表示的思维导图文本，节点文本可含 ⭐⚠️🎯📌 前缀。
- **LLM_Service**：`backend/services/llm_service.py` 中的 `LLMService`，封装对大语言模型的调用。

---

## Requirements

### Requirement 1：节点性质前缀解析

**User Story:** 作为学习者，我希望思维导图中的节点能根据 ⭐⚠️🎯📌 前缀显示不同颜色，以便在浏览时快速识别重点、难点、考点和基础知识。

#### Acceptance Criteria

1. THE MindMap_Painter SHALL 识别节点文本开头的四种 Node_Property 前缀：⭐（重点）、⚠️（难点/易错）、🎯（考点）、📌（基础）。
2. WHEN 节点文本以 ⭐ 开头，THE MindMap_Painter SHALL 以红色系（`#FFEBEE` 背景 / `#C62828` 文字）渲染该节点。
3. WHEN 节点文本以 ⚠️ 开头，THE MindMap_Painter SHALL 以橙色系（`#FFF3E0` 背景 / `#E65100` 文字）渲染该节点。
4. WHEN 节点文本以 🎯 开头，THE MindMap_Painter SHALL 以紫色系（`#F3E5F5` 背景 / `#6A1B9A` 文字）渲染该节点。
5. WHEN 节点文本以 📌 开头，THE MindMap_Painter SHALL 以绿色系（`#E8F5E9` 背景 / `#2E7D32` 文字）渲染该节点。
6. WHEN 节点同时处于「已点亮」状态（`NodeDisplayState.lit`），THE MindMap_Painter SHALL 优先使用点亮配色（`colorScheme.primary`），忽略 Node_Property 颜色。
7. WHEN 节点同时处于「有讲义」状态，THE MindMap_Painter SHALL 优先使用讲义配色（`#E8F5E9` / `#2E7D32`），忽略 Node_Property 颜色。
8. THE MindMap_Painter SHALL 在节点文本渲染时去除 Node_Property 前缀字符，仅显示前缀之后的文本内容。
9. WHEN 节点文本不含任何 Node_Property 前缀，THE MindMap_Painter SHALL 保持现有默认配色逻辑不变。
10. THE MindMap_Painter SHALL 在节点宽度计算时使用去除前缀后的文本长度，确保节点尺寸不因前缀字符而异常扩大。

---

### Requirement 2：知识关联数据生成接口

**User Story:** 作为学习者，我希望系统能自动分析我的思维导图，提取跨章节概念之间的关联关系，以便我理解知识点之间的内在联系。

#### Acceptance Criteria

1. THE Library_Router SHALL 提供 `POST /api/library/sessions/{session_id}/knowledge-links/generate` 接口，触发对指定 Session 的知识关联提取。
2. WHEN 该接口被调用，THE Knowledge_Graph_Service SHALL 读取该 Session 最新的 Markmap_Markdown 内容作为输入。
3. WHEN Markmap_Markdown 内容为空，THE Library_Router SHALL 返回 HTTP 422 错误，错误信息为「思维导图内容为空，无法生成关联图」。
4. THE Knowledge_Graph_Service SHALL 调用 LLM_Service，基于 Markmap_Markdown 提取跨节点关联关系，每条关联包含：源节点文本、目标节点文本、关联类型（causal / dependency / contrast / evolution）、依据文本（不超过 50 字）。
5. WHEN LLM 返回结果，THE Knowledge_Graph_Service SHALL 将源节点文本和目标节点文本与 Markmap_Markdown 中的实际 Node_Id 进行匹配，生成结构化 Knowledge_Link 列表。
6. WHEN 某节点文本在 Markmap_Markdown 中不存在匹配项，THE Knowledge_Graph_Service SHALL 跳过该条关联，不抛出错误。
7. THE Knowledge_Graph_Service SHALL 生成不少于 3 条、不超过 30 条 Knowledge_Link，确保结果密度适中。
8. WHEN 生成成功，THE Library_Router SHALL 将 Knowledge_Link 列表持久化到数据库，并返回 HTTP 200 及生成的关联条数。
9. IF LLM_Service 调用失败，THEN THE Library_Router SHALL 返回 HTTP 502 错误，错误信息为「AI 服务暂时不可用」。
10. THE Library_Router SHALL 提供 `GET /api/library/sessions/{session_id}/knowledge-links` 接口，返回该 Session 已存储的全部 Knowledge_Link 列表。
11. WHEN 该 Session 尚无 Knowledge_Link 记录，THE Library_Router SHALL 返回空列表（HTTP 200，`[]`）。

---

### Requirement 3：知识关联数据存储

**User Story:** 作为学习者，我希望生成的知识关联数据能被持久化保存，以便下次打开思维导图时无需重新生成。

#### Acceptance Criteria

1. THE System SHALL 在数据库中创建 `mindmap_knowledge_links` 表，字段包含：`id`（主键）、`user_id`（外键 → users）、`session_id`（外键 → conversation_sessions，ON DELETE CASCADE）、`source_node_id`（VARCHAR 512）、`target_node_id`（VARCHAR 512）、`link_type`（VARCHAR 16，枚举：causal / dependency / contrast / evolution）、`rationale`（TEXT）、`created_at`（TIMESTAMP）。
2. THE System SHALL 为 `(user_id, session_id)` 组合建立索引，确保按 Session 查询的性能。
3. WHEN 同一 Session 重新生成知识关联，THE System SHALL 删除该 Session 下该用户的全部旧 Knowledge_Link 记录，再插入新记录（覆盖语义）。
4. WHEN `conversation_sessions` 记录被删除，THE System SHALL 通过 ON DELETE CASCADE 自动删除关联的 `mindmap_knowledge_links` 记录。
5. THE System SHALL 在 `database.py` 的 `Base` 子类中定义 `MindmapKnowledgeLink` ORM 模型，与现有模型风格一致。

---

### Requirement 4：知识关联图 Flutter 视图

**User Story:** 作为学习者，我希望在思维导图页面的「知识关联图」Tab 中看到可交互的关联图谱，以便直观理解跨章节概念的关系。

#### Acceptance Criteria

1. THE Knowledge_Graph_View SHALL 替换 `EditableMindMapPage` 中的 `_KnowledgeGraphPlaceholder`，在「知识关联图」Tab 中渲染真实的关联图谱。
2. WHEN 该 Tab 首次被激活且该 Session 无已存储的 Knowledge_Link，THE Knowledge_Graph_View SHALL 显示「生成知识关联图」按钮，用户点击后触发生成接口。
3. WHEN 生成接口正在请求中，THE Knowledge_Graph_View SHALL 显示加载指示器和「AI 正在分析知识关联…」提示文本。
4. WHEN Knowledge_Link 数据加载完成，THE Knowledge_Graph_View SHALL 以节点-边图形式渲染所有关联，节点为圆形气泡，边为带箭头的曲线。
5. THE Knowledge_Graph_View SHALL 用不同颜色区分四种关联类型的边：因果（causal）红色、依赖（dependency）蓝色、对比（contrast）橙色、演进（evolution）绿色。
6. THE Knowledge_Graph_View SHALL 在图谱右上角显示图例，标注四种关联类型对应的颜色与中文名称（因果、依赖、对比、演进）。
7. WHEN 用户点击某条边，THE Knowledge_Graph_View SHALL 在底部弹出 BottomSheet，显示该 Knowledge_Link 的源节点文本、目标节点文本、关联类型及依据文本。
8. THE Knowledge_Graph_View SHALL 支持双指缩放和单指平移，使用 `InteractiveViewer` 实现。
9. WHEN 该 Session 已有 Knowledge_Link 数据，THE Knowledge_Graph_View SHALL 在 Tab 激活时直接展示已存储的关联图，不自动重新生成。
10. THE Knowledge_Graph_View SHALL 在图谱右下角提供「重新生成」按钮，用户点击后弹出确认对话框，确认后覆盖旧数据并重新渲染。
11. IF 生成接口返回错误，THEN THE Knowledge_Graph_View SHALL 显示错误提示 SnackBar，并恢复「生成知识关联图」按钮状态。

---

### Requirement 5：前端数据层（Provider 与 Service）

**User Story:** 作为开发者，我希望知识关联图的数据获取与状态管理遵循现有 Riverpod + LibraryService 架构，以便与现有代码风格保持一致。

#### Acceptance Criteria

1. THE System SHALL 在 `lib/services/library_service.dart` 中新增 `generateKnowledgeLinks(int sessionId)` 和 `getKnowledgeLinks(int sessionId)` 两个方法，分别调用生成接口和查询接口。
2. THE System SHALL 在 `lib/models/mindmap_library.dart` 中新增 `KnowledgeLink` 数据模型，包含 `sourceNodeId`、`targetNodeId`、`linkType`（枚举）、`rationale` 字段，并实现 `fromJson` 工厂方法。
3. THE System SHALL 在 `lib/providers/library_provider.dart` 中新增 `knowledgeLinksProvider`（`FutureProvider.family<List<KnowledgeLink>, int>`），按 `sessionId` 获取关联数据。
4. WHEN `generateKnowledgeLinks` 调用成功，THE System SHALL 通过 `ref.invalidate(knowledgeLinksProvider(sessionId))` 刷新关联数据缓存。
5. IF 网络请求失败，THEN THE System SHALL 通过 `ApiException` 统一抛出错误，与现有错误处理机制一致。
