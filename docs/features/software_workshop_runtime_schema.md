# 软件工坊运行配置 Schema

本文说明软件工坊 Mini App 的 `runtime_config` 目标结构。当前软件工坊仍是部分实现，本文是后续实现和验收的 schema 约束，不表示所有能力都已完成。

## 顶层结构

```json
{
  "schema_version": "miniapp.v1",
  "app": {},
  "template": {},
  "content": {},
  "screens": [],
  "flow": {},
  "scheduler": {},
  "practice": {},
  "assessment": {},
  "modules": [],
  "runtime": {}
}
```

必需字段：

- `schema_version`: 必须是 `miniapp.v1`。
- `app.title`: 小软件名称。
- `app.type`: 小软件类型，例如 `memory`、`quiz`、`drill`。
- `screens`: 至少包含一个可运行屏幕。
- `runtime.entry_screen`: 入口屏幕 ID。

## app

```json
{
  "type": "memory",
  "title": "二次函数闪卡",
  "subject_id": 11,
  "goal": "记住顶点式、图像平移和开口方向"
}
```

| 字段 | 类型 | 必需 | 说明 |
| --- | --- | --- | --- |
| `type` | string | 是 | 小软件类型 |
| `title` | string | 是 | 名称 |
| `subject_id` | number/null | 否 | 关联科目 |
| `goal` | string/null | 否 | 学习目标 |

## template

```json
{
  "name": "flashcard",
  "description": "问答闪卡练习",
  "content_fields": ["front", "back"],
  "acceptance": ["至少生成 5 张卡片", "错题会进入复习"]
}
```

`template` 描述教学设计模板，用来约束生成器和市场模板。

## content

手动内容：

```json
{
  "source_type": "manual",
  "items": [
    {
      "id": "card_001",
      "front": "顶点式是什么？",
      "back": "y=a(x-h)^2+k",
      "tags": ["二次函数"]
    }
  ]
}
```

资料来源：

```json
{
  "source_type": "document",
  "source": {
    "subject_id": 11,
    "doc_ids": [701]
  },
  "items": []
}
```

资料来源模式需要运行页或后端管线从资料库生成内容。

## screens

```json
[
  {
    "id": "card_practice",
    "type": "flashcard",
    "title": "闪卡练习",
    "content_ref": "content.items",
    "actions": ["flip", "rate", "next"]
  }
]
```

字段：

- `id`: 屏幕唯一 ID。
- `type`: 屏幕类型。
- `title`: 展示标题。
- `content_ref`: 内容路径。
- `actions`: 允许的操作。

## flow

```json
{
  "entry": "card_practice",
  "transitions": [
    {"from": "card_practice", "on": "complete", "to": "summary"}
  ]
}
```

## scheduler

```json
{
  "new_items_per_day": 10,
  "max_reviews_per_day": 30,
  "review_algorithm": "sm2-lite"
}
```

## practice 与 assessment

```json
{
  "practice": {
    "record_wrong_items": true,
    "allow_retry": true
  },
  "assessment": {
    "mastery_threshold": 0.8,
    "score_fields": ["accuracy", "speed", "streak"]
  }
}
```

## runtime

```json
{
  "entry_screen": "card_practice",
  "storage": "mini_app_local_and_backend",
  "permissions": [],
  "safety": {
    "allow_network": false,
    "allow_code_execution": false
  }
}
```

## 安全边界

- runtime config 不能允许任意代码执行。
- 用户生成配置必须经过 schema 校验。
- 资料生成内容必须记录来源。
- 与错题、笔记、日历联动时必须通过明确 API，而不是任意脚本。

## 当前代码入口

- `lib/features/workshop/mini_app_models.dart`
- `lib/features/workshop/mini_app_service.dart`
- `lib/features/workshop/mini_app_providers.dart`
- `lib/features/workshop/workshop_builder_page.dart`
- `lib/features/workshop/mini_app_run_page.dart`

## 后续验收

新增 `WORKSHOP-P2-01` 时，应校验：

- 创建 Mini App 请求体包含合法 runtime config。
- 运行页能按 `entry_screen` 渲染。
- 资料来源模式能从资料库生成内容。
- 错误 schema 会显示可理解错误。
- 运行结果能持久化。
