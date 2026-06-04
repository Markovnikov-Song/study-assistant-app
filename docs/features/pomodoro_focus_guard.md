# 番茄钟与专注防打扰

## 基本信息

| 字段 | 内容 |
| --- | --- |
| 功能 ID | `calendar.pomodoro_focus_guard` |
| 当前状态 | Android 部分可用，iOS 受 Screen Time entitlement 限制，Web 只做降级显示 |
| 主要入口 | `/toolkit/calendar` 今日任务 -> 番茄钟悬浮球 -> 防打扰 |
| 后端前缀 | `/api/calendar/sessions` |
| 自动化覆盖 | `POMO-P1-01`、`POMO-P1-02`、`POMO-P1-03` |

## 功能目标

番茄钟负责微观学习执行状态。用户从今日学习事件启动番茄钟后，页面显示一个可爱的可拖拽悬浮球，持续展示剩余时间、当前事件和控制按钮。

专注防打扰用于减少分心应用。Android 端通过使用情况访问权限识别当前前台 App，通过悬浮窗在白名单外 App 上方展示拦截提示，引导用户回到学习。

## 用户流程

1. 用户在学习日历今日任务中点击番茄钟入口。
2. 页面出现可拖拽悬浮球。
3. 用户点击悬浮球展开控制面板。
4. 用户可暂停、继续、结束当前番茄钟。
5. 用户打开防打扰面板。
6. 用户开启防打扰和锁应用。
7. Android 用户按提示开启使用情况访问和悬浮窗权限。
8. 用户设置允许使用的 App 白名单。
9. 番茄钟运行期间打开白名单外 App 时，Android 前台服务尝试显示拦截悬浮层。
10. 番茄钟结束后，前台服务停止。

## 已实现能力

- 番茄钟悬浮球显示、拖拽、展开。
- 专注、休息、暂停三种视觉状态。
- 暂停、继续、结束和写入学习 session。
- 防打扰设置面板。
- Android 使用情况访问权限状态读取。
- Android 悬浮窗权限状态读取。
- Android 已安装启动器 App 列表读取。
- Android 白名单保存。
- Android 前台服务 `FocusGuardService`。
- iOS 能力状态返回和限制说明。

## 技术结构

| 层级 | 文件 | 说明 |
| --- | --- | --- |
| 悬浮球 UI | `lib/features/calendar/widgets/pomodoro_timer.dart` | 番茄钟悬浮球、面板、防打扰设置 |
| 番茄状态 | `lib/features/calendar/providers/calendar_providers.dart` | 启动、暂停、继续、结束、学习 session |
| 防打扰状态 | `lib/features/calendar/providers/focus_guard_provider.dart` | 设置、权限、白名单、本地保存 |
| 平台通道 | `lib/services/focus_guard_platform_service.dart` | `focus_guard` MethodChannel |
| Android Activity | `android/app/src/main/kotlin/cn/studyassistant/app/MainActivity.kt` | 权限、App 列表、服务启停 |
| Android 服务 | `android/app/src/main/kotlin/cn/studyassistant/app/FocusGuardService.kt` | 前台 App 监控和拦截悬浮层 |
| Android Manifest | `android/app/src/main/AndroidManifest.xml` | 权限和前台服务声明 |
| iOS | `ios/Runner/AppDelegate.swift` | iOS 能力状态 |

## 权限说明

Android：

- `PACKAGE_USAGE_STATS`：读取当前前台 App。
- `SYSTEM_ALERT_WINDOW`：在其他 App 上方显示拦截层。
- `FOREGROUND_SERVICE`：运行前台服务。
- `FOREGROUND_SERVICE_SPECIAL_USE`：Android 14+ 前台服务类型声明。
- `POST_NOTIFICATIONS`：前台服务通知和学习提醒。

iOS：

真正跨 App 屏蔽需要 Apple Screen Time 相关能力：

- FamilyControls
- ManagedSettings
- DeviceActivity
- Apple 授予的 Screen Time entitlement

当前 iOS 不伪装成已能锁应用，只展示能力状态和限制。

## 数据与状态

本地保存：

- `focus_guard_enabled`
- `focus_guard_app_lock_enabled`
- `focus_guard_keep_screen_awake`
- `focus_guard_allowed_packages`

后端记录：

- `POST /api/calendar/sessions`
- 字段包括 `event_id`、`duration_minutes`、`pomodoro_count` 等。

## 行为边界

- Android 防打扰不是系统级家长控制，只是学习提醒和悬浮拦截。
- 厂商系统可能要求额外后台运行、自启动、电池无限制和锁屏显示设置。
- 用户可以随时关闭使用情况访问或悬浮窗权限。
- Web 无法验证应用锁，只能验证 UI 降级和无崩溃。

## 验证方式

自动化：

- `npx playwright test tests/playwright/calendar_flow.spec.ts --reporter=list`

验收点：

- 今日任务可以启动悬浮番茄钟。
- 悬浮球可展开。
- 暂停、继续、结束会写入 `/api/calendar/sessions`。
- 防打扰设置面板可打开。

Android 真机：

1. 安装 APK。
2. 开启通知、使用情况访问、悬浮窗权限。
3. 启动番茄钟并开启锁应用。
4. 设置白名单。
5. 切到白名单外 App，确认出现拦截层。
6. 点击回到学习，确认返回伴学。
7. 停止番茄钟，确认前台服务通知消失。
