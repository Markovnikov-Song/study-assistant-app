import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/dio_client.dart';
import 'notification_service.dart';

// ── Level 3 Monitor ───────────────────────────────────────────────────────────
//
// 连续多天未学习时，升级推送频率。
// 频率升级规则：
//   - 中断 1-2 天：每天 1 次推送
//   - 中断 3-4 天：每天 2 次推送
//   - 中断 5-6 天：每天 3 次推送
//   - 中断 7 天以上：每天 4 次推送
//
// 所有参数均可通过设置页面配置。

// ── Level 3 设置 ──────────────────────────────────────────────────────────────

class Level3Settings {
  /// 是否启用
  final bool enabled;
  /// 中断多少天后开始升级（默认 1 天，即中断 1 天就触发）
  final int escalationStartDays;
  /// 升级间隔（小时），每次升级后下一次推送的间隔缩短
  final int escalationIntervalHours;
  /// 每天最大推送次数
  final int maxDailyPushes;

  const Level3Settings({
    this.enabled = true,
    this.escalationStartDays = 1,
    this.escalationIntervalHours = 12,
    this.maxDailyPushes = 4,
  });

  static const _kEnabled = 'l3_enabled';
  static const _kEscalationDays = 'l3_escalation_days';
  static const _kEscalationInterval = 'l3_escalation_interval';
  static const _kMaxDailyPushes = 'l3_max_daily_pushes';

  static Future<Level3Settings> load() async {
    final p = await SharedPreferences.getInstance();
    return Level3Settings(
      enabled: p.getBool(_kEnabled) ?? true,
      escalationStartDays: p.getInt(_kEscalationDays) ?? 1,
      escalationIntervalHours: p.getInt(_kEscalationInterval) ?? 12,
      maxDailyPushes: p.getInt(_kMaxDailyPushes) ?? 4,
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, enabled);
    await p.setInt(_kEscalationDays, escalationStartDays);
    await p.setInt(_kEscalationInterval, escalationIntervalHours);
    await p.setInt(_kMaxDailyPushes, maxDailyPushes);
  }

  Level3Settings copyWith({
    bool? enabled,
    int? escalationStartDays,
    int? escalationIntervalHours,
    int? maxDailyPushes,
  }) => Level3Settings(
    enabled: enabled ?? this.enabled,
    escalationStartDays: escalationStartDays ?? this.escalationStartDays,
    escalationIntervalHours: escalationIntervalHours ?? this.escalationIntervalHours,
    maxDailyPushes: maxDailyPushes ?? this.maxDailyPushes,
  );
}

// ── SharedPreferences 键 ─────────────────────────────────────────────────────

class Level3Monitor {
  static const _prefLastPushDate = 'l3_last_push_date';
  static const _prefTodayPushCount = 'l3_today_push_count';
  static const _prefLastStreakCheck = 'l3_last_streak_check';

  // ── 实例 ────────────────────────────────────────────────────────────────────

  Timer? _timer;
  Level3Settings _settings = const Level3Settings();
  bool _initialized = false;

