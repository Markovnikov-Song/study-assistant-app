import '../../../components/library/mindmap/mindmap_parser.dart';
import '../../../models/mindmap_library.dart';
import '../domain/export_service.dart';
import '../models/mindmap_exception.dart';
import '../models/mindmap_meta.dart';
import 'mindmap_local_data_source.dart';

/// Repository that coordinates [MindmapLocalDataSource] with
/// [MindMapParser] / [ExportService] for Markdown ↔ TreeNode conversion.
///
/// Requirements: 10.1–10.6
class MindmapRepository {
  final MindmapLocalDataSource _dataSource;

  MindmapRepository(this._dataSource);

  // ── List ──────────────────────────────────────────────────────────────────

  /// Return all [MindmapMeta] entries for [subjectId].
  Future<List<MindmapMeta>> listMindmaps(int subjectId) async =>
      _dataSource.readMetaList(subjectId);

  // ── Load / Save tree ──────────────────────────────────────────────────────

  /// Load the [TreeNode] tree for [mindmapId].
  /// Returns an empty list when no data is stored yet.
  Future<List<TreeNode>> loadTree(int subjectId, String mindmapId) async {
    final markdown = _dataSource.readTree(subjectId, mindmapId);
    if (markdown == null || markdown.trim().isEmpty) return [];
    return MindMapParser.parse(markdown);
  }

  /// Serialize [roots] to Markdown and persist it.
  Future<void> saveTree(
      int subjectId, String mindmapId, List<TreeNode> roots) async {
    final markdown = ExportService.toMarkdown(roots);
    await _dataSource.writeTree(subjectId, mindmapId, markdown);
  }

  // ── Create ────────────────────────────────────────────────────────────────

  /// Create a new named mindmap, persist an empty tree, and return its meta.
  ///
  /// Requirement: 10.3
  Future<MindmapMeta> createMindmap(int subjectId, String name) async {
    final meta = MindmapMeta.create(subjectId: subjectId, name: name);
    final metas = _dataSource.readMetaList(subjectId)..add(meta);
    await _dataSource.writeMetaList(subjectId, metas);
    // Store an empty tree so the key exists.
    await _dataSource.writeTree(subjectId, meta.id, '');
    return meta;
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Delete [mindmapId] from [subjectId].
  ///
  /// Throws [CannotDeleteLastMindmap] when only one mindmap remains.
  ///
  /// Requirement: 10.5, 10.6
  Future<void> deleteMindmap(int subjectId, String mindmapId) async {
    final metas = _dataSource.readMetaList(subjectId);
    if (metas.length <= 1) {
      throw CannotDeleteLastMindmap(
          subjectId: subjectId, mindmapId: mindmapId);
    }
    final updated = metas.where((m) => m.id != mindmapId).toList();
    await _dataSource.writeMetaList(subjectId, updated);
    await _dataSource.deleteTree(subjectId, mindmapId);
  }

  // ── Rename ────────────────────────────────────────────────────────────────

  /// Rename [mindmapId] to [newName].
  ///
  /// Requirement: 10.3
  Future<void> renameMindmap(
      int subjectId, String mindmapId, String newName) async {
    final metas = _dataSource.readMetaList(subjectId);
    final updated = metas.map((m) {
      if (m.id != mindmapId) return m;
      return m.copyWith(name: newName, updatedAt: DateTime.now());
    }).toList();
    await _dataSource.writeMetaList(subjectId, updated);
  }

  // ── Active ID ─────────────────────────────────────────────────────────────

  /// Return the currently active mindmap ID for [subjectId], or `null`.
  Future<String?> getActiveId(int subjectId) async =>
      _dataSource.readActiveId(subjectId);

  /// Persist [mindmapId] as the active mindmap for [subjectId].
  Future<void> setActiveId(int subjectId, String mindmapId) async =>
      _dataSource.writeActiveId(subjectId, mindmapId);

  // ── Ensure default ────────────────────────────────────────────────────────

  /// Ensure [subjectId] has at least one mindmap.
  /// Creates a "默认导图" when the list is empty and returns its meta.
  ///
  /// Requirement: 10.3
  Future<MindmapMeta> ensureDefaultMindmap(int subjectId) async {
    final metas = _dataSource.readMetaList(subjectId);
    if (metas.isNotEmpty) return metas.first;
    return createMindmap(subjectId, '默认导图');
  }
}
