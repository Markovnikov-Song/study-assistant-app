// ─────────────────────────────────────────────────────────────
// app.dart — App 根组件，配置主题和路由
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'routes/app_router.dart';
import 'providers/background_style_provider.dart';

/// App 根组件，支持多风格切换
/// 
/// 主题系统连接到 BackgroundStyle：
/// - 浅色主题由 backgroundStyle.toLightColorScheme() 生成
/// - 深色主题由 backgroundStyle.toDarkColorScheme() 生成
/// 切换背景风格时，整个应用的组件颜色都会同步变化
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // 监听 BackgroundStyle，风格切换时自动重建主题
    final style = ref.watch(backgroundStyleProvider);
    
    // 基于 BackgroundStyle.accentColor 动态生成主题
    final lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: style.toLightColorScheme(),
    );
    final darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: style.toDarkColorScheme(),
    );

    return MaterialApp.router(
      title: '伴学',
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

      // 使用 BackgroundStyle 动态生成的主题
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,

      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}