  Level3Monitor();

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _settings = await Level3Settings.load();
    _initialized = true;
  }

  /// 更新设置并重启定时器
  Future<void> updateSettings(Level3Settings newSettings) async {
    _settings = newSettings;
    await _settings.save();
    stop();
    start();
  }

  Future<void> start() async {
    _timer?.cancel();
    if (!_settings.enabled) return;

    // 启动时立即检查一次，然后每小时检查一次
    await _ensureInit();
    _check();
    _timer = Timer.periodic(const Duration(hours: 1), (_) => _check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    await _ensureInit();
    if (!_settings.enabled) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 获取 streak_days（失败时快速返回，不阻塞）
    int streakDays;
    try {
      streakDays = await _getStreakDays().timeout(
        const Duration(seconds: 10),
        onTimeout: () => 0,
      );
    } catch (_) {
      // 网络不可用，跳过本次检查
      return;
    }
    
    final streakBrokenDays = await _getStreakBrokenDays().timeout(
      const Duration(seconds: 10),
      onTimeout: () => 0,
    );

    if (streakBrokenDays < _settings.escalationStartDays) {
      return;
    }

    final lastPushDateStr = prefs.getString(_prefLastPushDate);
    DateTime? lastPushDate;
    if (lastPushDateStr != null) {
      lastPushDate = DateTime.tryParse(lastPushDateStr);
    }

    int todayCount = 0;
    if (lastPushDate == today) {
      todayCount = prefs.getInt(_prefTodayPushCount) ?? 0;
    }

    final targetPushes = _calculateTargetPushes(streakBrokenDays);
    if (todayCount >= targetPushes) {
      return;
    }

    final lastCheckStr = prefs.getString(_prefLastStreakCheck);
    DateTime? lastCheck;
    if (lastCheckStr != null) {
      lastCheck = DateTime.tryParse(lastCheckStr);
    }

    final intervalHours = _calculateIntervalHours(streakBrokenDays);
    if (lastCheck != null) {
      final hoursSinceLastCheck = now.difference(lastCheck).inHours;
      if (hoursSinceLastCheck < intervalHours) {
        return;
      }
    }

    await _sendEscalationNotification(streakBrokenDays);

    await prefs.setString(_prefLastStreakCheck, now.toIso8601String());
    await prefs.setString(_prefLastPushDate, today.toIso8601String());
    await prefs.setInt(_prefTodayPushCount, todayCount + 1);
  }

  /// 获取连续学习天数
  Future<int> _getStreakDays() async {
    try {
      final dio = DioClient.instance.dio;
      // 请求最近 30 天数据以计算 streak
      final res = await dio.get('/api/calendar/stats', queryParameters: {
        'period': 'month',
      });
      final data = res.data as Map<String, dynamic>;
      return data['streak_days'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 获取学习连续中断天数（今天没有学习记录）
  Future<int> _getStreakBrokenDays() async {
    try {
      final dio = DioClient.instance.dio;
      final res = await dio.get('/api/calendar/stats', queryParameters: {
        'period': 'week',
      });
      final data = res.data as Map<String, dynamic>;
      
      // 获取 daily_stats 中今天的记录
      final dailyStats = data['daily_stats'] as List? ?? [];
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      bool hasStudyToday = false;
      for (final stat in dailyStats) {
        if (stat is Map && stat['date'] == todayStr && (stat['duration_minutes'] as int? ?? 0) > 0) {
          hasStudyToday = true;
          break;
        }
      }
      
      if (hasStudyToday) {
        // 今天有学习，返回 0
        return 0;
      }
      
      // 今天没学习，计算从哪天开始断的
      final streakDays = data['streak_days'] as int? ?? 0;
      
      // 如果 streak_days == 0，说明今天刚断
      // 如果 streak_days > 0，说明今天没断但 streak_days 是之前计算的
      // 实际上我们需要的是"今天没学习，且已经断了几天"
      
      // 根据 streak_days 和今天是否有学习来推断中断天数
      // 如果 streak_days == 0 且今天没学习，说明断了至少 1 天
      if (streakDays == 0) {
        return 1;
      }
      
      // streak_days > 0 但今天没学习？这种情况不太可能发生，因为
      // streak_days 是从今天往前数连续有学习的天数
      
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// 计算今天应该推送几次
  int _calculateTargetPushes(int streakBrokenDays) {
    if (streakBrokenDays < _settings.escalationStartDays) {
      return 1; // 默认每天 1 次
    }

    // 升级规则：中断天数越多，推送越频繁
    if (streakBrokenDays <= 2) {
      return 1;
    } else if (streakBrokenDays <= 4) {
      return 2;
    } else if (streakBrokenDays <= 6) {
      return 3;
    } else {
      return _settings.maxDailyPushes;
    }
  }

  /// 计算推送间隔（小时）
  int _calculateIntervalHours(int streakBrokenDays) {
    if (streakBrokenDays <= 2) {
      return 24; // 每天 1 次
    } else if (streakBrokenDays <= 4) {
      return 12; // 每天 2 次
    } else if (streakBrokenDays <= 6) {
      return 8;  // 每天 3 次
    } else {
      return 6;   // 每天 4 次
    }
  }

  Future<void> _sendEscalationNotification(int streakBrokenDays) async {
    String title;
    String body;

    if (streakBrokenDays >= 7) {
      title = '⚠️ 已经${streakBrokenDays}天没学习了';
      body = '学习习惯需要保持，今天开始重新学习吧！';
    } else if (streakBrokenDays >= 3) {
      title = '📚 ${streakBrokenDays}天没学习';
      body = '知识会遗忘哦，今天抽空复习一下吧～';
    } else {
      title = '📖 今天还没开始学习';
      body = '别让努力白费，打开 App 继续学习吧';
    }

    await NotificationService.instance.showImmediate(
      id: NotificationIds.streakWarning,
      title: title,
      body: body,
      payload: 'route:/spec',
    );
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final level3MonitorProvider = Provider<Level3Monitor>((ref) {
  final monitor = Level3Monitor();
  return monitor;
});
