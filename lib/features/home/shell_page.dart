import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/hint_provider.dart';
import '../../providers/subject_provider.dart';
import '../classroom/classroom_page.dart';
import '../library/library_page.dart';
import '../stationery/stationery_page.dart';
import '../profile/profile_page.dart';

class ShellPage extends ConsumerStatefulWidget {
  final Widget child;
  const ShellPage({super.key, required this.child});

  @override
  ConsumerState<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends ConsumerState<ShellPage> {
  static const _routes = ['/classroom', '/library', '/stationery', '/profile'];
  static const _tabs = [
    (Icons.school_outlined,          Icons.school,          '答疑室'),
    (Icons.local_library_outlined,   Icons.local_library,   '图书馆'),
    (Icons.edit_note_outlined,       Icons.edit_note,       '文具盒'),
    (Icons.person_outline,           Icons.person,          '我的'),
  ];

  static const _pages = [
    ClassroomPage(),
    LibraryPage(),
    StationeryPage(),
    ProfilePage(),
  ];

  late final PageController _pageCtrl;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: _currentIndex);
    // 登录后触发一次 hint 刷新（后台异步，不阻塞 UI）
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshHints());
  }

  Future<void> _refreshHints() async {
    try {
      final subjects = await ref.read(subjectsProvider.future);
      final ids = subjects.map((s) => s.id).toList();
      await triggerHintRefreshOnLogin(ref, ids);
    } catch (_) {
      // 静默忽略，不影响主流程
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  int _indexFromLocation(String location) {
    for (var i = 0; i < _routes.length; i++) {
      if (location.startsWith(_routes[i])) return i;
    }
    return 0;
  }

  bool _isSubRoute(String location) =>
      (location != '/profile' && location.startsWith('/profile/')) ||
      (location != '/library' && location.startsWith('/library/'));

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final routeIndex = _indexFromLocation(location);

    // 路由变化时同步 PageView（比如从其他地方 context.go）
    if (routeIndex != _currentIndex) {
      _currentIndex = routeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageCtrl.hasClients) {
          _pageCtrl.jumpToPage(_currentIndex);
        }
      });
    }

    return Scaffold(
      body: PageView(
        controller: _pageCtrl,
        physics: _isSubRoute(location)
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        onPageChanged: (i) {
          setState(() => _currentIndex = i);
          context.go(_routes[i]);
        },
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() => _currentIndex = i);
          _pageCtrl.animateToPage(i,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut);
          context.go(_routes[i]);
        },
        destinations: _tabs.map((t) => NavigationDestination(
          icon: Icon(t.$1), selectedIcon: Icon(t.$2), label: t.$3,
        )).toList(),
      ),
    );
  }
}
