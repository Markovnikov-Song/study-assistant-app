import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/onboarding/onboarding_page.dart';
import '../providers/shared_preferences_provider.dart';
import '../routes/app_routes.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _pulseController;
  late final Animation<double> _fade;
  late final Animation<double> _slide;
  late final Animation<double> _scale;

  bool _hasVibrated = false;
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _fade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0, 0.6, curve: Curves.easeOutCubic),
    );
    _slide = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.12, 0.82, curve: Curves.easeOutCubic),
    );
    _scale = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0, 0.76, curve: Curves.easeOutCubic),
      ),
    );

    _mainController
      ..addListener(() {
        if (_mainController.value >= 0.72 && !_hasVibrated) {
          _hasVibrated = true;
          HapticFeedback.lightImpact();
        }
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _navigateToHome();
      })
      ..forward();
  }

  Future<void> _navigateToHome() async {
    if (!mounted || _didNavigate) return;
    _didNavigate = true;
    final prefs = ref.read(sharedPreferencesProvider);
    final hasSeenOnboarding =
        prefs.getBool(onboardingSeenPreferenceKey) ?? false;
    context.go(hasSeenOnboarding ? R.chat : R.onboarding);
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final variant = _SplashVariant.fromWidth(size.width);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      body: AnimatedBuilder(
        animation: Listenable.merge([_mainController, _pulseController]),
        builder: (context, _) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              gradient: LinearGradient(
                colors: [
                  bg,
                  cs.primary.withValues(alpha: isDark ? 0.09 : 0.055),
                  cs.secondary.withValues(alpha: isDark ? 0.07 : 0.045),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _WorkbenchGridPainter(
                      color: cs.outlineVariant.withValues(
                        alpha: isDark ? 0.16 : 0.30,
                      ),
                      progress: _pulseController.value,
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: variant.horizontalPadding,
                      vertical: 32,
                    ),
                    child: Transform.scale(
                      scale: _scale.value,
                      child: Opacity(
                        opacity: _fade.value,
                        child: Transform.translate(
                          offset: Offset(0, 18 * (1 - _slide.value)),
                          child: _SplashContent(
                            variant: variant,
                            pulse: _pulseController.value,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 12,
                  right: 16,
                  child: TextButton(
                    onPressed: _navigateToHome,
                    child: const Text('跳过'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _SplashVariant {
  mobile,
  tablet,
  desktop;

  static _SplashVariant fromWidth(double width) {
    if (width >= 1100) return _SplashVariant.desktop;
    if (width >= 700) return _SplashVariant.tablet;
    return _SplashVariant.mobile;
  }

  double get horizontalPadding {
    switch (this) {
      case _SplashVariant.desktop:
        return 96;
      case _SplashVariant.tablet:
        return 56;
      case _SplashVariant.mobile:
        return 28;
    }
  }
}

class _SplashContent extends StatelessWidget {
  final _SplashVariant variant;
  final double pulse;

  const _SplashContent({required this.variant, required this.pulse});

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case _SplashVariant.desktop:
        return const _DesktopSplashCard();
      case _SplashVariant.tablet:
        return const _TabletSplashCard();
      case _SplashVariant.mobile:
        return const _MobileSplashCard();
    }
  }
}

class _DesktopSplashCard extends StatelessWidget {
  const _DesktopSplashCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1040),
      child: Row(
        children: [
          Expanded(
            child: _BrandLockup(
              titleSize: 64,
              subtitle: '把问题、资料、复盘和计划放在同一个学习工作台，少切换，多推进。',
            ),
          ),
          const SizedBox(width: 52),
          Container(
            width: 340,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusRow(
                  icon: Icons.chat_rounded,
                  title: '答疑',
                  value: '随问随解',
                ),
                _StatusRow(
                  icon: Icons.menu_book_rounded,
                  title: '资料',
                  value: '沉淀成库',
                ),
                _StatusRow(
                  icon: Icons.event_note_rounded,
                  title: '计划',
                  value: '下一步清晰',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabletSplashCard extends StatelessWidget {
  const _TabletSplashCard();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: const _BrandLockup(
        titleSize: 56,
        subtitle: '一个更清晰的学习工作台，连接答疑、资料、计划和复盘。',
        centered: true,
      ),
    );
  }
}

class _MobileSplashCard extends StatelessWidget {
  const _MobileSplashCard();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: const _BrandLockup(
        titleSize: 44,
        subtitle: '答疑、资料、计划和复盘，放进同一个现场。',
        centered: true,
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  final double titleSize;
  final String subtitle;
  final bool centered;

  const _BrandLockup({
    required this.titleSize,
    required this.subtitle,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final align = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.school_rounded, color: cs.onPrimary, size: 32),
        ),
        const SizedBox(height: 24),
        Text(
          '伴学',
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: titleSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
            height: 1,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          subtitle,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: centered ? 16 : 18,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 26),
        LinearProgressIndicator(
          minHeight: 3,
          borderRadius: BorderRadius.circular(999),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatusRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: cs.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(value, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _WorkbenchGridPainter extends CustomPainter {
  final Color color;
  final double progress;

  const _WorkbenchGridPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const gap = 42.0;
    final drift = progress * gap;

    for (double x = -gap + drift; x < size.width + gap; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = -gap + drift; y < size.height + gap; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WorkbenchGridPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.progress != progress;
  }
}
