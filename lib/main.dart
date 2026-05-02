// ─────────────────────────────────────────────────────────────
// main.dart — 程序入口，相当于 C 语言的 main() 函数
// ─────────────────────────────────────────────────────────────

// Flutter UI 框架的核心库，提供 Widget、Material 组件等
import 'package:flutter/material.dart';

// Riverpod：Flutter 的状态管理库，类似 Python 里的全局变量管理器
// 所有"全局状态"（登录信息、当前学科等）都通过它共享
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 导入同项目的其他文件（相对路径，类似 Python 的 from . import xxx）
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/network/dio_client.dart';
import 'core/storage/storage_service.dart';
import 'providers/shared_preferences_provider.dart';
import 'services/notification_service.dart';
import 'services/level3_monitor.dart';
import 'services/update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await StorageService.instance.init();
  DioClient.instance.init();

  // 初始化后台下载服务（用于应用更新）
  try {
    await UpdateService.initialize();
  } catch (e) {
    debugPrint('[main] UpdateService init failed: $e');
  }

  // 初始化推送通知服务（失败不阻塞启动）
  try {
    await NotificationService.instance.init();
    final notifSettings = await NotificationSettings.load();
    await NotificationService.instance.rescheduleAll(notifSettings);
  } catch (e) {
    debugPrint('[main] NotificationService init failed: $e');
  }

  final prefs = await SharedPreferences.getInstance();

  // Level 3 Monitor 在后台启动，不 await，避免网络请求阻塞启动
  final level3Monitor = Level3Monitor();
  level3Monitor.start().catchError((e) {
    debugPrint('[main] Level3Monitor start failed: $e');
  });

  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const App(),
  ));
}
