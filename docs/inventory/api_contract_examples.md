# API 合约样例

本文档补充 `docs/inventory/api_inventory.md` 的请求/响应样例。它不是完整 OpenAPI 导出，而是给人和 AI 复原项目时使用的关键合约样本。

## 通用约定

- 除 `/api/auth/register`、`/api/auth/login` 外，接口默认需要 `Authorization: Bearer <access_token>`。
- 时间字段优先使用 ISO 8601 字符串。
- 日期字段使用 `YYYY-MM-DD`。
- `start_time` 使用 `HH:MM`。
- 后端错误一般返回 FastAPI 默认结构：`{"detail": "错误说明"}`。
- 真实字段以 `backend/routers/*.py` 中的 Pydantic 模型为准，本文档应随模型同步更新。

## 认证

### POST `/api/auth/register`

请求：

```json
{
  "username": "student_001",
  "password": "123456"
}
```

响应：

```json
{
  "access_token": "jwt-token",
  "token_type": "bearer",
  "user_id": 1,
  "username": "student_001"
}
```

副作用：

- 创建用户。
- 初始化系统笔记本：好题本、错题本、笔记、通用。

### POST `/api/auth/login`

请求：

```json
{
  "username": "student_001",
  "password": "123456"
}
```

响应同注册接口。旧账号如果缺少系统笔记本，会在登录时补齐。

## 科目

### POST `/api/subjects`

请求：

```json
{
  "name": "初中数学",
  "category": "数学",
  "description": "七年级到九年级数学复习",
  "color_index": 2
}
```

响应：

```json
{
  "id": 11,
  "name": "初中数学",
  "category": "数学",
  "description": "七年级到九年级数学复习",
  "is_pinned": false,
  "is_archived": false,
  "color_index": 2,
  "created_at": "2026-06-01T20:00:00"
}
```

约束：

- `name` 长度 1 到 128。
- `color_index` 可为空，非空时范围为 0 到 11。

### GET `/api/subjects?include_archived=false`

响应：

```json
[
  {
    "id": 11,
    "name": "初中数学",
    "category": "数学",
    "description": "七年级到九年级数学复习",
    "is_pinned": false,
    "is_archived": false,
    "color_index": 2,
    "created_at": "2026-06-01T20:00:00"
  }
]
```

## 学习日历

### POST `/api/calendar/events`

请求：

```json
{
  "title": "二次函数错题复盘",
  "event_date": "2026-06-02",
  "start_time": "19:30",
  "duration_minutes": 45,
  "actual_duration_minutes": null,
  "subject_id": 11,
  "color": "#4F8EF7",
  "notes": "复盘最近 10 道错题",
  "is_completed": false,
  "is_countdown": false,
  "priority": "high",
  "source": "manual"
}
```

响应：

```json
{
  "id": 101,
  "user_id": 1,
  "title": "二次函数错题复盘",
  "event_date": "2026-06-02",
  "start_time": "19:30",
  "duration_minutes": 45,
  "actual_duration_minutes": null,
  "subject_id": 11,
  "subject_name": "初中数学",
  "subject_color": "#4F8EF7",
  "color": "#4F8EF7",
  "notes": "复盘最近 10 道错题",
  "is_completed": false,
  "is_countdown": false,
  "priority": "high",
  "source": "manual",
  "routine_id": null,
  "created_at": "2026-06-01T20:10:00",
  "updated_at": "2026-06-01T20:10:00"
}
```

约束：

- `title` 不能为空，最长 50。
- `duration_minutes` 范围 15 到 480。
- `priority` 只能是 `high`、`medium`、`low`。

### PATCH `/api/calendar/events/{event_id}`

请求只传需要修改的字段：

```json
{
  "is_completed": true,
  "actual_duration_minutes": 42,
  "notes": "已完成，仍需复习顶点式"
}
```

响应为更新后的事件对象。

### GET `/api/calendar/events/today`

响应形态：

```json
{
  "date": "2026-06-02",
  "events": [],
  "total_count": 3,
  "completed_count": 1,
  "completion_rate": 0.33,
  "planned_minutes": 120,
  "actual_minutes": 42
}
```

注意：实际字段请以 `backend/routers/calendar.py` 的实现为准。前端日历页面和通知服务应只依赖稳定字段。

### POST `/api/calendar/routines`

请求：

```json
{
  "title": "每日英语听力",
  "repeat_type": "daily",
  "day_of_week": null,
  "start_time": "07:30",
  "duration_minutes": 30,
  "subject_id": 12,
  "color": "#2BB673",
  "start_date": "2026-06-02",
  "end_date": null
}
```

约束：

- `repeat_type` 只能是 `daily`、`weekly`、`monthly`。
- `duration_minutes` 范围 15 到 480。

## 笔记

### POST `/api/notes`

请求：

