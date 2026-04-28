import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ── 通知 ID 常量 ──────────────────────────────────────────────────────────────

class NotificationIds {
  static const int dailyStudyReminder = 1001;   // 每日学习提醒
  static const int reviewDueReminder  = 1002;   // 复习到期提醒
  static const int planIncomplete     = 1003;   // 今日计划未完成
  static const int streakWarning      = 1004;   // 连续学习中断警告
  static const int planGenerated      = 1005;   // 计划生成完成（一次性）
  static const int level2Reminder     = 1006;   // Level 2 学习提醒（完成率低/闲置）
}

// ── 通知设置（用户可配置）────────────────────────────────────────────────────

class NotificationSettings {
  /// 每日学习提醒是否开启
  final bool dailyReminderEnabled;
  /// 每日提醒时间（小时）
  final int dailyReminderHour;
  /// 每日提醒时间（分钟）
  final int dailyReminderMinute;

  /// 复习到期提醒是否开启
  final bool reviewReminderEnabled;
  /// 复习提醒时间（小时）
  final int reviewReminderHour;

  /// 计划未完成提醒是否开启
  final bool planReminderEnabled;
  /// 计划未完成提醒时间（小时，默认 20:00）
  final int planReminderHour;

  /// 连续学习中断警告（连续 N 天未学习时触发）
  final bool streakWarningEnabled;
  final int streakWarningDays;

  const NotificationSettings({
    this.dailyReminderEnabled = true,
    this.dailyReminderHour = 19,
    this.dailyReminderMinute = 0,
    this.reviewReminderEnabled = true,
    this.reviewReminderHour = 9,
    this.planReminderEnabled = true,
    this.planReminderHour = 20,
    this.streakWarningEnabled = true,
    this.streakWarningDays = 3,
  });

  static const _kDailyEnabled    = 'notif_daily_enabled';
  static const _kDailyHour       = 'notif_daily_hour';
  static const _kDailyMinute     = 'notif_daily_minute';
  static const _kReviewEnabled   = 'notif_review_enabled';
  static const _kReviewHour      = 'notif_review_hour';
  static const _kPlanEnabled     = 'notif_plan_enabled';
  static const _kPlanHour        = 'notif_plan_hour';
  static const _kStreakEnabled   = 'notif_streak_enabled';
  static const _kStreakDays      = 'notif_streak_days';

  static Future<NotificationSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return NotificationSettings(
      dailyReminderEnabled: p.getBool(_kDailyEnabled) ?? true,
      dailyReminderHour:    p.getInt(_kDailyHour)    ?? 19,
      dailyReminderMinute:  p.getInt(_kDailyMinute)  ?? 0,
      reviewReminderEnabled: p.getBool(_kReviewEnabled) ?? true,
      reviewReminderHour:   p.getInt(_kReviewHour)   ?? 9,
      planReminderEnabled:  p.getBool(_kPlanEnabled)  ?? true,
      planReminderHour:     p.getInt(_kPlanHour)      ?? 20,
      streakWarningEnabled: p.getBool(_kStreakEnabled) ?? true,
      streakWarningDays:    p.getInt(_kStreakDays)    ?? 3,
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDailyEnabled,   dailyReminderEnabled);
    await p.setInt(_kDailyHour,       dailyReminderHour);
    await p.setInt(_kDailyMinute,     dailyReminderMinute);
    await p.setBool(_kReviewEnabled,  reviewReminderEnabled);
    await p.setInt(_kReviewHour,      reviewReminderHour);
    await p.setBool(_kPlanEnabled,    planReminderEnabled);
    await p.setInt(_kPlanHour,        planReminderHour);
    await p.setBool(_kStreakEnabled,  streakWarningEnabled);
    await p.setInt(_kStreakDays,      streakWarningDays);
  }

  NotificationSettings copyWith({
    bool? dailyReminderEnabled,
    int? dailyReminderHour,
    int? dailyReminderMinute,
    bool? reviewReminderEnabled,
    int? reviewReminderHour,
    bool? planReminderEnabled,
    int? planReminderHour,
    bool? streakWarningEnabled,
    int? streakWarningDays,
  }) => NotificationSettings(
    dailyReminderEnabled:  dailyReminderEnabled  ?? this.dailyReminderEnabled,
    dailyReminderHour:     dailyReminderHour     ?? this.dailyReminderHour,
    dailyReminderMinute:   dailyReminderMinute   ?? this.dailyReminderMinute,
    reviewReminderEnabled: reviewReminderEnabled ?? this.reviewReminderEnabled,
    reviewReminderHour:    reviewReminderHour    ?? this.reviewReminderHour,
    planReminderEnabled:   planReminderEnabled   ?? this.planReminderEnabled,
    planReminderHour:      planReminderHour      ?? this.planReminderHour,
    streakWarningEnabled:  streakWarningEnabled  ?? this.streakWarningEnabled,
    streakWarningDays:     streakWarningDays     ?? this.streakWarningDays,
  );
}

