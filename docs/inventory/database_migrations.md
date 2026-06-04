# 数据库迁移顺序

本文档描述 `backend/migrations/` 的历史迁移顺序、用途和复原注意事项。它用于从空数据库恢复项目，也用于防止 AI 被旧迁移名和重复编号误导。

## 迁移执行原则

- 新环境优先由 `backend/database.py` 的 ORM 模型创建基础表，再按迁移补齐新增字段和索引。
- 迁移应按编号从小到大执行。
- 遇到同编号迁移必须人工确认执行顺序，不能只按文件名排序后盲跑。
- 执行前备份数据库。
- 迁移脚本最好保持幂等，使用 `IF NOT EXISTS`、字段存在性检测或异常容忍。

## 当前迁移清单

| 顺序 | 文件 | 目的 | 状态与注意事项 |
| --- | --- | --- | --- |
| 001 | `001_create_notebooks_and_notes.sql` | 创建笔记本和笔记相关表 | 有效 |
| 002 | `002_add_avatar_to_users.sql` | 给用户增加头像字段 | 有效 |
| 003 | `003_add_user_memory.sql` | 增加用户长期记忆字段或表 | 有效 |
| 004 | `004_add_mindmap_library_tables.sql` | 增加思维导图、资料库相关表 | 有效 |
| 005 | `005_add_session_pin_sort.sql` | 会话置顶和排序 | 有效 |
| 006 | `006_add_mistake_details_to_notes.sql` | 原计划补错题字段 | 当前为空文件，占位历史 |
| 007 | `007_add_calendar_tables.sql` | 增加日历、计划、学习会话相关表 | 有效 |
| 008 | `008_add_missing_indexes.sql` | 补常用索引 | 有效 |
| 009 | `009_add_mistake_enhanced_fields.sql` | 增强错题字段 | 有效，应视为 006 的真实落地版本之一 |
| 010 | `010_add_sm2_review_to_notes.sql` | 增加 SM-2 复习卡片和复习日志 | 有效 |
| 011a | `011_add_token_tables.sql` | Token 配额和使用记录 | 有效 |
| 011b | `011_remove_payment_add_api_config.sql` | 移除支付依赖并增加 API 配置 | 与 011a 编号冲突，恢复时必须显式处理 |
| 012 | `012_add_payment_tables.sql` | 支付表 | 历史遗留。当前产品文档不把支付作为核心能力，不能据此判断支付已启用 |
| 013 | `013_add_mindmap_knowledge_links.sql` | 思维导图和知识点链接 | 有效 |
| 014 | `014_add_plan_id_to_calendar_events.sql` | 日历事件关联计划 | 有效，存在 `run_014.py` 辅助脚本 |
| 015 | `015_add_model_configs_to_users.sql` | 用户模型配置 | 有效 |
| 016 | `016_add_subject_knowledge_bases.sql` | 科目知识库 | 有效，存在 `run_016.py` 辅助脚本 |
| 017 | `017_add_capability_fields_to_plan_items.sql` | 学习计划项能力字段 | 有效 |
| 018 | `018_add_learning_path_tables.sql` | 学习路径表 | 有效 |
| 019 | `019_add_client_incidents.sql` | 客户端事件和异常上报 | 有效 |
| 020 | `020_add_subject_color_index.sql` | 科目颜色索引 | 有效，存在 `run_020.py` 辅助脚本 |

## 推荐恢复顺序

1. 准备 Python 环境和数据库连接。
2. 使用 ORM 创建当前基础表。
3. 执行 `001` 到 `010`。
4. 执行两个 `011` 文件时人工确认：
   - 先执行 `011_add_token_tables.sql`。
   - 再执行 `011_remove_payment_add_api_config.sql`。
   - 如果迁移工具不支持同编号，应把它们登记为 `011a` 和 `011b`。
5. 执行 `012` 时先判断产品是否需要支付能力。若当前版本采用免费或自带 API 配置模式，可保留表但不要把支付流程暴露为有效功能。
6. 执行 `013` 到 `020`。
7. 对 `014`、`016`、`020` 如 SQL 执行失败，检查对应 `run_*.py` 辅助脚本。
8. 启动后端，调用关键健康路径并运行冒烟测试。

## 迁移和领域模型关系

| 领域 | 主要迁移来源 |
| --- | --- |
| 用户与认证 | ORM 基础表、002、003、015 |
| 科目 | ORM 基础表、016、020 |
| 资料库和思维导图 | 004、013、016 |
| 笔记 | 001 |
| 错题和复习 | 009、010 |
| 日历和学习计划 | 007、014、017、018 |
| Token 和 API 配置 | 011a、011b |
| 客户端异常 | 019 |
| 支付 | 012，当前视为历史遗留 |

## 已知风险

- `006_add_mistake_details_to_notes.sql` 为空，不能作为错题功能已实现的证据。
- 两个 `011` 文件会让简单迁移工具误判顺序。
- `012_add_payment_tables.sql` 和 `011_remove_payment_add_api_config.sql` 在产品语义上有冲突，后续需要决定是否归档支付迁移。
- 旧文档如果声称某表存在，必须回到 `backend/database.py` 和迁移文件核验。

## 后续整改建议

- 建立正式迁移工具，例如 Alembic。
- 将重复 `011` 重命名为唯一版本号，并提供兼容说明。
- 给每个迁移增加校验 SQL 或 Python 检查脚本。
- 在 CI 中加入空库迁移测试。