```json
{
  "notes": [
    {
      "role": "assistant",
      "original_content": "二次函数顶点式：y=a(x-h)^2+k。",
      "title": "二次函数顶点式",
      "source_session_id": 33,
      "source_message_id": 210,
      "sources": {
        "type": "chat"
      },
      "notebook_id": 3,
      "subject_id": 11
    }
  ]
}
```

响应：

```json
[
  {
    "id": 501,
    "notebook_id": 3,
    "subject_id": 11,
    "source_session_id": 33,
    "source_message_id": 210,
    "role": "assistant",
    "original_content": "二次函数顶点式：y=a(x-h)^2+k。",
    "title": null,
    "outline": null,
    "imported_to_doc_id": null,
    "sources": {
      "type": "chat"
    },
    "created_at": "2026-06-01T20:30:00",
    "updated_at": "2026-06-01T20:30:00"
  }
]
```

## 错题与复习

### POST `/api/review/mistakes`

请求：

```json
{
  "notebook_id": 2,
  "subject_id": 11,
  "title": "错题：二次函数图像",
  "content": "题目内容和错误分析",
  "node_id": "math.quadratic.graph",
  "question_text": "已知抛物线顶点，求解析式。",
  "user_answer": "y=(x+1)^2+2",
  "correct_answer": "y=2(x+1)^2+2",
  "mistake_category": "concept",
  "review_card_id": null
}
```

响应：

```json
{
  "id": 801,
  "notebook_id": 2,
  "subject_id": 11,
  "title": "错题：二次函数图像",
  "content": "题目内容和错误分析",
  "note_type": "mistake",
  "mistake_status": "pending",
  "node_id": "math.quadratic.graph",
  "question_text": "已知抛物线顶点，求解析式。",
  "user_answer": "y=(x+1)^2+2",
  "correct_answer": "y=2(x+1)^2+2",
  "mistake_category": "concept",
  "review_card_id": null,
  "mastery_score": 0,
  "review_count": 0,
  "last_reviewed_at": null,
  "created_at": "2026-06-01T20:40:00",
  "updated_at": "2026-06-01T20:40:00"
}
```

### POST `/api/review/mistakes/from-practice`

这个接口用于出题、解题、Mini App 等练习场景自动写入错题本。它会自动查找或创建用户的系统错题本，因此请求不需要传 `notebook_id`。如果请求传入 `subject_id` 或 `node_id`，后端会创建关联 SM-2 复习卡；如果二者都为空，则只写入错题本，不进入复习队列。

请求：

```json
{
  "subject_id": 11,
  "title": "解题错题",
  "content": "题目/追问：\n图片题（原图见解题历史）\n\n解题解析：\n完整解题步骤",
  "node_id": null,
  "question_text": "图片题（原图见解题历史）",
  "user_answer": null,
  "correct_answer": null,
  "mistake_category": "complete",
  "review_card_id": null
}
```

响应同 `POST /api/review/mistakes`。如果提供了 `node_id` 或 `subject_id`，后端会尝试创建关联的 SM-2 复习卡片。

### POST `/api/review/review/submit`

请求：

```json
{
  "note_id": 801,
  "quality": 2,
  "review_content": "已经能说清顶点式系数 a 的作用",
  "practice_correct": true
}
```

响应：

```json
{
  "note_id": 801,
  "mistake_status": "reviewing",
  "sm2_result": {
    "next_review_at": "2026-06-03T20:40:00",
    "interval_days": 2,
    "ease_factor": 2.5
  },
  "message": "复盘已记录"
}
```

## 出题与判题

### POST `/api/quiz/generate`

请求：

```json
{
  "node_id": "math.quadratic.vertex",
  "node_title": "二次函数顶点式",
  "node_content": "y=a(x-h)^2+k 的图像和性质",
  "prerequisite_nodes": [
    {
      "node_id": "math.function.basic",
      "node_title": "函数基础",
      "node_content": "自变量、因变量、函数图像"
    }
  ],
  "followup_nodes": [],
  "question_count": 3,
  "question_types": ["choice", "fill"],
  "difficulty": "mixed"
}
```

响应：

```json
{
  "success": true,
  "total_count": 3,
  "questions": [
    {
      "id": "q_001",
      "type": "choice",
      "difficulty": "L1",
      "difficulty_label": "基础",
      "question": "函数 y=2(x-3)^2+1 的顶点是？",
      "options": [
        {
          "key": "A",
          "content": "(3, 1)",
          "is_correct": true
        }
      ],
      "correct_answer": "A",
      "explanation": "顶点式 y=a(x-h)^2+k 的顶点为 (h,k)。",
      "source_node_id": "math.quadratic.vertex",
      "source_node_title": "二次函数顶点式",
      "knowledge_zone": "current"
    }
  ],
  "knowledge_coverage": {
    "pre": 1,
    "current": 2,
    "post": 0
  },
  "message": "题目生成成功"
}
```

### POST `/api/quiz/submit-answer`

请求：

