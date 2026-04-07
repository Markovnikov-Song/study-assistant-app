import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShellPage extends StatelessWidget {
  final Widget child;
  const ShellPage({super.key, required this.child});

  static const _tabs = [
    ('/chat',    Icons.chat_bubble_outline,   Icons.chat_bubble,   '问答'),
    ('/solve',   Icons.calculate_outlined,    Icons.calculate,     '解题'),
    ('/mindmap', Icons.account_tree_outlined, Icons.account_tree,  '导图'),
    ('/quiz',    Icons.auto_awesome_outlined, Icons.auto_awesome,  '出题'),
    ('/profile', Icons.person_outline,        Icons.person,        '我的'),
  ];

  int _index(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].$1)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index(location),
        onDestinationSelected: (i) => context.go(_tabs[i].$1),
        destinations: _tabs.map((t) => NavigationDestination(
          icon: Icon(t.$2), selectedIcon: Icon(t.$3), label: t.$4,
        )).toList(),
      ),
    );
  }
}
