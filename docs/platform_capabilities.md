# 平台能力与权限矩阵

## 总览

| 能力 | Android | iOS | Web/桌面 | 说明 |
| --- | --- | --- | --- | --- |
| 本地学习提醒 | 支持 | 支持 | 受限 | Android/iOS 均需通知授权 |
| 精确定时提醒 | 支持但需权限 | 系统控制 | 受限 | Android 可检查精确闹钟能力 |
| 锁屏横幅通知 | 支持但受系统频道影响 | 支持但受系统设置影响 | 不适用 | 不能保证像微信一样弹出 |
| 番茄悬浮球 | 应用内支持 | 应用内支持 | 应用内支持 | 当前是应用内悬浮，不跨 App |
| 跨应用防打扰 | 支持温和锁 | 受限 | 不支持 | Android 通过 UsageStats + Overlay |
| 读取已安装 App | 支持 | 不支持 | 不支持 | Android 启动器 App 列表 |
| 覆盖其他 App | 支持但需悬浮窗 | 不支持 | 不支持 | iOS 普通 App 不允许 |
| Screen Time 锁 App | 不适用 | 需 entitlement | 不适用 | 需要 Apple 授权 |
| APK 应用内安装 | 支持 | 不适用 | 不适用 | Android FileProvider |

## Android 权限

| 权限 | 用途 | 授权方式 | 相关功能 |
| --- | --- | --- | --- |
| `POST_NOTIFICATIONS` | 通知提醒、前台服务通知 | 系统弹窗 | 日历提醒、番茄防打扰 |
| `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` | 精确定时提醒 | 系统设置/声明 | 日历提醒 |
| `RECEIVE_BOOT_COMPLETED` | 开机恢复定时任务 | Manifest | 日历提醒 |
| `VIBRATE` | 通知震动 | Manifest | 日历提醒 |
| `PACKAGE_USAGE_STATS` | 查询当前前台 App | 用户到设置页开启 | 专注防打扰 |
| `SYSTEM_ALERT_WINDOW` | 显示跨应用拦截浮层 | 用户到设置页开启 | 专注防打扰 |
| `FOREGROUND_SERVICE` | 运行前台服务 | Manifest | 专注防打扰 |
| `FOREGROUND_SERVICE_SPECIAL_USE` | Android 14+ 特殊前台服务类型 | Manifest | 专注防打扰 |
| `REQUEST_INSTALL_PACKAGES` | 安装下载的 APK | 用户到设置页开启 | 应用内更新 |
| `WAKE_LOCK` | 降低后台中断概率 | Manifest | 下载、前台服务 |

## iOS 限制

iOS 普通应用不能：

- 读取其他 App 的前台运行状态。
- 在其他 App 上方显示悬浮窗。
- 未经 Apple entitlement 锁定其他 App。

iOS 如需真正实现应用限制，需要申请并集成：

- FamilyControls
- ManagedSettings
- DeviceActivity
- Screen Time entitlement

当前项目仅保留 iOS 能力状态入口，不把锁应用伪装成可用能力。

## 厂商系统注意

部分 Android 厂商系统可能需要额外设置：

- 后台运行权限。
- 自启动权限。
- 电池优化白名单。
- 锁屏显示通知。
- 悬浮窗显示在其他应用上层。
- 通知频道高优先级。

这些设置无法全部由 App 自动完成，必须在 UI 中提示用户。
