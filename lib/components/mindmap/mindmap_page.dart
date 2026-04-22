import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/current_subject_provider.dart';
import '../../widgets/subject_bar.dart';
import 'models/mindmap_meta.dart';
import 'providers/mindmap_providers.dart';
import 'mindmap_editor_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MindMapPage — 脑图工坊首页
// 顶部学科选择器 + 该学科下的导图列表 + 新建入口
// ─────────────────────────────────────────────────────────────────────────────

class MindMapPage extends ConsumerStatefulWidget {
  /// 从外部传入时直接使用该学科（可选）
  final int? subjectId;

  const MindMapPage({super.key, this.subjectId});

  @override
  ConsumerState<MindMapPage> createState() => _MindMapPageState();
}

class _MindMapPageState extends ConsumerState<MindMapPage> {
  bool _fabExpanded = false;

  int? get _effectiveSubjectId {
    if (widget.subjectId != null) return widget.subjectId;
    return ref.watch(currentSubjectProvider)?.id;
  }

  @override
  Widget build(BuildContext context) {
    // 如果外部没传 subjectId，监听 subject-switch
    if (widget.subjectId == null) {
      ref.watch(subjectSwitchWatcherProvider);
    }

    final subjectId = _effectiveSubjectId;

    return Scaffold(
      appBar: AppBar(
        title: const SubjectBarTitle(),
        centerTitle: false,
      ),
      body: subjectId == null
          ? const _NoSubjectPlaceholder()
          : _MindmapWorkshopBody(
              subjectId: subjectId,
              fabExpanded: _fabExpanded,
              onFabToggle: () => setState(() => _fabExpanded = !_fabExpanded),
              onFabCollapse: () => setState(() => _fabExpanded = false),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MindmapWorkshopBody
// ─────────────────────────────────────────────────────────────────────────────

class _MindmapWorkshopBody extends ConsumerWidget {
  final int subjectId;
  final bool fabExpanded;
  final VoidCallback onFabToggle;
  final VoidCallback onFabCollapse;

  const _MindmapWorkshopBody({
    required this.subjectId,
    required this.fabExpanded,
    required this.onFabToggle,
    required this.onFabCollapse,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(mindmapListProvider(subjectId));

    return GestureDetector(
      onTap: fabExpanded ? onFabCollapse : null,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          listAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败：$e')),
            data: (list) => list.isEmpty
                ? _EmptyState(
                    subjectId: subjectId,
                    onCreateBlank: () => _createBlank(context, ref),
                    onCreateAi: () => _createWithAi(context, ref),
                  )
                : _MindmapList(
                    subjectId: subjectId,
                    list: list,
                  ),
          ),

          // FAB 区域
          Positioned(
            right: 16,
            bottom: 24,
            child: _ExpandableFab(
              expanded: fabExpanded,
              onToggle: onFabToggle,
              onCreateBlank: () {
                onFabCollapse();
                _createBlank(context, ref);
              },
              onCreateAi: () {
                onFabCollapse();
                _createWithAi(context, ref);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createBlank(BuildContext context, WidgetRef ref) async {
    final name = await _showNameDialog(context, title: '新建导图');
    if (name == null || !context.mounted) return;
    final repo = ref.read(mindmapRepositoryProvider);
    final meta = await repo.createMindmap(subjectId, name);
    ref.invalidate(mindmapListProvider(subjectId));
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MindmapEditorPage(
            subjectId: subjectId,
            mindmapId: meta.id,
            mindmapName: meta.name,
          ),
        ),
      );
    }
  }

  Future<void> _createWithAi(BuildContext context, WidgetRef ref) async {
    final name = await _showNameDialog(context, title: '新建 AI 导图');
    if (name == null || !context.mounted) return;
    final repo = ref.read(mindmapRepositoryProvider);
    final meta = await repo.createMindmap(subjectId, name);
    ref.invalidate(mindmapListProvider(subjectId));
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MindmapEditorPage(
            subjectId: subjectId,
            mindmapId: meta.id,
            mindmapName: meta.name,
            openAiTabOnStart: true,
          ),
        ),
      );
    }
  }

  Future<String?> _showNameDialog(BuildContext context,
      {required String title}) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(
            hintText: '输入导图名称',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MindmapList — 导图卡片列表
// ─────────────────────────────────────────────────────────────────────────────

class _MindmapList extends ConsumerWidget {
  final int subjectId;
  final List<MindmapMeta> list;

  const _MindmapList({required this.subjectId, required this.list});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _MindmapCard(
        meta: list[i],
        subjectId: subjectId,
        isLast: list.length == 1,
        onDelete: () => _delete(context, ref, list[i], list.length),
        onRename: () => _rename(context, ref, list[i]),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    MindmapMeta meta,
    int total,
  ) async {
    if (total <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少保留一份导图')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除导图'),
        content: Text('确认删除「${meta.name}」？此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(mindmapRepositoryProvider).deleteMindmap(subjectId, meta.id);
      ref.invalidate(mindmapListProvider(subjectId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('删除失败：$e')));
      }
    }
  }

  Future<void> _rename(
      BuildContext context, WidgetRef ref, MindmapMeta meta) async {
    final ctrl = TextEditingController(text: meta.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
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
    if (name == null || !context.mounted) return;
    try {
      final repo = ref.read(mindmapRepositoryProvider);
      await repo.renameMindmap(subjectId, meta.id, name);
      ref.invalidate(mindmapListProvider(subjectId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('重命名失败：$e')));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MindmapCard
// ─────────────────────────────────────────────────────────────────────────────

class _MindmapCard extends StatelessWidget {
  final MindmapMeta meta;
  final int subjectId;
  final bool isLast;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _MindmapCard({
    required this.meta,
    required this.subjectId,
    required this.isLast,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MindmapEditorPage(
              subjectId: subjectId,
              mindmapId: meta.id,
              mindmapName: meta.name,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.account_tree_outlined,
                    color: cs.onPrimaryContainer, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meta.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(meta.updatedAt),
                      style: TextStyle(fontSize: 12, color: cs.outline),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: cs.outline),
                onSelected: (v) {
                  if (v == 'rename') onRename();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'rename', child: Text('重命名')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      '删除',
                      style: TextStyle(
                          color: isLast
                              ? Theme.of(context).colorScheme.outlineVariant
                              : Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}  '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// _ExpandableFab — 展开式 FAB（自建 / AI 生成）
// ─────────────────────────────────────────────────────────────────────────────

class _ExpandableFab extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onCreateBlank;
  final VoidCallback onCreateAi;

  const _ExpandableFab({
    required this.expanded,
    required this.onToggle,
    required this.onCreateBlank,
    required this.onCreateAi,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // AI 生成
        AnimatedSlide(
          offset: expanded ? Offset.zero : const Offset(0, 0.5),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: expanded ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: IgnorePointer(
              ignoring: !expanded,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FloatingActionButton.extended(
                  heroTag: 'fab_ai',
                  onPressed: onCreateAi,
                  backgroundColor: cs.secondaryContainer,
                  foregroundColor: cs.onSecondaryContainer,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('AI 生成'),
                  elevation: 2,
                ),
              ),
            ),
          ),
        ),
        // 自建
        AnimatedSlide(
          offset: expanded ? Offset.zero : const Offset(0, 0.3),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: expanded ? 1 : 0,
            duration: const Duration(milliseconds: 120),
            child: IgnorePointer(
              ignoring: !expanded,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FloatingActionButton.extended(
                  heroTag: 'fab_blank',
                  onPressed: onCreateBlank,
                  backgroundColor: cs.tertiaryContainer,
                  foregroundColor: cs.onTertiaryContainer,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('自建'),
                  elevation: 2,
                ),
              ),
            ),
          ),
        ),
        // 主 FAB
        FloatingActionButton(
          heroTag: 'fab_main',
          onPressed: onToggle,
          child: AnimatedRotation(
            turns: expanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmptyState
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final int subjectId;
  final VoidCallback onCreateBlank;
  final VoidCallback onCreateAi;

  const _EmptyState({
    required this.subjectId,
    required this.onCreateBlank,
    required this.onCreateAi,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_outlined,
                size: 72, color: cs.outlineVariant),
            const SizedBox(height: 16),
            Text('还没有导图',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: cs.outline)),
            const SizedBox(height: 8),
            Text('选择一种方式创建你的第一份思维导图',
                style: TextStyle(fontSize: 13, color: cs.outline),
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: onCreateBlank,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('自建'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onCreateAi,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('AI 生成'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NoSubjectPlaceholder
// ─────────────────────────────────────────────────────────────────────────────

class _NoSubjectPlaceholder extends ConsumerWidget {
  const _NoSubjectPlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 64, color: cs.outlineVariant),
            const SizedBox(height: 16),
            Text('请先选择学科',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: cs.outline)),
            const SizedBox(height: 8),
            Text('点击顶部学科名称切换或新建学科',
                style: TextStyle(fontSize: 13, color: cs.outline)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const SubjectPickerSheet(),
              ),
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('选择学科'),
            ),
          ],
        ),
      ),
    );
  }
}
