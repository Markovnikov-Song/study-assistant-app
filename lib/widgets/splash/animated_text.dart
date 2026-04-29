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
    // 视觉补偿：专门针对书法字体的"下沉感"进行向上提拉
    final double visualCorrectionY = isCore ? -fontSize * 0.12 : 0.0;

    return Container(
      width: width,
      height: fontSize * 1.5,
      alignment: Alignment.center,
      child: Transform.translate(
        offset: Offset(0, visualCorrectionY), 
        child: Text(
          text,
          textAlign: TextAlign.center,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
            height: 1.0, 
            color: color,
            // 核心字使用小楷，次要字使用文楷
            fontFamily: isCore ? 'YanshiYouran' : 'LXGWWenKai',
            decoration: TextDecoration.none,
            letterSpacing: isCore ? 0.0 : 2.0,
            shadows: isCore ? [
              Shadow(
                color: const Color(0xFF759A87).withValues(alpha: 0.2 * shadowProgress),
                offset: Offset(0, 2 * shadowProgress), 
                blurRadius: 15.0 * shadowProgress,     
              )
            ] : null,
          ),
          textHeightBehavior: const TextHeightBehavior(
            leadingDistribution: TextLeadingDistribution.even,
          ),
        ),
      ),
    );
  }
}
