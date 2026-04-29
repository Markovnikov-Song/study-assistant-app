import 'package:flutter/material.dart';

class InkBleedPainter extends CustomPainter {
  final double progress;
  final Color color;

  InkBleedPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final double maxRadius = size.width * 0.65;
    final double currentRadius = maxRadius * Curves.easeOutCubic.transform(progress);
    final double alpha = (1.0 - progress) * 0.08; 

    final Paint paint = Paint()
      ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 40.0 * progress + 20.0);

    canvas.drawCircle(center, currentRadius, paint);
    canvas.drawCircle(center + Offset(20 * progress, -30 * progress), currentRadius * 0.8, paint);
    canvas.drawCircle(center + Offset(-30 * progress, 15 * progress), currentRadius * 0.9, paint);
  }

  @override
  bool shouldRepaint(covariant InkBleedPainter oldDelegate) => oldDelegate.progress != progress;
}