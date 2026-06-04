import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/calendar_models.dart';
import '../providers/calendar_providers.dart';
import '../providers/focus_guard_provider.dart';
import '../../../services/focus_guard_platform_service.dart';

/// 可拖拽番茄悬浮球：专注时显示在日历上方，点击展开控制面板。
class PomodoroFloatingBar extends ConsumerStatefulWidget {
  const PomodoroFloatingBar({super.key});

  @override
  ConsumerState<PomodoroFloatingBar> createState() =>
      _PomodoroFloatingBarState();
}

class _PomodoroFloatingBarState extends ConsumerState<PomodoroFloatingBar> {
  static const _bubbleSize = 76.0;
  static const _panelWidth = 320.0;
  Offset? _offset;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pomodoroTimerProvider);
    if (!state.isRunning && state.phase != PomodoroPhase.paused) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final offset = _resolvedOffset(constraints);
        final clamped = _clampOffset(offset, constraints);
        if (clamped != offset) _offset = clamped;

        return Stack(
          children: [
            Positioned(
              left: clamped.dx,
              top: clamped.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _offset = _clampOffset(
                      clamped + details.delta,
                      constraints,
                    );
                  });
                },
                child: _expanded
                    ? _PomodoroPanel(
                        width: math.min(_panelWidth, constraints.maxWidth - 24),
                        onCollapse: () => setState(() => _expanded = false),
                      )
                    : GestureDetector(
                        onTap: () => setState(() => _expanded = true),
                        child: const _PomodoroBubble(),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Offset _resolvedOffset(BoxConstraints constraints) {
    if (_offset != null) return _offset!;
    return Offset(
      math.max(12, constraints.maxWidth - _bubbleSize - 20),
      math.max(96, constraints.maxHeight - _bubbleSize - 112),
    );
  }

  Offset _clampOffset(Offset offset, BoxConstraints constraints) {
    final width = _expanded
        ? math.min(_panelWidth, constraints.maxWidth - 24)
        : _bubbleSize;
    final height = _expanded ? 220.0 : _bubbleSize;
    return Offset(
      offset.dx.clamp(12.0, math.max(12.0, constraints.maxWidth - width - 12)),
      offset.dy.clamp(
        12.0,
        math.max(12.0, constraints.maxHeight - height - 12),
      ),
    );
  }
}

