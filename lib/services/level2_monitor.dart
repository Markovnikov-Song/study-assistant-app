import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/dio_client.dart';
import '../features/spec/providers/study_planner_providers.dart';
import 'notification_service.dart';

// ── Level 2 Monitor ───────────────────────────────────────────────────────────
//
// 触发条件（每 5 分钟检查一次，可配置间隔）：
//   1. 今日计划完成率 < 50% 且当前时间 > 提醒触发时间（默认 20:00，用户可配置）
//   2. 无学习行为连续时长 > 闲置阈值（默认 15 分钟，用户可配置）
//
// 同一触发条件 30 分钟内最多触发一次（用户可配置冷却时间）。
// 仅在用户有 active study_plan 时生效。
// 同时触发 App 内气泡 + 系统通知（App 在后台时）。

// ── 用户可配置的键 ───────────────────────────────────────────────────────────

class Level2MonitorSettings {
  /// 检查间隔（分钟）
  final int checkIntervalMinutes;
  /// 闲置阈值（分钟）
  final int idleThresholdMinutes;
  /// 完成率阈值（0.0 - 1.0）
  final double completionThreshold;
  /// 冷却时间（分钟）
  final int cooldownMinutes;
  /// 完成率低提醒触发时间（小时，0-23）
  final int completionReminderHour;
  /// 是否启用完成率低提醒
  final bool completionReminderEnabled;
  /// 是否启用闲置提醒
  final bool idleReminderEnabled;

  const Level2MonitorSettings({
    this.checkIntervalMinutes = 5,
    this.idleThresholdMinutes = 15,
    this.completionThreshold = 0.5,
    this.cooldownMinutes = 30,
    this.completionReminderHour = 20,
    this.completionReminderEnabled = true,
    this.idleReminderEnabled = true,
  });

  static const _kCheckInterval    = 'l2_check_interval';
  static const _kIdleThreshold    = 'l2_idle_threshold';
  static const _kCooldown         = 'l2_cooldown';
  static const _kReminderHour      = 'l2_reminder_hour';
  static const _kCompletionEnabled = 'l2_completion_enabled';
  static const _kIdleEnabled       = 'l2_idle_enabled';

  static Future<Level2MonitorSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return Level2MonitorSettings(
      checkIntervalMinutes:   p.getInt(_kCheckInterval)    ?? 5,
      idleThresholdMinutes:   p.getInt(_kIdleThreshold)    ?? 15,
      cooldownMinutes:        p.getInt(_kCooldown)          ?? 30,
      completionReminderHour: p.getInt(_kReminderHour)     ?? 20,
      completionReminderEnabled: p.getBool(_kCompletionEnabled) ?? true,
      idleReminderEnabled:    p.getBool(_kIdleEnabled)      ?? true,
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kCheckInterval,    checkIntervalMinutes);
    await p.setInt(_kIdleThreshold,     idleThresholdMinutes);
    await p.setInt(_kCooldown,          cooldownMinutes);
    await p.setInt(_kReminderHour,       completionReminderHour);
    await p.setBool(_kCompletionEnabled, completionReminderEnabled);
    await p.setBool(_kIdleEnabled,       idleReminderEnabled);
  }

  Level2MonitorSettings copyWith({
    int? checkIntervalMinutes,
    int? idleThresholdMinutes,
    int? cooldownMinutes,
    int? completionReminderHour,
    bool? completionReminderEnabled,
    bool? idleReminderEnabled,
  }) => Level2MonitorSettings(
    checkIntervalMinutes:   checkIntervalMinutes   ?? this.checkIntervalMinutes,
    idleThresholdMinutes:   idleThresholdMinutes   ?? this.idleThresholdMinutes,
    cooldownMinutes:        cooldownMinutes        ?? this.cooldownMinutes,
    completionReminderHour: completionReminderHour ?? this.completionReminderHour,
    completionReminderEnabled: completionReminderEnabled ?? this.completionReminderEnabled,
    idleReminderEnabled:    idleReminderEnabled    ?? this.idleReminderEnabled,
  );
}

// ── SharedPreferences 键（保持向后兼容）─────────────────────────────────────

class Level2Monitor {
  static const _prefLastActivity = 'l2_last_activity';
  static const _prefLastTriggerCompletion = 'l2_last_trigger_completion';
  static const _prefLastTriggerIdle = 'l2_last_trigger_idle';

  // ── 实例 ────────────────────────────────────────────────────────────────────

  Timer? _timer;
  final WidgetRef _ref;
  final BuildContext Function() _contextGetter;
  Level2MonitorSettings _settings = const Level2MonitorSettings();
  bool _initialized = false;

