# 软件工坊积木系统设计

## 设计目标

软件工坊的积木系统参考 Scratch 的底层逻辑，但服务对象不是角色动画，而是学习智能体工作流。

核心目标：

- 用户能像 Scratch 一样把流程“搭出来”，而不是只靠自然语言描述。
- 积木分类按用户意图组织，先让用户找得到，再让系统能校验。
- 每块积木都有明确形状、插槽、输入输出、参数和运行语义。
- 资料库、错题、笔记、日历、复习队列、LLM 都是可拼装能力。
- 已运行版本不可直接覆盖，运行历史绑定版本快照。

## Scratch 底层逻辑对应

Scratch 的关键不是彩色外观，而是这些规则：

| Scratch 概念 | 含义 | 软件工坊对应 |
| --- | --- | --- |
| 分类 | Motion、Looks、Events、Control 等 | 事件、控制、资料、交互、判断、变量、LLM、写回、工具、自定义 |
| 形状 | 积木形状决定能插在哪里 | 帽子块、命令块、C 形块、表达式块、布尔块、结束块 |
| 插槽 | 数字、文本、下拉、布尔条件、积木嵌套 | 题量、知识点、资料范围、模型、条件表达式、子流程 |
| 脚本栈 | 从事件帽子块开始，命令块纵向连接 | 一个 Mini App version 下的 workflow script |
| Reporter | 返回一个值的圆角表达式 | 变量值、正确率、资料片段、LLM 输出、当前题 |
| Predicate | 返回真假值的六边形条件 | 答案是否正确、掌握度是否低于阈值、是否超时 |
| C 形控制块 | 包住一段子脚本 | if、if else、repeat、for each、try fallback |
| My Blocks | 用户自定义可复用积木 | 自定义学习步骤，如“答错后讲解并入错题” |

所以前端不能只做普通流程图。它要让积木的形状和插槽限制用户能拼出的结构，后端再用 schema 做二次校验。

## 积木形状

| 形状 | 用途 | 例子 |
| --- | --- | --- |
| 帽子块 Hat | 启动一个脚本，只能放最上面 | 当小工具开始运行、当用户提交答案 |
| 命令块 Stack | 执行动作，可上下连接 | 展示题目、写入错题、生成讲义 |
| C 形块 C-block | 包住子流程 | 重复 N 次、对每个资料片段执行、如果答错 |
| 表达式块 Reporter | 返回一个值，嵌入插槽 | 当前题、正确率、资料片段、LLM 生成结果 |
| 布尔块 Boolean | 返回真假，只能放条件槽 | 答案正确、连续错题数 >= 2、掌握度 < 60% |
| 结束块 Cap | 结束脚本，不允许后接 | 结束本轮、停止运行、跳出循环 |

## 参数插槽

积木内部必须能装参数。参数不是普通表单字段，而是 Scratch 风格的插槽：插槽类型决定能填什么，前端负责限制，后端负责校验。

| 插槽类型 | 用途 | 例子 |
| --- | --- | --- |
| 数字 | 题量、秒数、阈值、复习间隔 | `10`、`60`、`0.8` |
| 文本 | 标题、提示词、标签、说明 | `导数定义`、`答错后先提示` |
| 下拉枚举 | 从固定选项选择 | 难度：简单/中等/困难；题型：选择/填空/闪卡 |
| 布尔条件 | 嵌入 Boolean 积木 | `答案正确`、`掌握度 < 60%` |
| 表达式 | 嵌入 Reporter 积木 | `当前题`、`资料片段`、`正确率` |
| 资源引用 | 引用一个资料角色 | `高等数学导图`、`错题本: 导数`、`讲义: 极限` |
| 资源集合 | 引用一组资料角色 | 某科目的全部讲义、某知识点下的错题 |
| 资源查询 | 动态筛选资料 | 科目=数学、知识点=导数、类型=讲义 |
| 子脚本 | C 形块包住的积木列表 | `如果答错` 内部的处理流程 |
| LLM 配置 | 模型、温度、引用约束、失败策略 | 模型=fast、必须引用资料库=true |
| 写回策略 | 写到哪里、是否幂等、是否生成新资源 | 写入错题本、写入资料库讲义分类 |

参数 schema 应使用统一结构：

