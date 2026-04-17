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

import 'app.dart';                          // App 根组件
import 'core/network/dio_client.dart';      // HTTP 客户端
import 'core/storage/storage_service.dart'; // 本地存储（保存登录 token）
import 'providers/shared_preferences_provider.dart';

// main() 是 Dart 程序的唯一入口，async 表示这是异步函数
// 相当于 Python 的 async def main()
void main() async {
  // 确保 Flutter 引擎初始化完成后再执行后续代码
  // 因为下面要用到平台相关功能（本地存储），必须先初始化引擎
  // 类似 Python 里某些库需要先 init() 才能用
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化本地安全存储（用于保存 JWT token，App 重启后仍保持登录）
  // await 表示等待这个异步操作完成，类似 Python 的 await asyncio
  await StorageService.instance.init();

  // 初始化 HTTP 客户端（Dio），配置 baseUrl、超时时间、拦截器等
  DioClient.instance.init();

  // 初始化 SharedPreferences，供 mindmap 等功能使用
  final prefs = await SharedPreferences.getInstance();

  // 启动 Flutter 应用
  // ProviderScope 是 Riverpod 的根容器，必须包裹整个 App
  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const App(),
  ));
}