  Level2Monitor(this._ref, this._contextGetter);

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _settings = await Level2MonitorSettings.load();
    _initialized = true;
  }

  /// 更新设置并重启定时器
  Future<void> updateSettings(Level2MonitorSettings newSettings) async {
    _settings = newSettings;
    await _settings.save();
    // 重启定时器以应用新的检查间隔
    stop();
    start();
  }

  void start() {
    _timer?.cancel();
    // 默认 5 分钟检查一次
    _timer = Timer.periodic(
      Duration(minutes: _settings.checkIntervalMinutes),
      (_) => _check(),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// 记录用户活跃（在 ChatPage / LecturePage 等页面调用）
  static Future<void> recordActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLastActivity, DateTime.now().toIso8601String());
  }

  Future<void> _check() async {
    await _ensureInit();

    final context = _contextGetter();
    if (!context.mounted) return;

    // 检查是否有 active 计划
    final planAsync = _ref.read(activePlanProvider);
    final plan = planAsync.valueOrNull;
    if (plan == null || !plan.isActive) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // 条件 1：今日完成率 < 阈值 且已过提醒时间
    if (_settings.completionReminderEnabled && now.hour >= _settings.completionReminderHour) {
      final todayItems = _ref.read(todayPlanItemsProvider).valueOrNull ?? [];
      if (todayItems.isNotEmpty) {
        final done = todayItems.where((i) => i.isDone || i.isSkipped).length;
        final rate = done / todayItems.length;
        if (rate < _settings.completionThreshold) {
          final lastTrigger = prefs.getString(_prefLastTriggerCompletion);
          if (_canTrigger(lastTrigger, now)) {
            await prefs.setString(_prefLastTriggerCompletion, now.toIso8601String());
            if (!context.mounted) return;
            await _trigger(
              context,
              focusMinutes: 0,
              mistakeCount: 0,
              fallback: '今天的计划还没完成，要继续加油哦～',
              triggerType: 'completion',
            );
            return;
          }
        }
      }
    }

    // 条件 2：无学习行为 > 闲置阈值
    if (_settings.idleReminderEnabled) {
      final lastActivityStr = prefs.getString(_prefLastActivity);
      if (lastActivityStr != null) {
        final lastActivity = DateTime.tryParse(lastActivityStr);
        if (lastActivity != null) {
          final idleMinutes = now.difference(lastActivity).inMinutes;
          if (idleMinutes >= _settings.idleThresholdMinutes) {
            final lastTrigger = prefs.getString(_prefLastTriggerIdle);
            if (_canTrigger(lastTrigger, now)) {
              await prefs.setString(_prefLastTriggerIdle, now.toIso8601String());
              if (!context.mounted) return;
              await _trigger(
                context,
                focusMinutes: 0,
                mistakeCount: 0,
                fallback: '已经有一段时间没有学习了，要不要继续今天的计划？',
                triggerType: 'idle',
              );
            }
          }
        }
      }
    }
  }

  bool _canTrigger(String? lastTriggerStr, DateTime now) {
    if (lastTriggerStr == null) return true;
    final last = DateTime.tryParse(lastTriggerStr);
    if (last == null) return true;
    return now.difference(last).inMinutes >= _settings.cooldownMinutes;
  }

  Future<void> _trigger(
    BuildContext context, {
    required int focusMinutes,
    required int mistakeCount,
    required String fallback,
    required String triggerType,
  }) async {
    String message = fallback;

    // 尝试调用 companion_observe 获取 AI 文案
    try {
      final dio = DioClient.instance.dio;
      final res = await dio.post('/api/council/companion/observe', data: {
        'focus_minutes': focusMinutes,
        'mistake_count': mistakeCount,
        'trigger_type': triggerType,
      });
      final data = res.data as Map<String, dynamic>;
      final aiMessage = data['message'] as String?;
      if (aiMessage != null && aiMessage.isNotEmpty) {
        message = aiMessage;
      }
    } catch (e) {
      debugPrint('[Level2Monitor] AI 文案获取失败，使用兜底文案: $e');
    }

    if (!context.mounted) return;

    // Level 1: App 内气泡（前台显示）
    _CompanionBubble.show(context, message);

    // Level 2: 系统通知（后台也推送）
    final notificationTitle = triggerType == 'completion'
        ? '今日计划待完成'
        : '学习提醒';
    await NotificationService.instance.showImmediate(
      id: NotificationIds.level2Reminder,
      title: notificationTitle,
      body: message,
      payload: 'route:/spec',
    );
  }
}

// ── 助教气泡 Widget ───────────────────────────────────────────────────────────

class _CompanionBubble extends StatefulWidget {
  final String message;
  final VoidCallback onClose;

  const _CompanionBubble({required this.message, required this.onClose});

  static OverlayEntry? _entry;

  static void show(BuildContext context, String message) {
    _entry?.remove();
    _entry = OverlayEntry(
      builder: (_) => _CompanionBubbleOverlay(
        message: message,
        onClose: () {
          _entry?.remove();
          _entry = null;
        },
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  @override
  State<_CompanionBubble> createState() => _CompanionBubbleOverlayState();
}

class _CompanionBubbleOverlay extends StatefulWidget {
  final String message;
  final VoidCallback onClose;

  const _CompanionBubbleOverlay({required this.message, required this.onClose});

  @override
  State<_CompanionBubbleOverlay> createState() => _CompanionBubbleOverlayState();
}

class _CompanionBubbleOverlayState extends State<_CompanionBubbleOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();

    // 10 秒后自动关闭
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) _close();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _close() {
    _ctrl.reverse().then((_) => widget.onClose());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      bottom: 100,
      right: 16,
      child: FadeTransition(
        opacity: _anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.3, 0),
            end: Offset.zero,
          ).animate(_anim),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: cs.primaryContainer,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 260),
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 助教头像
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.school_outlined, size: 18, color: cs.onPrimary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onPrimaryContainer,
                        height: 1.4,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: cs.outline),
                    onPressed: _close,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
// Level2Monitor 直接在 SpecPage 里实例化，不需要 Provider
