import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../services/history_service.dart';

final historyServiceProvider = Provider<HistoryService>((ref) => HistoryService());

// 扩展 ConversationSession 加上 subjectId
extension SessionSubject on ConversationSession {
  int? get subjectId => null; // 由 HistoryService 返回的数据填充
}

final allSessionsProvider = FutureProvider<List<ConversationSession>>((ref) async {
  return ref.watch(historyServiceProvider).getAllSessions();
});
