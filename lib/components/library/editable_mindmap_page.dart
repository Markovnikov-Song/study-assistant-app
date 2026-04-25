import 'dart:async';
import 'dart:math' as math;
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

// ── 知识关联类型颜色映射（全局唯一）────────────────────────────────────

const _kLinkColors = {
  'causal': Color(0xFFEF4444),      // 因果 — 红
  'dependency': Color(0xFF3B82F6),  // 依赖 — 蓝
  'contrast': Color(0xFFF97316),    // 对比 — 橙
  'evolution': Color(0xFF22C55E),   // 演进 — 绿
};
import '../../routes/app_router.dart';
import 'package:go_router/go_router.dart';
import '../quiz/node_practice_sheet.dart';

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
    final progress = ref.watch(fullMindMapProgressProvider(widget.sessionId));

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
            builder: (_, _) => _tabController.index == 0
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
    final hasServerData = progress.overallProgress != null;

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
                      ? '全部完成！已学习 ${progress.lit} / 总计 ${progress.total} 个知识点（$pct%）'
                      : '已学习 ${progress.lit} / 总计 ${progress.total} 个知识点（$pct%）',
                  style: TextStyle(fontSize: 13, color: cs.onSurface),
                ),
              ),
              if (hasServerData)
                Text(
                  '综合 ${(progress.overallProgress! * 100).floor()}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (hasServerData) ...[
            // 三层进度条
            _ThreeLayerProgressBar(progress: progress, cs: cs),
          ] else ...[
            // 双层进度条（本地加权）
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.total == 0 ? 0 : progress.lit / progress.total,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                    color: cs.primary.withValues(alpha: 0.3),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.weightedScore,
                    minHeight: 6,
                    backgroundColor: Colors.transparent,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ],
          // 错题提示
          if (hasServerData && (progress.mistakeCount ?? 0) > 0) ...[
            const SizedBox(height: 4),
            Text(
              '错题 ${progress.mistakeCount} 道，已复盘 ${progress.reviewedMistakeCount ?? 0} 道',
              style: TextStyle(
                fontSize: 11,
                color: cs.error.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 三层进度条 ────────────────────────────────────────────────────────────────

class _ThreeLayerProgressBar extends StatelessWidget {
  final MindMapProgress progress;
  final ColorScheme cs;

  const _ThreeLayerProgressBar({required this.progress, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Layer(
          label: '阅读',
          value: progress.readProgress ?? 0,
          color: cs.primary,
          cs: cs,
        ),
        const SizedBox(height: 3),
        _Layer(
          label: '练习',
          value: progress.practiceProgress ?? 0,
          color: const Color(0xFF10B981), // 绿色
          cs: cs,
        ),
        const SizedBox(height: 3),
        _Layer(
          label: '掌握',
          value: progress.masteryProgress ?? 0,
          color: const Color(0xFFF59E0B), // 琥珀色
          cs: cs,
        ),
      ],
    );
  }
}

class _Layer extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final ColorScheme cs;

  const _Layer({
    required this.label,
    required this.value,
    required this.color,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            label,
            style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.55)),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: cs.surfaceContainerHighest,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 28,
          child: Text(
            '${(value * 100).floor()}%',
            style: TextStyle(
              fontSize: 10,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
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

  const _MindMapCanvas({
    required this.roots,
    required this.nodeStates,
    required this.sessionId,
    required this.subjectId,
    required this.onNodeTap,
    required this.onNodeLongPress,
    this.onZoomReady,
  });

  @override
  ConsumerState<_MindMapCanvas> createState() => _MindMapCanvasState();
}

class _MindMapCanvasState extends ConsumerState<_MindMapCanvas>
    with SingleTickerProviderStateMixin {
  TransformationController? _transformCtrl;
  Size? _lastCanvasSize;
  Size? _lastViewSize;
  final Set<String> _generatingNodeIds = {};
  final Set<String> _completedNodeIds = {}; // 本次会话生成完成的节点
  late final AnimationController _pulseCtrl;

  double get _pulseValue => _pulseCtrl.value;

  @override
  void initState() {
    super.initState();
    widget.onZoomReady?.call(zoom);
    // AnimationController 替代 Timer，帧率由 Flutter 引擎控制，更流畅
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _transformCtrl?.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startPulse() {
    if (!_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat();
    }
  }

  void _stopPulseIfIdle() {
    if (_generatingNodeIds.isEmpty) {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
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
                child: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, _) => CustomPaint(
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
            leading: const Icon(Icons.quiz_outlined),
            title: const Text('去练习'),
            subtitle: const Text('针对该知识点出题'),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => NodePracticeSheet(
                  nodeId: node.nodeId,
                  nodeText: node.text,
                  subjectId: subjectId,
                ),
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

// ── 知识关联图视图 ────────────────────────────────────────────────────────────

class _KnowledgeGraphPlaceholder extends ConsumerStatefulWidget {
  final int sessionId;
  const _KnowledgeGraphPlaceholder({required this.sessionId});

  @override
  ConsumerState<_KnowledgeGraphPlaceholder> createState() =>
      _KnowledgeGraphPlaceholderState();
}

class _KnowledgeGraphPlaceholderState
    extends ConsumerState<_KnowledgeGraphPlaceholder> {
  bool _generating = false;

  static const _linkLabels = {
    'causal': '因果',
    'dependency': '依赖',
    'contrast': '对比',
    'evolution': '演进',
  };

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      await ref.read(libraryServiceProvider).generateKnowledgeLinks(widget.sessionId);
      ref.invalidate(knowledgeLinksProvider(widget.sessionId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败：$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _confirmRegenerate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重新生成'),
        content: const Text('将覆盖现有知识关联数据，确认重新生成？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );
    if (ok == true) _generate();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final linksAsync = ref.watch(knowledgeLinksProvider(widget.sessionId));

    return linksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildEmpty(cs),
      data: (links) => links.isEmpty ? _buildEmpty(cs) : _buildGraph(cs, links),
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hub_outlined, size: 64, color: cs.outlineVariant),
            const SizedBox(height: 16),
            Text('知识关联图',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text(
              '展示跨章节概念的因果、依赖、对比、演进关系',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.outline),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(_generating ? 'AI 分析中…' : '生成知识关联图'),
            ),
            const SizedBox(height: 12),
            // 图例
            Wrap(
              spacing: 12,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: _kLinkColors.entries.map((e) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 12, height: 3, color: e.value),
                  const SizedBox(width: 4),
                  Text(_linkLabels[e.key]!, style: TextStyle(fontSize: 11, color: cs.outline)),
                ],
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraph(ColorScheme cs, List<KnowledgeLink> links) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
        final canvasSize = Size(
          math.max(viewSize.width, 600),
          math.max(viewSize.height, 500),
        );
        return _KnowledgeGraphCanvas(
          links: links,
          colorScheme: cs,
          canvasSize: canvasSize,
          viewSize: viewSize,
          generating: _generating,
          onLinkTap: _showLinkDetail,
          onRegenerate: _confirmRegenerate,
        );
      },
    );
  }

  void _showLinkDetail(KnowledgeLink link) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: _kLinkColors[link.linkType] ?? cs.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_linkLabels[link.linkType] ?? link.linkType,
                      style: TextStyle(
                          fontSize: 13,
                          color: _kLinkColors[link.linkType] ?? cs.primary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(link.sourceNodeText, style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, size: 16, color: cs.outline),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(link.targetNodeText, style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
              if (link.rationale.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('依据', style: TextStyle(fontSize: 12, color: cs.outline)),
                const SizedBox(height: 4),
                Text(link.rationale, style: const TextStyle(fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── 知识关联图画布（含缩放/平移，与思维导图逻辑一致）────────────────────────

class _KnowledgeGraphCanvas extends StatefulWidget {
  final List<KnowledgeLink> links;
  final ColorScheme colorScheme;
  final Size canvasSize;
  final Size viewSize;
  final bool generating;
  final void Function(KnowledgeLink) onLinkTap;
  final VoidCallback onRegenerate;

  const _KnowledgeGraphCanvas({
    required this.links,
    required this.colorScheme,
    required this.canvasSize,
    required this.viewSize,
    required this.generating,
    required this.onLinkTap,
    required this.onRegenerate,
  });

  @override
  State<_KnowledgeGraphCanvas> createState() => _KnowledgeGraphCanvasState();
}

class _KnowledgeGraphCanvasState extends State<_KnowledgeGraphCanvas> {
  late TransformationController _transformCtrl;

  @override
  void initState() {
    super.initState();
    _transformCtrl = TransformationController();
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final current = _transformCtrl.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(0.3, 3.0);
    final actualFactor = next / current;
    final cx = widget.viewSize.width / 2;
    final cy = widget.viewSize.height / 2;
    _transformCtrl.value = _transformCtrl.value.clone()
      ..translateByVector3(Vector3(cx, cy, 0))
      ..scaleByVector3(Vector3(actualFactor, actualFactor, 1.0))
      ..translateByVector3(Vector3(-cx, -cy, 0));
  }

  void _handleScroll(PointerScrollEvent event) {
    if (event.kind == PointerDeviceKind.mouse) {
      final dy = event.scrollDelta.dy;
      final dx = event.scrollDelta.dx;
      if (dx.abs() > dy.abs()) {
        _transformCtrl.value = _transformCtrl.value.clone()
          ..translateByVector3(Vector3(-dx, 0, 0));
      } else {
        _transformCtrl.value = _transformCtrl.value.clone()
          ..translateByVector3(Vector3(0, -dy, 0));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    // 预计算节点位置，供点击检测用
    final painter = _KnowledgeGraphPainter(
      links: widget.links,
      colorScheme: cs,
      canvasSize: widget.canvasSize,
    );

    return Stack(
      children: [
        Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) _handleScroll(event);
          },
          child: InteractiveViewer(
            constrained: false,
            minScale: 0.3,
            maxScale: 3.0,
            panEnabled: true,
            scaleEnabled: false,
            transformationController: _transformCtrl,
            child: SizedBox(
              width: widget.canvasSize.width,
              height: widget.canvasSize.height,
              child: GestureDetector(
                onTapUp: (details) {
                  final positions = painter.circleLayout(
                    painter.collectNodes(widget.links),
                    widget.canvasSize,
                  );
                  for (final link in widget.links) {
                    final src = positions[link.sourceNodeText];
                    final dst = positions[link.targetNodeText];
                    if (src == null || dst == null) continue;
                    final mid = Offset(
                      (src.dx + dst.dx) / 2,
                      (src.dy + dst.dy) / 2 - 40,
                    );
                    if ((details.localPosition - mid).distance < 24) {
                      widget.onLinkTap(link);
                      return;
                    }
                  }
                },
                child: CustomPaint(
                  painter: painter,
                  size: widget.canvasSize,
                  child: SizedBox(
                    width: widget.canvasSize.width,
                    height: widget.canvasSize.height,
                  ),
                ),
              ),
            ),
          ),
        ),
        // 缩放按钮（右上角，与思维导图一致）
        Positioned(
          top: 8,
          left: 8,
          child: Column(
            children: [
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                tooltip: '放大',
                onPressed: () => _zoom(1.25),
                style: IconButton.styleFrom(
                  backgroundColor: cs.surface,
                  side: BorderSide(color: cs.outlineVariant),
                ),
              ),
              const SizedBox(height: 4),
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                tooltip: '缩小',
                onPressed: () => _zoom(0.8),
                style: IconButton.styleFrom(
                  backgroundColor: cs.surface,
                  side: BorderSide(color: cs.outlineVariant),
                ),
              ),
            ],
          ),
        ),
        // 图例
        Positioned(
          top: 12,
          right: 12,
          child: _Legend(cs: cs),
        ),
        // 重新生成按钮
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.small(
            onPressed: widget.generating ? null : widget.onRegenerate,
            tooltip: '重新生成',
            child: widget.generating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh, size: 18),
          ),
        ),
      ],
    );
  }
}

// ── 图例 ──────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  final ColorScheme cs;
  const _Legend({required this.cs});

  static const _items = [
    ('causal', '因果', Color(0xFFEF4444)),
    ('dependency', '依赖', Color(0xFF3B82F6)),
    ('contrast', '对比', Color(0xFFF97316)),
    ('evolution', '演进', Color(0xFF22C55E)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: _items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 16, height: 2, color: item.$3),
              const SizedBox(width: 6),
              Text(item.$2, style: TextStyle(fontSize: 11, color: cs.onSurface)),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

// ── 知识关联图 Painter ────────────────────────────────────────────────────────

class _KnowledgeGraphPainter extends CustomPainter {
  final List<KnowledgeLink> links;
  final ColorScheme colorScheme;
  final Size canvasSize;

  _KnowledgeGraphPainter({
    required this.links,
    required this.colorScheme,
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final nodeTexts = collectNodes(links);
    final positions = circleLayout(nodeTexts, size);

    // 1. 画连线
    for (final link in links) {
      final src = positions[link.sourceNodeText];
      final dst = positions[link.targetNodeText];
      if (src == null || dst == null) continue;

      final color = _kLinkColors[link.linkType] ?? colorScheme.primary;
      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.65)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;

      final mid = Offset(
        (src.dx + dst.dx) / 2,
        (src.dy + dst.dy) / 2 - 40,
      );
      final path = Path()
        ..moveTo(src.dx, src.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, dst.dx, dst.dy);
      canvas.drawPath(path, linePaint);

      // 箭头
      final angle = (dst - mid).direction;
      final tip = dst - Offset.fromDirection(angle, 22);
      final p1 = tip + Offset.fromDirection(angle + 2.4, 7);
      final p2 = tip + Offset.fromDirection(angle - 2.4, 7);
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..close(),
        Paint()
          ..color = color.withValues(alpha: 0.65)
          ..style = PaintingStyle.fill,
      );
    }

    // 2. 画节点气泡
    const nodeR = 20.0;
    const textStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w500);

    for (final entry in positions.entries) {
      final pos = entry.value;
      final text = entry.key;

      // 气泡背景
      canvas.drawCircle(
        pos,
        nodeR,
        Paint()..color = colorScheme.primaryContainer,
      );
      canvas.drawCircle(
        pos,
        nodeR,
        Paint()
          ..color = colorScheme.primary.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      // 节点文字（截断）
      final label = text.length > 6 ? '${text.substring(0, 5)}…' : text;
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: textStyle.copyWith(color: colorScheme.onPrimaryContainer),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: nodeR * 2);

      tp.paint(
        canvas,
        Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2),
      );

      // 节点下方完整文字标签
      final fullTp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: 80);

      fullTp.paint(
        canvas,
        Offset(pos.dx - fullTp.width / 2, pos.dy + nodeR + 4),
      );
    }
  }

  Set<String> collectNodes(List<KnowledgeLink> links) {
    final nodes = <String>{};
    for (final l in links) {
      nodes.add(l.sourceNodeText);
      nodes.add(l.targetNodeText);
    }
    return nodes;
  }

  Map<String, Offset> circleLayout(Set<String> nodes, Size size) {
    final list = nodes.toList();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.shortestSide / 2 - 80).clamp(80.0, 220.0);
    final result = <String, Offset>{};
    for (int i = 0; i < list.length; i++) {
      final angle = 2 * math.pi * i / list.length - math.pi / 2;
      result[list[i]] = Offset(
        cx + r * math.cos(angle),
        cy + r * math.sin(angle),
      );
    }
    return result;
  }

  @override
  bool shouldRepaint(_KnowledgeGraphPainter old) =>
      old.links != links || old.canvasSize != canvasSize;
}
