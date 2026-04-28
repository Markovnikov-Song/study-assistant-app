import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 跨页面传递解题预填文字。
/// chat_page 里 OCR 识别成功后写入，SolvePage 挂载时读取并清空。
final solvePreFillProvider = StateProvider<String?>((ref) => null);
