import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// ============================================================
/// 装饰性背景组件
/// 提供各种美观的背景效果
/// ============================================================

/// 渐变背景组件
class GradientBackground extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final List<Color>? colors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;

  const GradientBackground({
    super.key,
    required this.child,
    this.gradient,
    this.colors,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient ??
            LinearGradient(
              begin: begin,
              end: end,
              colors: colors ?? [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surface,
              ],
            ),
      ),
      child: child,
    );
  }
}

/// 极光渐变背景
class AuroraBackground extends StatelessWidget {
  final Widget child;
  final double height;

  const AuroraBackground({
    super.key,
    required this.child,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: height,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0x206366F1), // 10% opacity
                  Color(0x308B5CF6), // 19% opacity
                  Color(0x20EC4899), // 12% opacity
                  Color(0x10F59E0B), // 6% opacity
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// 网格点状背景
class DotsPatternBackground extends StatelessWidget {
  final Widget child;
  final Color? dotColor;
  final double spacing;
  final double dotRadius;

  const DotsPatternBackground({
    super.key,
    required this.child,
    this.dotColor,
    this.spacing = 24,
    this.dotRadius = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _DotsPatternPainter(
              dotColor: dotColor ??
                  cs.onSurface.withValues(alpha: 0.12),
              spacing: spacing,
              dotRadius: dotRadius,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _DotsPatternPainter extends CustomPainter {
  final Color dotColor;
  final double spacing;
  final double dotRadius;

  _DotsPatternPainter({
    required this.dotColor,
    required this.spacing,
    required this.dotRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 波浪装饰背景
class WaveDecoration extends StatelessWidget {
  final Widget child;
  final Color? waveColor;
  final double height;
  final bool isBottom;

  const WaveDecoration({
    super.key,
    required this.child,
    this.waveColor,
    this.height = 60,
    this.isBottom = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        child,
        Positioned(
          bottom: isBottom ? 0 : null,
          top: isBottom ? null : 0,
          left: 0,
          right: 0,
          height: height,
          child: CustomPaint(
            painter: _WavePainter(
              color: waveColor ?? cs.surface,
            ),
            size: Size(double.infinity, height),
          ),
        ),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  final Color color;

  _WavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);

    // 第一层波浪
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.8,
      size.width * 0.5,
      size.height * 0.6,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.4,
      size.width,
      size.height * 0.7,
    );
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 渐变卡片装饰
class GradientCard extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final List<Color>? colors;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const GradientCard({
    super.key,
    required this.child,
    this.gradient,
    this.colors,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        gradient: gradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors ?? [cs.primary, cs.secondary],
            ),
        borderRadius: borderRadius ?? AppTheme.borderRadiusMd,
        boxShadow: AppTheme.shadowLg,
      ),
      child: child,
    );
  }
}

/// 悬浮效果卡片
class ElevatedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double elevation;

  const ElevatedCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.elevation = 1,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? cs.surface,
        borderRadius: AppTheme.borderRadiusMd,
        boxShadow: elevation > 0 ? AppTheme.shadowMd : null,
        border: Border.all(
          color: cs.outline,
        ),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppTheme.spaceLg),
        child: child,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: AppTheme.borderRadiusMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.borderRadiusMd,
          child: card,
        ),
      );
    }

    return card;
  }
}

/// 头像装饰
class AvatarDecoration extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final double size;
  final bool showBorder;

  const AvatarDecoration({
    super.key,
    required this.child,
    this.backgroundColor,
    this.size = 48,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? cs.primary.withValues(alpha: 0.15),
        border: showBorder
            ? Border.all(
                color: cs.primary,
                width: 2,
              )
            : null,
      ),
      child: Center(child: child),
    );
  }
}

/// 标签装饰
class TagDecoration extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? textColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const TagDecoration({
    super.key,
    required this.child,
    this.backgroundColor,
    this.textColor,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceSm,
            vertical: AppTheme.spaceXs,
          ),
      decoration: BoxDecoration(
        color: backgroundColor ?? cs.primary.withValues(alpha: 0.1),
        borderRadius: borderRadius ?? AppTheme.borderRadiusSm,
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor ?? cs.primary,
        ),
        child: child,
      ),
    );
  }
}

/// 进度条装饰
class ProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final Gradient? gradient;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const ProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.gradient,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? cs.surfaceContainerHighest,
        borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient ?? LinearGradient(
              colors: [cs.primary, cs.secondary],
            ),
            borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}

/// 渐变文字
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient? gradient;
  final List<Color>? colors;

  const GradientText({
    super.key,
    required this.text,
    this.style,
    this.gradient,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => (gradient ??
              LinearGradient(
                colors: colors ?? [cs.primary, cs.secondary],
              ))
          .createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(
        text,
        style: style,
      ),
    );
  }
}

/// 图标按钮装饰
class IconButtonDecoration extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double size;
  final bool showShadow;

  const IconButtonDecoration({
    super.key,
    required this.icon,
    this.onTap,
    this.backgroundColor,
    this.size = 44,
    this.showShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: backgroundColor ?? cs.surface,
      borderRadius: AppTheme.borderRadiusSm,
      elevation: showShadow ? 2 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.borderRadiusSm,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: icon),
        ),
      ),
    );
  }
}