```json
{
  "name": "source",
  "label": "资料来源",
  "slot": "resource_query",
  "accepts": ["library.document", "mindmap.node", "note", "mistake", "lecture"],
  "required": true,
  "default": {
    "subject_id": "$current_subject",
    "resource_types": ["lecture", "note", "mistake"]
  },
  "ui": {
    "control": "resource_picker",
    "allow_multiple": true,
    "show_filters": ["subject", "knowledge_point", "resource_type", "tag"]
  }
}
```

前端参数面板要支持三种填写方式：

- 手动填字面量。
- 从下拉或资源选择器选。
- 拖入 Reporter/Boolean 积木作为动态值。

## 资源角色

Scratch 里角色可以被脚本操作；软件工坊里资料也应成为可被脚本引用的“资源角色”。小工具运行时像舞台，资料角色像舞台上的角色。

| Scratch | 软件工坊 |
| --- | --- |
| Stage 舞台 | Mini App 运行环境 |
| Sprite 角色 | Resource Actor 资料角色 |
| Costume 造型 | 资源的展示视图，如导图视图、讲义视图、题目视图 |
| Sound 声音 | 可选媒体资源，如音频讲解 |
| Sprite variables | 资源元数据，如科目、知识点、标签、来源、掌握度 |
| Sprite scripts | 绑定资源执行的学习脚本 |

资源角色不是复制一份资料，而是对项目内资料的引用。引用必须能稳定追踪来源，也能在运行版本中形成快照。

### 资源角色类型

| 类型 | 来源板块 | 说明 |
| --- | --- | --- |
| `subject` | 科目管理 | 科目本身，作为资源范围和权限边界 |
| `library.document` | 资料库 | 上传或导入的 PDF、Word、图片、文本等 |
| `library.chunk` | 资料库/RAG | 资料切块，供检索和 LLM 引用 |
| `mindmap.session` | 科目空间 | 一棵导图或一次导图会话 |
| `mindmap.node` | 科目空间 | 导图节点，通常对应知识点或章节 |
| `lecture` | 科目空间/资料库 | 节点讲义或生成讲义 |
| `note` | 笔记 | 用户笔记、AI 润色笔记 |
| `mistake` | 错题本 | 错题记录，包含题目、答案、错因、状态 |
| `review_card` | 复习队列 | 调度后的复习对象 |
| `quiz_item` | 出题/练习 | 题目对象，可来自资料、错题或手动创建 |
| `calendar_event` | 日历 | 计划和提醒 |
| `generated_artifact` | 软件工坊 | 小工具生成的讲义、卡片、报告、题集 |

### 资源引用

资源引用用 `ResourceRef` 表示：

```json
{
  "type": "mindmap.node",
  "id": "node_derivative_definition",
  "subject_id": 1,
  "origin": {
    "feature": "course_space.mindmap_lecture",
    "route": "/course-space/1/mindmap/12"
  },
  "snapshot": {
    "mode": "versioned",
    "content_hash": "sha256:..."
  },
  "permissions": {
    "read": true,
    "write": false
  }
}
```

资源引用分三种：

| 引用方式 | 含义 | 适用场景 |
| --- | --- | --- |
| 固定引用 | 指向具体资源 id | 指定某篇讲义、某个导图节点、某条错题 |
| 查询引用 | 运行时按条件查资源 | 当前科目下所有“未掌握”的错题 |
| 快照引用 | 绑定运行版本时冻结内容 | 分享版本、复现历史运行 |

已运行版本优先保存快照引用，避免资料后来被删改导致历史运行无法复现。未运行草稿可以使用动态查询引用。

### 资源角色操作

资源角色要支持这些通用操作：

| 操作 | 说明 |
| --- | --- |
| 读取内容 | 读取全文、片段、题干、答案、讲义正文 |
| 读取元数据 | 科目、知识点、标签、更新时间、掌握度 |
| 获取子资源 | 导图节点取子节点，科目取资料，讲义取段落 |
| 检索相似内容 | RAG 查询、关键词查询、知识点查询 |
| 转成学习素材 | 转为题目、闪卡、讲义片段、复习卡 |
| 写回结果 | 写错题、写笔记、写讲义、写资料库、写日历 |

写回操作必须走写回积木，不能让普通资料读取积木悄悄产生副作用。

### 类似角色的绑定方式

