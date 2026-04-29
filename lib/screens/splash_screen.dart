import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// 导入三个核心组件
import '../widgets/splash/ink_bleed_painter.dart';
import '../widgets/splash/dust_painter.dart';
import '../widgets/splash/animated_text.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController; 
  
  bool _hasVibrated = false; 

  late Animation<double> _minorOpacityAnim;
  late Animation<double> _moveAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _shadowAnim;
  late Animation<double> _mistAnim;
  late Animation<double> _inkBleedAnim;
  late Animation<double> _colorProgressAnim; 

  final double _finalScale = 1.35; 

  @override
  void initState() {
    super.initState();
    
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    const curve = Curves.easeInOutQuad;

    _mistAnim = Tween<double>(begin: 0.8, end: 1.1).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 1.0, curve: curve)),
    );
    _minorOpacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.1, 0.4, curve: curve)),
    );
    _moveAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.4, 0.9, curve: curve)),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: _finalScale).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.7, 0.95, curve: curve)),
    );
    _shadowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.85, 1.0, curve: Curves.easeOutSine)),
    );
    _inkBleedAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.5, 1.0, curve: Curves.easeOutQuart)),
    );
    
    _colorProgressAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.9, 1.0, curve: curve)),
    );

    // 监听动画完成状态
    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToHome();
      }
    });

    _mainController.addListener(() {
      if (_mainController.value >= 0.9 && !_hasVibrated) {
        _hasVibrated = true;
        HapticFeedback.lightImpact(); 
      }
    });

    _mainController.forward();
  }

  // 丝滑渐变转场到主页
  void _navigateToHome() {
    // 使用 go_router 导航到主页
    context.go('/');
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    
    // 动态暗黑模式检测
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 白天：清秀宣纸 / 黑夜：幽深墨砚
    final Color bgStart = isDarkMode ? const Color(0xFF1A1D1A) : const Color(0xFFF7F9F7);
    final Color bgEnd = isDarkMode ? const Color(0xFF101211) : const Color(0xFFE2EBE5);
    final Color mistColor = isDarkMode ? const Color(0xFF26362D) : const Color(0xFFCDE0D5);
    
    // 白天：灰绿 / 黑夜：暗幽绿
    final Color minorTextColor = isDarkMode ? const Color(0xFF5C7A6A) : const Color(0xFF9EBAAB);
    
    // 核心文字初始颜色
    final Color coreInitColor = isDarkMode ? const Color(0xFF4A6B59) : const Color(0xFF759A87);
    // 核心文字最终定格颜色 (白天深竹青，夜晚化作发光的透亮玉色)
    final Color coreFinalColor = isDarkMode ? const Color(0xFF9CC9B0) : const Color(0xFF32654D);

    return Scaffold(
      backgroundColor: bgEnd,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bgStart, bgEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: AnimatedBuilder(
          animation: _mainController,
          builder: (context, child) {
            // 动态计算当前的文字颜色
            final Color? currentColor = Color.lerp(
              coreInitColor, 
              coreFinalColor, 
              _colorProgressAnim.value
            );

            return Stack(
              children: [
                _buildMistLayer(mistColor),
                _buildInkLayer(coreFinalColor),
                _buildDustLayer(coreFinalColor),
                _buildTextLayer(size, minorTextColor, currentColor!),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMistLayer(Color mistColor) {
    return Positioned.fill(
      child: Align(
        alignment: Alignment.center,
        child: Transform.scale(
          scale: _mistAnim.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  mistColor.withValues(alpha: 0.4), 
                  mistColor.withValues(alpha: 0.0), 
                ],
                radius: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInkLayer(Color inkColor) {
    return Positioned.fill(
      child: CustomPaint(
        painter: InkBleedPainter(
          progress: _inkBleedAnim.value, 
          color: inkColor,
        ),
      ),
    );
  }

  Widget _buildDustLayer(Color dustColor) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _particleController,
        builder: (context, child) {
          return CustomPaint(
            painter: DustParticlePainter(
              progress: _particleController.value, 
              color: dustColor,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextLayer(Size size, Color minorTextColor, Color coreColor) {
    final double w = size.width;
    final double h = size.height;

    final double unit = w * 0.1;
    final double yOffset = h * 0.11; 
    final double lineSpacing = unit * 0.6;
    final double moveProgress = _moveAnim.value;

    final xXue = -(unit * 2.5) * (1.0 - moveProgress); 
    final yXue = -lineSpacing + ((yOffset + lineSpacing) * moveProgress); 

    final xBan = -(unit * 0.5) * (1.0 - moveProgress);
    final yBan = lineSpacing - ((yOffset + lineSpacing) * moveProgress); 

    final xHaiWuYa = xXue + (unit * 2.0); 
    final yHaiWuYa = -lineSpacing;
            
    final xYiWeiZhou = xBan + (unit * 2.0); 
    final yYiWeiZhou = lineSpacing;

    return Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: Transform.translate(
              offset: Offset(xHaiWuYa, yHaiWuYa),
              child: Opacity(
                opacity: _minorOpacityAnim.value,
                child: AnimatedSplashText(
                  text: "如微光", 
                  width: unit * 3.0, 
                  fontSize: unit, 
                  color: minorTextColor,
                  shadowProgress: _shadowAnim.value,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: Transform.translate(
              offset: Offset(xYiWeiZhou, yYiWeiZhou),
              child: Opacity(
                opacity: _minorOpacityAnim.value,
                child: AnimatedSplashText(
                  text: "以清风", 
                  width: unit * 3.0, 
                  fontSize: unit, 
                  color: minorTextColor,
                  shadowProgress: _shadowAnim.value,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: Transform.translate(
              offset: Offset(xXue, yXue),
              child: Transform.scale(
                scale: _scaleAnim.value,
                child: AnimatedSplashText(
                  text: "学", 
                  width: unit, 
                  fontSize: unit * 1.25, 
                  color: coreColor,
                  isCore: true,
                  shadowProgress: _shadowAnim.value,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: Transform.translate(
              offset: Offset(xBan, yBan),
              child: Transform.scale(
                scale: _scaleAnim.value,
                child: AnimatedSplashText(
                  text: "伴", 
                  width: unit, 
                  fontSize: unit * 1.25, 
                  color: coreColor,
                  isCore: true,
                  shadowProgress: _shadowAnim.value,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
