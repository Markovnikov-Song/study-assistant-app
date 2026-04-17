import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/notebook.dart';
import '../../providers/notebook_provider.dart';
import '../../routes/app_router.dart';

class MistakeBookPage extends ConsumerWidget {
  const MistakeBookPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNotes = ref.watch(allMistakeNotesProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('错题本'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '待复盘'),
              Tab(text: '已复盘'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _createMistakeNote(context, ref),
          tooltip: '新建错题',
          child: const Icon(Icons.add),
        ),
        body: asyncNotes.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败：$e')),
          data: (notes) {
            if (notes == null) {
              return _EmptySystemNotebookState(
                onCreateNotebook: () => _createSystemNotebook(context, ref),
              );
            }
            final pending = notes.where((n) => n.mistakeStatus == 'pending').toList();
            final reviewed = notes.where((n) => n.mistakeStatus == 'reviewed').toList();
            return TabBarView(
              children: [
                _MistakeNoteList(notes: pending, emptyText: '暂无待复盘错题'),
                _MistakeNoteList(notes: reviewed, emptyText: '暂无已复盘错题'),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _createSystemNotebook(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(notebookListProvider.notifier).createNotebook('错题本');
      ref.invalidate(allMistakeNotesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _createMistakeNote(BuildContext context, WidgetRef ref) async {
    final notebooks = ref.read(notebookListProvider).valueOrNull ?? [];
    final mistakeBook = notebooks.cast<Notebook?>().firstWhere(
      (nb) => nb != null && nb.isSystem && nb.name == '错题本',
      orElse: () => null,
    );
    if (mistakeBook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先创建错题本')),
      );
      return;
    }
    context.push(AppRoutes.notebookDetail(mistakeBook.id));
  }
}

class _EmptySystemNotebookState extends StatelessWidget {
  final VoidCallback onCreateNotebook;
  const _EmptySystemNotebookState({required this.onCreateNotebook});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '还没有错题本',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onCreateNotebook,
            child: const Text('创建错题本'),
          ),
        ],
      ),
    );
  }
}

class _MistakeNoteList extends StatelessWidget {
  final List<Note> notes;
  final String emptyText;

  const _MistakeNoteList({required this.notes, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: notes.length,
      itemBuilder: (_, i) => _MistakeNoteCard(note: notes[i]),
    );
  }
}

class _MistakeNoteCard extends ConsumerWidget {
  final Note note;
  const _MistakeNoteCard({required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('yyyy-MM-dd').format(note.createdAt);
    final isPending = note.mistakeStatus == 'pending';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(AppRoutes.noteDetail(note.notebookId, note.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.error_outline, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.displayTitle,
                      style: note.hasTitleSet
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                              fontStyle: FontStyle.italic,
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          dateStr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                        if (note.subjectId != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '学科',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(isPending ? '待复盘' : '已复盘'),
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: isPending ? Colors.orange.shade800 : Colors.green.shade800,
                ),
                backgroundColor: isPending
                    ? Colors.orange.shade50
                    : Colors.green.shade50,
                side: BorderSide.none,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