一个小工具版本可以声明资源角色清单：

```json
{
  "actors": [
    {
      "id": "calculus_map",
      "name": "高等数学导图",
      "type": "mindmap.session",
      "ref": {
        "type": "mindmap.session",
        "id": "12"
      }
    },
    {
      "id": "weak_mistakes",
      "name": "薄弱错题",
      "type": "mistake.collection",
      "query": {
        "subject_id": 1,
        "knowledge_points": ["导数定义"],
        "status": "pending"
      }
    }
  ]
}
```

脚本中可以像 Scratch 选角色一样选择资源角色：

```text
当小工具开始运行
  从角色 [高等数学导图] 读取节点 [导数定义]
  从角色 [薄弱错题] 随机抽取 5 条
  让 AI 根据这些资料生成 10 道题
```

## 积木分类

分类沿用 Scratch 的“用户找积木方式”，但换成学习智能体语义。

### 事件

启动或唤醒脚本。

| 积木 | 形状 | 说明 |
| --- | --- | --- |
| 当小工具开始运行 | Hat | 用户打开版本并点击开始 |
| 当用户提交答案 | Hat | 交互块收到一次答案 |
| 当本轮完成 | Hat | 当前 session 达到结束条件 |
| 当计时结束 | Hat | 番茄钟或限时练习结束 |
| 当每日复习开始 | Hat | 来自复习队列或日历提醒 |
| 当掌握度变化 | Hat | 某知识点掌握度更新后触发 |

### 控制

组织执行顺序、循环、分支和异常降级。

| 积木 | 形状 | 说明 |
| --- | --- | --- |
| 如果 `<条件>` 那么 | C-block | 条件为真时执行子流程 |
| 如果 `<条件>` 那么 / 否则 | C-block | 双分支 |
| 重复 `<次数>` 次 | C-block | 固定次数循环 |
| 对每个 `<列表>` 项执行 | C-block | 遍历资料片段、题目、知识点 |
| 等待用户输入 | Stack | 暂停流程直到交互块返回 |
| 等待 `<秒数>` 秒 | Stack | 用于节奏控制 |
| 尝试执行 / 失败则 | C-block | LLM 或资料检索失败时降级 |
| 跳出当前循环 | Cap | 结束最近一层循环 |
| 结束本轮 | Cap | 结束当前 run session |

### 变量

管理临时状态和列表。变量属于版本运行时，不直接等同数据库字段。

| 积木 | 形状 | 说明 |
| --- | --- | --- |
| 设置 `<变量>` 为 `<值>` | Stack | 写入运行时变量 |
| 将 `<变量>` 增加 `<数值>` | Stack | 正确数、错误数、连错次数 |
| 将 `<值>` 加入 `<列表>` | Stack | 收集题目、错题、资料片段 |
| 清空 `<列表>` | Stack | 重置临时集合 |
| `<变量>` | Reporter | 读取变量 |
| `<列表>` 第 `<序号>` 项 | Reporter | 读取列表项 |
| `<列表>` 长度 | Reporter | 用于循环和结束条件 |
| 正确率 | Reporter | 从本轮答题事件计算 |
| 连续错误次数 | Reporter | 从状态变量或事件流计算 |

### 资料

连接资料库、讲义、笔记、错题和知识点。

| 积木 | 形状 | 说明 |
| --- | --- | --- |
| 从资料库取资料 | Stack/Reporter | 按科目、知识点、文档、标签筛选 |
| 搜索相似资料 | Stack/Reporter | RAG 检索片段 |
| 读取讲义片段 | Reporter | 从资料库讲义分类读取 |
| 读取笔记 | Reporter | 从笔记系统读取 |
| 读取错题 | Reporter | 从错题本或复习队列读取 |
| 读取知识点树 | Reporter | 读取科目知识树节点 |
| 取今日复习队列 | Reporter | 读取待复习内容 |

### 内容处理

把资料加工成题目、卡片、讲义素材。

| 积木 | 形状 | 说明 |
| --- | --- | --- |
| 切分资料 | Stack/Reporter | 按段落、标题、token 或知识点切分 |
| 提取知识点 | Stack/Reporter | 从资料片段提取知识点 |
| 生成摘要 | Stack/Reporter | 摘要可由规则或 LLM 完成 |
| 去重 | Reporter | 去掉重复题目或重复知识点 |
| 按难度筛选 | Reporter | 基于难度字段或模型评分 |
| 打乱顺序 | Reporter | 输出随机化列表 |
| 合并相似内容 | Reporter | 合并重复或近似片段 |

