import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../models/mindmap_library.dart';
import '../../../services/library_service.dart';
import '../../../providers/library_provider.dart';
import 'block_converter.dart';
import 'lecture_exporter.dart';

// ── LectureEditorState ────────────────────────────────────────────────────────

class LectureEditorState {
  final int? lectureId;
  final List<LectureBlock> blocks;
  final bool isDirty;
  final bool isSaving;
  final String? saveError;

  const LectureEditorState({
    this.lectureId,
    this.blocks = const [],
    this.isDirty = false,
    this.isSaving = false,
    this.saveError,
  });

  LectureEditorState copyWith({
    int? lectureId,
    List<LectureBlock>? blocks,
    bool? isDirty,
    bool? isSaving,
    String? saveError,
    bool clearError = false,
  }) =>
      LectureEditorState(
        lectureId: lectureId ?? this.lectureId,
        blocks: blocks ?? this.blocks,
        isDirty: isDirty ?? this.isDirty,
        isSaving: isSaving ?? this.isSaving,
        saveError: clearError ? null : (saveError ?? this.saveError),
      );
}

// ── LectureEditorNotifier ─────────────────────────────────────────────────────

typedef LectureKey = ({int sessionId, String nodeId});

class LectureEditorNotifier
    extends FamilyNotifier<LectureEditorState, LectureKey> {
  Timer? _saveTimer;
  StreamSubscription? _connectivitySub;

  LibraryService get _service => ref.read(libraryServiceProvider);

  @override
  LectureEditorState build(LectureKey arg) {
    ref.onDispose(() {
      _saveTimer?.cancel();
      _connectivitySub?.cancel();
    });
    _listenConnectivity();
    return const LectureEditorState();
  }

  void _listenConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final connected = results.any((r) => r != ConnectivityResult.none);
      if (connected && state.isDirty && state.saveError != null) {
        _autoSave();
      }
    });
  }

  void onContentChanged(Delta delta) {
    final blocks = BlockConverter.quillDeltaToBlocks(
      delta,
      existingBlocks: state.blocks,
    );
    state = state.copyWith(blocks: blocks, isDirty: true, clearError: true);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 5), _autoSave);
  }

  Future<void> _autoSave() async {
    if (!state.isDirty || state.lectureId == null) return;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _service.patchLecture(
        state.lectureId!,
        LectureContent(blocks: state.blocks).toJson(),
      );
      state = state.copyWith(isDirty: false, isSaving: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isSaving: false, saveError: e.toString());
    }
  }

  Future<void> forceSave() async {
    _saveTimer?.cancel();
    await _autoSave();
  }

  void setLecture(int lectureId, List<LectureBlock> blocks) {
    state = LectureEditorState(lectureId: lectureId, blocks: blocks);
  }
}

final lectureEditorProvider = NotifierProviderFamily<LectureEditorNotifier,
    LectureEditorState, LectureKey>(LectureEditorNotifier.new);

// ── LecturePage ───────────────────────────────────────────────────────────────

class LecturePage extends ConsumerStatefulWidget {
  final int subjectId;
  final int sessionId;
  final String nodeId;

  const LecturePage({
    super.key,
    required this.subjectId,
    required this.sessionId,
    required this.nodeId,
  });

  @override
  ConsumerState<LecturePage> createState() => _LecturePageState();
}

class _LecturePageState extends ConsumerState<LecturePage> {
  QuillController? _controller;
  bool _loading = true;
  String? _error;

  LectureKey get _key => (sessionId: widget.sessionId, nodeId: widget.nodeId);

