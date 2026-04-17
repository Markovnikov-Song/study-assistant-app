import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mindmap_meta.dart';
import '../providers/mindmap_providers.dart';

/// Displays the currently active mindmap name for [subjectId].
/// Tapping opens a bottom sheet listing all mindmaps with options to
/// switch, create, or delete.
///
/// Requirements: 10.3–10.6
class MindmapSelectorDropdown extends ConsumerWidget {
  final int subjectId;
  const MindmapSelectorDropdown({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(mindmapListProvider(subjectId));
    final activeId = ref.watch(activeMindmapIdProvider(subjectId));

    final activeName = listAsync.maybeWhen(
      data: (list) {
        if (list.isEmpty) return '导图';
        final active = list.where((m) => m.id == activeId).firstOrNull;
        return active?.name ?? list.first.name;
      },
      orElse: () => '导图',
    );

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showBottomSheet(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                activeName,
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }

  void _showBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MindmapSelectorSheet(subjectId: subjectId),
    );
  }
}

// ── Bottom Sheet ──────────────────────────────────────────────────────────────

class _MindmapSelectorSheet extends ConsumerWidget {
  final int subjectId;
  const _MindmapSelectorSheet({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(mindmapListProvider(subjectId));
    final activeId = ref.watch(activeMindmapIdProvider(subjectId));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              '切换导图',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: listAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败：$e')),
              data: (list) => ListView.builder(
                controller: scrollController,
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final meta = list[i];
                  final isActive = meta.id == activeId;
                  final isLast = list.length == 1;
                  return _MindmapListTile(
                    meta: meta,
                    isActive: isActive,
                    isLast: isLast,
                    onTap: () {
                      _switchMindmap(context, ref, meta.id);
                      Navigator.pop(context);
                    },
                    onDelete: () =>
                        _confirmDelete(context, ref, meta, list.length),
                  );
                },
              ),
            ),
          ),
          const Divider(height: 1),
          // Create new mindmap button
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('新建导图'),
            onTap: () => _showCreateDialog(context, ref),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _switchMindmap(BuildContext context, WidgetRef ref, String id) {
    ref.read(activeMindmapIdProvider(subjectId).notifier).state = id;
    final repo = ref.read(mindmapRepositoryProvider);
    repo.setActiveId(subjectId, id);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MindmapMeta meta,
    int totalCount,
  ) async {
    if (totalCount <= 1) return; // guard — button should already be disabled

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除导图'),
        content: Text('确认删除「${meta.name}」？此操作不可撤销。'),
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

    if (confirmed != true || !context.mounted) return;

    try {
      final repo = ref.read(mindmapRepositoryProvider);
      await repo.deleteMindmap(subjectId, meta.id);

      // If deleted mindmap was active, switch to first remaining
      final activeId = ref.read(activeMindmapIdProvider(subjectId));
      if (activeId == meta.id) {
        final remaining = await repo.listMindmaps(subjectId);
        if (remaining.isNotEmpty) {
          _switchMindmap(context, ref, remaining.first.id);
        }
      }

      ref.invalidate(mindmapListProvider(subjectId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败：$e')),
        );
      }
    }
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建导图'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(
            hintText: '请输入导图名称',
            border: OutlineInputBorder(),
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
              final v = nameCtrl.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (name == null || !context.mounted) return;

    try {
      final repo = ref.read(mindmapRepositoryProvider);
      final meta = await repo.createMindmap(subjectId, name);
      ref.invalidate(mindmapListProvider(subjectId));
      _switchMindmap(context, ref, meta.id);
      if (context.mounted) Navigator.pop(context); // close bottom sheet
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败：$e')),
        );
      }
    }
  }
}

// ── List Tile ─────────────────────────────────────────────────────────────────

class _MindmapListTile extends StatelessWidget {
  final MindmapMeta meta;
  final bool isActive;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MindmapListTile({
    required this.meta,
    required this.isActive,
    required this.isLast,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: isActive
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : const SizedBox(width: 24),
      title: Text(
        meta.name,
        style: isActive
            ? TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
      ),
      onTap: onTap,
      trailing: IconButton(
        icon: Icon(
          Icons.delete_outline,
          color: isLast
              ? Theme.of(context).colorScheme.outlineVariant
              : Theme.of(context).colorScheme.error,
        ),
        tooltip: isLast ? '最后一份导图不可删除' : '删除',
        onPressed: isLast ? null : onDelete,
      ),
    );
  }
}
