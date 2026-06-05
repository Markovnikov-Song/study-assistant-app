import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/document.dart';
import '../../../providers/document_provider.dart';

class DocsTab extends ConsumerWidget {
  final int subjectId;
  const DocsTab({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsProvider(subjectId));
    final kbAsync = ref.watch(subjectKnowledgeBaseProvider(subjectId));
    final uploadState = ref.watch(documentActionsProvider(subjectId));

    ref.listen(documentActionsProvider(subjectId), (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('上传失败：${next.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        ref.read(documentActionsProvider(subjectId).notifier).clearError();
      }
    });

    final hasActiveJob = docsAsync.maybeWhen(
      data: (docs) => docs.any(
        (d) =>
            d.status == DocumentStatus.pending ||
            d.status == DocumentStatus.processing,
      ),
      orElse: () => uploadState.isUploading,
    );

    return Column(
      children: [
        if (hasActiveJob) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(documentsProvider(subjectId));
              ref.invalidate(subjectKnowledgeBaseProvider(subjectId));
            },
            child: docsAsync.when(
              loading: () => const _DocsLoadingView(),
              error: (e, _) => _DocsErrorView(message: '加载失败：$e'),
              data: (docs) {
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      sliver: SliverToBoxAdapter(
                        child: kbAsync.maybeWhen(
                          data: (kb) => _KnowledgeBasePanel(kb: kb),
                          loading: () => const _KnowledgeBaseSkeleton(),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      sliver: SliverToBoxAdapter(
                        child: _ActionBar(
                          isUploading: uploadState.isUploading,
                          onUpload: () => ref
                              .read(documentActionsProvider(subjectId).notifier)
                              .pickAndUpload(),
                          onReindexAll: () => _reindexAll(context, ref),
                        ),
                      ),
                    ),
                    if (docs.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyDocsView(),
                      )
                    else
                      ..._buildDocSections(docs),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _reindexAll(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(documentActionsProvider(subjectId).notifier).reindexAll();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已开始重建索引')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重建索引失败：$e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  List<Widget> _buildDocSections(List<StudyDocument> docs) {
    final grouped = <_ResourceCategory, List<StudyDocument>>{};
    for (final doc in docs) {
      final category = _inferResourceCategory(doc);
      grouped.putIfAbsent(category, () => []).add(doc);
    }

    return [
      for (final category in _resourceCategoryOrder)
        if ((grouped[category] ?? const <StudyDocument>[]).isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverToBoxAdapter(
              child: _ResourceSectionHeader(
                category: category,
                count: grouped[category]!.length,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            sliver: SliverList.separated(
              itemCount: grouped[category]!.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _DocTile(
                doc: grouped[category]![i],
                subjectId: subjectId,
                category: category,
              ),
            ),
          ),
        ],
      const SliverToBoxAdapter(child: SizedBox(height: 6)),
    ];
  }
}

enum _ResourceCategory { textbook, lecture, mistake, note, exam, other }

const _resourceCategoryOrder = [
  _ResourceCategory.textbook,
  _ResourceCategory.lecture,
  _ResourceCategory.mistake,
  _ResourceCategory.note,
  _ResourceCategory.exam,
  _ResourceCategory.other,
];

_ResourceCategory _inferResourceCategory(StudyDocument doc) {
  final backend = (doc.parserBackend ?? '').toLowerCase();
  if (backend == 'lecture') return _ResourceCategory.lecture;
  if (backend == 'mistake') return _ResourceCategory.mistake;
  if (backend == 'note') return _ResourceCategory.note;

  final name = doc.filename.toLowerCase();
  if (name.startsWith('错题：') || name.contains('错题')) {
    return _ResourceCategory.mistake;
  }
  if (name.contains('真题') ||
      name.contains('试卷') ||
      name.contains('exam') ||
      name.contains('test') ||
      name.contains('paper')) {
    return _ResourceCategory.exam;
  }
  if (name.contains('讲义') ||
      name.contains('lecture') ||
      name.contains('lesson')) {
    return _ResourceCategory.lecture;
  }
  if (name.contains('笔记') || name.contains('note') || name.contains('notes')) {
    return _ResourceCategory.note;
  }
  if (name.contains('教材') ||
      name.contains('课本') ||
      name.contains('textbook') ||
      name.contains('book')) {
    return _ResourceCategory.textbook;
  }
  return _ResourceCategory.other;
}

String _resourceCategoryLabel(_ResourceCategory category) {
  return switch (category) {
    _ResourceCategory.textbook => '教材资料',
    _ResourceCategory.lecture => '生成讲义',
    _ResourceCategory.mistake => '错题资源',
    _ResourceCategory.note => '笔记导入',
    _ResourceCategory.exam => '真题练习',
    _ResourceCategory.other => '其他资料',
  };
}

String _resourceCategoryHint(_ResourceCategory category) {
  return switch (category) {
    _ResourceCategory.textbook => '原始教材、课件和资料包',
    _ResourceCategory.lecture => 'AI 或人工整理出的讲义产物',
    _ResourceCategory.mistake => '错题、错因和复盘记录',
    _ResourceCategory.note => '从笔记本回写到资料库的内容',
    _ResourceCategory.exam => '试卷、真题和专项练习材料',
    _ResourceCategory.other => '暂未归类的参考资料',
  };
}

IconData _resourceCategoryIcon(_ResourceCategory category) {
  return switch (category) {
    _ResourceCategory.textbook => Icons.menu_book_outlined,
    _ResourceCategory.lecture => Icons.article_outlined,
    _ResourceCategory.mistake => Icons.error_outline_rounded,
    _ResourceCategory.note => Icons.sticky_note_2_outlined,
    _ResourceCategory.exam => Icons.fact_check_outlined,
    _ResourceCategory.other => Icons.folder_outlined,
  };
}

class _ResourceSectionHeader extends StatelessWidget {
  final _ResourceCategory category;
  final int count;

  const _ResourceSectionHeader({required this.category, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Icon(_resourceCategoryIcon(category), size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          _resourceCategoryLabel(category),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            _resourceCategoryHint(category),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _KnowledgeBasePanel extends StatelessWidget {
  final SubjectKnowledgeBase kb;
  const _KnowledgeBasePanel({required this.kb});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ready = kb.mindmapReady;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (ready ? cs.primary : cs.tertiary).withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  ready
                      ? Icons.account_tree_rounded
                      : Icons.folder_open_rounded,
                  color: ready ? cs.primary : cs.tertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kb.statusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ready ? '可用于问答、讲义和思维导图' : '资料处理完成后自动可用',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricPill(
                  icon: Icons.description_outlined,
                  label: '资料',
                  value: '${kb.documentCount}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricPill(
                  icon: Icons.grid_view_rounded,
                  label: '知识块',
                  value: '${kb.chunkCount}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricPill(
                  icon: ready
                      ? Icons.check_circle_outline_rounded
                      : Icons.timelapse_rounded,
                  label: '导图',
                  value: ready ? '就绪' : '待处理',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final bool isUploading;
  final VoidCallback onUpload;
  final VoidCallback onReindexAll;

  const _ActionBar({
    required this.isUploading,
    required this.onUpload,
    required this.onReindexAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: isUploading ? null : onUpload,
            icon: isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_rounded),
            label: Text(isUploading ? '上传中' : '上传资料'),
          ),
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: '重建全部索引',
          child: IconButton.outlined(
            onPressed: isUploading ? null : onReindexAll,
            icon: const Icon(Icons.sync_rounded),
          ),
        ),
      ],
    );
  }
}

class _DocTile extends ConsumerWidget {
  final StudyDocument doc;
  final int subjectId;
  final _ResourceCategory category;
  const _DocTile({
    required this.doc,
    required this.subjectId,
    required this.category,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final processing =
        doc.status == DocumentStatus.pending ||
        doc.status == DocumentStatus.processing;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(
          color: _statusColor(cs, doc.status).withValues(alpha: 0.36),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DocStatusIcon(status: doc.status),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.filename,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _ResourceCategoryChip(category: category),
                        _StatusChip(
                          label: _stageLabel(doc),
                          status: doc.status,
                        ),
                        if (doc.chunkCount > 0)
                          _TinyChip(
                            icon: Icons.grid_view_rounded,
                            label: '${doc.chunkCount} 块',
                          ),
                        if ((doc.parserBackend ?? '').isNotEmpty)
                          _TinyChip(
                            icon: Icons.memory_rounded,
                            label: doc.parserBackend!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_DocAction>(
                tooltip: '资料操作',
                onSelected: (action) {
                  switch (action) {
                    case _DocAction.reindex:
                      _reindex(context, ref);
                    case _DocAction.delete:
                      _confirmDelete(context, ref);
                  }
                },
                itemBuilder: (_) => [
                  if (doc.status == DocumentStatus.completed)
                    const PopupMenuItem(
                      value: _DocAction.reindex,
                      child: ListTile(
                        leading: Icon(Icons.sync_rounded),
                        title: Text('重建索引'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  const PopupMenuItem(
                    value: _DocAction.delete,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline_rounded),
                      title: Text('删除资料'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (processing) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: doc.progress > 0 ? doc.progress / 100 : null,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${doc.progress.clamp(0, 100)}%',
              style: theme.textTheme.labelSmall,
            ),
          ],
          if (doc.error != null && doc.error!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              doc.error!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _reindex(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(documentActionsProvider(subjectId).notifier)
          .reindex(doc.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已开始重建索引')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败：$e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除资料'),
        content: Text('确定删除「${doc.filename}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref
                    .read(documentActionsProvider(subjectId).notifier)
                    .delete(doc.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('删除失败：$e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
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

class _ResourceCategoryChip extends StatelessWidget {
  final _ResourceCategory category;

  const _ResourceCategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _resourceCategoryIcon(category),
            size: 13,
            color: cs.onPrimaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            _resourceCategoryLabel(category),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: cs.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}

class _DocStatusIcon extends StatelessWidget {
  final DocumentStatus status;
  const _DocStatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _statusColor(cs, status);
    final icon = switch (status) {
      DocumentStatus.completed => Icons.check_circle_rounded,
      DocumentStatus.processing => Icons.autorenew_rounded,
      DocumentStatus.failed => Icons.error_rounded,
      DocumentStatus.pending => Icons.schedule_rounded,
    };

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final DocumentStatus status;
  const _StatusChip({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _statusColor(cs, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TinyChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _EmptyDocsView extends StatelessWidget {
  const _EmptyDocsView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 44, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('暂无资料', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '上传教材、课件或讲义后，会自动解析为可检索的知识块。',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DocsLoadingView extends StatelessWidget {
  const _DocsLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _DocsErrorView extends StatelessWidget {
  final String message;
  const _DocsErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _KnowledgeBaseSkeleton extends StatelessWidget {
  const _KnowledgeBaseSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 132,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

enum _DocAction { reindex, delete }

String _stageLabel(StudyDocument doc) {
  return switch (doc.processingStage) {
    'queued' => '等待解析',
    'parsing' => '正在解析',
    'indexing' => '正在索引',
    'preprocessing' => '预处理',
    'ready' => '已就绪',
    'failed' => '失败',
    _ => doc.statusLabel,
  };
}

Color _statusColor(ColorScheme cs, DocumentStatus status) {
  return switch (status) {
    DocumentStatus.completed => cs.primary,
    DocumentStatus.processing => cs.secondary,
    DocumentStatus.failed => cs.error,
    DocumentStatus.pending => cs.tertiary,
  };
}
