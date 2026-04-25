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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await StorageService.instance.init();
  DioClient.instance.init();

  // 初始化推送通知服务
  await NotificationService.instance.init();

  final prefs = await SharedPreferences.getInstance();

  // 根据已保存的设置重新调度所有通知（App 重启后恢复）
  final notifSettings = await NotificationSettings.load();
  await NotificationService.instance.rescheduleAll(notifSettings);

  // 初始化 Level 2 和 Level 3 Monitor
  final level3Monitor = Level3Monitor();
  await level3Monitor.start();

  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const App(),
  ));
}
