import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/mindmap_library.dart';
import '../../../tools/document/book_export_service.dart';

// ── ExportFormat ──────────────────────────────────────────────────────────────

enum ExportFormat {
  pdf('pdf', 'PDF', 'pdf'),
  docx('docx', 'Word (.docx)', 'docx');

  final String value;
  final String label;
  final String ext;

  const ExportFormat(this.value, this.label, this.ext);
}

// ── ExportBookDialog ──────────────────────────────────────────────────────────

/// Dialog for selecting nodes and exporting a multi-node lecture book.
///
/// Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 2.1, 2.2, 8.1–8.5
class ExportBookDialog extends ConsumerStatefulWidget {
  final int sessionId;
  final String sessionTitle;
  final List<TreeNode> nodes;
  final Set<String> hasLectureNodeIds;

  const ExportBookDialog({
    super.key,
    required this.sessionId,
    required this.sessionTitle,
    required this.nodes,
    required this.hasLectureNodeIds,
  });

  @override
  ConsumerState<ExportBookDialog> createState() => _ExportBookDialogState();
}

class _ExportBookDialogState extends ConsumerState<ExportBookDialog> {
  late Set<String> _selected;
  ExportFormat _format = ExportFormat.pdf;
  bool _isExporting = false;
  bool _includeToc = true;

