import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/shared_preferences_provider.dart';
import '../../routes/app_routes.dart';
import 'onboarding_demo_service.dart';

const onboardingSeenPreferenceKey = 'onboarding.calculus_demo.seen.v1';

class OnboardingPage extends ConsumerStatefulWidget {
  final bool replay;

  const OnboardingPage({super.key, this.replay = false});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  late final PageController _controller;
  int _index = 0;
  bool _startingDemo = false;

  static const _slides = [
    _OnboardingSlide(
      icon: Icons.school_rounded,
      title: '先建立一门“高等数学”',
      subtitle: '把教材、真题、课堂笔记和复习目标放到同一个课程空间里，后面的答疑、讲义、练习都会围绕它展开。',
      primaryLabel: '高等数学',
      accent: Color(0xFF2563EB),
      secondaryAccent: Color(0xFFF97316),
      mockup: _MockupKind.course,
    ),
    _OnboardingSlide(
      icon: Icons.chat_bubble_rounded,
      title: '不会的题直接问',
      subtitle: '输入“求极限”“二重积分换元”这类问题，AI 会按步骤拆开：先找知识点，再写解法，最后给你一个可复述的结论。',
      primaryLabel: '答疑室',
      accent: Color(0xFF10B981),
      secondaryAccent: Color(0xFF7C3AED),
      mockup: _MockupKind.chat,
    ),
    _OnboardingSlide(
      icon: Icons.account_tree_rounded,
      title: '把碎知识整理成图',
      subtitle: '复习到“函数、极限、连续”时，可以生成思维导图和讲义，把定义、定理、典型题型串成一条清楚的线。',
      primaryLabel: '思维导图',
      accent: Color(0xFF0891B2),
      secondaryAccent: Color(0xFFDB2777),
      mockup: _MockupKind.mindmap,
    ),
    _OnboardingSlide(
      icon: Icons.quiz_rounded,
      title: '练习和错题自动接上',
      subtitle: '学完一节就让工具箱出几道同类题；做错后沉淀到错题本，下次复盘会优先回到薄弱点。',
      primaryLabel: '工具箱',
      accent: Color(0xFFEA580C),
      secondaryAccent: Color(0xFF0D9488),
      mockup: _MockupKind.practice,
    ),
    _OnboardingSlide(
      icon: Icons.event_available_rounded,
      title: '最后排成可执行计划',
      subtitle: '告诉它“期末前 14 天复习高数”，它会把章节、练习、复盘拆到日历里，让今天该做什么变得很明确。',
      primaryLabel: '学习计划',
      accent: Color(0xFF4F46E5),
      secondaryAccent: Color(0xFFE11D48),
      mockup: _MockupKind.plan,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!widget.replay) {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(onboardingSeenPreferenceKey, true);
    }
    if (!mounted) return;
    if (widget.replay && context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _startDemoCourse() async {
    if (_startingDemo) return;
    setState(() => _startingDemo = true);
    try {
      if (!widget.replay) {
        final prefs = ref.read(sharedPreferencesProvider);
        await prefs.setBool(onboardingSeenPreferenceKey, true);
      }
      final result = await ref
          .read(onboardingDemoServiceProvider)
          .prepareDemoCourse();
      if (!mounted) return;
      if (result.deferred || result.subjectId == null) {
        context.go('/');
      } else {
        context.go(R.courseSpaceSubject(result.subjectId!, generate: true));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('示例课程准备失败：$e')));
      setState(() => _startingDemo = false);
    }
  }

  void _goPrevious() {
    if (_index == 0 || _startingDemo) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goNext() async {
    if (_startingDemo) return;
    if (_index == _slides.length - 1) {
      await _startDemoCourse();
      return;
    }
    await _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_index];
    final size = MediaQuery.sizeOf(context);
    final isDesktop = size.width >= 920;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _OnboardingBackground(slide: slide)),
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 40 : 18,
                    14,
                    isDesktop ? 40 : 18,
                    8,
                  ),
                  child: Row(
                    children: [
                      _BrandMark(slide: slide),
                      const Spacer(),
                      TextButton(
                        onPressed: _startingDemo ? null : _finish,
                        child: const Text('跳过'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    physics: _startingDemo
                        ? const NeverScrollableScrollPhysics()
                        : const PageScrollPhysics(),
                    itemCount: _slides.length,
                    onPageChanged: (value) => setState(() => _index = value),
                    itemBuilder: (context, index) {
                      return _SlideView(
                        slide: _slides[index],
                        isDesktop: isDesktop,
                      );
                    },
                  ),
                ),
                _BottomControls(
                  index: _index,
                  count: _slides.length,
                  slide: slide,
                  isBusy: _startingDemo,
                  onPrevious: _goPrevious,
                  onNext: _goNext,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final Color accent;
  final Color secondaryAccent;
  final _MockupKind mockup;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.accent,
    required this.secondaryAccent,
    required this.mockup,
  });
}

enum _MockupKind { course, chat, mindmap, practice, plan }

class _OnboardingBackground extends StatelessWidget {
  final _OnboardingSlide slide;

