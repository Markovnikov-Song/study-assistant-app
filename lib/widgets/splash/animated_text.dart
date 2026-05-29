import 'package:flutter/material.dart';

class AnimatedSplashText extends StatelessWidget {
  final String text;
  final double width;
  final double fontSize;
  final Color color;
  final bool isCore;
  final double shadowProgress;

  const AnimatedSplashText({
    super.key,
    required this.text,
    required this.width,
    required this.fontSize,
    required this.color,
    this.isCore = false,
    required this.shadowProgress,
  });

  @override
  Widget build(BuildContext context) {
    final visualCorrectionY = isCore ? -fontSize * 0.08 : 0.0;

    return SizedBox(
      width: width,
      height: fontSize * 1.35,
      child: Center(
        child: Transform.translate(
          offset: Offset(0, visualCorrectionY),
          child: Text(
            text,
            textAlign: TextAlign.center,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isCore ? FontWeight.w800 : FontWeight.w500,
              height: 1.0,
              color: color,
              decoration: TextDecoration.none,
              letterSpacing: 0,
              shadows: isCore
                  ? [
                      Shadow(
                        color: color.withValues(alpha: 0.20 * shadowProgress),
                        offset: Offset(0, 8 * shadowProgress),
                        blurRadius: 28 * shadowProgress,
                      ),
                    ]
                  : null,
            ),
            textHeightBehavior: const TextHeightBehavior(
              leadingDistribution: TextLeadingDistribution.even,
            ),
          ),
        ),
      ),
    );
  }
}