```json
{
  "question_id": "q_001",
  "user_answer": "B",
  "node_id": "math.quadratic.vertex",
  "node_title": "二次函数顶点式",
  "subject_id": 11,
  "question_text": "函数 y=2(x-3)^2+1 的顶点是？",
  "correct_answer": "A",
  "question_type": "choice"
}
```

响应：

```json
{
  "question_id": "q_001",
  "user_answer": "B",
  "correct": false,
  "correct_answer": "A",
  "message": "答错了，已加入错题本",
  "added_to_mistake_book": true
}
```

## 解题历史

### GET `/api/solve/sessions`

响应：

```json
[
  {
    "id": 33,
    "title": "解题记录",
    "created_at": "2026-06-01T20:55:00",
    "thumbnail": "data:image/png;base64,iVBOR..."
  }
]
```

### GET `/api/solve/sessions/{session_id}`

响应：

```json
[
  {
    "id": 210,
    "role": "user",
    "content": "这道题怎么做？",
    "sources": {
      "images": ["data:image/png;base64,iVBOR..."]
    },
    "created_at": "2026-06-01T20:55:00"
  },
  {
    "id": 211,
    "role": "assistant",
    "content": "先把题目条件转成方程。",
    "sources": null,
    "created_at": "2026-06-01T20:56:00"
  }
]
```

## 软件工坊

### POST `/api/mini-apps/validate`

请求：

```json
{
  "spec": {
    "schema_version": "miniapp.v1",
    "app": {
      "type": "memory",
      "title": "二次函数闪卡",
      "subject_id": 11,
      "goal": "记住顶点式和图像性质"
    },
    "template": {
      "name": "flashcard",
      "description": "问答闪卡练习",
      "content_fields": ["front", "back"],
      "acceptance": ["至少 5 张卡片"]
    },
    "content": {
      "source_type": "manual",
      "items": [
        {
          "front": "顶点式是什么？",
          "back": "y=a(x-h)^2+k"
        }
      ]
    },
    "screens": ["daily_home", "card_practice", "answer_feedback", "summary"],
    "scheduler": {
      "type": "sm2",
      "new_items_per_day": 10,
      "max_reviews_per_day": 30
    }
  }
}
```

响应：

```json
{
  "validation": {
    "ok": true,
    "errors": [],
    "warnings": ["手动内容少于 5 条，练习价值可能不足"]
  }
}
```

### POST `/api/mini-apps`

请求：

```json
{
  "title": "二次函数闪卡",
  "app_type": "memory",
  "subject_id": 11,
  "documents": {
    "README.md": "# 二次函数闪卡",
    "runtime_config.json": "{}"
  },
  "spec": {
    "schema_version": "miniapp.v1",
    "app": {
      "type": "memory",
      "title": "二次函数闪卡",
      "subject_id": 11
    },
    "content": {
      "source_type": "manual",
      "items": [
        {
          "front": "顶点式是什么？",
          "back": "y=a(x-h)^2+k"
        }
      ]
    },
    "screens": ["card_practice"],
    "scheduler": {
      "type": "sm2",
      "new_items_per_day": 10,
      "max_reviews_per_day": 30
    }
  },
  "status": "draft"
}
```

响应为 `MiniAppRecord`：

```json
{
  "id": "app_abc",
  "user_id": 1,
  "title": "二次函数闪卡",
  "app_type": "memory",
  "subject_id": 11,
  "status": "draft",
  "documents": {},
  "spec": {},
  "graph": {},
  "validation": {
    "ok": true,
    "errors": [],
    "warnings": []
  },
  "created_at": "2026-06-01T21:00:00",
  "updated_at": "2026-06-01T21:00:00"
}
```

### POST `/api/mini-apps/{app_id}/runs/start`

响应：

```json
{
  "run_id": "run_001",
  "app_id": "app_abc",
  "status": "running",
  "graph": {
    "schema_version": "miniapp.graph.v1"
  },
  "preview": {
    "ok": true,
    "steps": []
  },
  "created_at": "2026-06-01T21:05:00"
}
```

### POST `/api/mini-apps/runs/{run_id}/events`

请求：

```json
{
  "node_id": "practice",
  "event_type": "answer_submitted",
  "payload": {
    "item_id": "card_001",
    "is_correct": false,
    "answer": "y=a(x+h)^2+k"
  }
}
```

响应：

```json
{
  "run_id": "run_001",
  "event": {
    "node_id": "practice",
    "event_type": "answer_submitted",
    "payload": {
      "item_id": "card_001",
      "is_correct": false,
      "answer": "y=a(x+h)^2+k"
    },
    "created_at": "2026-06-01T21:06:00"
  },
  "event_count": 1
}
```

## 仍需补齐

- 文档上传、知识库重建、讲义生成、思维导图节点接口的完整样例。
- CAS action registry 的输入输出 schema。
- 流式聊天和 SSE 事件格式。
- Mini App 图校验、图预览、卡片生成接口的完整样例。
