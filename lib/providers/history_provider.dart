import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/history_service.dart';

final historyServiceProvider = Provider<HistoryService>((ref) => HistoryService());

final allSessionsProvider = FutureProvider<List<HistorySessionItem>>((ref) async {
  return ref.watch(historyServiceProvider).getAllSessions();
});
