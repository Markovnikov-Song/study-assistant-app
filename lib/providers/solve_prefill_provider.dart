import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 跨页面传递解题预填文字。
/// chat_page 里 OCR 识别成功后写入，SolvePage 挂载时读取并清空。
final solvePreFillProvider = StateProvider<String?>((ref) => null);

/// 跨页面传递解题图片。聊天图片预览页点击“去解题页编辑”时写入，
/// SolvePage 挂载后自动以拍照解题流程发送。
final solveImagePreFillProvider = StateProvider<List<String>>(
  (ref) => const [],
);
