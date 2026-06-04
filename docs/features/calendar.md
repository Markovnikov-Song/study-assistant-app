# 学习日历与提醒

## 基本信息

| 字段 | 内容 |
| --- | --- |
| 功能 ID | `calendar.learning_calendar` |
| 当前状态 | 部分实现，Web 可测入口和请求合同，锁屏通知需真机验收 |
| 主要入口 | `/toolkit/calendar`、`/toolkit/calendar/countdown`、`/toolkit/calendar/stats` |
| 后端前缀 | `/api/calendar` |
| 自动化覆盖 | `CAL-P1-01`、`CAL-P1-02` |

## 功能目标

学习日历负责把学习计划落到日期、时间、提醒和统计。它是宏观安排层；番茄钟是微观执行层。

## 用户流程

1. 用户手动创建学习事件，或从学习计划生成事件。
2. 事件显示在日历和今日任务中。
3. 用户设置开始时间、持续时间、优先级和提醒。
4. 系统保存事件到后端。
5. 如果开启提醒，原生通知服务尝试安排本地通知。
6. 用户到时间后收到系统通知，进入日历或启动番茄钟。

## 技术结构

| 层级 | 文件 | 说明 |
| --- | --- | --- |
| 页面 | `lib/features/calendar/calendar_page.dart` | 日历主页面、提醒测试入口 |
| 表单 | `lib/features/calendar/widgets/event_form_sheet.dart` | 创建/编辑事件和提醒设置 |
| 今日任务 | `lib/features/calendar/widgets/today_panel.dart` | 今日事件和番茄钟入口 |
| Provider | `lib/features/calendar/providers/calendar_providers.dart` | 事件、今日任务、统计、番茄钟状态 |
| 通知调度 | `lib/features/calendar/services/calendar_notification_service.dart` | 事件提醒转本地通知 |
| 通知基础服务 | `lib/services/notification_service.dart` | 本地通知、权限、渠道、定时 |
| 后端 | `backend/routers/calendar.py` | 事件、学习 session、统计 |

## API 合同

核心端点：

- `GET /api/calendar/events`
- `POST /api/calendar/events`
- `PATCH /api/calendar/events/{id}`
- `DELETE /api/calendar/events/{id}`
- `POST /api/calendar/sessions`

创建事件请求应包含：

- `title`
- `event_date`
- `start_time`
- `duration_minutes`
- `source`
- `priority`
- `is_countdown`
- 提醒相关字段

## 权限说明

Android：

- Android 13+ 需要 `POST_NOTIFICATIONS`。
- 精确提醒可能受系统精确闹钟能力影响。
- 锁屏横幅、弹窗样式由系统通知渠道、厂商策略和用户设置决定。

iOS：

- 需要用户授权通知。
- 通知展示样式由 iOS 系统控制，应用不能保证“像微信一样”的具体样式。

Web：

- Playwright 只验证页面、面板和请求合同，不验证系统锁屏通知。

## 行为边界

- 如果通知权限不足，创建事件不应失败，只应降级为无系统提醒或提示用户授权。
- 过去时间不应安排未来通知。
- 修改事件时间时应覆盖或取消旧提醒。

## 验证方式

- `npx playwright test tests/playwright/calendar_flow.spec.ts --reporter=list`

验收点：

- 创建事件会请求 `/api/calendar/events`。
- 请求体包含标题、日期、开始时间、持续时间和来源。
- 提醒测试面板可打开且无 fatal browser error。

真机验收：

1. Android/iOS 授权通知。
2. 创建未来 1-2 分钟后的学习事件。
3. 锁屏等待通知。
4. 记录通知是否出现、是否有横幅/声音/锁屏显示。
