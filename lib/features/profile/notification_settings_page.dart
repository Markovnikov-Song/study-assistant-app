import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/notification_service.dart';
import '../../services/level3_monitor.dart';

final notificationSettingsProvider =
    StateNotifierProvider<_NotifSettingsNotifier, NotificationSettings>(
  (_) => _NotifSettingsNotifier(),
);

final level3SettingsProvider =
    StateNotifierProvider<_Level3SettingsNotifier, Level3Settings>(
  (_) => _Level3SettingsNotifier(),
);

class _NotifSettingsNotifier extends StateNotifier<NotificationSettings> {
  _NotifSettingsNotifier() : super(const NotificationSettings()) {
    _load();
  }

  Future<void> _load() async {
    state = await NotificationSettings.load();
  }

  Future<void> update(NotificationSettings s) async {
    state = s;
    await s.save();
    await NotificationService.instance.rescheduleAll(s);
  }
}

class _Level3SettingsNotifier extends StateNotifier<Level3Settings> {
  _Level3SettingsNotifier() : super(const Level3Settings()) {
    _load();
  }

  Future<void> _load() async {
    state = await Level3Settings.load();
  }

  Future<void> update(Level3Settings s) async {
    state = s;
    await s.save();
  }
}

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知设置'),
        centerTitle: false,
      ),
      body: ListView(
        children: [
          // ── 每日学习提醒 ────────────────────────────────────────────────
          _SectionHeader('每日学习提醒'),
          SwitchListTile(
            title: const Text('开启每日提醒'),
            subtitle: const Text('每天固定时间提醒你打开 App 学习'),
            value: settings.dailyReminderEnabled,
            onChanged: (v) => notifier.update(settings.copyWith(dailyReminderEnabled: v)),
          ),
          if (settings.dailyReminderEnabled)
            _TimePicker(
              label: '提醒时间',
              hour: settings.dailyReminderHour,
              minute: settings.dailyReminderMinute,
              onChanged: (h, m) => notifier.update(
                settings.copyWith(dailyReminderHour: h, dailyReminderMinute: m),
              ),
            ),

          const Divider(height: 1),

          // ── 复习到期提醒 ────────────────────────────────────────────────
          _SectionHeader('错题复习提醒'),
          SwitchListTile(
            title: const Text('开启复习提醒'),
            subtitle: const Text('有待复盘的错题时提醒你'),
            value: settings.reviewReminderEnabled,
            onChanged: (v) => notifier.update(settings.copyWith(reviewReminderEnabled: v)),
          ),
          if (settings.reviewReminderEnabled)
            _TimePicker(
              label: '提醒时间',
              hour: settings.reviewReminderHour,
              minute: 0,
              showMinute: false,
              onChanged: (h, _) => notifier.update(
                settings.copyWith(reviewReminderHour: h),
              ),
            ),

          const Divider(height: 1),

          // ── 计划未完成提醒 ──────────────────────────────────────────────
          _SectionHeader('学习计划提醒'),
          SwitchListTile(
            title: const Text('开启计划提醒'),
            subtitle: const Text('今日计划未完成时在晚间提醒'),
            value: settings.planReminderEnabled,
            onChanged: (v) => notifier.update(settings.copyWith(planReminderEnabled: v)),
          ),
          if (settings.planReminderEnabled)
            _TimePicker(
              label: '提醒时间',
              hour: settings.planReminderHour,
              minute: 0,
              showMinute: false,
              onChanged: (h, _) => notifier.update(
                settings.copyWith(planReminderHour: h),
              ),
            ),

          const Divider(height: 1),

          // ── Level 2 智能提醒（App 后台/关闭时）───────────────────────────
          _SectionHeader('智能学习提醒'),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '今日计划完成率低或长时间未学习时，即使 App 在后台也会推送通知',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          SwitchListTile(
            title: const Text('开启智能提醒'),
            subtitle: const Text('完成率低提醒 + 闲置提醒'),
            value: settings.streakWarningEnabled,
            onChanged: (v) => notifier.update(settings.copyWith(streakWarningEnabled: v)),
          ),
          if (settings.streakWarningEnabled) ...[
            ListTile(
              title: const Text('完成率提醒时间'),
              subtitle: Text('每日 ${settings.planReminderHour.toString().padLeft(2, '0')}:00 后检测'),
              trailing: TextButton(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: settings.planReminderHour, minute: 0),
                  );
                  if (picked != null) {
                    notifier.update(settings.copyWith(planReminderHour: picked.hour));
                  }
                },
                child: Text(
                  '${settings.planReminderHour.toString().padLeft(2, '0')}:00',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.primary),
                ),
              ),
            ),
            ListTile(
              title: const Text('闲置提醒阈值'),
              subtitle: Text('${settings.streakWarningDays} 分钟无学习行为时触发'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: settings.streakWarningDays > 5
                        ? () => notifier.update(settings.copyWith(streakWarningDays: settings.streakWarningDays - 5))
                        : null,
                  ),
                  Text(
                    '${settings.streakWarningDays}',
                    style: TextStyle(fontSize: 16, color: cs.primary, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: settings.streakWarningDays < 120
                        ? () => notifier.update(settings.copyWith(streakWarningDays: settings.streakWarningDays + 5))
                        : null,
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('冷却时间'),
              subtitle: Text('同一条件 ${settings.dailyReminderMinute == 0 ? 30 : settings.dailyReminderMinute} 分钟内不重复提醒'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: settings.dailyReminderMinute > 10
                        ? () => notifier.update(settings.copyWith(dailyReminderMinute: settings.dailyReminderMinute - 10))
                        : null,
                  ),
                  Text(
                    '${settings.dailyReminderMinute == 0 ? 30 : settings.dailyReminderMinute}',
                    style: TextStyle(fontSize: 16, color: cs.primary, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: settings.dailyReminderMinute < 120
                        ? () => notifier.update(settings.copyWith(dailyReminderMinute: settings.dailyReminderMinute + 10))
                        : null,
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 1),

          // ── 连续学习中断警告 ────────────────────────────────────────────
          _SectionHeader('学习中断警告'),
          // 复用 streakWarningEnabled 作为 Level 3 总开关
          SwitchListTile(
            title: const Text('开启中断警告'),
            subtitle: const Text('连续多天未学习时发出更强提醒（频率升级）'),
            value: settings.streakWarningEnabled,
            onChanged: (v) => notifier.update(settings.copyWith(streakWarningEnabled: v)),
          ),
          if (settings.streakWarningEnabled) ...[
            // Level 3 详细设置
            _Level3SettingsSection(),
          ],

          const Divider(height: 1),

          // ── 测试按钮 ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () async {
                await NotificationService.instance.showImmediate(
                  id: 9999,
                  title: '📚 测试通知',
                  body: '通知功能正常工作！',
                  payload: 'route:/',
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('测试通知已发送')),
                  );
                }
              },
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('发送测试通知'),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── 辅助 Widget ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _TimePicker extends StatelessWidget {
  final String label;
  final int hour;
  final int minute;
  final bool showMinute;
  final void Function(int hour, int minute) onChanged;

  const _TimePicker({
    required this.label,
    required this.hour,
    required this.minute,
    required this.onChanged,
    this.showMinute = true,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = showMinute
        ? '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}'
        : '${hour.toString().padLeft(2, '0')}:00';

    return ListTile(
      title: Text(label),
      trailing: TextButton(
        onPressed: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: hour, minute: minute),
          );
          if (picked != null) {
            onChanged(picked.hour, picked.minute);
          }
        },
        child: Text(
          timeStr,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

// ── Level 3 频率升级设置 ─────────────────────────────────────────────────────

class _Level3SettingsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(level3SettingsProvider);
    final notifier = ref.read(level3SettingsProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // 频率升级说明
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            '频率升级规则：\n'
            '• 中断 1-2 天：每天 1 次\n'
            '• 中断 3-4 天：每天 2 次\n'
            '• 中断 5-6 天：每天 3 次\n'
            '• 中断 7 天以上：每天 4 次',
            style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
          ),
        ),
        // 开始升级的阈值
        ListTile(
          title: const Text('开始升级天数'),
          subtitle: Text('中断 ${settings.escalationStartDays} 天后开始升级频率'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: settings.escalationStartDays > 1
                    ? () => notifier.update(settings.copyWith(
                          escalationStartDays: settings.escalationStartDays - 1,
                        ))
                    : null,
              ),
              Text(
                '${settings.escalationStartDays}',
                style: TextStyle(fontSize: 16, color: cs.primary, fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: settings.escalationStartDays < 7
                    ? () => notifier.update(settings.copyWith(
                          escalationStartDays: settings.escalationStartDays + 1,
                        ))
                    : null,
              ),
            ],
          ),
        ),
        // 每天最大推送次数
        ListTile(
          title: const Text('每天最大推送次数'),
          subtitle: Text('最多 ${settings.maxDailyPushes} 次/天'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: settings.maxDailyPushes > 1
                    ? () => notifier.update(settings.copyWith(
                          maxDailyPushes: settings.maxDailyPushes - 1,
                        ))
                    : null,
              ),
              Text(
                '${settings.maxDailyPushes}',
                style: TextStyle(fontSize: 16, color: cs.primary, fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: settings.maxDailyPushes < 8
                    ? () => notifier.update(settings.copyWith(
                          maxDailyPushes: settings.maxDailyPushes + 1,
                        ))
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
