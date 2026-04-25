import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/subject.dart';
import '../../providers/notebook_provider.dart';
import '../../providers/subject_provider.dart';
import 'note_create_page.dart';
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

  void _openNewNotePage(BuildContext context, int? subjectId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteCreatePage(
          notebookId: widget.notebookId,
          initialSubjectId: subjectId,
        ),
      ),
    );
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final currentSubjectId = _tabController != null && _currentTabIds.isNotEmpty
              ? _currentTabIds[_tabController!.index]
              : null;
          _openNewNotePage(context, currentSubjectId);
        },
        tooltip: '新建笔记',
        child: const Icon(Icons.edit_note),
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (groupedNotes) {
          // Tab 列表：通用 + 所有未归档学科（不管有没有笔记）
          final allIds = <int?>[null];
          for (final s in subjects) {
            allIds.add(s.id);
          }
          // 额外补充有笔记但不在学科列表里的 subject_id
          for (final sid in groupedNotes.keys) {
            if (!allIds.contains(sid)) allIds.add(sid);
          }

          _updateTabs(allIds);

          if (_tabController == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: allIds.map((id) {
                  if (id == null) return const Tab(text: '通用');
                  return Tab(text: subjectMap[id] ?? '未知学科');
                }).toList(),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: allIds.map((subjectId) {
                    final notes = groupedNotes[subjectId] ?? [];
                    if (notes.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_note_outlined, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              '暂无笔记，点击右下角新建',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
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

