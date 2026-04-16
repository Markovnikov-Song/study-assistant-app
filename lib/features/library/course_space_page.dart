import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/mindmap_library.dart';
import '../../providers/library_provider.dart';
import '../../routes/app_router.dart';
/// CourseSpacePage — 课程空间，展示某学科下所有思维导图大纲列表
class CourseSpacePage extends ConsumerWidget {
  final int subjectId;
  const CourseSpacePage({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(courseSessionsProvider(subjectId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('课程空间'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: '资料库',
            onPressed: () => context.push(AppRoutes.subjectDetailPath(subjectId)),
          ),
        ],
      ),
      body: Column(
        children: [
          // 整体进度条（从 sessions 聚合）
          sessionsAsync.when(
            data: (sessions) {
              // 进度只基于当前大纲（置顶优先，否则最新）
              final active = sessions.isNotEmpty ? sessions.first : null;
              final total = active?.totalNodes ?? 0;
              final lit = active?.litNodes ?? 0;
              return _ProgressHeader(
                progress: MindMapProgress(total: total, lit: lit),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          Expanded(
            child: sessionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败：$e')),
              data: (sessions) {
                if (sessions.isEmpty) {
                  return _EmptyState(subjectId: subjectId);
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(courseSessionsProvider(subjectId).notifier).refresh(),
                  child: _SessionList(
                    sessions: sessions,
                    subjectId: subjectId,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.classroom),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('去生成大纲'),
      ),
    );
  }
}

// ── 可排序列表 ────────────────────────────────────────────────────────────────

class _SessionList extends ConsumerWidget {
  final List<MindMapSession> sessions;
  final int subjectId;

  const _SessionList({required this.sessions, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 置顶卡片排前面，非置顶卡片可拖拽排序
    final pinned = sessions.where((s) => s.isPinned).toList();
    final unpinned = sessions.where((s) => !s.isPinned).toList();

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      // 置顶卡片 + 非置顶卡片
      itemCount: sessions.length,
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) async {
        // 只对非置顶部分重排
        final pinnedCount = pinned.length;

        // 如果拖拽涉及置顶区域，忽略
        if (oldIndex < pinnedCount || newIndex <= pinnedCount) return;

        // 调整 newIndex（ReorderableListView 的惯例）
        final adjustedNew = newIndex > oldIndex ? newIndex - 1 : newIndex;

        // 在非置顶列表中的相对索引
        final relOld = oldIndex - pinnedCount;
        final relNew = adjustedNew - pinnedCount;

        if (relOld == relNew) return;

        // 重新排列非置顶列表
        final reordered = List<MindMapSession>.from(unpinned);
        final item = reordered.removeAt(relOld);
        reordered.insert(relNew, item);

        // 批量更新 sort_order
        final notifier = ref.read(courseSessionsProvider(subjectId).notifier);
        for (var i = 0; i < reordered.length; i++) {
          await notifier.updateMeta(reordered[i].id, sortOrder: i);
        }
      },
      itemBuilder: (context, index) {
        final session = sessions[index];
        final isPinnedItem = session.isPinned;
        return _SessionCard(
          key: ValueKey(session.id),
          session: session,
          subjectId: subjectId,
          // 只有非置顶卡片显示拖拽手柄
          showDragHandle: !isPinnedItem,
          dragIndex: index,
        );
      },
    );
  }
}

// ── 进度头部 ──────────────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  final MindMapProgress progress;
  const _ProgressHeader({required this.progress});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = progress.percent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: cs.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('整体进度', style: TextStyle(fontSize: 13, color: cs.outline)),
              Text(
                '$pct%  (${progress.lit}/${progress.total})',
                style: TextStyle(fontSize: 13, color: cs.outline),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.total == 0 ? 0 : progress.lit / progress.total,
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 大纲卡片（StatefulWidget，支持折叠）────────────────────────────────────────

class _SessionCard extends ConsumerStatefulWidget {
  final MindMapSession session;
  final int subjectId;
  final bool showDragHandle;
  final int dragIndex;

  const _SessionCard({
    super.key,
    required this.session,
    required this.subjectId,
    required this.showDragHandle,
    required this.dragIndex,
  });

  @override
  ConsumerState<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends ConsumerState<_SessionCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final session = widget.session;
    final title = session.title?.isNotEmpty == true ? session.title! : '未命名大纲';
    final pct = session.totalNodes == 0
        ? 0
        : (session.litNodes / session.totalNodes * 100).floor();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          AppRoutes.editableMindMap(widget.subjectId, session.id),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 标题行 ──────────────────────────────────────────────────
              Row(
                children: [
                  // 图钉图标（置顶时显示）
                  if (session.isPinned) ...[
                    Icon(Icons.push_pin, size: 14, color: cs.primary),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  // 拖拽手柄（非置顶卡片）
                  if (widget.showDragHandle)
                    ReorderableDragStartListener(
                      index: widget.dragIndex,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.drag_handle,
                            size: 20, color: cs.outlineVariant),
                      ),
                    ),
                  _MoreMenu(session: session, subjectId: widget.subjectId),
                ],
              ),
              // ── 展开内容（进度、标签、日期）──────────────────────────────
              if (_expanded) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (session.resourceScopeLabel != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          session.resourceScopeLabel!,
                          style: TextStyle(
                              fontSize: 11, color: cs.onSecondaryContainer),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      _formatDate(session.createdAt),
                      style: TextStyle(fontSize: 12, color: cs.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${session.litNodes}/${session.totalNodes}  $pct%',
                  style: TextStyle(fontSize: 12, color: cs.primary),
                ),
              ],
              // ── 展开/折叠按钮 ─────────────────────────────────────────
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: cs.outline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

// ── ⋯ 菜单（重命名 / 置顶 / 删除）──────────────────────────────────────────────

class _MoreMenu extends ConsumerWidget {
  final MindMapSession session;
  final int subjectId;
  const _MoreMenu({required this.session, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'rename') {
          _showRenameDialog(context, ref);
        } else if (value == 'pin') {
          _togglePin(context, ref);
        } else if (value == 'delete') {
          _showDeleteDialog(context, ref);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'rename', child: Text('重命名')),
        PopupMenuItem(
          value: 'pin',
          child: Text(session.isPinned ? '取消置顶' : '置顶'),
        ),
        const PopupMenuItem(value: 'delete', child: Text('删除')),
      ],
    );
  }

  Future<void> _togglePin(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(courseSessionsProvider(subjectId).notifier)
          .updateMeta(session.id, isPinned: !session.isPinned);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败：$e')),
        );
      }
    }
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(
      text: session.title?.isNotEmpty == true ? session.title : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名大纲'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 64,
          decoration: const InputDecoration(hintText: '输入新名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final title = controller.text.trim();
              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('名称不能为空')),
                );
                return;
              }
              if (title.length > 64) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('名称不能超过 64 个字符')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref
                    .read(courseSessionsProvider(subjectId).notifier)
                    .renameSession(session.id, title);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('重命名失败：$e')),
                  );
                }
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除大纲'),
        content: Text(
          '确认删除「${session.title?.isNotEmpty == true ? session.title : '未命名大纲'}」？\n此操作不可撤销，相关讲义和学习记录也将一并删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(courseSessionsProvider(subjectId).notifier)
                    .deleteSession(session.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已删除')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败：$e')),
                  );
                }
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final int subjectId;
  const _EmptyState({required this.subjectId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '还没有大纲',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
            Text(
              '去「答疑室 → 导图」选择学科后生成思维导图，\n大纲就会出现在这里',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.classroom),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('去生成思维导图'),
            ),
          ],
        ),
      ),
    );
  }
}
