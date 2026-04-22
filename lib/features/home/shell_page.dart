import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/hint_provider.dart';
import '../../providers/subject_provider.dart';
import '../chat/chat_page.dart';
import '../../components/library/library_page.dart';
import '../toolkit/toolkit_page.dart';
import '../profile/profile_page.dart';
import '../../core/theme/app_colors.dart';

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
    } catch (_) {}
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
          // 背景渐变装饰
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          AppColors.primaryDark.withOpacity(0.15),
                          AppColors.primaryLight.withOpacity(0.05),
                        ]
                      : [
                          AppColors.primaryLight.withOpacity(0.08),
                          AppColors.primary.withOpacity(0.02),
                        ],
                ),
              ),
            ),
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
              color: (isDark ? AppColors.surfaceDark : AppColors.surface)
                  .withOpacity(0.85),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? AppColors.borderDark.withOpacity(0.3)
                      : AppColors.border.withOpacity(0.5),
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

// 渐变选中图标
class _GradientIcon extends StatelessWidget {
  final IconData icon;
  
  const _GradientIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [AppColors.primary, AppColors.primaryLight],
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