  const _OnboardingBackground({required this.slide});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.surface,
            slide.accent.withValues(alpha: isDark ? 0.16 : 0.09),
            slide.secondaryAccent.withValues(alpha: isDark ? 0.12 : 0.07),
            cs.surface,
          ],
          stops: const [0, 0.38, 0.72, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  final _OnboardingSlide slide;

  const _BrandMark({required this.slide});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: slide.accent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(slide.icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          '伴学使用教学',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SlideView extends StatelessWidget {
  final _OnboardingSlide slide;
  final bool isDesktop;

  const _SlideView({required this.slide, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final maxWidth = isDesktop ? 1120.0 : 560.0;
    final horizontal = isDesktop ? 48.0 : 22.0;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 18),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _SlideCopy(slide: slide)),
                    const SizedBox(width: 40),
                    Expanded(child: _SoftwareMockup(slide: slide)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SlideCopy(slide: slide),
                    const SizedBox(height: 28),
                    _SoftwareMockup(slide: slide),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SlideCopy extends StatelessWidget {
  final _OnboardingSlide slide;

  const _SlideCopy({required this.slide});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.sizeOf(context).width >= 920;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: slide.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: slide.accent.withValues(alpha: 0.24)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(slide.icon, size: 18, color: slide.accent),
              const SizedBox(width: 8),
              Text(
                slide.primaryLabel,
                style: TextStyle(
                  color: slide.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          slide.title,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: isDesktop ? 42 : 30,
            height: 1.12,
            letterSpacing: 0,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          slide.subtitle,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: isDesktop ? 18 : 16,
            height: 1.72,
            letterSpacing: 0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SoftwareMockup extends StatelessWidget {
  final _OnboardingSlide slide;

  const _SoftwareMockup({required this.slide});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.sizeOf(context).width >= 920;

    return AspectRatio(
      aspectRatio: isDesktop ? 1.08 : 0.86,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: isDark ? 0.86 : 0.94),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: slide.accent.withValues(alpha: isDark ? 0.22 : 0.18),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          children: [
            _MockupTopBar(slide: slide),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _MockupBody(slide: slide),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MockupTopBar extends StatelessWidget {
  final _OnboardingSlide slide;

  const _MockupTopBar({required this.slide});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.56),
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          _WindowDot(color: const Color(0xFFEF4444)),
          const SizedBox(width: 6),
          _WindowDot(color: const Color(0xFFF59E0B)),
          const SizedBox(width: 6),
          _WindowDot(color: const Color(0xFF22C55E)),
          const SizedBox(width: 14),
          Icon(slide.icon, size: 18, color: slide.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '高等数学 / ${slide.primaryLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WindowDot extends StatelessWidget {
  final Color color;

  const _WindowDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _MockupBody extends StatelessWidget {
  final _OnboardingSlide slide;

  const _MockupBody({required this.slide});

  @override
  Widget build(BuildContext context) {
    switch (slide.mockup) {
      case _MockupKind.course:
        return _CourseMockup(slide: slide);
      case _MockupKind.chat:
        return _ChatMockup(slide: slide);
      case _MockupKind.mindmap:
        return _MindmapMockup(slide: slide);
      case _MockupKind.practice:
        return _PracticeMockup(slide: slide);
      case _MockupKind.plan:
        return _PlanMockup(slide: slide);
    }
  }
}

class _CourseMockup extends StatelessWidget {
  final _OnboardingSlide slide;

  const _CourseMockup({required this.slide});

  @override
  Widget build(BuildContext context) {
    final stats = [
      _MiniStat(Icons.functions_rounded, '极限与连续', '7 个节点'),
      _MiniStat(Icons.show_chart_rounded, '导数应用', '14 道题'),
      _MiniStat(Icons.area_chart_rounded, '积分方法', '5 份讲义'),
      _MiniStat(Icons.assignment_rounded, '期末真题', '已归档'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MockHeader(
          title: '高等数学',
          subtitle: '示例讲义 1 份 / 导图与讲义可一键生成',
          color: slide.accent,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              return GridView.count(
                crossAxisCount: compact ? 1 : 2,
                childAspectRatio: compact ? 4.6 : 2.2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                physics: const NeverScrollableScrollPhysics(),
                children: compact ? stats.take(3).toList() : stats,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChatMockup extends StatelessWidget {
  final _OnboardingSlide slide;

  const _ChatMockup({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MessageBubble(
          text: '求 lim(x->0) (sin x - x) / x^3，为什么结果是 -1/6？',
          alignRight: true,
          color: slide.accent,
        ),
        const SizedBox(height: 12),
        const _MessageBubble(
          text:
              '先用泰勒展开：sin x = x - x^3/6 + o(x^3)。所以分子留下 -x^3/6，除以 x^3 得 -1/6。',
          alignRight: false,
        ),
        const SizedBox(height: 12),
        _MockStepList(
          color: slide.secondaryAccent,
          items: const ['识别知识点：泰勒公式', '写出展开式', '代回并约去 x^3'],
        ),
      ],
    );
  }
}

class _MindmapMockup extends StatelessWidget {
  final _OnboardingSlide slide;

  const _MindmapMockup({required this.slide});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MindmapPainter(
        color: slide.accent,
        secondaryColor: slide.secondaryAccent,
        textColor: Theme.of(context).colorScheme.onSurface,
        surfaceColor: Theme.of(context).colorScheme.surface,
        outlineColor: Theme.of(context).colorScheme.outlineVariant,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _PracticeMockup extends StatelessWidget {
  final _OnboardingSlide slide;

  const _PracticeMockup({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MockHeader(
          title: '导数应用 / 5 题小组',
          subtitle: '根据今天的高数讲义自动生成',
          color: slide.accent,
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _QuizRow('01', '单调区间与极值', '已掌握', slide.secondaryAccent),
              _QuizRow('02', '洛必达法则条件', '待复盘', slide.accent),
              _QuizRow('03', '曲线凹凸性判断', '练习中', slide.secondaryAccent),
              _QuizRow('04', '渐近线综合题', '错题本', slide.accent),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanMockup extends StatelessWidget {
  final _OnboardingSlide slide;

  const _PlanMockup({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MockHeader(
          title: '14 天高数复习',
          subtitle: '每天 45 分钟 / 自动穿插复盘',
          color: slide.accent,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _TimelineColumn(
                  color: slide.accent,
                  items: const ['极限计算', '连续与间断点', '导数与微分', '不定积分'],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimelineColumn(
                  color: slide.secondaryAccent,
                  items: const ['定积分应用', '多元函数', '二重积分', '错题回炉'],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MockHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _MockHeader({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool alignRight;
  final Color? color;

  const _MessageBubble({
    required this.text,
    required this.alignRight,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = alignRight ? (color ?? cs.primary) : cs.surfaceContainerHighest;
    final fg = alignRight ? Colors.white : cs.onSurface;
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.86,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: fg,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _MockStepList extends StatelessWidget {
  final Color color;
  final List<String> items;

  const _MockStepList({required this.color, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      items[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MindmapPainter extends CustomPainter {
  final Color color;
  final Color secondaryColor;
  final Color textColor;
  final Color surfaceColor;
  final Color outlineColor;

  const _MindmapPainter({
    required this.color,
    required this.secondaryColor,
    required this.textColor,
    required this.surfaceColor,
    required this.outlineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final nodes = [
      (Offset(size.width * 0.22, size.height * 0.22), '函数'),
      (Offset(size.width * 0.78, size.height * 0.23), '极限'),
      (Offset(size.width * 0.22, size.height * 0.72), '连续'),
      (Offset(size.width * 0.78, size.height * 0.72), '导数'),
    ];
    final linePaint = Paint()
      ..color = outlineColor
      ..strokeWidth = 2;
    for (final node in nodes) {
      canvas.drawLine(center, node.$1, linePaint);
    }
    _drawNode(canvas, center, '高等数学', color, Colors.white, 104);
    for (var i = 0; i < nodes.length; i++) {
      _drawNode(
        canvas,
        nodes[i].$1,
        nodes[i].$2,
        surfaceColor,
        textColor,
        76,
        borderColor: i.isEven ? color : secondaryColor,
      );
    }
  }

  void _drawNode(
    Canvas canvas,
    Offset center,
    String label,
    Color fill,
    Color textColor,
    double width, {
    Color? borderColor,
  }) {
    final rect = Rect.fromCenter(center: center, width: width, height: 42);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    final paint = Paint()..color = fill;
    canvas.drawRRect(rrect, paint);
    if (borderColor != null) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = borderColor,
      );
    }
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: width - 12);
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _MindmapPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.surfaceColor != surfaceColor ||
        oldDelegate.outlineColor != outlineColor;
  }
}

class _QuizRow extends StatelessWidget {
  final String number;
  final String title;
  final String status;
  final Color color;

  const _QuizRow(this.number, this.title, this.status, this.color);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              number,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TimelineColumn extends StatelessWidget {
  final Color color;
  final List<String> items;

  const _TimelineColumn({required this.color, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'D${i + 1} ${items[i]}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (i != items.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                child: Container(
                  width: 1,
                  height: 18,
                  color: cs.outlineVariant,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  final int index;
  final int count;
  final _OnboardingSlide slide;
  final bool isBusy;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _BottomControls({
    required this.index,
    required this.count,
    required this.slide,
    required this.isBusy,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLast = index == count - 1;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width >= 920 ? 40 : 18,
        10,
        MediaQuery.sizeOf(context).width >= 920 ? 40 : 18,
        18,
      ),
      child: Row(
        children: [
          IconButton.outlined(
            onPressed: index == 0 || isBusy ? null : onPrevious,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: '上一页',
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < count; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: i == index ? 28 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: i == index
                          ? slide.accent
                          : cs.outlineVariant.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          FilledButton.icon(
            onPressed: isBusy ? null : onNext,
            icon: isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isLast
                        ? Icons.auto_awesome_rounded
                        : Icons.arrow_forward_rounded,
                  ),
            label: Text(isBusy ? '正在准备' : (isLast ? '创建示例课程' : '下一页')),
            style: FilledButton.styleFrom(
              backgroundColor: slide.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(132, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
