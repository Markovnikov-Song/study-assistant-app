import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mindmap_library.dart';
import '../services/learning_path_service.dart';

// ── Service ───────────────────────────────────────────────────────────────────

final learningPathServiceProvider =
    Provider<LearningPathService>((ref) => LearningPathService());

// ── Learning Path (by subjectId) ─────────────────────────────────────────────

final learningPathProvider =
    FutureProvider.family<LearningPath?, int>((ref, subjectId) async {
  return LearningPathService().getLearningPath(subjectId);
});

// ── Node States (by sessionId) ───────────────────────────────────────────────

final nodeStatesMapProvider =
    FutureProvider.family<Map<String, NodeState>, int>((ref, sessionId) async {
  return LearningPathService().getNodeStates(sessionId);
});

// ── Node Mastery (by sessionId) ──────────────────────────────────────────────

final nodeMasteryProvider =
    FutureProvider.family<Map<String, NodeMastery>, int>((ref, sessionId) async {
  return LearningPathService().getNodeMasteries(sessionId);
});

// ── Path Progress (derived) ──────────────────────────────────────────────────

/// 路径进度 Provider：返回 "已掌握数/总数" 格式字符串
final pathProgressProvider =
    FutureProvider.family<String, int>((ref, sessionId) async {
  final states = await ref.watch(nodeStatesMapProvider(sessionId).future);
  final mastered =
      states.values.where((s) => s == NodeState.mastered).length;
  return "$mastered/${states.length}";
});