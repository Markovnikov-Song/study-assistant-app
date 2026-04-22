import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/mindmap_library.dart';
import '../../providers/library_provider.dart';
import '../../../tools/mindmap/mindmap_painter.dart';
import '../../../tools/mindmap/mindmap_parser.dart';
import '../../../tools/mindmap/mindmap_serializer.dart';
import '../../routes/app_router.dart';
import 'package:go_router/go_router.dart';

// ── Undo stack provider ───────────────────────────────────────────────────────

class _UndoStack {
  static const int maxSize = 20;
  final List<String> _snapshots = [];

  void push(String markdown) {
    _snapshots.add(markdown);
    if (_snapshots.length > maxSize) _snapshots.removeAt(0);
  }

  String? pop() => _snapshots.isNotEmpty ? _snapshots.removeLast() : null;

  bool get canUndo => _snapshots.isNotEmpty;
}

// ── EditableMindMapPage ───────────────────────────────────────────────────────

class EditableMindMapPage extends ConsumerStatefulWidget {
  final int subjectId;
  final int sessionId;

  const EditableMindMapPage({
    super.key,
    required this.subjectId,
    required this.sessionId,
  });

  @override
  ConsumerState<EditableMindMapPage> createState() =>
      _EditableMindMapPageState();
}

class _EditableMindMapPageState extends ConsumerState<EditableMindMapPage>
    with SingleTickerProviderStateMixin {
  final _undoStack = _UndoStack();
  void Function(double)? _zoomFn;
  List<TreeNode> _roots = [];
  bool _initialized = false;
  bool _wasComplete = false;
  late final ConfettiController _confettiController;
  late final TabController _tabController;

  String _currentMarkdown = '';

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nodesAsync = ref.watch(mindMapNodesProvider(widget.sessionId));
    final nodeStates = ref.watch(nodeStatesProvider(widget.sessionId));
    final progress = ref.watch(mindMapProgressProvider(widget.sessionId));

    // Initialize roots from provider on first load
    nodesAsync.whenData((roots) {
      if (!_initialized && roots.isNotEmpty) {
        _initialized = true;
        _roots = roots;
        _currentMarkdown = MindMapSerializer.serializeRoots(roots);
      }
    });

    // Trigger confetti when all nodes become lit
    if (progress.total > 0 && progress.lit == progress.total && !_wasComplete) {
      _wasComplete = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _confettiController.play();
      });
    } else if (progress.lit < progress.total) {
      _wasComplete = false;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('思维导图'),
        centerTitle: false,
        actions: [
          // 缩放和撤销只在知识树 Tab 显示
          AnimatedBuilder(
            animation: _tabController,
            builder: (_, __) => _tabController.index == 0
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.add), tooltip: '放大', onPressed: () => _zoomFn?.call(1.25)),
                    IconButton(icon: const Icon(Icons.remove), tooltip: '缩小', onPressed: () => _zoomFn?.call(0.8)),
                    IconButton(icon: const Icon(Icons.undo), tooltip: '撤销', onPressed: _undoStack.canUndo ? _handleUndo : null),
                  ])
                : const SizedBox.shrink(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.account_tree_outlined), text: '知识树'),
            Tab(icon: Icon(Icons.hub_outlined), text: '知识关联图'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // ── Tab 0: 知识树 ─────────────────────────────────────────
          Stack(
            children: [
              Column(
                children: [
                  _ProgressBar(progress: progress),
                  Expanded(
                    child: nodesAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('加载失败：$e')),
                      data: (_) => _MindMapCanvas(
                        onZoomReady: (fn) => _zoomFn = fn,
                        roots: _roots.isEmpty ? nodesAsync.value ?? [] : _roots,
                        nodeStates: nodeStates,
                        sessionId: widget.sessionId,
                        subjectId: widget.subjectId,
                        onNodeTap: _handleNodeTap,
                        onNodeLongPress: _handleNodeLongPress,
                      ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  numberOfParticles: 30,
                  gravity: 0.2,
                  emissionFrequency: 0.05,
                ),
              ),
            ],
          ),

          // ── Tab 1: 知识关联图 ─────────────────────────────────────
          _KnowledgeGraphPlaceholder(sessionId: widget.sessionId),
        ],
      ),
    );
  }

  // ── Gesture handlers ────────────────────────────────────────────────────────

  void _handleNodeTap(TreeNode node) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _NodeActionSheet(
        node: node,
        sessionId: widget.sessionId,
        subjectId: widget.subjectId,
        onEditText: () => _showEditTextDialog(node),
        onAddChild: () => _showAddChildDialog(node),
        onDelete: () => _showDeleteDialog(node),
      ),
    );
  }

  void _handleNodeLongPress(TreeNode node) {
    final states = ref.read(nodeStatesProvider(widget.sessionId));
    final isLit = states[node.nodeId] == true;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isLit ? Icons.star : Icons.star_border,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(isLit ? '取消标记' : '标记为已学习'),
              onTap: () async {
                Navigator.pop(ctx);
                await ref
                    .read(nodeStatesProvider(widget.sessionId).notifier)
                    .toggleNode(node.nodeId, !isLit);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit operations ─────────────────────────────────────────────────────────

  void _showEditTextDialog(TreeNode node) {
    final controller = TextEditingController(text: node.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑文本'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(hintText: '输入节点文本'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('文本不能为空')));
                return;
              }
              if (text.length > 200) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('文本不能超过 200 个字符')));
                return;
              }
              Navigator.pop(ctx);
              _editNodeText(node, text);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showAddChildDialog(TreeNode node) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加子节点'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(hintText: '输入子节点文本'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('文本不能为空')));
                return;
              }
              if (text.length > 200) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('文本不能超过 200 个字符')));
                return;
              }
              Navigator.pop(ctx);
              _addChildNode(node, text);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(TreeNode node) {
    // Reject root node deletion
    if (node.parentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('根节点不可删除')));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除节点'),
        content: Text('确认删除「${node.text}」及其所有子节点？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteNode(node);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  // ── Tree mutation helpers ───────────────────────────────────────────────────

  void _editNodeText(TreeNode node, String newText) {
    _pushUndo();
    setState(() {
      _mutateNode(_roots, node.nodeId, (n) {
        // Replace node in-place by rebuilding with new text
        n.children; // access to keep reference
      });
      _updateNodeText(_roots, node.nodeId, newText);
    });
    _persistAndRefresh();
  }

  void _addChildNode(TreeNode parent, String text) {
    _pushUndo();
    final newDepth = (parent.depth + 1).clamp(1, 4);
    final newNode = TreeNode(
      nodeId: '${parent.nodeId}_user_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      depth: newDepth,
      parentId: parent.nodeId,
      isUserCreated: true,
      children: [],
      isExpanded: true,
    );
    setState(() {
      _findAndAddChild(_roots, parent.nodeId, newNode);
    });
    _persistAndRefresh();
  }

  void _deleteNode(TreeNode node) {
    _pushUndo();
    setState(() {
      _removeNode(_roots, node.nodeId);
    });
    _persistAndRefresh();
  }

  void _handleUndo() async {
    final snapshot = _undoStack.pop();
    if (snapshot == null) return;
    final newRoots = MindMapParser.parse(snapshot);
    setState(() {
      _roots = newRoots;
      _currentMarkdown = snapshot;
    });
    try {
      await ref.read(libraryServiceProvider).updateContent(
            widget.sessionId,
            snapshot,
          );
      ref.invalidate(mindMapNodesProvider(widget.sessionId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('撤销持久化失败：$e')));
      }
    }
  }

  void _pushUndo() {
    _undoStack.push(_currentMarkdown);
  }

  Future<void> _persistAndRefresh() async {
    final markdown = MindMapSerializer.serializeRoots(_roots);
    _currentMarkdown = markdown;
    try {
      await ref.read(libraryServiceProvider).updateContent(
            widget.sessionId,
            markdown,
          );
      ref.invalidate(mindMapNodesProvider(widget.sessionId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$e')));
        // Rollback
        final snapshot = _undoStack.pop();
        if (snapshot != null) {
          setState(() {
            _roots = MindMapParser.parse(snapshot);
            _currentMarkdown = snapshot;
          });
        }
      }
    }
  }

  // ── Tree mutation utilities ─────────────────────────────────────────────────

  static void _mutateNode(
      List<TreeNode> nodes, String nodeId, void Function(TreeNode) fn) {
    for (final n in nodes) {
      if (n.nodeId == nodeId) {
        fn(n);
        return;
      }
      _mutateNode(n.children, nodeId, fn);
    }
  }

  static void _updateNodeText(
      List<TreeNode> nodes, String nodeId, String newText) {
    for (int i = 0; i < nodes.length; i++) {
      if (nodes[i].nodeId == nodeId) {
        nodes[i] = TreeNode(
          nodeId: nodes[i].nodeId,
          text: newText,
          depth: nodes[i].depth,
          parentId: nodes[i].parentId,
          isUserCreated: nodes[i].isUserCreated,
          children: nodes[i].children,
          isExpanded: nodes[i].isExpanded,
        );
        return;
      }
      _updateNodeText(nodes[i].children, nodeId, newText);
    }
  }

  static bool _findAndAddChild(
      List<TreeNode> nodes, String parentId, TreeNode child) {
    for (final n in nodes) {
      if (n.nodeId == parentId) {
        n.children.add(child);
        return true;
      }
      if (_findAndAddChild(n.children, parentId, child)) return true;
    }
    return false;
  }

  static bool _removeNode(List<TreeNode> nodes, String nodeId) {
    for (int i = 0; i < nodes.length; i++) {
      if (nodes[i].nodeId == nodeId) {
        nodes.removeAt(i);
        return true;
      }
      if (_removeNode(nodes[i].children, nodeId)) return true;
    }
    return false;
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final MindMapProgress progress;
  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = progress.percent;
    final isComplete = progress.total > 0 && progress.lit == progress.total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: cs.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isComplete
                      ? '🎉 全部完成！已学习 ${progress.lit} / 总计 ${progress.total} 个知识点（$pct%）'
                      : '已学习 ${progress.lit} / 总计 ${progress.total} 个知识点（$pct%）',
                  style: TextStyle(fontSize: 13, color: cs.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.total == 0
                  ? 0
                  : progress.lit / progress.total,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

// ── MindMap canvas with InteractiveViewer ─────────────────────────────────────

class _MindMapCanvas extends ConsumerStatefulWidget {
  final List<TreeNode> roots;
  final Map<String, bool> nodeStates;
  final int sessionId;
  final int subjectId;
  final void Function(TreeNode) onNodeTap;
  final void Function(TreeNode) onNodeLongPress;
  final void Function(void Function(double))? onZoomReady;
  final void Function(void Function(String), void Function(String))? onGeneratingReady;

  const _MindMapCanvas({
    super.key,
    required this.roots,
    required this.nodeStates,
    required this.sessionId,
    required this.subjectId,
    required this.onNodeTap,
    required this.onNodeLongPress,
    this.onZoomReady,
    this.onGeneratingReady,
  });

  @override
  ConsumerState<_MindMapCanvas> createState() => _MindMapCanvasState();
}

class _MindMapCanvasState extends ConsumerState<_MindMapCanvas> {
  TransformationController? _transformCtrl;
  Size? _lastCanvasSize;
  Size? _lastViewSize;
  final Set<String> _generatingNodeIds = {};
  final Set<String> _completedNodeIds = {}; // 本次会话生成完成的节点
  Timer? _pulseTimer;
  double _pulseValue = 0.0;

  @override
  void initState() {
    super.initState();
    widget.onZoomReady?.call(zoom);
    widget.onGeneratingReady?.call(addGenerating, removeGenerating);
  }

  @override
  void dispose() {
    _transformCtrl?.dispose();
    _pulseTimer?.cancel();
    super.dispose();
  }

  void _startPulse() {
    _pulseTimer?.cancel();
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      setState(() => _pulseValue = (_pulseValue + 0.05) % 1.0);
    });
  }

  void _stopPulseIfIdle() {
    if (_generatingNodeIds.isEmpty) {
      _pulseTimer?.cancel();
      _pulseTimer = null;
    }
  }

  void addGenerating(String nodeId) {
    setState(() => _generatingNodeIds.add(nodeId));
    _startPulse();
  }

  void removeGenerating(String nodeId) {
    setState(() {
      _generatingNodeIds.remove(nodeId);
      _completedNodeIds.add(nodeId); // 标记为已完成
    });
    _stopPulseIfIdle();
  }

  void _initTransform(Size canvasSize, Size viewSize) {
    _transformCtrl?.dispose();
    final scale = (viewSize.width / (canvasSize.width + 48)).clamp(0.3, 1.0);
    final scaledW = canvasSize.width * scale;
    final offsetX = ((viewSize.width - scaledW) / 2).clamp(0.0, double.infinity);
    _transformCtrl = TransformationController(
      Matrix4.diagonal3Values(scale, scale, 1.0)
        ..setTranslationRaw(offsetX, 24.0 * scale, 0),
    );
    _lastCanvasSize = canvasSize;
    _lastViewSize = viewSize;
  }

  void _handleScroll(PointerScrollEvent event) {
    final ctrl = _transformCtrl;
    if (ctrl == null) return;
    if (event.kind == PointerDeviceKind.mouse) {
      final dy = event.scrollDelta.dy;
      final dx = event.scrollDelta.dx;
      if (dx.abs() > dy.abs()) {
        ctrl.value = ctrl.value.clone()
          ..translateByVector3(Vector3(-dx, 0, 0));
      } else {
        ctrl.value = ctrl.value.clone()
          ..translateByVector3(Vector3(0, -dy, 0));
      }
    }
  }

  void zoom(double factor) {
    final ctrl = _transformCtrl;
    if (ctrl == null) return;
    final current = ctrl.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(0.3, 3.0);
    final actualFactor = next / current;
    // 以画布中心为缩放点
    final size = _lastViewSize ?? const Size(400, 400);
    final cx = size.width / 2;
    final cy = size.height / 2;
    ctrl.value = ctrl.value.clone()
      ..translateByVector3(Vector3(cx, cy, 0))
      ..scaleByVector3(Vector3(actualFactor, actualFactor, 1.0))
      ..translateByVector3(Vector3(-cx, -cy, 0));
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w500);
    final cs = Theme.of(context).colorScheme;

    final lectureNodeIds = _completedNodeIds;

    final layouts = computeLayout(
      roots: widget.roots,
      lectureNodeIds: lectureNodeIds,
      textStyle: textStyle,
    );
    final canvasSize = computeCanvasSize(layouts);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewSize = Size(constraints.maxWidth, constraints.maxHeight);

        if (_transformCtrl == null ||
            _lastCanvasSize != canvasSize ||
            _lastViewSize != viewSize) {
          _initTransform(canvasSize, viewSize);
        }

        final wrapW = canvasSize.width.clamp(viewSize.width, double.infinity);
        final wrapH = canvasSize.height.clamp(viewSize.height, double.infinity);

        return Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) _handleScroll(event);
          },
          child: InteractiveViewer(
            constrained: false,
            minScale: 0.3,
            maxScale: 3.0,
            panEnabled: true,
            scaleEnabled: false, // 禁用内置缩放，由 Listener 接管
            transformationController: _transformCtrl!,
            child: SizedBox(
              width: wrapW,
              height: wrapH,
              child: GestureDetector(
                onTapUp: (details) {
                  final hit = MindMapPainter.nodeAt(layouts, details.localPosition);
                  if (hit != null) widget.onNodeTap(hit.node);
                },
                onLongPressStart: (details) {
                  final hit = MindMapPainter.nodeAt(layouts, details.localPosition);
                  if (hit != null) widget.onNodeLongPress(hit.node);
                },
                child: CustomPaint(
                  size: canvasSize,
                  painter: MindMapPainter(
                    layouts: layouts,
                    nodeStates: widget.nodeStates,
                    colorScheme: cs,
                    generatingNodeIds: _generatingNodeIds,
                    pulseValue: _pulseValue,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── NodeActionSheet ───────────────────────────────────────────────────────────

class _NodeActionSheet extends ConsumerWidget {
  final TreeNode node;
  final int sessionId;
  final int subjectId;
  final VoidCallback onEditText;
  final VoidCallback onAddChild;
  final VoidCallback onDelete;

  const _NodeActionSheet({
    required this.node,
    required this.sessionId,
    required this.subjectId,
    required this.onEditText,
    required this.onAddChild,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              node.text,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('查看讲义'),
            onTap: () {
              Navigator.pop(context);
              context.push(
                AppRoutes.lecturePage(subjectId, sessionId, node.nodeId),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('添加子节点'),
            onTap: () {
              Navigator.pop(context);
              onAddChild();
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('编辑文本'),
            onTap: () {
              Navigator.pop(context);
              onEditText();
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            title: Text('删除节点',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── 生成进度对话框 ─────────────────────────────────────────────────────────────

class _GeneratingDialog extends StatefulWidget {
  const _GeneratingDialog();

  @override
  State<_GeneratingDialog> createState() => _GeneratingDialogState();
}

class _GeneratingDialogState extends State<_GeneratingDialog> {
  static const _stages = [
    '正在检索相关资料…',
    '正在分析知识点…',
    '正在生成讲义内容…',
    '正在整理格式…',
    '即将完成…',
  ];

  int _stageIndex = 0;
  double _progress = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      setState(() {
        _progress = (_progress + 0.018).clamp(0.0, 0.9);
        _stageIndex = (_progress * _stages.length).floor().clamp(0, _stages.length - 1);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: null, color: cs.primary),
            const SizedBox(height: 20),
            Text('AI 正在生成讲义',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 8),
            Text(
              _stages[_stageIndex],
              style: TextStyle(fontSize: 13, color: cs.outline),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toInt()}%',
              style: TextStyle(fontSize: 12, color: cs.outline),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 知识关联图占位 ─────────────────────────────────────────────────────────────

class _KnowledgeGraphPlaceholder extends StatelessWidget {
  final int sessionId;
  const _KnowledgeGraphPlaceholder({required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hub_outlined, size: 64, color: cs.outlineVariant),
            const SizedBox(height: 16),
            Text('知识关联图',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: cs.onSurface)),
            const SizedBox(height: 8),
            Text(
              '展示跨章节概念的因果、依赖、对比关系\n与思维导图一同生成后在此显示',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.outline),
            ),
            const SizedBox(height: 20),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('即将推出',
                  style: TextStyle(
                      fontSize: 12, color: cs.onTertiaryContainer)),
            ),
          ],
        ),
      ),
    );
  }
}
