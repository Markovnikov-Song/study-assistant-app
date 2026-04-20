# 提示词迁移指南

## 一、工业落地的提示词长度标准

根据工业实践，提示词长度应遵循以下原则：

### 1. **System Prompt（系统提示词）**
- **简洁型**（50-150 tokens）：适用于明确任务，如 OCR、关键词提取
- **标准型**（150-500 tokens）：适用于大多数场景，如问答、解题、出题
- **详细型**（500-1500 tokens）：适用于复杂任务，如讲义生成、多步骤推理

### 2. **Few-shot Examples（示例）**
- 每个示例 50-200 tokens
- 通常 1-3 个示例即可
- 总长度不超过 system prompt 的 50%

### 3. **总长度控制**
- **轻量任务**：< 500 tokens（如分类、提取）
- **标准任务**：500-1500 tokens（如问答、生成）
- **重型任务**：1500-3000 tokens（如长文档生成、复杂推理）
- **极限**：不超过 4000 tokens（留给 context 和 output）

### 4. **优化原则**
- **精简指令**：用动词开头，避免冗余描述
- **结构化**：用列表、分段，不用长段落
- **具体化**：给出格式示例，不要模糊描述
- **可测试**：每条规则都应可验证

---

## 二、已迁移的提示词清单

### study_assistant_streamlit/prompts/

| 文件路径 | 提示词键 | 用途 | 原位置 |
|---------|---------|------|--------|
| `qa/rag.yaml` | strict, broad, hybrid, hybrid_fallback, solve, title_extraction | RAG 问答 | rag_pipeline.py |
| `mindmap/generate.yaml` | from_material, custom | 思维导图生成 | mindmap_service.py, chat.py |
| `ocr/recognize.yaml` | image, image_simple | OCR 识别 | ocr_service.py, backend/routers/ocr.py |
| `memory/extract.yaml` | extract_and_merge | 用户画像提取 | memory_service.py |
| `exam/generate.yaml` | parse_paper, extract_knowledge, predicted_with_past, predicted_no_past, custom | 出题 | exam_service.py |
| `lecture/generate.yaml` | generate | 讲义生成 | lecture_generator_service.py |
| `notes/manage.yaml` | generate_title, polish | 笔记管理 | backend/routers/notes.py |
| `hints/suggest.yaml` | suggest | 提示词建议 | backend/routers/hints.py |

### backend/prompts/

| 文件路径 | 提示词键 | 用途 | 原位置 |
|---------|---------|------|--------|
| `council/agents.yaml` | principal, advisor, subject_teacher, companion | 多 Agent 议事会 | backend/routers/council.py |
| `agent/skill.yaml` | recommend_skill, execute_node | Skill 推荐与执行 | backend/routers/agent.py |
| `skill/parse.yaml` | parse | Skill 解析 | backend/skill_ecosystem/ai_model_adapter.py |

---

## 三、如何优化提示词

### 1. **思维导图生成优化示例**

**当前版本**（`mindmap/generate.yaml`）：
```yaml
from_material:
  system: |
    你是一个专业的知识结构分析助手。请分析以下学习资料的全部内容，
    提炼所有章节的核心知识点，以 Markdown 标题层级格式输出完整思维导图（markmap 格式）。

    输出要求：
    1. 使用 Markdown 标题语法（# ## ### ####）表示层级
    2. 第一行用 # 作为根节点，内容为学科名称
    3. 二级节点（##）对应每个章节，必须覆盖资料中出现的所有章节
    4. 三级节点（###）对应章节内的核心概念
    5. 四级节点（####）对应具体知识点，最多四级
    6. 每个节点简洁，不超过 15 个字
    7. 只输出 Markdown 内容，不要有任何代码块标记或说明文字
```

