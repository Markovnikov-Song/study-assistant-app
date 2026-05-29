import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/library/library_page.dart';
import '../../core/theme/styles/export.dart';
import '../../providers/hint_provider.dart';
import '../../providers/subject_provider.dart';
import '../../services/update_service.dart';
import '../chat/responsive_chat_page.dart';
import '../profile/profile_page.dart';
import '../toolkit/toolkit_page.dart';
import '../update/update_dialog.dart';

const _tabs = [
  (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, '答疑室'),
  (Icons.menu_book_outlined, Icons.menu_book_rounded, '图书馆'),
  (Icons.edit_note_rounded, Icons.edit_rounded, '工具箱'),
  (Icons.person_outline_rounded, Icons.person_rounded, '我的'),
];

class ResponsiveShell extends ConsumerStatefulWidget {
  final Widget child;
  final String location;

  const ResponsiveShell({
    super.key,
    required this.child,
    required this.location,
  });

  @override
  ConsumerState<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends ConsumerState<ResponsiveShell> {
  static const _routes = ['/', '/course-space', '/toolkit', '/profile'];

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshHints();
      _checkForUpdate();
    });
  }

  Future<void> _checkForUpdate() async {
    final result = await UpdateService.instance.checkForUpdate();
    if (!result.hasUpdate || !mounted) return;
    await showUpdateDialog(context, result.info!, isForced: result.isForced);
  }

  Future<void> _refreshHints() async {
    try {
      final subjects = await ref.read(subjectsProvider.future);
      final ids = subjects.map((s) => s.id).toList();
      await triggerHintRefreshOnLogin(ref, ids);
    } catch (e) {
      debugPrint('[ResponsiveShell] 提示词刷新失败: $e');
    }
  }

  @override
  void didUpdateWidget(ResponsiveShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateCurrentIndex();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateCurrentIndex();
  }

  void _updateCurrentIndex() {
    for (var i = 0; i < _routes.length; i++) {
      final route = _routes[i];
      if (route == '/') {
        if (widget.location == '/') {
          if (_currentIndex != i) setState(() => _currentIndex = i);
          return;
        }
      } else if (widget.location.startsWith(route)) {
        if (_currentIndex != i) setState(() => _currentIndex = i);
        return;
      }
    }
  }

  void _onDestinationSelected(int index) {
    setState(() => _currentIndex = index);
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    if (!isDesktop) {
      return _MobileShell(
        currentIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        isDark: isDark,
      );
    }

    return _DesktopShell(
      currentIndex: _currentIndex,
      onDestinationSelected: _onDestinationSelected,
      isDark: isDark,
      location: widget.location,
      child: widget.child,
    );
  }
}

