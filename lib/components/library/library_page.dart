import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/document.dart';
import '../../models/mindmap_library.dart';
import '../../core/theme/subject_gradients.dart';
import '../../models/subject.dart';
import '../../core/theme/styles/export.dart';
import '../../providers/document_provider.dart';
import '../../providers/library_provider.dart';
import '../../routes/app_router.dart';

/// LibraryPage — 图书馆主页，展示学科课程卡片列表（含学习进度）
/// 全新设计的「静谧学习」视觉风格
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SubjectWithProgress> _sorted(List<SubjectWithProgress> list) {
    final filtered = _query.isEmpty
        ? list
        : list.where((s) {
            final q = _query.toLowerCase();
            return s.subject.name.toLowerCase().contains(q) ||
                (s.subject.category?.toLowerCase().contains(q) ?? false);
          }).toList();

    filtered.sort((a, b) {
      // Pinned first
      final pinCmp =
          (b.subject.isPinned ? 1 : 0) - (a.subject.isPinned ? 1 : 0);
      if (pinCmp != 0) return pinCmp;
      // Then by last visited desc
      final aTime = a.lastVisitedAt ?? DateTime(0);
      final bTime = b.lastVisitedAt ?? DateTime(0);
      return bTime.compareTo(aTime);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(schoolSubjectsProvider);
    final cs = Theme.of(context).colorScheme;
    final styleId = ref.watch(uiStyleIdProvider);
    final isClay = styleId == StyleIds.clay;
    final useDesktopGrid = MediaQuery.sizeOf(context).width >= 1180;

    return Scaffold(
      backgroundColor: isClay ? Colors.transparent : cs.surface,
      body: Stack(
        children: [
          // 主内容（SVG 背景由 ShellPage 提供）
          CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 80,
                floating: true,
                pinned: false,
                backgroundColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  title: Text(
                    '图书馆',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
              // 搜索栏
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isClay
                          ? Color.lerp(
                              cs.surface,
                              cs.surfaceContainerHighest,
                              0.22,
                            )
                          : cs.surface,
                      borderRadius: BorderRadius.circular(isClay ? 24 : 16),
                      border: Border.all(
                        color: isClay
                            ? Colors.white.withValues(alpha: 0.88)
                            : Colors.transparent,
                        width: isClay ? 1.2 : 0,
                      ),
                      boxShadow: [
                        if (isClay) ...[
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).shadowColor.withValues(alpha: 0.16),
                            blurRadius: 20,
                            offset: const Offset(9, 9),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.76),
                            blurRadius: 18,
                            offset: const Offset(-9, -9),
                          ),
                        ] else
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: cs.brightness == Brightness.dark
                                  ? 0.2
                                  : 0.05,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '搜索科目名称或分类…',
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                ),
              ),
              // 内容
              subjectsAsync.when(
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) =>
                    SliverFillRemaining(child: Center(child: Text('加载失败：$e'))),
                data: (subjects) {
                  final sorted = _sorted(subjects);
                  if (sorted.isEmpty) {
                    return SliverFillRemaining(
                      child: _EmptyState(hasQuery: _query.isNotEmpty),
                    );
                  }
                  if (useDesktopGrid) {
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 18,
                              mainAxisSpacing: 18,
                              mainAxisExtent: 280,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _SubjectCard(
                            item: sorted[index],
                            styleId: styleId,
                          ),
                          childCount: sorted.length,
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _SubjectCard(
                            item: sorted[index],
                            styleId: styleId,
                          ),
                        ),
                        childCount: sorted.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  const _EmptyState({this.hasQuery = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    cs.secondary.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Icon(
                Icons.menu_book_outlined,
                size: 56,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              hasQuery ? '没有匹配的科目' : '图书馆空空的',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery ? '试试其他关键词' : '去「我的」→「科目管理」创建科目\n再生成思维导图，课程就会出现',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectCard extends ConsumerStatefulWidget {
  final SubjectWithProgress item;
  final String styleId;

  const _SubjectCard({required this.item, required this.styleId});

  @override
  ConsumerState<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends ConsumerState<_SubjectCard> {
  bool _detailExpanded = false;

  SubjectWithProgress get item => widget.item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subject = item.subject;
    final percent = item.totalNodes == 0
        ? 0.0
        : item.litNodes / item.totalNodes;
    final isClay = widget.styleId == StyleIds.clay;
    final radius = isClay ? 28.0 : 16.0;
    final cardColor = isClay
        ? Color.lerp(cs.surface, cs.surfaceContainerHighest, 0.30)!
        : cs.surface;
    final kbAsync = ref.watch(subjectKnowledgeBaseProvider(subject.id));

    final subjectColors = SubjectGradients.colorsFor(
      colorIndex: subject.colorIndex,
      name: subject.name,
    );

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          if (isClay) ...[
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.20),
              blurRadius: 24,
              spreadRadius: 1,
              offset: const Offset(12, 12),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.78),
              blurRadius: 22,
              spreadRadius: 1,
              offset: const Offset(-12, -12),
            ),
          ] else
            BoxShadow(
              color: Colors.black.withValues(
                alpha: cs.brightness == Brightness.dark ? 0.2 : 0.06,
              ),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
        border: Border.all(
          color: isClay ? Colors.white.withValues(alpha: 0.92) : cs.outline,
          width: isClay ? 1.4 : 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: subjectColors,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: subjectColors.first.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        subject.name.isNotEmpty ? subject.name[0] : '?',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                subject.name,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            if (subject.isPinned)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: cs.tertiary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.push_pin,
                                  size: 14,
                                  color: cs.tertiary,
                                ),
                              ),
                          ],
                        ),
                        if (subject.category != null &&
                            subject.category!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subject.category!,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StartLearningButton(
                    colors: subjectColors,
                    onTap: () =>
                        context.push(AppRoutes.courseSpaceById(subject.id)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: isClay
                            ? cs.surface.withValues(alpha: 0.72)
                            : cs.surfaceContainerHighest,
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: percent,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: subjectColors),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          subjectColors.first.withValues(alpha: 0.15),
                          subjectColors.last.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(percent * 100).floor()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: subjectColors.first,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _KnowledgeBaseChip(
                    isClay: isClay,
                    accentColor: subjectColors.first,
                    onTap: () => context.push(
                      AppRoutes.subjectDetailPath(subject.id),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.lightbulb_outline_rounded,
                    label: '${item.litNodes}/${item.totalNodes}',
                    isClay: isClay,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.account_tree_outlined,
                    label: '${item.sessionCount}份导图',
                    isClay: isClay,
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () =>
                        setState(() => _detailExpanded = !_detailExpanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '详细',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: subjectColors.first,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            _detailExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: subjectColors.first,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _detailExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                sizeCurve: Curves.easeInOut,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _SubjectDetailPanel(
                    subject: subject,
                    lastVisitedAt: item.lastVisitedAt,
                    kbAsync: kbAsync,
                    isClay: isClay,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartLearningButton extends StatelessWidget {
  final List<Color> colors;
  final VoidCallback onTap;

  const _StartLearningButton({
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '开始学习',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectDetailPanel extends StatelessWidget {
  final Subject subject;
  final DateTime? lastVisitedAt;
  final AsyncValue<SubjectKnowledgeBase> kbAsync;
  final bool isClay;

  const _SubjectDetailPanel({
    required this.subject,
    required this.lastVisitedAt,
    required this.kbAsync,
    required this.isClay,
  });

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kbLabel = kbAsync.maybeWhen(
      data: (kb) => kb.documentCount > 0
          ? '${kb.statusLabel} · ${kb.documentCount} 份资料'
          : kb.statusLabel,
      orElse: () => '加载中…',
    );
    final kbUpdated = kbAsync.maybeWhen(
      data: (kb) => kb.updatedAt != null ? _formatDate(kb.updatedAt!) : null,
      orElse: () => null,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isClay
            ? cs.surface.withValues(alpha: 0.55)
            : cs.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(isClay ? 14 : 10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(
            icon: Icons.source_outlined,
            label: '资料来源',
            value: kbLabel,
          ),
          const SizedBox(height: 6),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: '创建时间',
            value: _formatDate(subject.createdAt),
          ),
          if (lastVisitedAt != null) ...[
            const SizedBox(height: 6),
            _DetailRow(
              icon: Icons.history_rounded,
              label: '最近访问',
              value: _formatDate(lastVisitedAt!),
            ),
          ],
          if (kbUpdated != null) ...[
            const SizedBox(height: 6),
            _DetailRow(
              icon: Icons.update_rounded,
              label: '资料更新',
              value: kbUpdated,
            ),
          ],
          if (subject.description != null &&
              subject.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            _DetailRow(
              icon: Icons.notes_rounded,
              label: '备注',
              value: subject.description!.trim(),
            ),
          ],
        ],
      ),
    );
  }
}

class _KnowledgeBaseChip extends StatelessWidget {
  final bool isClay;
  final Color accentColor;
  final VoidCallback onTap;

  const _KnowledgeBaseChip({
    required this.isClay,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(isClay ? 10 : 6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: isClay ? 0.12 : 0.10),
            borderRadius: BorderRadius.circular(isClay ? 10 : 6),
            border: Border.all(color: accentColor.withValues(alpha: 0.25)),
            boxShadow: isClay
                ? [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(3, 3),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.62),
                      blurRadius: 7,
                      offset: const Offset(-3, -3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_outlined, size: 12, color: accentColor),
              const SizedBox(width: 4),
              Text(
                '进入资料库',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: cs.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 6),
        Text(
          '$label：',
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurface.withValues(alpha: 0.55),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isClay;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.isClay,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isClay
            ? cs.surface.withValues(alpha: 0.58)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(isClay ? 10 : 6),
        boxShadow: isClay
            ? [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.10),
                  blurRadius: 8,
                  offset: const Offset(3, 3),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.62),
                  blurRadius: 7,
                  offset: const Offset(-3, -3),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: cs.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
