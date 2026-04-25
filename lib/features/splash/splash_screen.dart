import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../routes/app_router.dart';

/// 开屏动画：「伴」无涯，以书为「学」→ 合并为「伴学」
///
/// 动画分为 3 阶段：
///   阶段 1 — 淡入：完整句子「伴无涯，以书为学」渐现
///   阶段 2 — 合并：中间「无涯，以书为」淡出，「伴」「学」向中间靠拢
///   阶段 3 — 定格：文字变为金色，停留后跳转首页
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ─── 动画控制器 ────────────────────────────────────────────
  late final AnimationController _ctrl;

  // ─── 阶段 1：整体淡入 ─────────────────────────────────────
  late final Animation<double> _fadeIn;

  // ─── 阶段 2：中间字淡出 ───────────────────────────────────
  late final Animation<double> _midFade;

  // ─── 阶段 2：「伴」右内边距（增大 → 向右让出空间）────────
  late final Animation<double> _leftCharPadding;

  // ─── 阶段 2：「学」左内边距（增大 → 向左让出空间）────────
  late final Animation<double> _rightCharPadding;

  // ─── 阶段 3：最终文字颜色（蓝白 → 金色）─────────────────
  late final Animation<Color?> _finalTextColor;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    // ─── 时序分段 ────────────────────────────────────────────
    //  0.00 – 0.32   淡入完整句子
    //  0.32 – 0.60   中间字消失 + 两端字靠拢
    //  0.60 – 0.72   颜色从蓝白渐变为金色
    //  0.72 – 1.00   停留（动画结束后额外停留 0.5s 再跳转）

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.32, curve: Curves.easeOut)),
    );

    _midFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.32, 0.60, curve: Curves.easeIn)),
    );

    _leftCharPadding = Tween<double>(begin: 0.0, end: 14.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.32, 0.60, curve: Curves.easeInOut)),
    );

    _rightCharPadding = Tween<double>(begin: 0.0, end: 14.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.32, 0.60, curve: Curves.easeInOut)),
    );

    _finalTextColor = ColorTween(
      begin: const Color(0xFFE8EAF6), // 蓝白
      end: const Color(0xFFFFD700),   // 金色
    ).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.60, 0.72, curve: Curves.easeInOut)),
    );

    _ctrl.forward().then((_) {
      // 动画结束后停留 0.5s 再跳转首页
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

  // ─── 文字样式常量 ──────────────────────────────────────────

  static const _charTextStyle = TextStyle(
    fontFamily: 'Noto Sans SC',
    fontSize: 56.0,
    fontWeight: FontWeight.w900,
    color: Color(0xFFE8EAF6),
    letterSpacing: 4.0,
    shadows: [
      Shadow(color: Color(0x40E8EAF6), blurRadius: 20.0),
    ],
  );

  TextStyle _finalCharStyle(Color? color) => TextStyle(
    fontFamily: 'Noto Sans SC',
    fontSize: 56.0,
    fontWeight: FontWeight.w900,
    color: color,
    letterSpacing: 4.0,
    shadows: [
      Shadow(color: (color ?? Colors.white).withAlpha(100), blurRadius: 20.0),
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
                  Color(0xFF0D1B2A), // 深蓝黑
                  Color(0xFF1B263B), // 深海蓝
                  Color(0xFF2D3A8C), // 靛蓝
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: Center(
              child: Opacity(
                opacity: _fadeIn.value,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 左端字：「伴」
                    Padding(
                      padding: EdgeInsets.only(right: _leftCharPadding.value),
                      child: Text('伴', style: _finalCharStyle(_finalTextColor.value)),
                    ),
                    // 中间字：「无涯，以书为」— 整体淡出
                    Opacity(
                      opacity: _midFade.value,
                      child: const Text('无涯，以书为', style: _charTextStyle),
                    ),
                    // 右端字：「学」
                    Padding(
                      padding: EdgeInsets.only(left: _rightCharPadding.value),
                      child: Text('学', style: _finalCharStyle(_finalTextColor.value)),
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
