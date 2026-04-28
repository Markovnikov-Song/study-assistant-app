import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/device_info.dart';
import '../chat/responsive_chat_page.dart';
import '../../components/library/library_page.dart';
import '../toolkit/toolkit_page.dart';
import '../profile/profile_page.dart';
import '../../providers/hint_provider.dart';
import '../../providers/subject_provider.dart';
import '../../providers/background_style_provider.dart';
import '../update/update_dialog.dart';
import '../../services/update_service.dart';

/// 响应式 Shell - 移动端底部导航，桌面端侧边导航

const _tabs = [
  (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, '答疑室'),
  (Icons.menu_book_outlined,          Icons.menu_book_rounded,    '图书馆'),
  (Icons.edit_note_rounded,           Icons.edit_rounded,         '工具箱'),
  (Icons.person_outline_rounded,      Icons.person_rounded,       '我的'),
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
    await showUpdateDialog(
      context,
      result.info!,
      isForced: result.isForced,
    );
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
    final isDesktop = DeviceInfo.isLargeScreen;

    // 移动端：使用原来的底部导航方式
    if (!isDesktop) {
      return _MobileShell(
        currentIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        isDark: isDark,
      );
    }

    // 桌面端：侧边导航 + 内容区
    return _DesktopShell(
      currentIndex: _currentIndex,
      onDestinationSelected: _onDestinationSelected,
      isDark: isDark,
      child: widget.child,
    );
  }
}

/// 移动端 Shell
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
          // 全页 SVG 背景装饰
          Positioned.fill(
            child: _PageBackground(pageIndex: currentIndex, isDark: isDark),
          ),
          // 页面内容
          IndexedStack(
            index: currentIndex,
            children: const [
              _KeepAlivePage(child: ResponsiveChatPage(key: PageStorageKey('chat'))),
              _KeepAlivePage(child: LibraryPage(key: PageStorageKey('library'))),
              _KeepAlivePage(child: ToolkitPage(key: PageStorageKey('toolkit'))),
              _KeepAlivePage(child: ProfilePage(key: PageStorageKey('profile'))),
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
              color: cs.surface.withValues(alpha: 0.85),
              border: Border(
                top: BorderSide(
                  color: cs.outline.withValues(alpha: isDark ? 0.3 : 0.5),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: NavigationBar(
                  selectedIndex: currentIndex,
                  onDestinationSelected: onDestinationSelected,
                  destinations: _tabs.map((t) => NavigationDestination(
                    icon: Icon(t.$1),
                    selectedIcon: _GradientIcon(icon: t.$2),
                    label: t.$3,
                  )).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 桌面端 Shell - 侧边导航 + 内容区
class _DesktopShell extends ConsumerStatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isDark;
  final Widget child;

  const _DesktopShell({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.isDark,
    required this.child,
  });

  @override
  ConsumerState<_DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<_DesktopShell> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          // 侧边导航栏
          _DesktopNavigationRail(
            currentIndex: widget.currentIndex,
            onDestinationSelected: widget.onDestinationSelected,
            isDark: widget.isDark,
          ),
          // 分隔线
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: cs.outline.withValues(alpha: widget.isDark ? 0.3 : 0.5),
          ),
          // 内容区 - 桌面端使用分栏布局
          Expanded(
            child: _buildDesktopContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopContent() {
    // 桌面端 Chat 页面使用分栏布局
    if (widget.currentIndex == 0) {
      return const ResponsiveChatPage();
    }
    // 其他页面使用 shell 传入的 child
    return widget.child;
  }
}

/// 桌面端导航栏
class _DesktopNavigationRail extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isDark;

  const _DesktopNavigationRail({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 200,
      color: cs.surface,
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Logo/标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, cs.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  '伴学',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 导航项
          Expanded(
            child: ListView.builder(
              itemCount: _tabs.length,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final isSelected = index == currentIndex;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _DesktopNavItem(
                    icon: isSelected ? tab.$2 : tab.$1,
                    label: tab.$3,
                    isSelected: isSelected,
                    isDark: isDark,
                    onTap: () => onDestinationSelected(index),
                  ),
                );
              },
            ),
          ),
          // 底部
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'v1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: cs.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 桌面端导航项
class _DesktopNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _DesktopNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: cs.primary.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected
                    ? cs.primary
                    : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? cs.primary
                      : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 全页 SVG 背景装饰
class _PageBackground extends ConsumerWidget {
  final int pageIndex;
  final bool isDark;

  const _PageBackground({required this.pageIndex, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 从 BackgroundStyle 获取底色 + SVG路径 + 透明度
    final style = ref.watch(backgroundStyleProvider);
    final bgAsset = (pageIndex >= 0 && pageIndex < style.svgAssets.length)
        ? style.svgAssets[pageIndex]
        : style.svgAssets[0];
    final bgColor = isDark ? style.darkBg : style.lightBg;

    return Stack(
      children: [
        // 风格底色（随风格切换而变化）
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          color: bgColor,
        ),
        // SVG 背景叠加层 - 使用风格配置的透明度
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: style.svgOpacity,
          child: SvgPicture.asset(bgAsset, fit: BoxFit.cover),
        ),
      ],
    );
  }
}

/// 渐变选中图标
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

/// KeepAlive 页面包装
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
