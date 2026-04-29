import 'package:flutter/material.dart';
import 'dart:math';

class DustParticlePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Random random = Random(42); 

  DustParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 25; i++) { 
      final double startX = random.nextDouble() * size.width;
      final double startY = random.nextDouble() * size.height;
      final double speed = 0.3 + random.nextDouble() * 1.0; 
      final double sizeMultiplier = random.nextDouble() * 2.5;
      final double currentY = (startY - (progress * size.height * speed)) % size.height;
      final double currentX = startX + sin((progress * pi * 4) + i) * 15;
      final double alpha = sin((currentY / size.height) * pi) * 0.12;
      paint.color = color.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(currentX, currentY), sizeMultiplier, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DustParticlePainter oldDelegate) => oldDelegate.progress != progress;
}