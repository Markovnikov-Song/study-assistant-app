import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../tools/mindmap/mindmap_parser.dart';
import '../../../models/mindmap_library.dart';
import '../../../providers/current_subject_provider.dart';
import '../../../providers/shared_preferences_provider.dart';
import '../data/mindmap_local_data_source.dart';
import '../data/mindmap_repository.dart';
import '../../../core/network/dio_client.dart';
import '../../../tools/ocr/ocr_api_client.dart';
import '../domain/edit_history.dart';
import '../../../tools/mindmap/export_service.dart';
import '../domain/node_tree_editor.dart';
import '../../../tools/ocr/ocr_service.dart';
import '../models/mindmap_meta.dart';
import '../models/node_tree_state.dart';

// ── 9.1 mindmapRepositoryProvider ────────────────────────────────────────────

/// Provides a [MindmapRepository] backed by [SharedPreferences].
///
/// Requirement: 10.1–10.6
final mindmapRepositoryProvider = Provider<MindmapRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final dataSource = MindmapLocalDataSource(prefs);
  return MindmapRepository(dataSource);
});

// ── 9.2 mindmapListProvider ───────────────────────────────────────────────────

/// Lists all [MindmapMeta] entries for a given [subjectId].
///
/// Requirement: 10.3, 10.4
final mindmapListProvider =
    FutureProvider.family<List<MindmapMeta>, int>((ref, subjectId) async {
  final repo = ref.watch(mindmapRepositoryProvider);
  return repo.listMindmaps(subjectId);
});

// ── 9.3 activeMindmapIdProvider ──────────────────────────────────────────────

/// Tracks the currently active mindmap ID for each subject.
/// Initialisation (loading the last saved active ID) is handled by
/// [subjectMindmapInitProvider] / [NodeTreeNotifier._init].
///
/// Requirement: 10.4
final activeMindmapIdProvider =
    StateProvider.family<String?, int>((ref, subjectId) => null);

// ── 9.4 NodeTreeNotifier ──────────────────────────────────────────────────────

/// Manages the mutable node-tree state for a single mindmap.
///
/// Encapsulates [NodeTreeEditor] and [EditHistory].
/// Every mutation:
///   1. Pushes a Markdown snapshot to [EditHistory].
///   2. Updates [state] via [_commit].
///   3. Schedules a debounced 2-second auto-save via [MindmapRepository].
///
/// Requirements: 5.1–5.6, 10.1
class NodeTreeNotifier extends StateNotifier<NodeTreeState> {
  final MindmapRepository _repo;
  final int subjectId;
  final String mindmapId;

  final EditHistory _history = EditHistory();
  late final NodeTreeEditor _editor;
  Timer? _debounceTimer;

  NodeTreeNotifier(
    this._repo, {
    required this.subjectId,
    required this.mindmapId,
  }) : super(const NodeTreeState.empty()) {
    _init();
  }