### LLM

调用模型的积木必须显式声明输入、输出、成本、失败策略和资料约束。

| 积木 | 形状 | 说明 |
| --- | --- | --- |
| 生成题目 | Stack/Reporter | 输入资料或知识点，输出题目列表 |
| 生成闪卡 | Stack/Reporter | 输入资料，输出 front/back 卡片 |
| 生成讲义 | Stack/Reporter | 输入知识点和资料，输出讲义 |
| 生成提示 | Stack/Reporter | 输入题目和错误答案，输出提示 |
| 解释错因 | Stack/Reporter | 输入答题事件，输出错因解释 |
| 判断答案相似度 | Reporter | 输出分数或是否通过 |
| 改写为更简单 | Reporter | 输出改写文本 |
| 总结本轮学习 | Stack/Reporter | 输出学习报告 |

LLM 积木必须支持这些参数：

- 模型
- 温度
- 最大输出长度
- 是否必须引用资料库
- 是否允许使用用户历史
- 失败时使用规则降级、跳过或询问用户

### 交互

控制用户看到什么、提交什么。

| 积木 | 形状 | 说明 |
| --- | --- | --- |
| 展示文本 | Stack | 显示讲义、提示、总结 |
| 展示闪卡 | Stack | front/back 翻卡 |
| 展示选择题 | Stack | 单选或多选 |
| 展示填空题 | Stack | 支持文本和 LaTeX |
| 展示公式题 | Stack | 支持公式输入键盘 |
| 展示讲解 | Stack | 展示固定讲解或 LLM 讲解 |
| 展示进度 | Stack | 进度条、正确率、剩余题量 |
| 收集答案 | Stack/Reporter | 返回 answer_event |
| 收集自评 | Stack/Reporter | 例如“会了/不会/模糊” |

### 判断

布尔块和表达式块，用于控制块条件。

| 积木 | 形状 | 说明 |
| --- | --- | --- |
| 答案正确 | Boolean | 基于标准答案或判题结果 |
| 分数 `>` `<数值>` | Boolean | LLM 或规则评分 |
| 连续错误次数 `>=` `<数值>` | Boolean | 控制提示和讲解 |
| 掌握度 `<` `<阈值>` | Boolean | 控制是否加入复习 |
| 当前题属于知识点 | Boolean | 按知识点路由 |
| 当前时间超过限制 | Boolean | 限时练习 |
| 列表为空 | Boolean | 防止空内容运行 |
| 文本包含关键词 | Boolean | 简单规则判断 |

### 写回

所有有副作用的积木单独成类，并要求绑定版本和运行事件。

| 积木 | 形状 | 说明 |
| --- | --- | --- |
| 写入错题本 | Stack | 保存题目、答案、错因、来源版本 |
| 加入复习队列 | Stack | 写入复习计划和间隔 |
| 写入资料库 | Stack | 保存讲义、卡片、总结等资源 |
| 写入笔记 | Stack | 保存一条笔记 |
| 写入日历计划 | Stack | 创建学习事件 |
| 更新掌握度 | Stack | 更新知识点状态 |
| 保存学习记录 | Stack | 写入 run event |
| 生成学习报告 | Stack | 保存 session 报告 |

写回积木必须满足：

- 每次写入带 `app_id`、`version_id`、`run_id`。
- 重复执行不会产生不可控重复数据，至少要有幂等 key。
- 写入结果可在运行日志中回放。
- 分享导入的工具默认不能写原作者数据，只能写当前用户数据。

### 工具

辅助运行、调试和格式处理。

| 积木 | 形状 | 说明 |
| --- | --- | --- |
| 随机抽取 | Reporter | 从列表抽 N 项 |
| 排序 | Reporter | 按难度、时间、掌握度排序 |
| 格式化 LaTeX | Reporter | 清洗公式文本 |
| 计时器开始 | Stack | 开始计时 |
| 计时器停止 | Stack/Reporter | 返回耗时 |
| 调试输出 | Stack | 写入调试面板 |
| 查看运行日志 | Reporter | 用于调试和复盘 |
| 导出小工具包 | Stack | 导出 version manifest |

