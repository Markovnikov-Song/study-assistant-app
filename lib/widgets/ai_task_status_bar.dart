import 'package:flutter/material.dart';

import '../core/motion/app_motion.dart';

enum AiTaskTone { primary, secondary, warning }

class AiTaskStatusBar extends StatelessWidget {
  final bool active;
  final String title;
  final String idleTitle;
  final String? subtitle;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final AiTaskTone tone;
  final bool showWhenIdle;

  const AiTaskStatusBar({
    super.key,
    required this.active,
    required this.title,
    this.idleTitle = '已停止，可以调整方向后继续',
    this.subtitle,
    this.onCancel,
    this.onRetry,
    this.tone = AiTaskTone.primary,
    this.showWhenIdle = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (tone) {
      AiTaskTone.primary => cs.primary,
      AiTaskTone.secondary => cs.secondary,
      AiTaskTone.warning => Colors.orange,
    };

    if (!active && !showWhenIdle && onRetry == null) {
      return const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: AppMotion.standard,
      switchInCurve: AppMotion.emphasizedCurve,
      switchOutCurve: Curves.easeInCubic,
      child: Container(
        key: ValueKey(active),
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            if (active)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.12),
                ),
              )
            else
              Icon(Icons.pause_circle_outline_rounded, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    active ? title : idleTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (active && onCancel != null)
              TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.stop_rounded, size: 16),
                label: const Text('停止'),
              ),
            if (!active && onRetry != null)
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('继续'),
              ),
          ],
        ),
      ),
    );
  }
}