class _PomodoroBubble extends ConsumerWidget {
  const _PomodoroBubble();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pomodoroTimerProvider);
    final progress = state.durationMinutes == 0
        ? 0.0
        : (state.elapsedSeconds / (state.durationMinutes * 60)).clamp(0.0, 1.0);
    final remaining = _formatRemaining(state);
    final isResting = state.phase == PomodoroPhase.resting;
    final isPaused = state.phase == PomodoroPhase.paused;
    final fill = isResting
        ? const Color(0xFF21B487)
        : isPaused
        ? const Color(0xFFF59E0B)
        : const Color(0xFFE84D4D);

    return SizedBox(
      width: _PomodoroFloatingBarState._bubbleSize,
      height: _PomodoroFloatingBarState._bubbleSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 260),
            builder: (context, value, child) => CircularProgressIndicator(
              value: value,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              backgroundColor: fill.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation(fill),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              width: 62,
              height: 62,
              child: CustomPaint(
                painter: _TomatoFacePainter(
                  color: fill,
                  resting: isResting,
                  paused: isPaused,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      remaining,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PomodoroPanel extends ConsumerWidget {
  final double width;
  final VoidCallback onCollapse;

  const _PomodoroPanel({required this.width, required this.onCollapse});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pomodoroTimerProvider);
    final settings = ref.watch(focusGuardProvider);
    final isResting = state.phase == PomodoroPhase.resting;
    final isPaused = state.phase == PomodoroPhase.paused;
    final accent = isResting
        ? const Color(0xFF21B487)
        : isPaused
        ? const Color(0xFFF59E0B)
        : const Color(0xFFE84D4D);
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 58,
                  height: 58,
                  child: CustomPaint(
                    painter: _TomatoFacePainter(
                      color: accent,
                      resting: isResting,
                      paused: isPaused,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isResting ? '休息中' : (isPaused ? '已暂停' : '专注中'),
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.currentEvent?.title ?? '自由专注',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '收起',
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  onPressed: onCollapse,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatRemaining(state),
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                _CounterPill(
                  icon: Icons.local_fire_department_rounded,
                  label: '${state.completedPomodoros}',
                  color: const Color(0xFFE84D4D),
                ),
                const SizedBox(width: 8),
                _CounterPill(
                  icon: settings.enabled
                      ? Icons.shield_rounded
                      : Icons.shield_outlined,
                  label: settings.enabled ? '开' : '关',
                  color: settings.enabled
                      ? const Color(0xFF2F80ED)
                      : cs.outline,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: state.durationMinutes == 0
                    ? 0
                    : (state.elapsedSeconds / (state.durationMinutes * 60))
                          .clamp(0.0, 1.0),
                backgroundColor: accent.withValues(alpha: 0.14),
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _RoundActionButton(
                  tooltip: isPaused ? '继续' : '暂停',
                  icon: isPaused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  color: accent,
                  onPressed: () {
                    if (isPaused) {
                      ref.read(pomodoroTimerProvider.notifier).resume();
                    } else {
                      ref.read(pomodoroTimerProvider.notifier).pause();
                    }
                  },
                ),
                const SizedBox(width: 8),
                _RoundActionButton(
                  tooltip: '防打扰',
                  icon: Icons.do_not_disturb_on_outlined,
                  color: const Color(0xFF2F80ED),
                  onPressed: () => _showFocusGuardSheet(context),
                ),
                const Spacer(),
                _RoundActionButton(
                  tooltip: '结束',
                  icon: Icons.stop_rounded,
                  color: cs.error,
                  onPressed: () => _confirmStop(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFocusGuardSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => const _FocusGuardSheet(),
    );
  }

  void _confirmStop(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('停止计时'),
        content: const Text('是否标记当前事件为已完成？'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(pomodoroTimerProvider.notifier)
                  .stop(markCompleted: false);
            },
            child: const Text('不标记'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(pomodoroTimerProvider.notifier)
                  .stop(markCompleted: true);
            },
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }
}

class _FocusGuardSheet extends ConsumerWidget {
  const _FocusGuardSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(focusGuardProvider);
    final notifier = ref.read(focusGuardProvider.notifier);
    final statusAsync = ref.watch(focusGuardPermissionStatusProvider);
    final appsAsync = ref.watch(focusGuardInstalledAppsProvider);
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('专注防打扰', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.enabled,
              title: const Text('开启防打扰'),
              subtitle: const Text('番茄钟运行时启用'),
              onChanged: (value) =>
                  notifier.update(settings.copyWith(enabled: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.appLockEnabled,
              title: const Text('锁应用'),
              subtitle: const Text('Android 权限接入后生效'),
              onChanged: settings.enabled
                  ? (value) => notifier.update(
                      settings.copyWith(appLockEnabled: value),
                    )
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.keepScreenAwake,
              title: const Text('保持计时可见'),
              subtitle: const Text('专注时优先显示悬浮计时'),
              onChanged: (value) =>
                  notifier.update(settings.copyWith(keepScreenAwake: value)),
            ),
            const SizedBox(height: 8),
            statusAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) =>
                  Text('权限状态读取失败：$error', style: TextStyle(color: cs.error)),
              data: (status) => Column(
                children: [
                  _FocusPermissionRow(
                    icon: Icons.analytics_outlined,
                    label: status.platform == 'ios' ? '屏幕使用时间' : '使用情况访问',
                    ok: status.platform == 'ios'
                        ? status.screenTimeAvailable
                        : status.usageAccessGranted,
                    okText: status.platform == 'ios' ? '可用' : '已开启',
                    badText: status.platform == 'ios' ? '需 entitlement' : '未开启',
                    onTap: status.platform == 'android'
                        ? () => _openUsageSettings(ref)
                        : null,
                  ),
                  _FocusPermissionRow(
                    icon: Icons.layers_outlined,
                    label: status.platform == 'ios' ? '跨应用锁定' : '悬浮窗',
                    ok: status.platform == 'ios'
                        ? status.serviceAvailable
                        : status.overlayGranted,
                    okText: '已开启',
                    badText: status.platform == 'ios' ? '系统限制' : '未开启',
                    onTap: status.platform == 'android'
                        ? () => _openOverlaySettings(ref)
                        : null,
                  ),
                  if (status.platform == 'android')
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _refreshAndSync(ref),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('刷新权限并启动'),
                      ),
                    ),
                  if (status.platform == 'ios')
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 8),
                      child: Text(
                        'iOS 需要 Apple Screen Time entitlement 才能选择并屏蔽其他 App。当前先保留番茄钟内防打扰配置。',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '白名单',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            appsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (error, _) =>
                  Text('应用列表读取失败：$error', style: TextStyle(color: cs.error)),
              data: (apps) {
                if (apps.isEmpty) {
                  return Text(
                    '当前平台暂不支持读取应用列表。',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  );
                }
                final visibleApps = apps.take(36).toList();
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final app in visibleApps)
                          FilterChip(
                            label: Text(app.label),
                            selected: settings.allowedPackages.contains(
                              app.packageName,
                            ),
                            onSelected: settings.enabled
                                ? (_) => notifier.togglePackage(app.packageName)
                                : null,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUsageSettings(WidgetRef ref) async {
    await FocusGuardPlatformService.instance.openUsageAccessSettings();
    ref.invalidate(focusGuardPermissionStatusProvider);
  }

  Future<void> _openOverlaySettings(WidgetRef ref) async {
    await FocusGuardPlatformService.instance.openOverlaySettings();
    ref.invalidate(focusGuardPermissionStatusProvider);
  }

  Future<void> _refreshAndSync(WidgetRef ref) async {
    ref.invalidate(focusGuardPermissionStatusProvider);
    await ref.read(focusGuardProvider.notifier).syncNativeGuard();
  }
}

class _FocusPermissionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ok;
  final String okText;
  final String badText;
  final VoidCallback? onTap;

  const _FocusPermissionRow({
    required this.icon,
    required this.label,
    required this.ok,
    required this.okText,
    required this.badText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = ok ? Colors.green : Theme.of(context).colorScheme.error;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ok ? okText : badText,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          if (onTap != null) const SizedBox(width: 4),
          if (onTap != null) const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _CounterPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CounterPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _RoundActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        fixedSize: const Size(44, 44),
        foregroundColor: color,
        backgroundColor: color.withValues(alpha: 0.12),
      ),
    );
  }
}

class _TomatoFacePainter extends CustomPainter {
  final Color color;
  final bool resting;
  final bool paused;

  const _TomatoFacePainter({
    required this.color,
    required this.resting,
    required this.paused,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 2);
    final radius = math.min(size.width, size.height) * 0.33;
    final body = Paint()..color = color;
    final leaf = Paint()..color = const Color(0xFF2FB86E);
    final ink = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;
    final eye = Paint()..color = Colors.white;

    canvas.drawCircle(center, radius, body);

    final leafPath = Path()
      ..moveTo(center.dx, center.dy - radius + 4)
      ..quadraticBezierTo(
        center.dx - 18,
        center.dy - radius - 10,
        center.dx - 10,
        center.dy - radius + 8,
      )
      ..quadraticBezierTo(
        center.dx,
        center.dy - radius - 14,
        center.dx + 10,
        center.dy - radius + 8,
      )
      ..quadraticBezierTo(
        center.dx + 18,
        center.dy - radius - 10,
        center.dx,
        center.dy - radius + 4,
      );
    canvas.drawPath(leafPath, leaf);

    final leftEye = Offset(
      center.dx - radius * 0.38,
      center.dy - radius * 0.14,
    );
    final rightEye = Offset(
      center.dx + radius * 0.38,
      center.dy - radius * 0.14,
    );
    if (resting) {
      canvas.drawLine(leftEye.translate(-3, 0), leftEye.translate(3, 0), ink);
      canvas.drawLine(rightEye.translate(-3, 0), rightEye.translate(3, 0), ink);
    } else {
      canvas.drawCircle(leftEye, 2.5, eye);
      canvas.drawCircle(rightEye, 2.5, eye);
    }

    if (paused) {
      canvas.drawLine(center.translate(-5, 8), center.translate(5, 8), ink);
    } else {
      final smile = Rect.fromCenter(
        center: center.translate(0, 4),
        width: 18,
        height: 12,
      );
      canvas.drawArc(smile, 0.18 * math.pi, 0.64 * math.pi, false, ink);
    }
  }

  @override
  bool shouldRepaint(covariant _TomatoFacePainter oldDelegate) =>
      color != oldDelegate.color ||
      resting != oldDelegate.resting ||
      paused != oldDelegate.paused;
}

String _formatRemaining(PomodoroTimerState state) {
  final remaining = state.remainingSeconds.clamp(0, 24 * 60 * 60);
  final minutes = remaining ~/ 60;
  final seconds = remaining % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