### 自定义

对应 Scratch 的 My Blocks。

用途：

- 把一段常用学习流程封装成可复用积木。
- 用户可命名、设置参数、声明返回值。
- 自定义积木也必须保存为结构化脚本，不能保存成自然语言。

例子：

```text
定义 [答错后讲解并入错题] 参数：题目、答案事件
  生成提示
  展示提示
  如果 连续错误次数 >= 2 那么
    解释错因
    写入错题本
    加入复习队列
```

## 颗粒度规则

一个积木应该满足三个条件：

1. 用户能用一句话理解它在学习流程里的作用。
2. 它能独立调参。
3. 它的输入输出能被 schema 校验。

合适颗粒度：

- 从资料库取 5 个知识点。
- 对每个知识点生成 2 道选择题。
- 展示一道题并收集答案。
- 答错时生成提示。
- 连错 2 次写入错题本。
- 本轮结束后生成总结。

不合适的过粗积木：

- 自动完成学习闭环。
- 生成完整课程。
- 智能复习系统。

不合适的过细积木：

- 读取 JSON 字段。
- 拼接字符串。
- 调 HTTP。
- 遍历 map。
- 直接写数据库表。

## 数据结构草案

```json
{
  "schema_version": "workshop.workflow.v1",
  "app_id": "mini_app_1",
  "version_id": "v3",
  "scripts": [
    {
      "id": "script_on_start",
      "hat": {
        "block": "event.on_start"
      },
      "body": [
        {
          "block": "data.query_library",
          "params": {
            "subject_id": 1,
            "knowledge_points": ["导数定义"],
            "limit": 5
          },
          "output": "materials"
        },
        {
          "block": "control.for_each",
          "params": {
            "items": "$materials",
            "item_name": "material"
          },
          "body": [
            {
              "block": "llm.generate_quiz",
              "params": {
                "material": "$material",
                "count": 2,
                "difficulty": "medium"
              },
              "output": "questions"
            }
          ]
        },
        {
          "block": "control.repeat",
          "params": {
            "times": 10
          },
          "body": [
            {
              "block": "interaction.show_question",
              "params": {
                "question": "$questions.current"
              },
              "output": "answer_event"
            },
            {
              "block": "control.if_else",
              "condition": {
                "block": "judge.answer_correct",
                "params": {
                  "answer_event": "$answer_event"
                }
              },
              "then": [
                {
                  "block": "state.increment",
                  "params": {
                    "variable": "correct_count",
                    "by": 1
                  }
                }
              ],
              "else": [
                {
                  "block": "llm.explain_mistake",
                  "params": {
                    "answer_event": "$answer_event"
                  },
                  "output": "explanation"
                },
                {
                  "block": "system.write_mistake",
                  "params": {
                    "answer_event": "$answer_event",
                    "explanation": "$explanation"
                  }
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

## 前端形态

第一版采用 Scratch 逻辑，但不必一开始完整复刻 Scratch 画布。

推荐三栏：

| 区域 | 作用 |
| --- | --- |
| 左侧积木库 | 按分类列出积木，颜色和形状表达类型 |
| 中间脚本区 | 拼接脚本栈，支持 C 形嵌套、表达式插槽、条件插槽 |
| 右侧参数面板 | 编辑当前积木参数、资料范围、LLM 配置、失败策略 |

运行区可以复用现有 `/workshop/apps/:appId`，但编辑区应能打开某个 version 的 workflow。

## 操作者模型

同一套积木 workflow 必须同时支持三类操作者：

| 操作者 | 操作方式 | 约束 |
| --- | --- | --- |
| 用户 | 拖拽积木、编辑参数、组合脚本栈 | 前端用形状、插槽、类型和参数面板限制错误拼接 |
| 系统 | 根据模板、资料库、错题、复习队列自动生成或补全积木 | 必须输出结构化 workflow，不允许只保存自然语言 |
| AI 助教 | 根据用户自然语言生成、改造、解释、修复 workflow | 必须通过 block registry、schema 校验和版本 diff |

这意味着“自然语言生成”和“用户手搓积木”不是两套系统。自然语言只是生成或修改积木 AST 的一种入口，最终保存的仍然是结构化 workflow。

AI 助教改造时应采用补丁模型：

```json
{
  "base_version_id": "v2",
  "change_request": "答错两次后再写错题，并加入 1 天后复习",
  "patch": [
    {
      "op": "insert_block",
      "path": "scripts/script_on_start/body/2/body/1/else/1",
      "block": {
        "block": "control.if",
        "condition": {
          "block": "judge.consecutive_wrong_gte",
          "params": {
            "value": 2
          }
        },
        "body": [
          {
            "block": "system.write_mistake"
          },
          {
            "block": "system.schedule_review",
            "params": {
              "after_days": 1
            }
          }
        ]
      }
    }
  ]
}
```

补丁应用后必须重新生成完整 workflow，并重新校验：

- 积木是否存在。
- 插槽类型是否匹配。
- 变量是否已定义。
- LLM 积木是否有失败策略。
- 写回积木是否带版本、运行和幂等信息。
- 已运行版本是否被直接修改。

## 版本规则

- `MiniApp` 是长期存在的小工具壳。
- `MiniAppVersion` 是具体可运行版本，包含 workflow、文档、运行配置和积木图。
- `Run` 必须绑定 `version_id`。
- 当前后端已落地版本快照：创建、访谈生成、配置保存、助教改造和资料生成卡片会写入 `mini_app_versions.json`，运行记录会保存 `app_version_id`、`app_snapshot` 和 `graph_snapshot`。
- 当前后端已落地 workflow patch 合同：`POST /api/mini-apps/workflow/patch` 会把自然语言修改转为可审计 patch operations，并复用 workflow validator 校验结果。
- 版本一旦运行，默认锁定。
- 修改已运行版本时创建新版本。
- 未运行草稿可以直接编辑。
- 分享应默认分享指定版本，而不是模糊分享最新状态。

## Git 追溯

软件工坊的版本追溯应尽量像代码仓库，而不是只在数据库里覆盖一份 JSON。

每个可运行版本应能导出成稳定文件树：

```text
mini_apps/
  mini_app_1/
    app.json
    versions/
      v1/
        manifest.json
        workflow.json
        documents/
          design.md
          runtime_config.json
        validation.json
      v2/
        manifest.json
        workflow.json
        documents/
          design.md
          runtime_config.json
        validation.json
