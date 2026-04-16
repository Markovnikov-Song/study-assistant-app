import 'dart:async';
import 'dart:collection';
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

// Simple LRU cache for QuillControllers (max 5 entries)
class _LruCache<K, V> {
  final int maxSize;
  final _map = LinkedHashMap<K, V>();

  _LruCache(this.maxSize);

  V? get(K key) {
    final val = _map.remove(key);
    if (val != null) _map[key] = val;
    return val;
  }

  void put(K key, V value) {
    _map.remove(key);
    if (_map.length >= maxSize) {
      _map.remove(_map.keys.first);
    }
    _map[key] = value;
  }

  void forEach(void Function(K, V) fn) => _map.forEach(fn);

  void remove(K key) => _map.remove(key);
}

class _LecturePageState extends ConsumerState<LecturePage> {
  // ── State ──────────────────────────────────────────────────────────────────
  late String _currentNodeId;
  final Set<String> _generatingNodeIds = {};
  final Set<String> _hasLectureNodeIds = {};
  final Set<String> _checkedNodeIds = {}; // nodes we've already queried
  final _controllers = _LruCache<String, QuillController>(5);

  // Per-node loading/error state
  final Map<String, bool> _nodeLoading = {};
  final Map<String, String?> _nodeError = {};

  // Expanded state for tree nodes
  final Map<String, bool> _expandedNodes = {};