  @override
  void initState() {
    super.initState();
    _loadLecture();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadLecture() async {
    try {
      final data = await ref.read(libraryServiceProvider).getLecture(
            widget.sessionId,
            widget.nodeId,
          );
      final content = LectureContent.fromJson(data['content'] as Map<String, dynamic>);
      final lectureId = data['id'] as int;

      ref.read(lectureEditorProvider(_key).notifier).setLecture(
            lectureId,
            content.blocks,
          );

      final delta = BlockConverter.blocksToQuillDelta(content.blocks);
      setState(() {
        _controller = QuillController(
          document: Document.fromDelta(delta),
          selection: const TextSelection.collapsed(offset: 0),
        );
        _loading = false;
      });

      _controller!.addListener(() {
        ref
            .read(lectureEditorProvider(_key).notifier)
            .onContentChanged(_controller!.document.toDelta());
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(lectureEditorProvider(_key));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await ref.read(lectureEditorProvider(_key).notifier).forceSave();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('讲义'),
          centerTitle: false,
          actions: [
            // Save status indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _SaveStatusChip(state: editorState),
            ),
            // Export button
            IconButton(
              icon: const Icon(Icons.ios_share_outlined),
              tooltip: '导出',
              onPressed: _loading ? null : () => _showExportMenu(context),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('加载失败：$_error'))
                : Column(
                    children: [
                      // Save error banner
                      if (editorState.saveError != null)
                        _SaveErrorBanner(error: editorState.saveError!),
                      // Format toolbar
                      if (_controller != null)
                        QuillSimpleToolbar(
                          controller: _controller!,
                          config: const QuillSimpleToolbarConfig(
                            showFontFamily: false,
                            showFontSize: false,
                            showStrikeThrough: false,
                            showUnderLineButton: false,
                            showColorButton: false,
                            showBackgroundColorButton: false,
                            showClearFormat: false,
                            showAlignmentButtons: false,
                            showIndent: false,
                            showLink: false,
                            showSearchButton: false,
                            showSubscript: false,
                            showSuperscript: false,
                          ),
                        ),
                      const Divider(height: 1),
                      // Editor
                      Expanded(
                        child: _controller != null
                            ? _LectureEditor(
                                controller: _controller!,
                                blocks: editorState.blocks,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
      ),
    );
  }

  void _showExportMenu(BuildContext context) {
    final blocks = ref.read(lectureEditorProvider(_key)).blocks;
    final lectureId = ref.read(lectureEditorProvider(_key)).lectureId;

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('导出格式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Markdown (.md)'),
              onTap: () {
                Navigator.pop(context);
                LectureExporter.exportToMarkdown(blocks);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF (.pdf)'),
              onTap: () {
                Navigator.pop(context);
                LectureExporter.exportToPdf(blocks);
              },
            ),
            if (lectureId != null)
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('Word (.docx)'),
                onTap: () {
                  Navigator.pop(context);
                  LectureExporter.exportToDocx(
                    context: context,
                    lectureId: lectureId,
                    service: ref.read(libraryServiceProvider),
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Editor widget with AI/user source highlighting ────────────────────────────

class _LectureEditor extends StatelessWidget {
  final QuillController controller;
  final List<LectureBlock> blocks;

  const _LectureEditor({required this.controller, required this.blocks});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return QuillEditor.basic(
      controller: controller,
      config: QuillEditorConfig(
        padding: const EdgeInsets.all(16),
        customStyles: DefaultStyles(
          paragraph: DefaultTextBlockStyle(
            TextStyle(fontSize: 15, color: cs.onSurface, height: 1.6),
            const HorizontalSpacing(0, 0),
            const VerticalSpacing(4, 4),
            const VerticalSpacing(0, 0),
            null,
          ),
        ),
      ),
    );
  }
}

// ── Save status chip ──────────────────────────────────────────────────────────

class _SaveStatusChip extends StatelessWidget {
  final LectureEditorState state;
  const _SaveStatusChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (state.isSaving) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
          ),
          const SizedBox(width: 6),
          Text('保存中…', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      );
    }
    if (state.saveError != null) {
      return Text('保存失败', style: TextStyle(fontSize: 12, color: cs.error));
    }
    if (!state.isDirty) {
      return Text('已保存', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant));
    }
    return const SizedBox.shrink();
  }
}

// ── Save error banner ─────────────────────────────────────────────────────────

class _SaveErrorBanner extends StatelessWidget {
  final String error;
  const _SaveErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: cs.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        '保存失败，请检查网络',
        style: TextStyle(fontSize: 13, color: cs.onErrorContainer),
      ),
    );
  }
}