```

建议 Git 追溯字段：

| 字段 | 说明 |
| --- | --- |
| `version_id` | 业务版本 |
| `parent_version_id` | 从哪个版本改造而来 |
| `created_by` | 用户、系统或 AI |
| `change_summary` | 人能读的改动说明 |
| `change_request` | 用户或系统提出的原始需求 |
| `workflow_hash` | workflow 内容 hash |
| `git_commit` | 如果写入本地/远端仓库，对应 commit |
| `validation_status` | 此版本是否通过校验 |

AI 和系统自动修改也必须写 commit 风格记录。推荐提交信息：

```text
workshop(mini_app_1): add delayed mistake capture

Base-Version: v2
New-Version: v3
Actor: assistant
Workflow-Hash: sha256:...
```

前端“版本历史”应展示：

- 版本号。
- 谁改的。
- 为什么改。
- 改了哪些积木。
- 是否运行过。
- 是否可回滚。
- 可查看 workflow diff。

workflow diff 不应只显示 JSON 行差异，还应显示积木语义差异：

```text
新增：
  如果 连续错误次数 >= 2
    写入错题本
    加入 1 天后复习

修改：
  重复次数：10 -> 8
  LLM 模型：default -> fast
```

## 落地顺序

1. 已定义 `workshop.workflow.v1` schema 和 block registry。
2. 已增加 version 层，run 绑定 version。
3. 已增加 AI patch 合同：自然语言改造生成结构化补丁，而不是直接覆盖 JSON。
4. 已有前端列表式/脚本式积木编辑器底座。
5. 下一步增加 workflow 文件树导出和 Git commit 追溯。
6. 下一步把 patch 接入前端确认流。
7. 支持最小积木集：事件、控制、变量、资料、LLM、交互、判断、写回。
8. 支持一个可运行示例：资料库生成题 -> 展示题目 -> 判题 -> 写错题 -> 加入复习队列。
9. 再升级为真正拖拽画布和调试日志。
