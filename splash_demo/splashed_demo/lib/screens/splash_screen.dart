import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 导入我们拆分出去的三个核心组件
import '../widgets/ink_bleed_painter.dart';
import '../widgets/dust_painter.dart';
import '../widgets/animated_text.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController; 
  
  bool _hasVibrated = false; 

  late Animation<double> _minorOpacityAnim;
  late Animation<double> _moveAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _shadowAnim;
  late Animation<double> _mistAnim;
  late Animation<double> _inkBleedAnim;

  // 我们移除之前写死的 ColorTween，将颜色判断移入 build 方法中，以响应系统主题变化
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
    
    // 用一个 0 到 1 的进度来代替颜色变化，方便在 build 里配合主题动态计算颜色
    _colorProgressAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.9, 1.0, curve: curve)),
    );

    // 【新增：转场逻辑】监听动画完成状态
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

  // 【新增：丝滑渐变转场】
  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        // 1.2秒的极缓淡出，给用户一种水墨在宣纸上渐渐散去的感觉
        transitionDuration: const Duration(milliseconds: 1200), 
        pageBuilder: (context, animation, secondaryAnimation) => const HomePage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
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
    
    // 【核心新增：动态暗黑模式检测与色彩矩阵】
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
      backgroundColor: bgEnd, // 底色兜底
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
                _buildInkLayer(coreFinalColor), // 水墨跟随最终核心色
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
                  color: minorTextColor, // 动态颜色
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
                  color: minorTextColor, // 动态颜色
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
                  color: coreColor, // 动态颜色
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
                  color: coreColor, // 动态颜色
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

/// -----------------------------------------------------------------
/// 占位主页：为了展示转场效果，简单写了一个主页，您可以稍后替换成您的真实首页
/// -----------------------------------------------------------------
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 简单匹配主页的暗色/亮色模式
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F7F4),
      appBar: AppBar(
        title: const Text('伴学', style: TextStyle(fontFamily: 'LXGWWenKai')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Text(
          '欢迎来到伴学',
          style: TextStyle(
            fontSize: 24,
            fontFamily: 'LXGWWenKai',
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ),
    );
  }
}