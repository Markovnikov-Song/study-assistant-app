import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/mindmap_meta.dart';

/// Local storage layer backed by [SharedPreferences].
///
/// Storage schema:
///   "mindmap_meta_{subjectId}"          → JSON array of MindmapMeta
///   "mindmap_tree_{subjectId}_{id}"     → Markdown string (Node_Tree)
///   "mindmap_active_{subjectId}"        → String (active mindmap id)
///
/// Requirement: 10.1, 10.3
class MindmapLocalDataSource {
  final SharedPreferences _prefs;

  MindmapLocalDataSource(this._prefs);

  // ── Keys ──────────────────────────────────────────────────────────────────

  String _metaKey(int subjectId) => 'mindmap_meta_$subjectId';
  String _treeKey(int subjectId, String mindmapId) =>
      'mindmap_tree_${subjectId}_$mindmapId';
  String _activeKey(int subjectId) => 'mindmap_active_$subjectId';

  // ── Meta list ─────────────────────────────────────────────────────────────

  /// Read all [MindmapMeta] entries for [subjectId].
  List<MindmapMeta> readMetaList(int subjectId) {
    final raw = _prefs.getString(_metaKey(subjectId));
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => MindmapMeta.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Persist [metas] for [subjectId].
  Future<void> writeMetaList(int subjectId, List<MindmapMeta> metas) async {
    final encoded = jsonEncode(metas.map((m) => m.toJson()).toList());
    await _prefs.setString(_metaKey(subjectId), encoded);
  }

  // ── Tree (Markdown) ───────────────────────────────────────────────────────

  /// Read the Markdown string for [mindmapId] under [subjectId].
  /// Returns `null` when not found.
  String? readTree(int subjectId, String mindmapId) =>
      _prefs.getString(_treeKey(subjectId, mindmapId));

  /// Persist [markdown] for [mindmapId] under [subjectId].
  Future<void> writeTree(
      int subjectId, String mindmapId, String markdown) async {
    await _prefs.setString(_treeKey(subjectId, mindmapId), markdown);
  }

  /// Remove the Markdown string for [mindmapId] under [subjectId].
  Future<void> deleteTree(int subjectId, String mindmapId) async {
    await _prefs.remove(_treeKey(subjectId, mindmapId));
  }

  // ── Active ID ─────────────────────────────────────────────────────────────

  /// Read the currently active mindmap ID for [subjectId].
  /// Returns `null` when not set.
  String? readActiveId(int subjectId) =>
      _prefs.getString(_activeKey(subjectId));

  /// Persist [mindmapId] as the active mindmap for [subjectId].
  Future<void> writeActiveId(int subjectId, String mindmapId) async {
    await _prefs.setString(_activeKey(subjectId), mindmapId);
  }
}
