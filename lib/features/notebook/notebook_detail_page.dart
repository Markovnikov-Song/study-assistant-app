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

  void _showNewNoteSheet(
    BuildContext context,
    WidgetRef ref,
    int? subjectId,
    Map<int, String> subjectMap,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NewNoteSheet(
        notebookId: widget.notebookId,
        subjectId: subjectId,
        subjectMap: subjectMap,
        onCreated: () => ref.invalidate(notebookNotesProvider(widget.notebookId)),
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
          _showNewNoteSheet(context, ref, currentSubjectId, subjectMap);
        },
        tooltip: '新建笔记',
        child: const Icon(Icons.edit_note),
      ),
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

class _NewNoteSheet extends ConsumerStatefulWidget {
  final int notebookId;
  final int? subjectId;
  final Map<int, String> subjectMap;
  final VoidCallback onCreated;

  const _NewNoteSheet({
    required this.notebookId,
    required this.subjectId,
    required this.subjectMap,
    required this.onCreated,
  });

  @override
  ConsumerState<_NewNoteSheet> createState() => _NewNoteSheetState();
}

class _NewNoteSheetState extends ConsumerState<_NewNoteSheet> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _loading = false;
  late int? _selectedSubjectId;

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.subjectId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入笔记内容')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(notebookServiceProvider).createNotes([
        {
          'notebook_id': widget.notebookId,
          'subject_id': _selectedSubjectId,
          'role': 'user',
          'original_content': content,
          if (_titleCtrl.text.trim().isNotEmpty) 'title': _titleCtrl.text.trim(),
        }
      ]);
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败：$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectEntries = widget.subjectMap.entries.toList();
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('新建笔记', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),
          // 分区选择
          if (subjectEntries.isNotEmpty) ...[
            const Text('分区', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 6),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('通用'),
                      selected: _selectedSubjectId == null,
                      onSelected: (_) => setState(() => _selectedSubjectId = null),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  ...subjectEntries.map((e) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _selectedSubjectId == e.key,
                      onSelected: (_) => setState(() => _selectedSubjectId = e.key),
                      visualDensity: VisualDensity.compact,
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _titleCtrl,
            maxLength: 64,
            decoration: const InputDecoration(
              labelText: '标题（可选）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentCtrl,
            maxLines: 6,
            minLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '笔记内容 *',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('保存'),
          ),
        ],
      ),
    );
  }
}
