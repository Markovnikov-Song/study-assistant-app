import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../models/mindmap_library.dart';
import '../models/mindmap_exception.dart';
import '../providers/mindmap_providers.dart';

/// A tree-list based editor canvas for manually editing a mindmap.
///
/// Uses [ReorderableListView] to render a flattened, indented node list
/// with inline editing, delete confirmation, and drag-to-reorder support.
///
/// Requirements: 1.1, 1.2, 1.5, 2.1–2.4, 3.1–3.3, 4.1–4.5
class MindmapEditorCanvas extends ConsumerStatefulWidget {
  final int subjectId;
  final String mindmapId;

  const MindmapEditorCanvas({
    super.key,
    required this.subjectId,
    required this.mindmapId,
  });

  @override
  ConsumerState<MindmapEditorCanvas> createState() =>
      _MindmapEditorCanvasState();
}

class _MindmapEditorCanvasState extends ConsumerState<MindmapEditorCanvas> {
  /// The nodeId currently being edited inline, or null.
  String? _editingNodeId;

  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(nodeTreeProvider((widget.subjectId, widget.mindmapId)));
    final notifier = ref.read(
        nodeTreeProvider((widget.subjectId, widget.mindmapId)).notifier);

    final nodes = _flattenTree(state.roots);

    if (nodes.isEmpty) {
      return _EmptyTreePlaceholder(
        onAddRoot: () => _addRootNode(context, notifier),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: nodes.length,
      onReorder: (oldIndex, newIndex) =>
          _onReorder(context, notifier, nodes, oldIndex, newIndex),
      proxyDecorator: (child, index, animation) => Material(
        elevation: 4,
        color: Colors.transparent,
        child: child,
      ),
      itemBuilder: (context, index) {
        final node = nodes[index];
        final indent = (node.depth - 1) * 24.0;
        final isEditing = _editingNodeId == node.nodeId;
        final isRoot = state.roots.any((r) => r.nodeId == node.nodeId);
        final isDragging = state.draggingNodeId == node.nodeId;
        final isDropTarget = state.dropTargetId == node.nodeId;

        return Padding(
          key: ValueKey(node.nodeId),
          padding: EdgeInsets.only(left: indent),
          child: isEditing
              ? _EditingNodeTile(
                  node: node,
                  onConfirm: (text) => _confirmEdit(notifier, node, text, isRoot),
                  onCancel: () => setState(() => _editingNodeId = null),
                )
              : _NodeTile(
                  node: node,
                  index: index,
                  isRoot: isRoot,
                  isDragging: isDragging,
                  isDropTarget: isDropTarget,
                  onDoubleTap: () =>
                      setState(() => _editingNodeId = node.nodeId),
                  onAddChild: node.depth >= 6
                      ? null
                      : () => _addChildNode(context, notifier, node),
                  onAddSibling: isRoot
                      ? null
                      : () => _addSiblingNode(context, notifier, node),
                  onDelete: isRoot
                      ? null
                      : () => _confirmDelete(context, notifier, node),
                ),
        );      },
    );
  }

  // ── Tree helpers ────────────────────────────────────────────────────────

  /// Pre-order flatten of the tree, preserving depth for indentation.
  List<TreeNode> _flattenTree(List<TreeNode> roots) {
    final result = <TreeNode>[];
    for (final root in roots) {
      _collectPreOrder(root, result);
    }
    return result;
  }

