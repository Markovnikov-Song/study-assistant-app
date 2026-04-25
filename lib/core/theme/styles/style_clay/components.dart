import 'package:flutter/material.dart';
import 'colors.dart';
import 'theme.dart';

/// ============================================================
/// 黏土风装饰性组件 (Claymorphism)
/// ============================================================

/// 黏土风卡片 - 具有柔软、微凸的体积感
class ClayCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double depth;

  const ClayCard({
    super.key,
    required this.child,
    this.color,
    this.padding,
    this.margin,
    this.borderRadius,
    this.depth = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = color ?? (isDark ? const ClayColors().surfaceDark : const ClayColors().surface);
    final radius = borderRadius ?? BorderRadius.circular(const ClaySpacing().radiusMd);

    return Container(
      margin: margin,
      padding: padding ?? EdgeInsets.all(const ClaySpacing().spaceLg),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: radius,
        // 模拟黏土的表面微小隆起
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(baseColor, Colors.white, isDark ? 0.05 : 0.08)!,
            baseColor,
          ],
        ),
        // 核心：黏土风双重外阴影
        boxShadow: isDark ? _buildDarkShadows(depth) : _buildLightShadows(depth),
        // 白边/亮边增加质感
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.white.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: child,
    );
  }

  List<BoxShadow> _buildLightShadows(double d) => [
        BoxShadow(
          color: const ClayColors().shadowDark,
          blurRadius: d * 2,
          offset: Offset(d, d),
        ),
        BoxShadow(
          color: Colors.white,
          blurRadius: d * 2,
          offset: Offset(-d, -d),
        ),
      ];

  List<BoxShadow> _buildDarkShadows(double d) => [
        BoxShadow(
          color: const ClayColors().shadowDarkNight,
          blurRadius: d * 2,
          offset: Offset(d, d),
        ),
        BoxShadow(
          color: const ClayColors().shadowLightNight,
          blurRadius: d * 2,
          offset: Offset(-d * 0.7, -d * 0.7),
        ),
      ];
}

/// 黏土风可点击卡片 - 点击时有按压反馈
class ClayInteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color? color;
  final BorderRadius? borderRadius;
  final double depth;

  const ClayInteractiveCard({
    super.key,
    required this.child,
    required this.onTap,
    this.color,
    this.borderRadius,
    this.depth = 8.0,
  });

  @override
  State<ClayInteractiveCard> createState() => _ClayInteractiveCardState();
}

class _ClayInteractiveCardState extends State<ClayInteractiveCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        transform: Matrix4.translationValues(
          _isPressed ? 2.0 : 0.0,
          _isPressed ? 2.0 : 0.0,
          0.0,
        ),
        child: ClayCard(
          depth: _isPressed ? 2.0 : widget.depth,
          color: widget.color,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(const ClaySpacing().radiusSm),
          child: widget.child,
        ),
      ),
    );
  }
}

/// 黏土风按钮
class ClayButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? color;
  final BorderRadius? borderRadius;
  final bool isLoading;

  const ClayButton({
    super.key,
    required this.child,
    this.onPressed,
    this.color,
    this.borderRadius,
    this.isLoading = false,
  });

  @override
  State<ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<ClayButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = widget.color ?? const ClayColors().primary;
    final radius = widget.borderRadius ?? BorderRadius.circular(const ClaySpacing().radiusSm);

    return GestureDetector(
      onTapDown: widget.onPressed != null ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.onPressed != null
          ? (_) {
              setState(() => _isPressed = false);
              widget.onPressed!();
            }
          : null,
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        transform: Matrix4.translationValues(
          _isPressed ? 1.5 : 0.0,
          _isPressed ? 1.5 : 0.0,
          0.0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(baseColor, Colors.white, isDark ? 0.1 : 0.15)!,
              baseColor,
            ],
          ),
          boxShadow: _isPressed
              ? _buildPressedShadows(isDark)
              : _buildButtonShadows(baseColor, isDark),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.white.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: widget.isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(
                    isDark ? const ClayColors().backgroundDark : const ClayColors().textOnPrimary,
                  ),
                ),
              )
            : DefaultTextStyle(
                style: TextStyle(
                  color: isDark ? const ClayColors().backgroundDark : const ClayColors().textOnPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                child: widget.child,
              ),
      ),
    );
  }

  List<BoxShadow> _buildButtonShadows(Color color, bool isDark) => [
        BoxShadow(
          color: isDark ? const ClayColors().shadowDarkNight : const ClayColors().shadowDark,
          blurRadius: 8,
          offset: const Offset(3, 3),
        ),
        BoxShadow(
          color: isDark ? const ClayColors().shadowLightNight : Colors.white,
          blurRadius: 6,
          offset: const Offset(-3, -3),
        ),
      ];

  List<BoxShadow> _buildPressedShadows(bool isDark) => [
        BoxShadow(
          color: isDark ? const ClayColors().shadowDarkNight : const ClayColors().shadowDark,
          blurRadius: 3,
          offset: const Offset(1, 1),
        ),
        BoxShadow(
          color: isDark ? const ClayColors().shadowLightNight : Colors.white,
          blurRadius: 3,
          offset: const Offset(-1, -1),
        ),
      ];
}

/// 黏土风输入框装饰
class ClayInputDecoration extends BoxDecoration {
  ClayInputDecoration({
    required bool isDark,
    bool isFocused = false,
    bool hasError = false,
  }) : super(
          color: isDark ? const ClayColors().surfaceElevatedDark : const ClayColors().surface,
          borderRadius: BorderRadius.circular(const ClaySpacing().radiusMd),
          border: Border.all(
            color: hasError
                ? (isDark ? const ClayColors().errorLight : const ClayColors().error)
                : isFocused
                    ? const ClayColors().primary
                    : (isDark ? const ClayColors().borderDark : const ClayColors().border),
            width: isFocused || hasError ? 2 : 1,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: const ClayColors().shadowDark.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.8),
                    blurRadius: 4,
                    offset: const Offset(-2, -2),
                  ),
                ],
        );
}