**优化版本**（增强理工科支持）：
```yaml
from_material:
  system: |
    你是一个专业的知识结构分析助手。请分析以下学习资料的全部内容，
    提炼所有章节的核心知识点，以 Markdown 标题层级格式输出完整思维导图（markmap 格式）。

    输出要求：
    1. 使用 Markdown 标题语法（# ## ### ####）表示层级
    2. 第一行用 # 作为根节点，内容为学科名称
    3. 二级节点（##）对应每个章节，必须覆盖资料中出现的所有章节
    4. 三级节点（###）对应章节内的核心概念
    5. 四级节点（####）对应具体知识点，最多四级
    6. 每个节点简洁，不超过 15 个字
    7. 关键公式用 LaTeX 内联格式（如 $F=ma$），定理/定义用 **粗体**
    8. 重点/难点节点前加 ⭐ 标记
    9. 只输出 Markdown 内容，不要有任何代码块标记或说明文字

  # Few-shot 示例（可选，提升一致性）
  example: |
    # 材料力学
    ## ⭐ 第1章 绪论
    ### 基本概念
    #### 应力 $\sigma = F/A$
    #### 应变 $\varepsilon = \Delta L / L$
    ### 材料性能
    #### **弹性模量** $E$
    #### 泊松比 $\mu$
    ## 第2章 轴向拉压
    ### 内力与应力
    #### 轴力 $N$
    #### 正应力 $\sigma$
```

### 2. **优化步骤**

#### Step 1: 明确目标
- 当前问题：思维导图对理工科公式支持不足，缺少重点标注
- 优化目标：增加公式渲染、重点标记、示例输出

#### Step 2: 增强指令
- 添加第 7-8 条规则（公式格式、重点标记）
- 添加 `example` 字段（few-shot）

#### Step 3: 测试验证
```python
from services.prompt_manager import PromptManager
pm = PromptManager()

# 测试新提示词
system = pm.get("mindmap/generate.yaml", "from_material")
print(system)

# 可选：加载示例
example = pm.get("mindmap/generate.yaml", "from_material", field="example")
```

#### Step 4: A/B 测试
- 用相同资料生成 10 次，对比新旧版本
- 评估指标：公式覆盖率、重点标注准确率、结构一致性

---

## 四、提示词库与 Skill 的关系

### 1. **层次关系**

```
Skill（业务逻辑层）
  ↓ 调用
Service（服务层）
  ↓ 调用
PromptManager（提示词管理层）
  ↓ 加载
YAML 文件（配置层）
```

### 2. **具体示例**

```python
# Skill 定义（skill_ecosystem/）
skill_feynman = {
    "id": "skill_feynman",
    "name": "费曼学习法",
    "promptChain": [
        {
            "id": "node_explain",
            "prompt": "请用最简单的语言解释「{topic}」",
        }
    ]
}

# Service 调用（services/）
class LectureGeneratorService:
    def generate(self, node_id):
        # 调用 PromptManager 获取提示词
        pm = PromptManager()
        system = pm.get("lecture/generate.yaml", "generate", node_full_path=path)
        # 调用 LLM
        return llm.chat([{"role": "system", "content": system}, ...])

# YAML 配置（prompts/）
# lecture/generate.yaml
generate:
  system: |
    你是一位专业的学科辅导老师...
```

### 3. **Skill 如何调用提示词库**

Skill 不直接调用 PromptManager，而是通过 Service 层间接使用：

```python
# backend/routers/agent.py
@router.post("/execute-node")
def execute_node(body: ExecuteNodeIn):
    # Skill 的 promptChain 中的 prompt 是模板
    prompt_template = body.prompt  # "请用最简单的语言解释「{topic}」"
    
    # 渲染模板
    rendered = prompt_template.format(topic=body.input["topic"])
    
    # 调用 LLM（可选：从 PromptManager 加载 system prompt）
    pm = PromptManager()
    system = pm.get("agent/skill.yaml", "execute_node")
    
    return llm.chat([
        {"role": "system", "content": system},
        {"role": "user", "content": rendered}
    ])
```

---

