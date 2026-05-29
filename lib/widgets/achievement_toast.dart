import 'package:flutter/material.dart';
import '../services/achievement_service.dart';

/// 成就解锁 Toast 组件
class AchievementToast extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback? onDismiss;
  
  const AchievementToast({
    super.key,
    required this.achievement,
    this.onDismiss,
  });
  
  static Future<void> show(BuildContext context, Achievement achievement) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AchievementToast(
        achievement: achievement,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }
  
  @override
  State<AchievementToast> createState() => _AchievementToastState();
}

class _AchievementToastState extends State<AchievementToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
    
    // 3秒后自动关闭
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        widget.onDismiss?.call();
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD54F), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.achievement.icon,
                      style: const TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '🎉 成就解锁!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFFF8F00),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.achievement.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.achievement.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8D6E63),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}