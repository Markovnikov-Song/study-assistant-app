# Design Document

## 知识图谱进化 - 技术设计

### 1. 系统架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter (Frontend)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐   ┌──────────────────┐                   │
│  │ MindMapPainter   │   │ LearningPath     │                   │
│  │ - 节点状态渲染    │   │ Service          │                   │
│  │ - 热力图模式      │   │ - 获取预设路径    │                   │
│  │ - 路径高亮        │   │ - 节点状态管理    │                   │
│  └──────────────────┘   └──────────────────┘                   │
│                                                                  │
│  ┌──────────────────┐   ┌──────────────────┐                   │
│  │ Achievement      │   │ SkillDiagnostic  │                   │
│  │ Service          │   │ Service          │                   │
│  │ - 成就检测       │   │ - 错题分析       │                   │
│  │ - 节点点亮动画   │   │ - 薄弱点识别     │                   │
│  └──────────────────┘   └──────────────────┘                   │
│                                                                  │
└─────────────────────────────┬───────────────────────────────────┘
                              │ HTTP
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Backend (Python)                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ API Layer                                                 │  │
│  │  - /api/library/learning-paths                           │  │
│  │  - /api/library/node-mastery                            │  │
│  │  - /api/library/knowledge-nodes/dimensions              │  │
│  │  - /api/teacher/class-heatmap                           │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────┐   ┌──────────────────┐                   │
│  │ LearningPath     │   │ NodeMastery      │                   │
│  │ Generator        │   │ Calculator       │                   │
│  │ (预设路径管理)    │   │ (掌握度计算)      │                   │
│  └──────────────────┘   └──────────────────┘                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Database                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  mindmap_learning_paths                                         │
│  ├─ id, subject_id, name, node_ids[], prerequisites{}         │
│                                                                  │
│  mindmap_node_mastery                                           │
│  ├─ id, user_id, session_id, node_id, mastery_level (0-100)   │
│  ├─ last_practiced_at, correct_count, wrong_count             │
│                                                                  │
│  node_dimension_mappings                                        │
│  ├─ id, node_id, dimension, mapping_value, source             │
│                                                                  │
│  user_achievements                                              │
│  ├─ id, user_id, achievement_type, unlocked_at                │
│                                                                  │
│  question_node_mapping                                          │
│  ├─ id, question_id, node_id, weight                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 2. 核心数据模型

#### 2.1 NodeState (Flutter)

```dart
enum NodeState {
  locked,      // 未解锁 - 灰色 + 锁图标
  unlocked,    // 已解锁 - 白色边框
  inProgress,  // 进行中 - 蓝色脉冲
  mastered,    // 已掌握 - 绿色 + ✓
}
```

#### 2.2 LearningPath

```python
# Backend Model
class LearningPath(Base):
    id = Column(Integer, primary_key=True)
    subject_id = Column(Integer, ForeignKey('subjects.id'))
    name = Column(String(128))  # "材料力学 - 期末备考"
    node_ids = Column(JSON)  # ["L1_chap1", "L1_chap1_sec1", ...]
    prerequisites = Column(JSON)  # {"L1_chap2": ["L1_chap1"]}
    is_default = Column(Boolean, default=False)
```

#### 2.3 NodeMastery

```python
class NodeMastery(Base):
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'))
    session_id = Column(Integer, ForeignKey('conversation_sessions.id'))
    node_id = Column(String(512))
    mastery_level = Column(Float, default=0.0)  # 0-100
    correct_count = Column(Integer, default=0)
    wrong_count = Column(Integer, default=0)
    lecture_read_duration = Column(Integer, default=0)  # 秒
```

### 3. 掌握度计算算法

```python
def calculate_mastery(correct_count, wrong_count, lecture_duration):
    # 基础正确率 (50% 权重)
    total = correct_count + wrong_count
    correct_rate = correct_count / total if total > 0 else 0.5
    base_score = correct_rate * 50
    
    # 错误惩罚 (30% 权重)
    wrong_ratio = wrong_count / total if total > 0 else 0
    wrong_penalty = (1 - wrong_ratio) * 30
    
    # 讲义阅读 (20% 权重)
    # 假设完成阅读需要 300 秒 (5 分钟)
    read_score = min(lecture_duration / 300, 1.0) * 20
    
    return base_score + wrong_penalty + read_score
```