## 五、后续工作

### 1. **未迁移的硬编码**（需手动处理）

- `backend/routers/chat.py` 第 209-221 行：自定义思维导图生成（已创建 YAML，需替换）
- `backend/routers/hints.py` 第 114-128 行：提示词建议（已创建 YAML，需替换）
- `backend/routers/notes.py` 第 203-204、313-315 行：笔记标题生成和润色（已创建 YAML，需替换）
- `backend/skill_ecosystem/ai_model_adapter.py` 第 52-88 行：Skill 解析（已创建 YAML，需替换）
- `backend/routers/agent.py` 第 220-254、368-379 行：Skill 推荐和执行（已创建 YAML，需替换）
- `backend/routers/council.py` 第 275-476 行：多 Agent 提示词（已创建 YAML，需替换）

### 2. **优化建议**

- 为每个提示词添加 `meta` 字段（name, description, tags, version）
- 建立提示词版本管理（Git + 语义化版本号）
- 添加提示词单元测试（固定输入 → 验证输出格式）
- 建立提示词性能监控（token 消耗、响应时间、成功率）

### 3. **共创提示词库**

参考 `_registry.yaml`，未来可实现：
- 用户上传自定义提示词
- 社区投票评分
- 按学科/场景分类浏览
- 一键导入/导出

---

## 六、使用示例

### 1. **基础用法**

```python
from services.prompt_manager import PromptManager

pm = PromptManager()

# 获取 system prompt
system = pm.get("qa/rag.yaml", "strict")

# 获取 user prompt 并填充变量
user = pm.get("notes/manage.yaml", "generate_title", field="user", content="笔记内容...")

# 调用 LLM
messages = [
    {"role": "system", "content": system},
    {"role": "user", "content": user}
]
```

### 2. **降级处理**

```python
try:
    system = pm.get("mindmap/generate.yaml", "from_material")
except Exception:
    # 降级到硬编码（向后兼容）
    system = "你是一个专业的知识结构分析助手..."
```

### 3. **热重载**

```python
# 开发环境：修改 YAML 后重新加载
pm.reload()
system = pm.get("qa/rag.yaml", "strict")  # 读取最新版本
```

---

## 七、常见问题

### Q1: 提示词太长怎么办？
**A**: 拆分为多个子提示词，按场景组合：
```yaml
base:
  system: |
    你是一个专业的学科辅导助手。

strict_rules:
  system: |
    重要规则：
    1. 只使用上传资料
    2. 必须写出公式

# 使用时组合
system = pm.get("qa/rag.yaml", "base") + "\n" + pm.get("qa/rag.yaml", "strict_rules")
```

### Q2: 如何添加 few-shot 示例？
**A**: 在 YAML 中添加 `example` 字段：
```yaml
generate:
  system: |
    你是一个出题助手...
  example: |
    示例输入：材料力学
    示例输出：
    1. 【选择题】...
```

### Q3: 如何 A/B 测试提示词？
**A**: 创建多个版本，用代码切换：
```yaml
# qa/rag.yaml
strict_v1:
  system: |
    旧版本...

strict_v2:
  system: |
    新版本...
```

```python
version = "v2"  # 从配置读取
system = pm.get("qa/rag.yaml", f"strict_{version}")
```

---

## 八、总结

✅ **已完成**：
- 创建 11 个 YAML 文件，覆盖 30+ 硬编码提示词
- 迁移 `mindmap_service.py`、`ocr_service.py`、`memory_service.py`、`rag_pipeline.py`、`exam_service.py` 部分代码
- 创建 backend 的 `PromptManager`

⏳ **待完成**：
- 迁移剩余 6 个 backend 文件的硬编码
- 添加提示词元数据（meta 字段）
- 建立提示词测试框架

📈 **优化方向**：
- 增加 few-shot 示例
- 添加重点标记（⭐）和公式支持
- 建立提示词版本管理
- 实现共创提示词库 UI
