// ─────────────────────────────────────────────────────────────
// app.dart — App 根组件，配置主题和路由
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'routes/app_router.dart'; // 路由配置（页面跳转规则）

// ConsumerWidget：能读取 Riverpod 状态的 Widget
// 普通 Widget 用 StatelessWidget，需要读全局状态时用 ConsumerWidget
// 类比 Python：普通类 vs 继承了某个带状态基类的类
class App extends ConsumerWidget {
  // super.key 是 Flutter Widget 的标识符，用于性能优化，固定写法
  const App({super.key});

  // build() 是 Flutter 的核心方法，返回"这个组件长什么样"
  // 每次状态变化时 Flutter 会重新调用 build() 重绘 UI
  // context：当前组件在 Widget 树中的位置信息
  // ref：Riverpod 提供的引用，用来读取全局状态
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听路由 provider，获取 GoRouter 实例
    // ref.watch() 表示"订阅"这个状态，状态变化时自动重建
    // 类比 Python：相当于 router = state_manager.get('router')，且自动更新
    final router = ref.watch(routerProvider);

    // MaterialApp.router：使用路由配置的 Material Design 应用根组件
    // .router 版本支持 GoRouter 这类声明式路由库
    return MaterialApp.router(
      title: '学科学习助手',
      routerConfig: router,
      localizationsDelegates: const [
        FlutterQuillLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('zh', 'CN'),

      // 亮色主题配置
      theme: ThemeData(
        // fromSeed：从一个种子颜色自动生成整套配色方案
        // 0xFF4A90D9 是十六进制颜色值，FF=不透明，4A90D9=蓝色
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A90D9)),
        useMaterial3: true, // 使用 Material Design 3 风格（更现代）
      ),

      // 深色主题配置（系统切换深色模式时自动使用）
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90D9),
          brightness: Brightness.dark, // 告诉框架这是深色方案
        ),
        useMaterial3: true,
      ),
    );
  }
}