// ── NotificationService ───────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  static const String _androidNotifIcon = '@mipmap/ic_launcher_1';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── 初始化 ────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    // 尝试设置本地时区，失败时用 UTC
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    } catch (e) {
      debugPrint('[NotificationService] 时区设置失败，使用 UTC: $e');
    }

    const android = AndroidInitializationSettings(_androidNotifIcon);
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    try {
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
      _initialized = true;
    } catch (e) {
      // Avoid app boot blocking if notification icon/resource init fails.
      debugPrint('[NotificationService] 初始化失败，已降级跳过通知能力: $e');
      _initialized = false;
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    // 通知点击后的路由跳转由 App 层处理
    // payload 格式：'route:/spec' 或 'route:/toolkit/review'
    final payload = response.payload;
    if (payload != null && payload.startsWith('route:')) {
      _pendingRoute = payload.substring(6);
    }
  }

  String? _pendingRoute;

  /// App 启动时检查是否有待处理的通知跳转
  String? consumePendingRoute() {
    final r = _pendingRoute;
    _pendingRoute = null;
    return r;
  }

  // ── 权限请求 ──────────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return true;
  }

  // ── 通知详情 ──────────────────────────────────────────────────────────────

  NotificationDetails _details({
    String channelId = 'study_reminder',
    String channelName = '学习提醒',
    String? channelDesc,
    Importance importance = Importance.high,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc ?? channelName,
        importance: importance,
        priority: Priority.high,
        icon: _androidNotifIcon,
        styleInformation: const BigTextStyleInformation(''),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  // ── 立即发送（一次性，用于计划生成完成等）────────────────────────────────

  Future<void> showImmediate({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(id, title, body, _details(), payload: payload);
  }

  // ── 每日定时推送 ──────────────────────────────────────────────────────────

  Future<void> scheduleDailyAt({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOf(hour, minute),
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // 每天重复
      payload: payload,
    );
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // ── 取消特定通知 ──────────────────────────────────────────────────────────

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();

  /// 取消所有复习提醒（cancelAll 的别名，供 ReviewReminderService 使用）
  Future<void> cancelAllReminders() => cancelAll();

  /// 取消单条复习提醒
  Future<void> cancelReminder(int id) => cancel(id);

  /// 安排单次复习提醒（指定 DateTime，而非每天重复）
  Future<void> scheduleReviewReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      _details(channelId: 'review_reminder', channelName: '复习提醒'),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  // ── 根据设置重新调度所有通知 ─────────────────────────────────────────────

  Future<void> rescheduleAll(NotificationSettings settings) async {
    await cancelAll();

    // 1. 每日学习提醒
    if (settings.dailyReminderEnabled) {
      await scheduleDailyAt(
        id: NotificationIds.dailyStudyReminder,
        title: '📚 今天学了吗？',
        body: '打开伴学，继续今天的学习计划',
        hour: settings.dailyReminderHour,
        minute: settings.dailyReminderMinute,
        payload: 'route:/',
      );
    }

    // 2. 复习到期提醒
    if (settings.reviewReminderEnabled) {
      await scheduleDailyAt(
        id: NotificationIds.reviewDueReminder,
        title: '🔁 有错题等待复盘',
        body: '今天有待复习的知识点，趁热打铁效果更好',
        hour: settings.reviewReminderHour,
        minute: 0,
        payload: 'route:/toolkit/review',
      );
    }

    // 3. 计划未完成提醒
    if (settings.planReminderEnabled) {
      await scheduleDailyAt(
        id: NotificationIds.planIncomplete,
        title: '📋 今日计划还没完成',
        body: '距离目标又近了一步，加油！',
        hour: settings.planReminderHour,
        minute: 0,
        payload: 'route:/spec',
      );
    }
  }
}
