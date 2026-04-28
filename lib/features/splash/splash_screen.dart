import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../routes/app_router.dart';

/// 开屏动画：「学海无涯，伴以为舟」
///
/// 动画分为 3 阶段：
///   阶段 1 — 淡入：完整句子「学海无涯，伴以为舟」渐现
///   阶段 2 — 合并：中间「海无涯，」和「以为舟」淡出，
///             「学」向右移动，「伴」向左移动，两字靠拢合并为「伴学」
///   阶段 3 — 定格：文字变为金色，停留后跳转首页
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;

  // 阶段 1：整体淡入
  late final Animation<double> _fadeIn;

  // 阶段 2：中间字淡出
  late final Animation<double> _midFade;

  // 阶段 2：「学」向右位移（往「伴」靠拢）
  late final Animation<double> _xueOffset;

  // 阶段 2：「伴」向左位移（往「学」靠拢）
  late final Animation<double> _banOffset;

  // 阶段 3：颜色变金色
  late final Animation<Color?> _finalColor;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // 时序：
    //  0.00 – 0.30  淡入完整句子
    //  0.30 – 0.65  中间字消失 + 两端字位移靠拢
    //  0.65 – 0.78  颜色变金色
    //  0.78 – 1.00  停留

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
      ),
    );

    _midFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.30, 0.65, curve: Curves.easeIn),
      ),
    );

    // 「学」从左端向右移动约 120px（靠近中心）
    _xueOffset = Tween<double>(begin: 0.0, end: 120.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.30, 0.65, curve: Curves.easeInOut),
      ),
    );

    // 「伴」从右侧向左移动约 120px（靠近中心）
    _banOffset = Tween<double>(begin: 0.0, end: -120.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.30, 0.65, curve: Curves.easeInOut),
      ),
    );

    _finalColor = ColorTween(
      begin: const Color(0xFFE8EAF6), // 蓝白
      end: const Color(0xFFFFD700),   // 金色
    ).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.65, 0.78, curve: Curves.easeInOut),
      ),
    );

    _ctrl.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 400), () {
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
    fontSize: 52.0,
    fontWeight: FontWeight.w900,
    color: Color(0xFFE8EAF6),
    letterSpacing: 2.0,
    shadows: [Shadow(color: Color(0x40E8EAF6), blurRadius: 20.0)],
  );

  TextStyle _colorStyle(Color? color) => TextStyle(
        fontFamily: 'Noto Sans SC',
        fontSize: 52.0,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: 2.0,
        shadows: [
          Shadow(
            color: (color ?? Colors.white).withAlpha(100),
            blurRadius: 20.0,
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
              child: Opacity(
                opacity: _fadeIn.value,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 中间字：「海无涯，」和「以为舟」— 淡出
                    Opacity(
                      opacity: _midFade.value,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 「学」占位（透明，保持布局）
                          const Text('学', style: TextStyle(fontSize: 52, color: Colors.transparent)),
                          const Text('海无涯，', style: _baseStyle),
                          // 「伴」占位（透明，保持布局）
                          const Text('伴', style: TextStyle(fontSize: 52, color: Colors.transparent)),
                          const Text('以为舟', style: _baseStyle),
                        ],
                      ),
                    ),
                    // 「学」— 从左端向右位移
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.translate(
                          offset: Offset(_xueOffset.value, 0),
                          child: Text('学', style: _colorStyle(_finalColor.value)),
                        ),
                        // 中间占位（随中间字淡出收缩）
                        SizedBox(
                          width: _midFade.value * 4 * 52.0 * 0.6,
                        ),
                        // 「伴」— 从右侧向左位移
                        Transform.translate(
                          offset: Offset(_banOffset.value, 0),
                          child: Text('伴', style: _colorStyle(_finalColor.value)),
                        ),
                        SizedBox(
                          width: _midFade.value * 3 * 52.0 * 0.6,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