  Future<void> _init() async {
    final roots = await _repo.loadTree(subjectId, mindmapId);
    _editor = NodeTreeEditor(roots);
    state = NodeTreeState(roots: List.unmodifiable(roots));
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  /// Commit the current editor state to [state] and schedule a debounced save.
  void _commit() {
    state = state.copyWith(
      roots: List.unmodifiable(_editor.roots),
      isDirty: true,
    );
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), _save);
  }

  Future<void> _save() async {
    await _repo.saveTree(subjectId, mindmapId, _editor.roots);
    state = state.copyWith(isDirty: false, lastSavedAt: DateTime.now());
  }

  /// Push a Markdown snapshot of the current tree onto the undo stack.
  /// Call this BEFORE mutating the tree.
  void _pushHistory() {
    final snapshot = ExportService.toMarkdown(_editor.roots);
    _history.push(snapshot);
  }

  // ── Public mutation API ───────────────────────────────────────────────────

  /// Add a child node under [parentId] with [text].
  /// Returns the new [TreeNode], or null if [text] is blank or parent not found.
  TreeNode? addChild(String parentId, String text) {
    _pushHistory();
    final node = _editor.addChild(parentId, text);
    if (node != null) _commit();
    return node;
  }

  /// Insert a sibling node after [nodeId] with [text].
  /// Returns the new [TreeNode], or null if [text] is blank.
  TreeNode? addSibling(String nodeId, String text) {
    _pushHistory();
    final node = _editor.addSibling(nodeId, text);
    if (node != null) _commit();
    return node;
  }

  /// Update the text of [nodeId]. Truncates to 200 characters.
  void updateText(String nodeId, String text) {
    _pushHistory();
    _editor.updateText(nodeId, text);
    _commit();
  }

  /// Delete [nodeId] and all its descendants.
  void deleteNode(String nodeId) {
    _pushHistory();
    _editor.deleteNode(nodeId);
    _commit();
  }

  /// Move [nodeId] to become the last child of [targetId].
  void moveNode(String nodeId, String targetId) {
    _pushHistory();
    _editor.moveNode(nodeId, targetId);
    _commit();
  }

  // ── Undo / Redo ───────────────────────────────────────────────────────────

  /// Undo the last edit operation.
  void undo() {
    final current = ExportService.toMarkdown(_editor.roots);
    final prev = _history.undo(current);
    if (prev == null) return;
    _editor.roots = MindMapParser.parse(prev);
    state = state.copyWith(
      roots: List.unmodifiable(_editor.roots),
      isDirty: true,
    );
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), _save);
  }

  /// Redo the last undone operation.
  void redo() {
    final current = ExportService.toMarkdown(_editor.roots);
    final next = _history.redo(current);
    if (next == null) return;
    _editor.roots = MindMapParser.parse(next);
    state = state.copyWith(
      roots: List.unmodifiable(_editor.roots),
      isDirty: true,
    );
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), _save);
  }

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  // ── AI / Import integration ───────────────────────────────────────────────

  /// Replace the entire tree with [newRoots] (AI generate / import replace mode).
  void replaceTree(List<TreeNode> newRoots) {
    _pushHistory();
    _editor.roots = newRoots;
    _commit();
  }

  /// Merge [newRoots] into the current tree (AI generate / import merge mode).
  void mergeTree(List<TreeNode> newRoots) {
    _pushHistory();
    _editor.roots = [..._editor.roots, ...newRoots];
    _commit();
  }

  // ── Drag state ────────────────────────────────────────────────────────────

  /// Set the node currently being dragged, or null to clear.
  void setDragging(String? nodeId) {
    state = state.copyWith(
      draggingNodeId: nodeId,
      clearDraggingNodeId: nodeId == null,
    );
  }

  /// Set the node currently hovered as a drop target, or null to clear.
  void setDropTarget(String? nodeId) {
    state = state.copyWith(
      dropTargetId: nodeId,
      clearDropTargetId: nodeId == null,
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

// ── 9.5 nodeTreeProvider ──────────────────────────────────────────────────────

/// Provides a [NodeTreeNotifier] keyed by (subjectId, mindmapId).
///
/// Requirement: 10.1
final nodeTreeProvider = StateNotifierProvider.family<NodeTreeNotifier,
    NodeTreeState, (int, String)>(
  (ref, key) => NodeTreeNotifier(
    ref.watch(mindmapRepositoryProvider),
    subjectId: key.$1,
    mindmapId: key.$2,
  ),
);

// ── 9.6 editHistoryProvider ───────────────────────────────────────────────────

// EditHistory is embedded inside NodeTreeNotifier.
// Access canUndo / canRedo via nodeTreeProvider.notifier:
//
//   final notifier = ref.read(nodeTreeProvider((sid, mid)).notifier);
//   notifier.canUndo;
//   notifier.canRedo;
//
// No separate provider is needed.

// ── 9.7 subjectMindmapInitProvider ───────────────────────────────────────────

/// Ensures [subjectId] has at least one mindmap, loads the last active ID,
/// and writes it into [activeMindmapIdProvider].
///
/// Watch this provider on the mindmap page to trigger subject-switch
/// save/load behaviour (Requirement 10.2).
final subjectMindmapInitProvider =
    FutureProvider.family<MindmapMeta, int>((ref, subjectId) async {
  final repo = ref.watch(mindmapRepositoryProvider);
  final meta = await repo.ensureDefaultMindmap(subjectId);
  final savedActiveId = await repo.getActiveId(subjectId);
  final activeId = savedActiveId ?? meta.id;
  ref.read(activeMindmapIdProvider(subjectId).notifier).state = activeId;
  return meta;
});

// ── Subject-switch watcher ────────────────────────────────────────────────────

/// Watches [currentSubjectProvider] and triggers [subjectMindmapInitProvider]
/// whenever the active subject changes.
///
/// Requirement: 10.2
final subjectSwitchWatcherProvider = Provider<void>((ref) {
  final subject = ref.watch(currentSubjectProvider);
  if (subject != null) {
    ref.watch(subjectMindmapInitProvider(subject.id));
  }
});

// ── 10.2 ocrServiceProvider ───────────────────────────────────────────────────

/// Provides an [OcrService] backed by the shared [DioClient] instance.
///
/// Requirements: 9.2, 9.6, 9.7
final ocrServiceProvider = Provider<OcrService>((ref) {
  final dio = DioClient.instance.dio;
  return OcrService(OcrApiClient(dio));
});