class _MobileShell extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isDark;

  const _MobileShell({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: _PageBackground(pageIndex: currentIndex, isDark: isDark),
          ),
          IndexedStack(
            index: currentIndex,
            children: const [
              _KeepAlivePage(
                child: ResponsiveChatPage(key: PageStorageKey('chat')),
              ),
              _KeepAlivePage(
                child: LibraryPage(key: PageStorageKey('library')),
              ),
              _KeepAlivePage(
                child: ToolkitPage(key: PageStorageKey('toolkit')),
              ),
              _KeepAlivePage(
                child: ProfilePage(key: PageStorageKey('profile')),
              ),
            ],
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.96),
              border: Border(
                top: BorderSide(color: cs.outlineVariant, width: 0.5),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: NavigationBar(
                  selectedIndex: currentIndex,
                  onDestinationSelected: onDestinationSelected,
                  destinations: _tabs
                      .map(
                        (t) => NavigationDestination(
                          icon: Icon(t.$1),
                          selectedIcon: _GradientIcon(icon: t.$2),
                          label: t.$3,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopShell extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isDark;
  final String location;
  final Widget child;

  const _DesktopShell({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.isDark,
    required this.location,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final styleId = ref.watch(uiStyleIdProvider);

    return Scaffold(
      body: Row(
        children: [
          _DesktopNavigationRail(
            currentIndex: currentIndex,
            onDestinationSelected: onDestinationSelected,
            isDark: isDark,
            styleId: styleId,
          ),
          VerticalDivider(width: 1, thickness: 1, color: cs.outlineVariant),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _PageBackground(
                    pageIndex: currentIndex,
                    isDark: isDark,
                  ),
                ),
                Column(
                  children: [
                    _DesktopPathBar(
                      location: location,
                      sectionLabel: _tabs[currentIndex].$3,
                      styleId: styleId,
                    ),
                    Expanded(child: _buildDesktopContent()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopContent() {
    if (currentIndex == 0) return const ResponsiveChatPage();
    return child;
  }
}

class _DesktopPathBar extends StatelessWidget {
  final String location;
  final String sectionLabel;
  final String styleId;

  const _DesktopPathBar({
    required this.location,
    required this.sectionLabel,
    required this.styleId,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayPath = location.isEmpty ? '/' : location;
    final crumbs = _buildCrumbs(displayPath, sectionLabel);
    final isClay = styleId == StyleIds.clay;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: isClay ? 50 : 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: isClay ? 0.88 : 0.94),
            borderRadius: isClay
                ? const BorderRadius.only(bottomRight: Radius.circular(24))
                : null,
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
            boxShadow: isClay
                ? [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).shadowColor.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(8, 8),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.72),
                      blurRadius: 16,
                      offset: const Offset(-8, -8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(Icons.route_rounded, size: 19, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < crumbs.length; i++) ...[
                        if (i > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: cs.outline,
                            ),
                          ),
                        Text(
                          crumbs[i],
                          style: TextStyle(
                            fontSize: i == crumbs.length - 1 ? 14 : 13,
                            fontWeight: i == crumbs.length - 1
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: i == crumbs.length - 1
                                ? cs.onSurface
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Tooltip(
                message: '复制当前路径',
                child: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: displayPath));
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('路径已复制')));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _buildCrumbs(String path, String sectionLabel) {
    final segments = path
        .split('/')
        .where((part) => part.trim().isNotEmpty)
        .map(_labelForSegment)
        .toList();
    if (segments.isEmpty) return ['伴学', sectionLabel, '/'];
    return ['伴学', sectionLabel, ...segments];
  }

  String _labelForSegment(String value) {
    switch (value) {
      case 'course-space':
        return '课程空间';
      case 'toolkit':
        return '工具箱';
      case 'profile':
        return '我的';
      case 'calendar':
        return '学习日历';
      case 'notebooks':
        return '笔记本';
      case 'mindmap':
        return '脑图';
      case 'lecture':
        return '讲义';
      case 'solve':
        return '解题';
      case 'quiz':
        return '出题';
      case 'review':
        return '复盘';
      case 'mistake-book':
        return '错题本';
      default:
        return Uri.decodeComponent(value);
    }
  }
}

class _DesktopNavigationRail extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isDark;
  final String styleId;

  const _DesktopNavigationRail({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.isDark,
    required this.styleId,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isClay = styleId == StyleIds.clay;

    return Container(
      width: isClay ? 204 : 196,
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: isClay ? 0.90 : 1),
        border: Border(right: BorderSide(color: cs.outlineVariant)),
        borderRadius: isClay
            ? const BorderRadius.only(
                topRight: Radius.circular(28),
                bottomRight: Radius.circular(28),
              )
            : null,
        boxShadow: isClay
            ? [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.20),
                  blurRadius: 24,
                  offset: const Offset(10, 10),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.75),
                  blurRadius: 20,
                  offset: const Offset(-10, -10),
                ),
              ]
            : null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(isClay ? 14 : 8),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '伴学',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                itemCount: _tabs.length,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemBuilder: (context, index) {
                  final tab = _tabs[index];
                  final isSelected = index == currentIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _DesktopNavItem(
                      icon: isSelected ? tab.$2 : tab.$1,
                      label: tab.$3,
                      isSelected: isSelected,
                      styleId: styleId,
                      onTap: () => onDestinationSelected(index),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'v1.2.2',
                style: TextStyle(fontSize: 12, color: cs.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final String styleId;
  final VoidCallback onTap;

  const _DesktopNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.styleId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isClay = styleId == StyleIds.clay;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(isClay ? 18 : 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isClay ? 18 : 8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.primary.withValues(alpha: isClay ? 0.16 : 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(isClay ? 18 : 8),
            border: isSelected
                ? Border.all(color: cs.primary.withValues(alpha: 0.28))
                : null,
            boxShadow: isClay && isSelected
                ? [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).shadowColor.withValues(alpha: 0.16),
                      blurRadius: 14,
                      offset: const Offset(6, 6),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.70),
                      blurRadius: 12,
                      offset: const Offset(-6, -6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? cs.primary : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageBackground extends ConsumerWidget {
  final int pageIndex;
  final bool isDark;

  const _PageBackground({required this.pageIndex, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final base = Theme.of(context).scaffoldBackgroundColor;
    final styleId = ref.watch(uiStyleIdProvider);
    final isClay = styleId == StyleIds.clay;
    return Stack(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 360),
          decoration: BoxDecoration(
            color: base,
            gradient: isClay
                ? LinearGradient(
                    colors: [
                      base,
                      cs.primary.withValues(alpha: isDark ? 0.10 : 0.07),
                      cs.secondary.withValues(alpha: isDark ? 0.08 : 0.055),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primary.withValues(alpha: isDark ? 0.06 : 0.045),
                  Colors.transparent,
                  cs.secondary.withValues(alpha: isDark ? 0.045 : 0.035),
                  Colors.transparent,
                ],
                stops: const [0, 0.34, 0.72, 1],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientIcon extends StatelessWidget {
  final IconData icon;

  const _GradientIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [cs.primary, cs.secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Icon(icon, color: Colors.white),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;

  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
