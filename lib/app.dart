import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/styles/export.dart';
import 'routes/app_router.dart';
import 'widgets/incident_feedback_fab.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final lightTheme = ref.watch(uiLightThemeProvider);
    final darkTheme = ref.watch(uiDarkThemeProvider);

    return MaterialApp.router(
      title: '伴学',
      routerConfig: router,
      localizationsDelegates: const [
        FlutterQuillLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      locale: const Locale('zh', 'CN'),
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      builder: (context, child) {
        return RepaintBoundary(
          key: IncidentCapture.boundaryKey,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: Stack(
              fit: StackFit.expand,
              children: [
                child ?? const SizedBox(),
                const IncidentFeedbackFab(),
              ],
            ),
          ),
        );
      },
    );
  }
}
