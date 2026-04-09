import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/subject.dart';
import '../../providers/notebook_provider.dart';
import '../../providers/subject_provider.dart';
import 'widgets/note_card.dart';

class NotebookDetailPage extends ConsumerStatefulWidget {
  final int notebookId;
  const NotebookDetailPage({super.key, required this.notebookId});

  @override
  ConsumerState<NotebookDetailPage> createState() => _NotebookDetailPageState();
}

class _NotebookDetailPageState extends ConsumerState<NotebookDetailPage>
    with TickerProviderStateMixin {
  TabController? _tabController;
  List<int?> _currentTabIds = [];

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _updateTabs(List<int?> newIds) {
    if (_currentTabIds.length == newIds.length &&
        _currentTabIds.every((id) => newIds.contains(id))) {
      return;
    }
    _tabController?.dispose();
    _tabController = TabController(length: newIds.length, vsync: this);
    _currentTabIds = List.from(newIds);
  }

  @override
  Widget build(BuildContext context) {
    final notebooksAsync = ref.watch(notebookListProvider);
    final notesAsync = ref.watch(notebookNotesProvider(widget.notebookId));
    final subjectsAsync = ref.watch(subjectsProvider);

    final notebookName = notebooksAsync.maybeWhen(
      data: (list) => list.where((nb) => nb.id == widget.notebookId).firstOrNull?.name ?? '笔记本',
      orElse: () => '笔记本',
    );

    final subjects = subjectsAsync.maybeWhen(
      data: (list) => list.where((s) => !s.isArchived).toList(),
      orElse: () => <Subject>[],
    );

    final subjectMap = {for (final s in subjects) s.id: s.name};

    return Scaffold(
      appBar: AppBar(title: Text(notebookName)),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (groupedNotes) {
          // 构建 Tab 列表：通用栏 + 有笔记的学科 + 学科列表里的学科
          final allIds = <int?>[null];
          for (final s in subjects) {
            if (!allIds.contains(s.id)) allIds.add(s.id);
          }
          for (final sid in groupedNotes.keys) {
            if (!allIds.contains(sid)) allIds.add(sid);
          }
          // 只显示通用栏 + 有笔记的学科
          final visibleIds = allIds
              .where((id) => id == null || groupedNotes.containsKey(id))
              .toList();
          if (visibleIds.isEmpty) visibleIds.add(null);

          _updateTabs(visibleIds);

          if (_tabController == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: visibleIds.map((id) {
                  if (id == null) return const Tab(text: '通用');
                  return Tab(text: subjectMap[id] ?? '未知学科');
                }).toList(),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: visibleIds.map((subjectId) {
                    final notes = groupedNotes[subjectId] ?? [];
                    if (notes.isEmpty) {
                      return Center(
                        child: Text(
                          '暂无笔记',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                              ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: notes.length,
                      itemBuilder: (_, i) => NoteCard(
                        note: notes[i],
                        notebookId: widget.notebookId,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
