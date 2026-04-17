import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/ocr_api_client.dart';
import '../domain/import_parser.dart';
import '../domain/ocr_service.dart';
import '../providers/mindmap_providers.dart';
import 'import_mode_dialog.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

/// Prompts the user to choose a camera or gallery source, runs OCR on the
/// selected image, and shows [OcrPreviewSheet] for review before importing.
///
/// Requirements: 9.1, 9.5, 9.7
Future<void> handleOcrPhoto(
  BuildContext context,
  WidgetRef ref,
  int subjectId,
  String mindmapId,
) async {
  final picker = ImagePicker();
  final source = await _showImageSourceDialog(context);
  if (source == null) return;

  final picked = await picker.pickImage(source: source, imageQuality: 85);
  if (picked == null || !context.mounted) return;

  final bytes = await picked.readAsBytes();

  if (!context.mounted) return;

  // Show loading indicator
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final ocrService = ref.read(ocrServiceProvider);
    final result = await ocrService.recognize(bytes);
    if (!context.mounted) return;
    Navigator.pop(context); // close loading

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => OcrPreviewSheet(
        lines: result.lines,
        onConfirm: (confirmedLines) async {
          final parseResult = ImportParser.parseOcrLines(confirmedLines);
          if (parseResult is ImportError) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('未识别到有效内容')),
              );
            }
            return;
          }
          final roots = (parseResult as ImportSuccess).roots;
          if (!context.mounted) return;
          final mode = await showImportModeDialog(context);
          if (mode == null || !context.mounted) return;
          final notifier =
              ref.read(nodeTreeProvider((subjectId, mindmapId)).notifier);
          if (mode == ImportMode.replace) {
            notifier.replaceTree(roots);
          } else {
            notifier.mergeTree(roots);
          }
        },
      ),
    );
  } on OcrTimeoutException {
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('识别超时，请重试或手动输入')),
      );
    }
  } on OcrException {
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片识别失败，请确保图片清晰且包含文字内容')),
      );
    }
  }
}

Future<ImageSource?> _showImageSourceDialog(BuildContext context) {
  return showDialog<ImageSource>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('选择图片来源'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
          child: const Text('从相册选取'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ImageSource.camera),
          child: const Text('拍照'),
        ),
      ],
    ),
  );
}

// ── OcrPreviewSheet ───────────────────────────────────────────────────────────

/// Bottom sheet that shows OCR recognition results for review before import.
///
/// - Each line shows an editable text field and indent-level controls.
/// - Lines with confidence < 0.7 are highlighted in yellow.
/// - The user can confirm or cancel.
///
/// Requirements: 9.3, 9.4, 9.6
class OcrPreviewSheet extends StatefulWidget {
  final List<OcrLine> lines;
  final Future<void> Function(List<OcrLine>) onConfirm;

  const OcrPreviewSheet({
    super.key,
    required this.lines,
    required this.onConfirm,
  });

  @override
  State<OcrPreviewSheet> createState() => _OcrPreviewSheetState();
}

class _OcrPreviewSheetState extends State<OcrPreviewSheet> {
  late final List<OcrLine> _lines;
  late final List<TextEditingController> _controllers;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    // Shallow copy so we can mutate indentLevel / isSelected independently.
    _lines = widget.lines
        .map((l) => OcrLine(
              text: l.text,
              confidence: l.confidence,
              indentLevel: l.indentLevel,
              isSelected: l.isSelected,
            ))
        .toList();
    _controllers =
        _lines.map((l) => TextEditingController(text: l.text)).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_confirming) return;
    setState(() => _confirming = true);

    // Build updated lines with the edited text from controllers.
    final updatedLines = List.generate(
      _lines.length,
      (i) => OcrLine(
        text: _controllers[i].text,
        confidence: _lines[i].confidence,
        indentLevel: _lines[i].indentLevel,
        isSelected: _lines[i].isSelected,
      ),
    );

    try {
      await widget.onConfirm(updatedLines);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'OCR 识别结果',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${_lines.length} 行',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _lines.isEmpty
                ? const Center(child: Text('未识别到任何文字'))
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _lines.length,
                    itemBuilder: (_, i) =>
                        _OcrLineTile(
                          line: _lines[i],
                          controller: _controllers[i],
                          onIndentChanged: (delta) {
                            setState(() {
                              final newLevel =
                                  (_lines[i].indentLevel + delta).clamp(0, 5);
                              _lines[i].indentLevel = newLevel;
                            });
                          },
                          onSelectedChanged: (v) {
                            setState(() => _lines[i].isSelected = v);
                          },
                        ),
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _confirming ? null : _confirm,
                    child: _confirming
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('确认导入'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _OcrLineTile ──────────────────────────────────────────────────────────────

class _OcrLineTile extends StatelessWidget {
  final OcrLine line;
  final TextEditingController controller;
  final void Function(int delta) onIndentChanged;
  final void Function(bool selected) onSelectedChanged;

  const _OcrLineTile({
    required this.line,
    required this.controller,
    required this.onIndentChanged,
    required this.onSelectedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isLowConfidence = OcrService.shouldHighlight(line.confidence);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isLowConfidence
            ? Colors.yellow.withValues(alpha: 0.3)
            : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          // Selection checkbox
          Checkbox(
            value: line.isSelected,
            onChanged: (v) => onSelectedChanged(v ?? true),
            visualDensity: VisualDensity.compact,
          ),
          // Indent level controls
          IconButton(
            icon: const Icon(Icons.remove, size: 16),
            onPressed: line.indentLevel > 0 ? () => onIndentChanged(-1) : null,
            visualDensity: VisualDensity.compact,
            tooltip: '减少缩进',
          ),
          SizedBox(
            width: 24,
            child: Text(
              '${line.indentLevel + 1}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 16),
            onPressed: line.indentLevel < 5 ? () => onIndentChanged(1) : null,
            visualDensity: VisualDensity.compact,
            tooltip: '增加缩进',
          ),
          // Editable text
          Expanded(
            child: TextField(
              controller: controller,
              enabled: line.isSelected,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: InputBorder.none,
                hintText: '(空行将被忽略)',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          // Confidence badge
          if (isLowConfidence)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: '置信度 ${(line.confidence * 100).toStringAsFixed(0)}%，请核查',
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