  void _collectPreOrder(TreeNode node, List<TreeNode> result) {
    result.add(node);
    for (final child in node.children) {
      _collectPreOrder(child, result);
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  void _addRootNode(
      BuildContext context, NodeTreeNotifier notifier) async {
    final text = await _showTextInputDialog(context, title: '添加根节点');
    if (text == null || text.trim().isEmpty) return;
    // Root nodes are added via replaceTree / mergeTree; for MVP we use
    // a temporary approach: add a child to a virtual root or create a
    // standalone root by calling addChild on the first root if it exists,
    // otherwise we create a root directly via the notifier.
    _addStandaloneRoot(notifier, text.trim());
  }

  void _addStandaloneRoot(NodeTreeNotifier notifier, String text) {
    // NodeTreeEditor doesn't expose addRoot directly; we replicate the
    // logic by merging a single-node tree.
    final newRoot = TreeNode(
      nodeId: const Uuid().v4(),
      text: text,
      depth: 1,
      parentId: null,
      isUserCreated: true,
    );
    notifier.mergeTree([newRoot]);
  }

  void _addChildNode(
      BuildContext context, NodeTreeNotifier notifier, TreeNode parent) async {
    if (parent.depth >= 6) return;
    final text =
        await _showTextInputDialog(context, title: '添加子节点', hint: '输入节点文本');
    if (text == null || text.trim().isEmpty) return;
    notifier.addChild(parent.nodeId, text.trim());
  }

  void _addSiblingNode(
      BuildContext context, NodeTreeNotifier notifier, TreeNode node) async {
    final text =
        await _showTextInputDialog(context, title: '添加兄弟节点', hint: '输入节点文本');
    if (text == null || text.trim().isEmpty) return;
    notifier.addSibling(node.nodeId, text.trim());
  }

  void _confirmEdit(
    NodeTreeNotifier notifier,
    TreeNode node,
    String newText,
    bool isRoot,
  ) {
    setState(() => _editingNodeId = null);
    if (newText.trim().isEmpty) {
      if (!isRoot) {
        notifier.deleteNode(node.nodeId);
      }
      // Root with empty text: keep as-is (requirement 12.2)
    } else {
      notifier.updateText(node.nodeId, newText.trim());
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    NodeTreeNotifier notifier,
    TreeNode node,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除节点'),
        content: const Text('删除该节点将同时删除其所有子节点，确认删除？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      notifier.deleteNode(node.nodeId);
    } on CannotDeleteRoot {
      // Should not happen since root has no delete button, but guard anyway.
    }
  }

  // ── Drag reorder ─────────────────────────────────────────────────────────

  void _onReorder(
    BuildContext context,
    NodeTreeNotifier notifier,
    List<TreeNode> nodes,
    int oldIndex,
    int newIndex,
  ) {
    // ReorderableListView passes newIndex after removal; adjust.
    if (newIndex > oldIndex) newIndex -= 1;

    final dragged = nodes[oldIndex];

    // Determine target parent: the node at newIndex (or its parent).
    // MVP strategy: move dragged node to become a sibling of the node at
    // newIndex by targeting that node's parent, or as a child of the node
    // at newIndex if it's a different branch.
    //
    // Simplified: use the node at newIndex as the new parent target.
    if (newIndex == oldIndex) return;

    final targetNode = nodes[newIndex.clamp(0, nodes.length - 1)];

    // Prevent moving to self
    if (targetNode.nodeId == dragged.nodeId) return;

    notifier.setDragging(dragged.nodeId);
    notifier.setDropTarget(targetNode.nodeId);

    try {
      notifier.moveNode(dragged.nodeId, targetNode.nodeId);
    } on CircularMove {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('不能将节点移动到其自身的子节点下'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      notifier.setDragging(null);
      notifier.setDropTarget(null);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<String?> _showTextInputDialog(
    BuildContext context, {
    required String title,
    String hint = '输入节点文本',
  }) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}

// ── _EmptyTreePlaceholder ─────────────────────────────────────────────────────

class _EmptyTreePlaceholder extends StatelessWidget {
  final VoidCallback onAddRoot;

  const _EmptyTreePlaceholder({required this.onAddRoot});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '点击 + 开始添加节点',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAddRoot,
            icon: const Icon(Icons.add),
            label: const Text('添加根节点'),
          ),
        ],
      ),
    );
  }
}

// ── _NodeTile ─────────────────────────────────────────────────────────────────

/// A single read-only node row with action buttons.
///
/// Requirements: 1.1, 1.2, 1.5, 3.3
class _NodeTile extends StatelessWidget {
  final TreeNode node;
  final int index;
  final bool isRoot;
  final bool isDragging;
  final bool isDropTarget;
  final VoidCallback onDoubleTap;

  /// null when depth >= 6 (disabled)
  final VoidCallback? onAddChild;

  /// null for root nodes
  final VoidCallback? onAddSibling;

  /// null for root nodes
  final VoidCallback? onDelete;

  const _NodeTile({
    required this.node,
    required this.index,
    required this.isRoot,
    required this.isDragging,
    required this.isDropTarget,
    required this.onDoubleTap,
    required this.onAddChild,
    required this.onAddSibling,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color? bgColor;
    if (isDragging) {
      bgColor = colorScheme.primaryContainer.withValues(alpha: 0.4);
    } else if (isDropTarget) {
      bgColor = colorScheme.secondaryContainer.withValues(alpha: 0.6);
    }

    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: isDropTarget
              ? Border.all(color: colorScheme.secondary, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            // Depth indicator line
            if (!isRoot)
              Container(
                width: 2,
                height: 36,
                margin: const EdgeInsets.only(right: 6),
                color: colorScheme.outlineVariant,
              ),
            // Node text
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Text(
                  node.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            isRoot ? FontWeight.w600 : FontWeight.normal,
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Add child button
            Tooltip(
              message: node.depth >= 6 ? '已达最大层级深度' : '添加子节点',
              child: IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: onAddChild,
                color: onAddChild != null
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                visualDensity: VisualDensity.compact,
              ),
            ),
            // Add sibling button (hidden for root)
            if (!isRoot)
              Tooltip(
                message: '添加兄弟节点',
                child: IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  onPressed: onAddSibling,
                  color: colorScheme.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            // Delete button (hidden for root)
            if (!isRoot)
              Tooltip(
                message: '删除节点',
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: onDelete,
                  color: colorScheme.error,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            // Drag handle (provided by ReorderableListView)
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.drag_handle, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _EditingNodeTile ──────────────────────────────────────────────────────────

/// An inline text-editing row for a node.
///
/// Requirements: 2.1–2.4
class _EditingNodeTile extends StatefulWidget {
  final TreeNode node;
  final void Function(String text) onConfirm;
  final VoidCallback onCancel;

  const _EditingNodeTile({
    required this.node,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_EditingNodeTile> createState() => _EditingNodeTileState();
}

class _EditingNodeTileState extends State<_EditingNodeTile> {
  late final TextEditingController _ctrl;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.node.text);
    _focusNode = FocusNode();
    // Select all text on open for quick replacement
    _ctrl.selection =
        TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _confirm() => widget.onConfirm(_ctrl.text);

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onCancel();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focusNode,
                maxLength: 200,
                maxLines: 1,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: const OutlineInputBorder(),
                  counterText: '',
                  hintText: '节点文本最多 200 个字符',
                ),
                onSubmitted: (_) => _confirm(),
                onEditingComplete: _confirm,
                // Confirm on focus loss
                onTapOutside: (_) => _confirm(),
              ),
            ),
            const SizedBox(width: 4),
            // Cancel button
            Tooltip(
              message: '取消编辑',
              child: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: widget.onCancel,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
