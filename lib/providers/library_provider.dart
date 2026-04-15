import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mindmap_library.dart';
import '../services/library_service.dart';

// ── Service ───────────────────────────────────────────────────────────────────

final libraryServiceProvider = Provider<LibraryService>((ref) => LibraryService());

// ── School subjects (with progress) ──────────────────────────────────────────

class SchoolSubjectsNotifier extends AsyncNotifier<List<SubjectWithProgress>> {
  LibraryService get _service => ref.read(libraryServiceProvider);

  @override
  Future<List<SubjectWithProgress>> build() => _service.getSubjects();

  Future<void> refresh() => update((_) => _service.getSubjects());
}

final schoolSubjectsProvider =
    AsyncNotifierProvider<SchoolSubjectsNotifier, List<SubjectWithProgress>>(
  SchoolSubjectsNotifier.new,
);

// ── Course sessions (by subjectId) ────────────────────────────────────────────

class CourseSessionsNotifier
    extends FamilyAsyncNotifier<List<MindMapSession>, int> {
  LibraryService get _service => ref.read(libraryServiceProvider);

  @override
  Future<List<MindMapSession>> build(int subjectId) =>
      _service.getSessions(subjectId);

  Future<void> refresh() => update((_) => _service.getSessions(arg));

  Future<void> renameSession(int sessionId, String title) async {
    await _service.renameSession(sessionId, title);
    ref.invalidateSelf();
  }

  Future<void> deleteSession(int sessionId) async {
    await _service.deleteSession(sessionId);
    ref.invalidateSelf();
  }

  Future<void> updateMeta(int sessionId, {bool? isPinned, int? sortOrder}) async {
    await _service.updateSessionMeta(sessionId, isPinned: isPinned, sortOrder: sortOrder);
    ref.invalidateSelf();
  }
}

final courseSessionsProvider = AsyncNotifierProviderFamily<
    CourseSessionsNotifier, List<MindMapSession>, int>(
  CourseSessionsNotifier.new,
);

// ── MindMap nodes (by sessionId) ──────────────────────────────────────────────

final mindMapNodesProvider =
    FutureProvider.family<List<TreeNode>, int>((ref, sessionId) {
  return ref.read(libraryServiceProvider).getNodes(sessionId);
});

// ── Node states (by sessionId) ────────────────────────────────────────────────

class NodeStatesNotifier extends FamilyNotifier<Map<String, bool>, int> {
  LibraryService get _service => ref.read(libraryServiceProvider);

  @override
  Map<String, bool> build(int sessionId) {
    // Load async; start empty and populate via loadStates()
    _loadStates(sessionId);
    return {};
  }

  Future<void> _loadStates(int sessionId) async {
    final states = await _service.getNodeStates(sessionId);
    state = states;
  }

  Future<void> toggleNode(String nodeId, bool isLit) async {
    state = {...state, nodeId: isLit};
    await _service.updateNodeStates(arg, {nodeId: isLit});
  }

  Future<void> batchUpdate(Map<String, bool> updates) async {
    state = {...state, ...updates};
    await _service.updateNodeStates(arg, updates);
  }
}

final nodeStatesProvider =
    NotifierProviderFamily<NodeStatesNotifier, Map<String, bool>, int>(
  NodeStatesNotifier.new,
);

// ── Progress (derived) ────────────────────────────────────────────────────────

final mindMapProgressProvider =
    Provider.family<MindMapProgress, int>((ref, sessionId) {
  final nodesAsync = ref.watch(mindMapNodesProvider(sessionId));
  final states = ref.watch(nodeStatesProvider(sessionId));

  return nodesAsync.maybeWhen(
    data: (roots) {
      final allNodes = _flattenNodes(roots);
      return MindMapProgress.calculate(allNodes, states);
    },
    orElse: () => const MindMapProgress.empty(),
  );
});

List<TreeNode> _flattenNodes(List<TreeNode> nodes) {
  final result = <TreeNode>[];
  for (final node in nodes) {
    result.add(node);
    result.addAll(_flattenNodes(node.children));
  }
  return result;
}

// ── Lecture exists (by sessionId + nodeId) ────────────────────────────────────

typedef NodeKey = ({int sessionId, String nodeId});

final nodeLectureExistsProvider =
    FutureProvider.family<bool, NodeKey>((ref, key) async {
  try {
    await ref.read(libraryServiceProvider).getLecture(key.sessionId, key.nodeId);
    return true;
  } catch (_) {
    return false;
  }
});
