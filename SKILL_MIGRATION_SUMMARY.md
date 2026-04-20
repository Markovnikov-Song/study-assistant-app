# Skill 定义迁移总结

## 完成内容

将 `backend/routers/agent.py` 中硬编码的 5 个内置 Skill 定义迁移到 YAML 配置文件，实现提示词与代码分离。

---

## 文件变更

### 新增文件

| 文件 | 说明 |
|------|------|
| `backend/prompts/skills/builtin.yaml` | 5 个内置 Skill 的完整定义（元数据 + promptChain） |
| `backend/skill_registry.py` | SkillRegistry 单例类，从 YAML 加载并提供查询接口 |

### 修改文件

| 文件 | 改动 |
|------|------|
| `backend/routers/agent.py` | 删除 `_BUILTIN_SKILLS` 和 `_SKILL_INDEX` 硬编码，改用 `SkillRegistry` |
| `backend/skill_ecosystem/skill_io.py` | `export_skill` 改为从 `SkillRegistry` 读取 |
| `backend/skill_ecosystem/marketplace_service.py` | `_make_builtin_skills` 改为从 `SkillRegistry` 同步 |
| `backend/tests/test_agent_routes.py` | 测试改用 `SkillRegistry` |
| `backend/tests/test_skill_lifecycle.py` | 测试改用 `SkillRegistry` |

---

## 架构变化

### 迁移前

```
agent.py
  ↓ 硬编码
_BUILTIN_SKILLS = [...]  # 150+ 行 Python dict
_SKILL_INDEX = {...}
```

### 迁移后

```
prompts/skills/builtin.yaml  ← 单一数据源
  ↓ 加载
SkillRegistry (skill_registry.py)
  ↓ 查询
agent.py / skill_io.py / marketplace_service.py / tests
```

---

## SkillRegistry API

```python
from skill_registry import get_registry

registry = get_registry()

# 查询所有 Skill
skills = registry.list_skills()  # -> list[dict]

# 按 ID 获取单个 Skill
skill = registry.get_skill("skill_feynman")  # -> dict | None

# 按标签过滤
skills = registry.filter(tag="理工科")  # -> list[dict]

# 按关键词搜索
skills = registry.filter(keyword="费曼")  # -> list[dict]

# 获取节点定义
node = registry.get_node("skill_feynman", "node_explain")  # -> dict | None

# 生成 LLM 摘要文本（用于 resolve-intent）
summaries = registry.summaries()  # -> str

# 热重载（开发用）
registry.reload()
```

---

## YAML 格式示例

```yaml
skills:
  - id: skill_feynman
    name: 费曼学习法
    description: 用自己的话解释知识点，暴露理解盲区，强化记忆
    tags: [通用, 理解, 记忆]
    requiredComponents: [chat]
    version: "2.0"
    type: builtin
    promptChain:
      - id: node_explain
        prompt: |
          请用最简单的语言解释「{topic}」，假设你在向一个完全不懂的人讲解。

          要求：
          - 不使用专业术语，用日常语言类比
          - 如果涉及公式，先用文字说明含义，再写出公式（LaTeX 格式：行内 $...$）
          - 长度控制在 200 字以内
        inputMapping: {}

      - id: node_identify_gaps
        prompt: |
          根据上面的解释，找出哪些地方解释得不够清楚或有逻辑漏洞。

          请列出：
          1. ⭐ 最关键的理解盲区（1-3个）
          2. 每个盲区具体是什么概念没说清楚
          3. 为什么这个盲区会导致理解偏差
        inputMapping:
          explanation: node_explain.content
```

---

## 优化内容（v2.0）

所有 Skill 的 promptChain 节点提示词都按三个方向优化：

### 1. 精简指令
- 去掉冗余描述，改用动词开头
- 规则用列表而非段落
- 标题用【】分块

### 2. 公式/格式支持
- 所有节点加入 LaTeX 公式支持（行内 `$...$`，块级 `\[...\]`）
- ⭐ 标记重点知识点
- 结构化输出（表格、列表）

### 3. Few-shot 示例
- 复杂输出格式的节点加入示例
- 示例简洁，只展示关键结构

### 对比（费曼学习法第一个节点）

**v1.0（旧版）**：
```
请用最简单的语言解释「{topic}」，假设你在向一个完全不懂的人讲解。
```

**v2.0（新版）**：
```
请用最简单的语言解释「{topic}」，假设你在向一个完全不懂的人讲解。

要求：
- 不使用专业术语，用日常语言类比
- 如果涉及公式，先用文字说明含义，再写出公式（LaTeX 格式：行内 $...$）
- 长度控制在 200 字以内
```

---

## 优势

### 1. 可维护性
- 提示词集中管理，不分散在代码里
- 修改提示词不需要改 Python 代码
- 版本控制更清晰（YAML diff 比 Python dict diff 可读）

### 2. 可扩展性
- 新增 Skill 只需编辑 YAML，不动代码
- 支持热重载（`registry.reload()`），开发时无需重启服务
- 未来可轻松迁移到数据库（SkillRegistry 接口不变）

### 3. 一致性
- 单一数据源，避免多处维护（agent.py、marketplace_service.py 之前各有一份）
- 所有模块通过 SkillRegistry 访问，保证数据一致

### 4. 可读性
- YAML 格式比 Python dict 更适合长文本（多行字符串用 `|`）
- 提示词工程师可以直接编辑 YAML，不需要懂 Python

---

## 向后兼容

- 所有 API 接口不变（`/api/agent/skills`、`/api/agent/resolve-intent` 等）
- 返回的 Skill 数据结构不变（仍是 dict，字段名保持 camelCase）
- 测试全部通过，无破坏性变更

---

## 后续工作

### 短期
- [ ] 添加 YAML schema 验证（启动时检查格式）
- [ ] 添加 Skill 版本管理（支持多版本共存）
- [ ] 支持用户自定义 Skill YAML（放在 `prompts/skills/custom/` 目录）

### 中期
- [ ] 迁移到数据库（PostgreSQL `skills` 表）
- [ ] 实现 Skill 市场的上传/下载/评分
- [ ] 支持 Skill 的 A/B 测试（同一 Skill 多个 prompt 版本）

### 长期
- [ ] 可视化 Skill 编辑器（Web UI）
- [ ] Skill 性能监控（token 消耗、成功率、用户评分）
- [ ] 社区共创提示词库

---

## 关于 Skill 与提示词库的关系

你问得对：**Skill 本质上就是一个结构化的提示词序列**。

区别在于粒度和用途：

| | 提示词库（YAML） | Skill（promptChain） |
|---|---|---|
| **是什么** | 单次 LLM 调用的行为定义 | 多步骤学习流程的编排 |
| **粒度** | 一个 system prompt | 多个 prompt 节点 + 数据流 |
| **用途** | 定义"你是谁、怎么回答" | 定义"先做A，再做B，再做C" |
| **示例** | `qa/rag.yaml` 的 `strict` | `skill_feynman` 的 3 个节点 |

现在两者都是 YAML 管理，统一了提示词工程的工作流：

```
prompts/
  qa/rag.yaml          ← 单次调用的提示词
  mindmap/generate.yaml
  skills/builtin.yaml  ← 多步骤的 Skill 定义
```

未来可以进一步整合：Skill 的节点 prompt 可以引用提示词库的模板，实现复用。
