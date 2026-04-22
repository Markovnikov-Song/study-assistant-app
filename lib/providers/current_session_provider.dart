import 'package:flutter_riverpod/flutter_riverpod.dart';

/// UI 层的 Session 数据类（与后端 ConversationSession 分离，轻量级）
class Session {
  final String id;
  final String title;
  final DateTime updatedAt;
  final String? subjectId;
  final String? taskId;

  const Session({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.subjectId,
    this.taskId,
  });
}

/// 当前活跃 Session，ChatPage 进入时写入，离开时清除
final currentSessionProvider = StateProvider<Session?>((ref) => null);
