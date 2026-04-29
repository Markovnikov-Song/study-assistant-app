import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../routes/app_router.dart';

/// 开屏动画：「学海无涯  伴以为舟」
///
/// 动画分为 3 阶段：
///   阶段 1 — 第一行「学海无涯」逐字淡入
///   阶段 2 — 第二行「伴以为舟」逐字淡入
///   阶段 3 — 「伴学」高亮金色，停留后跳转首页
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;

  // 第一行整体淡入
  late final Animation<double> _line1Fade;
  // 第二行整体淡入
  late final Animation<double> _line2Fade;
  // 第二行从下方滑入
  late final Animation<double> _line2Slide;
  // 「伴」「学」变金色
  late final Animation<Color?> _highlightColor;
  // 其余字变暗
  late final Animation<double> _otherDim;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 3200),
      vsync: this,
    );

    // 时序：
    //  0.00 – 0.35  第一行淡入
    //  0.35 – 0.70  第二行淡入 + 从下滑入
    //  0.70 – 0.85  「伴」「学」变金色，其余字变暗
    //  0.85 – 1.00  停留

    _line1Fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    _line2Fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.35, 0.70, curve: Curves.easeOut),
      ),
    );

    _line2Slide = Tween<double>(begin: 24.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.35, 0.70, curve: Curves.easeOut),
      ),
    );

    _highlightColor = ColorTween(
      begin: const Color(0xFFE8EAF6),
      end: const Color(0xFFFFD700),
    ).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.70, 0.85, curve: Curves.easeInOut),
      ),
    );

    _otherDim = Tween<double>(begin: 1.0, end: 0.45).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.70, 0.85, curve: Curves.easeInOut),
      ),
    );

    _ctrl.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) context.go(R.chat);
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static const _baseStyle = TextStyle(
    fontFamily: 'Noto Sans SC',
    fontSize: 48.0,
    fontWeight: FontWeight.w900,
    color: Color(0xFFE8EAF6),
    letterSpacing: 6.0,
    shadows: [Shadow(color: Color(0x40E8EAF6), blurRadius: 20.0)],
  );

  TextStyle _dimStyle(double opacity) => TextStyle(
        fontFamily: 'Noto Sans SC',
        fontSize: 48.0,
        fontWeight: FontWeight.w900,
        color: Color(0xFFE8EAF6).withValues(alpha: opacity),
        letterSpacing: 6.0,
        shadows: [
          Shadow(
            color: const Color(0xFFE8EAF6).withValues(alpha: opacity * 0.4),
            blurRadius: 20.0,
          ),
        ],
      );

  TextStyle _goldStyle(Color? color) => TextStyle(
        fontFamily: 'Noto Sans SC',
        fontSize: 48.0,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: 6.0,
        shadows: [
          Shadow(
            color: (color ?? Colors.white).withValues(alpha: 0.6),
            blurRadius: 24.0,
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D1B2A),
                  Color(0xFF1B263B),
                  Color(0xFF2D3A8C),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 第一行：学海无涯
                  Opacity(
                    opacity: _line1Fade.value,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('学', style: _goldStyle(_highlightColor.value)),
                        Text('海无涯', style: _dimStyle(_otherDim.value)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 第二行：伴以为舟
                  Opacity(
                    opacity: _line2Fade.value,
                    child: Transform.translate(
                      offset: Offset(0, _line2Slide.value),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('伴', style: _goldStyle(_highlightColor.value)),
                          Text('以为舟', style: _dimStyle(_otherDim.value)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
