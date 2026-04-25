import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/hint_provider.dart';
import '../../providers/subject_provider.dart';
import '../../providers/background_style_provider.dart';
import '../chat/chat_page.dart';
import '../../components/library/library_page.dart';
import '../toolkit/toolkit_page.dart';
import '../profile/profile_page.dart';

class ShellPage extends ConsumerStatefulWidget {
  final Widget child;
  const ShellPage({super.key, required this.child});

  @override
  ConsumerState<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends ConsumerState<ShellPage> {
  static const _routes = ['/', '/course-space', '/toolkit', '/profile'];
  static const _tabs = [
    (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, '答疑室'),
    (Icons.menu_book_outlined,          Icons.menu_book_rounded,    '图书馆'),
    (Icons.edit_note_rounded,           Icons.edit_rounded,         '工具箱'),
    (Icons.person_outline_rounded,      Icons.person_rounded,       '我的'),
  ];

  late final PageController _pageCtrl;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshHints());
  }

  Future<void> _refreshHints() async {
    try {
      final subjects = await ref.read(subjectsProvider.future);
      final ids = subjects.map((s) => s.id).toList();
      await triggerHintRefreshOnLogin(ref, ids);
    } catch (e) {
      debugPrint('[ShellPage] 提示词刷新失败: $e');
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  int _indexFromLocation(String location) {
    for (var i = 0; i < _routes.length; i++) {
      final route = _routes[i];
      if (route == '/') {
        if (location == '/') return i;
      } else if (location.startsWith(route)) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final routeIndex = _indexFromLocation(location);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (routeIndex != _currentIndex) {
      _currentIndex = routeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(_currentIndex);
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          // 全页 SVG 背景装饰
          Positioned.fill(
            child: _PageBackground(pageIndex: _currentIndex, isDark: isDark),
          ),
          // 页面内容
          PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              _KeepAlivePage(child: ChatPage(key: PageStorageKey('chat'))),
              _KeepAlivePage(child: LibraryPage(key: PageStorageKey('library'))),
              _KeepAlivePage(child: ToolkitPage(key: PageStorageKey('toolkit'))),
              _KeepAlivePage(child: ProfilePage(key: PageStorageKey('profile'))),
            ],
          ),
        ],
      ),
      // 毛玻璃效果底部导航
      extendBody: true,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface
                  .withValues(alpha: 0.85),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline
                      .withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: NavigationBar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (i) {
                    setState(() => _currentIndex = i);
                    _pageCtrl.jumpToPage(i);
                    context.go(_routes[i]);
                  },
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

// 全页 SVG 背景装饰
class _PageBackground extends ConsumerWidget {
  final int pageIndex;
  final bool isDark;

  const _PageBackground({required this.pageIndex, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 从 Provider 获取当前背景风格（同时拿到底色 + SVG路径 + 透明度）
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

// 渐变选中图标 - 使用 Theme API 动态获取主色
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