### 4. 热力图颜色映射

| 掌握度 | 颜色代码 | 颜色名称 |
|--------|----------|----------|
| 0-20%  | #D32F2F  | 深红 (严重薄弱) |
| 21-40% | #F57C00  | 橙色 (需要加强) |
| 41-60% | #FBC02D  | 黄色 (初步了解) |
| 61-80% | #8BC34A  | 浅绿 (基本掌握) |
| 81-100%| #388E3C  | 深绿 (完全掌握) |

### 5. 节点状态渲染逻辑 (MindMapPainter)

```dart
Color getNodeColor(NodeState state, {double? masteryLevel}) {
  if (heatmapMode && masteryLevel != null) {
    return getHeatmapColor(masteryLevel);
  }
  
  switch (state) {
    case NodeState.locked:
      return const Color(0xFF9E9E9E);
    case NodeState.unlocked:
      return Colors.white;
    case NodeState.inProgress:
      return const Color(0xFF1976D2);
    case NodeState.mastered:
      return const Color(0xFF4CAF50);
  }
}
```

### 6. 多维图谱维度定义

```dart
enum GraphDimension {
  knowledge,  // 知识图谱 (默认)
  capability, // 能力图谱 ("工程分析能力")
  problem,    // 问题图谱 ("计算题/分析题")
  quality,    // 素质图谱 ("团队协作")
  ideological // 思政图谱 ("工程师伦理")
}
```

### 7. 预设学习路径数据结构

```json
{
  "subjectId": 1,
  "name": "材料力学 - 期末备考",
  "isDefault": true,
  "nodeIds": [
    "L1_chap1_force",
    "L1_chap1_eq",
    "L1_chap2_stress",
    "L1_chap2_strain",
    "L2_chap3_bending"
  ],
  "prerequisites": {
    "L1_chap2_stress": ["L1_chap1_force"],
    "L2_chap3_bending": ["L1_chap2_stress", "L1_chap2_strain"]
  },
  "estimatedHours": {
    "L1_chap1_force": 2,
    "L1_chap2_stress": 3
  }
}
```

### 8. API 接口设计

#### 8.1 获取学科预设路径

```
GET /api/library/subjects/{subjectId}/learning-path

Response:
{
  "id": 1,
  "subjectId": 1,
  "name": "材料力学 - 期末备考",
  "nodeIds": ["L1_...", "L2_..."],
  "prerequisites": {...}
}
```

#### 8.2 获取节点掌握度

```
GET /api/library/sessions/{sessionId}/node-mastery

Response:
{
  "nodes": [
    {"nodeId": "L1_chap1", "masteryLevel": 85, "state": "mastered"},
    {"nodeId": "L1_chap2", "masteryLevel": 45, "state": "inProgress"},
    {"nodeId": "L2_chap3", "masteryLevel": 10, "state": "locked"}
  ],
  "progress": "3/15"
}
```

#### 8.3 班级热力图 (教师)

```
GET /api/teacher/class/{classId}/heatmap?subjectId=1

Response:
{
  "nodes": [
    {"nodeId": "L1_chap1", "avgMastery": 78, "studentCount": 25},
    {"nodeId": "L1_chap2", "avgMastery": 45, "studentCount": 18}
  ],
  "topWeakPoints": ["L1_chap2", "L2_chap3"],
  "needsAttention": [ {"userId": 123, "weakNodes": ["L1_chap2"]} ]
}
```

### 9. 依赖服务

- `library_service.dart`: MindMap 数据存取
- `calendar_service.dart`: 日历任务关联
- `notification_service.dart`: 学习提醒
- `mistake_book_service.dart`: 错题数据源
- `llm_service.py`: 生成节点-维度映射（AI 辅助）

### 10. 性能考虑

- 节点状态缓存：使用 Riverpod `ref.watch` 缓存，避免重复请求
- 热力图渲染：节点数量 >100 时使用 `RepaintBoundary` 优化
- 班级视图：使用分页加载，避免一次性加载全班数据
- 掌握度计算：结果缓存 5 分钟，避免频繁重算