  // Scaffold key for drawer (mobile)
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _currentNodeId = widget.nodeId;
    _loadLectureForNode(_currentNodeId);
  }

  @override
  void dispose() {
    _controllers.forEach((_, ctrl) => ctrl.dispose());
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  LectureKey _keyFor(String nodeId) =>
      (sessionId: widget.sessionId, nodeId: nodeId);

  String _currentNodeText(List<TreeNode> roots) {
    return _findNodeText(roots, _currentNodeId) ?? '讲义';
  }

  String? _findNodeText(List<TreeNode> nodes, String nodeId) {
    for (final n in nodes) {
      if (n.nodeId == nodeId) return n.text;
      final found = _findNodeText(n.children, nodeId);
      if (found != null) return found;
    }
    return null;
  }

  // ── Lecture loading ────────────────────────────────────────────────────────

  Future<void> _loadLectureForNode(String nodeId) async {
    if (_nodeLoading[nodeId] == true) return;
    setState(() {
      _nodeLoading[nodeId] = true;
      _nodeError[nodeId] = null;
    });
    try {
      final data = await ref.read(libraryServiceProvider).getLecture(
            widget.sessionId,
            nodeId,
          );
      final content =
          LectureContent.fromJson(data['content'] as Map<String, dynamic>);
      final lectureId = data['id'] as int;

      ref
          .read(lectureEditorProvider(_keyFor(nodeId)).notifier)
          .setLecture(lectureId, content.blocks);

      final delta = BlockConverter.blocksToQuillDelta(content.blocks);
      final ctrl = QuillController(
        document: Document.fromDelta(delta),
        selection: const TextSelection.collapsed(offset: 0),
      );
      ctrl.addListener(() {
        ref
            .read(lectureEditorProvider(_keyFor(nodeId)).notifier)
            .onContentChanged(ctrl.document.toDelta());
      });

      // Evict old controller if replaced
      final old = _controllers.get(nodeId);
      old?.dispose();
      _controllers.put(nodeId, ctrl);

      if (mounted) {
        setState(() {
          _hasLectureNodeIds.add(nodeId);
          _checkedNodeIds.add(nodeId);
          _nodeLoading[nodeId] = false;
        });
      }
    } catch (_) {
      // Lecture doesn't exist yet
      if (mounted) {
        setState(() {
          _checkedNodeIds.add(nodeId);
          _nodeLoading[nodeId] = false;
          // Don't set error — treat as "no lecture"
        });
      }
    }
  }

  Future<void> _switchToNode(String nodeId) async {
    if (nodeId == _currentNodeId) return;

    // Save current node first
    await ref
        .read(lectureEditorProvider(_keyFor(_currentNodeId)).notifier)
        .forceSave();

    setState(() => _currentNodeId = nodeId);

    // Load if not yet checked
    if (!_checkedNodeIds.contains(nodeId)) {
      await _loadLectureForNode(nodeId);
    }
  }

  Future<void> _generateLecture(String nodeId, String nodeText) async {
    setState(() => _generatingNodeIds.add(nodeId));

    // 在右侧显示流式打字机内容
    final streamBuffer = StringBuffer();
    final streamCtrl = StreamController<String>.broadcast();

    // 用一个临时的 QuillController 显示流式内容
    final streamQuillCtrl = QuillController(
      document: Document()..insert(0, ''),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _controllers.put('__stream__$nodeId', streamQuillCtrl);

    // 切换到流式节点显示
    setState(() {
      _currentNodeId = nodeId;
      _hasLectureNodeIds.remove(nodeId); // 先标记为无讲义，显示流式区域
    });

    try {
      final stream = ref.read(libraryServiceProvider).generateLectureStream(
        sessionId: widget.sessionId,
        nodeId: nodeId,
      );

      bool hasError = false;
      String? errorMsg;

      await for (final event in stream) {
        if (event == '[DONE]') break;
        if (event.startsWith('[ERROR]')) {
          hasError = true;
          errorMsg = event.substring(7);
          break;
        }
        // 追加 token 到 buffer 并更新 Quill
        streamBuffer.write(event);
        if (mounted) {
          final doc = streamQuillCtrl.document;
          final len = doc.length;
          // 追加新 token（在末尾插入，保留光标）
          doc.insert(len > 0 ? len - 1 : 0, event);
        }
      }

      if (hasError) {
        if (mounted) {
          setState(() => _generatingNodeIds.remove(nodeId));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('生成失败：$errorMsg'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      // 生成完成，重新加载正式讲义
      _checkedNodeIds.remove(nodeId);
      await _loadLectureForNode(nodeId);

      if (mounted) {
        setState(() => _generatingNodeIds.remove(nodeId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('「$nodeText」讲义生成成功！'),
            ]),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generatingNodeIds.remove(nodeId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败：$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      streamCtrl.close();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final nodesAsync = ref.watch(mindMapNodesProvider(widget.sessionId));
    final editorState =
        ref.watch(lectureEditorProvider(_keyFor(_currentNodeId)));
    final isWide = MediaQuery.sizeOf(context).width > 600;

    final roots = nodesAsync.valueOrNull ?? [];
    final currentNodeText = _currentNodeText(roots);

    final outlinePanel = _OutlinePanel(
      roots: roots,
      currentNodeId: _currentNodeId,
      hasLectureNodeIds: _hasLectureNodeIds,
      generatingNodeIds: _generatingNodeIds,
      expandedNodes: _expandedNodes,
      onNodeTap: (nodeId) {
        if (isWide) {
          _switchToNode(nodeId);
        } else {
          Navigator.of(context).pop(); // close drawer
          _switchToNode(nodeId);
        }
      },
      onToggleExpand: (nodeId) {
        setState(() {
          _expandedNodes[nodeId] = !(_expandedNodes[nodeId] ?? true);
        });
      },
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await ref
            .read(lectureEditorProvider(_keyFor(_currentNodeId)).notifier)
            .forceSave();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(
            currentNodeText,
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: false,
          leading: isWide
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Back button
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () async {
                        await ref
                            .read(lectureEditorProvider(
                                    _keyFor(_currentNodeId))
                                .notifier)
                            .forceSave();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                    // Hamburger for outline drawer
                    IconButton(
                      icon: const Icon(Icons.menu),
                      tooltip: '大纲',
                      onPressed: () =>
                          _scaffoldKey.currentState?.openDrawer(),
                    ),
                  ],
                ),
          leadingWidth: isWide ? null : 96,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _SaveStatusChip(state: editorState),
            ),
            IconButton(
              icon: const Icon(Icons.ios_share_outlined),
              tooltip: '导出',
              onPressed: _nodeLoading[_currentNodeId] == true
                  ? null
                  : () => _showExportMenu(context),
            ),
          ],
        ),
        drawer: isWide
            ? null
            : Drawer(
                width: 280,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          '大纲',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(child: outlinePanel),
                    ],
                  ),
                ),
              ),
        body: isWide
            ? Row(
                children: [
                  SizedBox(
                    width: 240,
                    child: outlinePanel,
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: _RightPanel(
                      nodeId: _currentNodeId,
                      nodeText: currentNodeText,
                      sessionId: widget.sessionId,
                      controller: _controllers.get(_currentNodeId),
                      editorState: editorState,
                      isLoading: _nodeLoading[_currentNodeId] == true,
                      isChecked: _checkedNodeIds.contains(_currentNodeId),
                      hasLecture:
                          _hasLectureNodeIds.contains(_currentNodeId),
                      isGenerating:
                          _generatingNodeIds.contains(_currentNodeId),
                      onGenerate: () =>
                          _generateLecture(_currentNodeId, currentNodeText),
                    ),
                  ),
                ],
              )
            : _RightPanel(
                nodeId: _currentNodeId,
                nodeText: currentNodeText,
                sessionId: widget.sessionId,
                controller: _controllers.get(_currentNodeId),
                editorState: editorState,
                isLoading: _nodeLoading[_currentNodeId] == true,
                isChecked: _checkedNodeIds.contains(_currentNodeId),
                hasLecture: _hasLectureNodeIds.contains(_currentNodeId),
                isGenerating: _generatingNodeIds.contains(_currentNodeId),
                onGenerate: () =>
                    _generateLecture(_currentNodeId, currentNodeText),
              ),
      ),
    );
  }

  void _showExportMenu(BuildContext context) {
    final blocks =
        ref.read(lectureEditorProvider(_keyFor(_currentNodeId))).blocks;
    final lectureId =
        ref.read(lectureEditorProvider(_keyFor(_currentNodeId))).lectureId;

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('导出格式',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

// ── Outline panel (left side) ─────────────────────────────────────────────────

class _OutlinePanel extends StatelessWidget {
  final List<TreeNode> roots;
  final String currentNodeId;
  final Set<String> hasLectureNodeIds;
  final Set<String> generatingNodeIds;
  final Map<String, bool> expandedNodes;
  final void Function(String nodeId) onNodeTap;
  final void Function(String nodeId) onToggleExpand;

  const _OutlinePanel({
    required this.roots,
    required this.currentNodeId,
    required this.hasLectureNodeIds,
    required this.generatingNodeIds,
    required this.expandedNodes,
    required this.onNodeTap,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    if (roots.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('加载中…', style: TextStyle(fontSize: 13)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: roots
          .map((node) => _buildNodeTile(context, node, 0))
          .toList(),
    );
  }

  Widget _buildNodeTile(BuildContext context, TreeNode node, int depth) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = node.nodeId == currentNodeId;
    final hasChildren = node.children.isNotEmpty;
    final isExpanded = expandedNodes[node.nodeId] ?? true;
    final isGenerating = generatingNodeIds.contains(node.nodeId);
    final hasLecture = hasLectureNodeIds.contains(node.nodeId);

    // Status dot color
    final Color dotColor;
    if (isGenerating) {
      dotColor = Colors.orange;
    } else if (hasLecture) {
      dotColor = Colors.green;
    } else {
      dotColor = cs.outlineVariant;
    }

    final tile = InkWell(
      onTap: () => onNodeTap(node.nodeId),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: isSelected
            ? BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              )
            : null,
        padding: EdgeInsets.only(
          left: 8.0 + depth * 16.0,
          right: 8,
          top: 6,
          bottom: 6,
        ),
        child: Row(
          children: [
            // Expand/collapse arrow
            SizedBox(
              width: 20,
              child: hasChildren
                  ? GestureDetector(
                      onTap: () => onToggleExpand(node.nodeId),
                      child: Icon(
                        isExpanded
                            ? Icons.expand_more
                            : Icons.chevron_right,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 2),
            // Node text
            Expanded(
              child: Text(
                node.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: depth == 0
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: isSelected
                      ? cs.onPrimaryContainer
                      : cs.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Status dot
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );

    if (!hasChildren || !isExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: tile,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: tile,
        ),
        ...node.children.map(
          (child) => _buildNodeTile(context, child, depth + 1),
        ),
      ],
    );
  }
}

// ── Right panel (editor or empty state) ──────────────────────────────────────

class _RightPanel extends StatelessWidget {
  final String nodeId;
  final String nodeText;
  final int sessionId;
  final QuillController? controller;
  final LectureEditorState editorState;
  final bool isLoading;
  final bool isChecked;
  final bool hasLecture;
  final bool isGenerating;
  final VoidCallback onGenerate;

  const _RightPanel({
    required this.nodeId,
    required this.nodeText,
    required this.sessionId,
    required this.controller,
    required this.editorState,
    required this.isLoading,
    required this.isChecked,
    required this.hasLecture,
    required this.isGenerating,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    // Still loading
    if (isLoading || !isChecked) {
      return const Center(child: CircularProgressIndicator());
    }

    // Generating
    if (isGenerating) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'AI 正在生成「$nodeText」的讲义…',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      );
    }

    // No lecture yet
    if (!hasLecture) {
      return _EmptyLectureState(
        nodeText: nodeText,
        onGenerate: onGenerate,
      );
    }

    // Has lecture — show editor
    final ctrl = controller;
    if (ctrl == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        if (editorState.saveError != null)
          _SaveErrorBanner(error: editorState.saveError!),
        QuillSimpleToolbar(
          controller: ctrl,
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
        Expanded(
          child: _LectureEditor(
            controller: ctrl,
            blocks: editorState.blocks,
          ),
        ),
      ],
    );
  }
}

// ── Empty lecture state ───────────────────────────────────────────────────────

class _EmptyLectureState extends StatelessWidget {
  final String nodeText;
  final VoidCallback onGenerate;

  const _EmptyLectureState({
    required this.nodeText,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 56, color: cs.outlineVariant),
            const SizedBox(height: 16),
            Text(
              nodeText,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '此节点还没有讲义',
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('生成讲义'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Editor widget ─────────────────────────────────────────────────────────────

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
            child:
                CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
          ),
          const SizedBox(width: 6),
          Text('保存中…',
              style:
                  TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      );
    }
    if (state.saveError != null) {
      return Text('保存失败',
          style: TextStyle(fontSize: 12, color: cs.error));
    }
    if (!state.isDirty) {
      return Text('已保存',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant));
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
