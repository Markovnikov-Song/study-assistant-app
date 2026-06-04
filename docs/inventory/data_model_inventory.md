# 数据模型清单

当前后端主要数据模型定义在 `backend/database.py`，增量结构在 `backend/migrations/`。

## 核心用户与配置

| 表 | ORM | 用途 | 关键字段 |
| --- | --- | --- | --- |
| `users` | `User` | 用户账号和模型配置 | `username`、`password_hash`、`avatar`、`use_shared_config`、自定义 LLM/Vision/Embedding/Reranker 配置 |
| `user_token_quotas` | `UserTokenQuota` | 用户 Token 配额 | `tier`、`quota_daily`、`used_today`、`rate_limit_per_min` |
| `token_usage_logs` | `TokenUsageLog` | LLM 调用消耗记录 | `user_id`、`session_id`、`model_name`、`input_tokens`、`output_tokens`、`endpoint` |
| `tier_definitions` | `TierDefinition` | 档位定义 | `tier`、`price_monthly`、`daily_quota` |
| `payment_orders` | `PaymentOrder` | 支付订单历史 | `order_no`、`product_type`、`amount`、`status` |

## 学科、资料与知识库

| 表 | ORM | 用途 | 关键字段 |
| --- | --- | --- | --- |
| `subjects` | `Subject` | 用户科目 | `name`、`category`、`description`、`is_pinned`、`is_archived`、`color_index` |
| `documents` | `Document` | 上传学习资料 | `subject_id`、`filename`、`status`、`processing_stage`、`progress`、`chunk_count`、`outline`、`mindmap_ready` |
| `chunks` | `Chunk` | 文档切片 | `document_id`、`subject_id`、`chunk_index`、`content`、`heading_path`、`token_count` |
| `subject_knowledge_bases` | `SubjectKnowledgeBase` | 每科知识库状态 | `status`、`document_count`、`chunk_count`、`outline`、`mindmap_ready` |
| `past_exam_files` | `PastExamFile` | 真题文件 | `subject_id`、`filename`、`status` |
| `past_exam_questions` | `PastExamQuestion` | 真题题目 | `exam_file_id`、`question_number`、`content`、`answer` |

## 对话、思维导图与讲义

| 表 | ORM | 用途 | 关键字段 |
| --- | --- | --- | --- |
| `conversation_sessions` | `ConversationSession` | 会话和导图会话 | `subject_id`、`title`、`session_type`、`is_pinned`、`sort_order` |
| `conversation_history` | `ConversationHistory` | 会话消息 | `session_id`、`role`、`content`、`sources`、`scope_choice` |
| `mindmap_node_states` | `MindmapNodeState` | 导图节点点亮状态 | `user_id`、`session_id`、`node_id`、`is_lit` |
| `node_lectures` | `NodeLecture` | 节点讲义 | `user_id`、`session_id`、`node_id`、`content`、`resource_scope` |
| `mindmap_knowledge_links` | `MindmapKnowledgeLink` | 节点知识关系 | `source_node_id`、`target_node_id`、`link_type`、`rationale` |
| `learning_paths` | `LearningPath` | 学习路径 | `subject_id`、`node_ids`、`prerequisites`、`is_default` |
| `node_masteries` | `NodeMastery` | 节点掌握度 | `mastery_level`、`correct_count`、`wrong_count`、`lecture_read_duration` |

## 笔记、错题与复习

| 表 | ORM | 用途 | 关键字段 |
| --- | --- | --- | --- |
| `notebooks` | `Notebook` | 笔记本 | `name`、`is_system`、`is_pinned`、`is_archived` |
| `notes` | `Note` | 笔记和错题复用表 | `notebook_id`、`subject_id`、`original_content`、`title`、`note_type`、`mistake_status`、`question_text`、`user_answer`、`correct_answer`、`mastery_score` |
| `review_cards` | `ReviewCard` | SM-2 复习卡片 | `node_id`、`ease_factor`、`interval`、`repetitions`、`next_review`、`mastery_score` |
| `review_logs` | `ReviewLog` | 复习日志 | `card_id`、`quality`、`response_time_ms`、`ease_before`、`ease_after` |

## 学习计划、日历与执行

| 表 | ORM | 用途 | 关键字段 |
| --- | --- | --- | --- |
| `study_plans` | `StudyPlan` | 系统学习计划 | `name`、`target_subjects`、`deadline`、`daily_minutes`、`status` |
| `plan_items` | `PlanItem` | 计划条目 | `plan_id`、`subject_id`、`node_id`、`estimated_minutes`、`priority`、`planned_date`、`status`、`capability_id`、`completion_result` |
| `calendar_events` | SQL migration | 日历事件 | `title`、`event_date`、`start_time`、`duration_minutes`、`subject_id`、`source`、`plan_id` |
| `calendar_routines` | SQL migration | 重复例程 | `repeat_type`、`day_of_week`、`start_time`、`duration_minutes` |
| `study_sessions` | SQL migration | 实际学习会话 | `event_id`、`subject_id`、`started_at`、`ended_at`、`duration_minutes`、`pomodoro_count` |
| `feedback_signals` | `FeedbackSignal` | Agent/系统反馈信号 | `level`、`signal_type`、`description`、`trigger_context` |

## 运维与反馈

| 表 | ORM | 用途 | 关键字段 |
| --- | --- | --- | --- |
| `client_incidents` | `ClientIncident` | 客户端问题反馈 | `route`、`description`、`device_info`、`client_logs`、`status`、`storage_dir` |
| `user_memory` | `UserMemory` | 用户学习画像 | `user_id`、`subject_id`、`memory` |
| `hint_suggestions` | `HintSuggestion` | 提示词建议缓存 | `subject_id`、`hint_type`、`hints` |

## 关键关系

```text
User
  -> Subject
      -> Document -> Chunk
      -> ConversationSession(session_type=mindmap)
          -> ConversationHistory
          -> MindmapNodeState
          -> NodeLecture
          -> NodeMastery
      -> StudyPlan -> PlanItem
      -> CalendarEvent / StudySession
      -> Notebook -> Note
      -> ReviewCard -> ReviewLog
```

## 复原注意

- `notes` 同时承载普通笔记和错题，靠 `note_type` 区分。
- 思维导图会话复用 `conversation_sessions`，不是单独的 `mindmaps` 表。
- 日历表主要来自 migration，不在 `database.py` 中完整 ORM 化。
- `plan_items` 已扩展 Capability 字段，是软件工坊/能力调度与学习计划串联的关键。
- `payment_orders` 等支付相关表存在，但当前产品策略可能已迁移到开源/自带 Key 模式，复原时要对照当前支付策略文档。