  @override
  void initState() {
    super.initState();
    // Task 9.1: init _selected to all node IDs
    _selected = _collectAllIds(widget.nodes);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Set<String> _collectAllIds(List<TreeNode> nodes) {
    final ids = <String>{};
    void collect(List<TreeNode> list) {
      for (final n in list) {
        ids.add(n.nodeId);
        collect(n.children);
      }
    }
    collect(nodes);
    return ids;
  }

  Set<String> _collectDescendantIds(TreeNode node) {
    final ids = <String>{node.nodeId};
    void collect(List<TreeNode> children) {
      for (final c in children) {
        ids.add(c.nodeId);
        collect(c.children);
      }
    }
    collect(node.children);
    return ids;
  }

  /// Count selected nodes that have no lecture.
  int get _selectedWithoutLecture =>
      _selected.where((id) => !widget.hasLectureNodeIds.contains(id)).length;

  // ── Actions ────────────────────────────────────────────────────────────────

  void _selectAll() => setState(() => _selected = _collectAllIds(widget.nodes));

  void _selectNone() => setState(() => _selected = {});

  void _toggleNode(TreeNode node, bool checked) {
    final ids = _collectDescendantIds(node);
    setState(() {
      if (checked) {
        _selected.addAll(ids);
      } else {
        _selected.removeAll(ids);
      }
    });
  }

  Future<void> _export() async {
    if (_selected.isEmpty || _isExporting) return;

    setState(() => _isExporting = true);

    // Preserve tree order: collect selected IDs in DFS order
    final orderedIds = <String>[];
    void collectOrdered(List<TreeNode> nodes) {
      for (final n in nodes) {
        if (_selected.contains(n.nodeId)) orderedIds.add(n.nodeId);
        collectOrdered(n.children);
      }
    }
    collectOrdered(widget.nodes);

    final service = BookExportService();
    try {
      final Uint8List bytes = await service.exportBook(
        sessionId: widget.sessionId,
        nodeIds: orderedIds,
        format: _format.value,
        includeToc: _includeToc,
      );

      // 文件名：{sessionTitle}_专属辅导书_{日期}.{ext}
      final date = DateTime.now();
      final dateStr = '${date.year}${date.month.toString().padLeft(2,'0')}${date.day.toString().padLeft(2,'0')}';
      final filename = '${widget.sessionTitle}_专属辅导书_$dateStr';
      await FileSaver.instance.saveFile(
        name: filename,
        bytes: bytes,
        ext: _format.ext,
        mimeType: _format == ExportFormat.pdf
            ? MimeType.pdf
            : MimeType.microsoftWord,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 专属辅导书已生成'),
          backgroundColor: Colors.green,
        ),
      );
    } on BookExportException catch (e) {
      if (!mounted) return;
      final msg = e.message == '导出超时，请减少选择的节点数量后重试'
          ? e.message
          : e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
      setState(() => _isExporting = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e'), backgroundColor: Colors.red),
      );
      setState(() => _isExporting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final noLectureCount = _selectedWithoutLecture;
    final canExport = _selected.isNotEmpty && !_isExporting;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '导出专属辅导书',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 16),

            // ── Select-all / select-none buttons (Task 9.3) ─────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _isExporting ? null : _selectAll,
                    child: const Text('全选'),
                  ),
                  TextButton(
                    onPressed: _isExporting ? null : _selectNone,
                    child: const Text('全不选'),
                  ),
                  const Spacer(),
                  Text(
                    '已选 ${_selected.length} 个节点',
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                ],
              ),
            ),

            // ── Node tree (Task 9.2) ─────────────────────────────────────────
            Expanded(
              child: widget.nodes.isEmpty
                  ? const Center(child: Text('暂无节点'))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      children: widget.nodes
                          .map((n) => _buildNodeRow(context, n, 0))
                          .toList(),
                    ),
            ),

            const Divider(height: 1),

            // ── Warnings & validation (Task 9.3) ────────────────────────────
            if (noLectureCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: cs.outline),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$noLectureCount 个节点暂无讲义，导出时将跳过',
                        style: TextStyle(fontSize: 13, color: cs.outline),
                      ),
                    ),
                  ],
                ),
              ),
            if (_selected.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(
                  '请至少选择一个节点',
                  style: TextStyle(fontSize: 13, color: cs.error),
                ),
              ),

            // ── Format selector (Task 9.4) ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Text('格式：',
                      style: TextStyle(fontSize: 14, color: cs.onSurface)),
                  const SizedBox(width: 8),
                  Expanded(
                  child: SegmentedButton<ExportFormat>(
                    segments: const [
                      ButtonSegment(
                        value: ExportFormat.pdf,
                        label: Text('PDF'),
                        icon: Icon(Icons.picture_as_pdf_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: ExportFormat.docx,
                        label: Text('Word (.docx)'),
                        icon: Icon(Icons.description_outlined, size: 16),
                      ),
                    ],
                    selected: {_format},
                    onSelectionChanged: _isExporting
                        ? null
                        : (s) => setState(() => _format = s.first),
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  ),
                ],
              ),
            ),

            // ── TOC 开关 ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  Switch(
                    value: _includeToc,
                    onChanged: _isExporting ? null : (v) => setState(() => _includeToc = v),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 4),
                  Text('包含目录', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
                ],
              ),
            ),

            // ── Export button (Task 9.4) ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: canExport ? _export : null,
                icon: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_stories_outlined),
                label: Text(_isExporting ? '生成中…' : '生成辅导书'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tree row builder (Task 9.2) ────────────────────────────────────────────

  Widget _buildNodeRow(BuildContext context, TreeNode node, int depth) {
    final cs = Theme.of(context).colorScheme;
    final hasLecture = widget.hasLectureNodeIds.contains(node.nodeId);
    final isChecked = _selected.contains(node.nodeId);

    // Determine tri-state: checked / unchecked / indeterminate
    bool? checkValue;
    if (node.children.isEmpty) {
      checkValue = isChecked;
    } else {
      final descendantIds = _collectDescendantIds(node);
      final selectedCount =
          descendantIds.where((id) => _selected.contains(id)).length;
      if (selectedCount == 0) {
        checkValue = false;
      } else if (selectedCount == descendantIds.length) {
        checkValue = true;
      } else {
        checkValue = null; // indeterminate
      }
    }

    final row = InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: _isExporting
          ? null
          : () => _toggleNode(node, checkValue != true),
      child: Padding(
        padding: EdgeInsets.only(
          left: depth * 16.0,
          top: 2,
          bottom: 2,
          right: 8,
        ),
        child: Row(
          children: [
            // Checkbox (tri-state for parent nodes)
            SizedBox(
              width: 36,
              height: 36,
              child: Checkbox(
                value: checkValue,
                tristate: node.children.isNotEmpty,
                onChanged: _isExporting
                    ? null
                    : (v) => _toggleNode(node, v == true),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            // Lecture status dot
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: hasLecture ? Colors.green : cs.outlineVariant,
                shape: BoxShape.circle,
              ),
            ),
            // Node title
            Expanded(
              child: Text(
                node.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      depth == 0 ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (node.children.isEmpty) {
      return row;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        ...node.children
            .map((child) => _buildNodeRow(context, child, depth + 1)),
      ],
    );
  }
}
