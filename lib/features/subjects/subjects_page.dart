import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/subject.dart';
import '../../providers/subject_provider.dart';

class SubjectsPage extends ConsumerStatefulWidget {
  const SubjectsPage({super.key});
  @override
  ConsumerState<SubjectsPage> createState() => _SubjectsPageState();
}

class _SubjectsPageState extends ConsumerState<SubjectsPage> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('学科管理')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context),
        child: const Icon(Icons.add),
      ),
      body: subjectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (subjects) {
          final active = subjects.where((s) => !s.isArchived).toList();
          final archived = subjects.where((s) => s.isArchived).toList();
          if (subjects.isEmpty) {
            return const Center(child: Text('还没有学科，点击右下角新建'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              ...active.map((s) => _SubjectCard(subject: s)),
              if (archived.isNotEmpty)
                InkWell(
                  onTap: () => setState(() => _showArchived = !_showArchived),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(_showArchived ? Icons.expand_less : Icons.expand_more, size: 18, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          _showArchived ? '隐藏已归档学科' : '显示已归档学科（${archived.length}）',
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_showArchived) ...archived.map((s) => _SubjectCard(subject: s, archived: true)),
            ],
          );
        },
      ),
    );
  }

  void _showForm(BuildContext context, {Subject? subject}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SubjectFormSheet(ref: ref, subject: subject),
    );
  }
}

class _SubjectCard extends ConsumerWidget {
  final Subject subject;
  final bool archived;
  const _SubjectCard({required this.subject, this.archived = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: subject.isPinned ? const Icon(Icons.push_pin, size: 18, color: Colors.orange) : null,
        title: Text(subject.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subject.category != null ? Text(subject.category!) : null,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (v) => _onAction(v, context, ref),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('编辑')),
            PopupMenuItem(value: 'pin', child: Text(subject.isPinned ? '取消置顶' : '置顶')),
            PopupMenuItem(value: 'archive', child: Text(archived ? '取消归档' : '归档')),
            const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  Future<void> _onAction(String action, BuildContext context, WidgetRef ref) async {
    final actions = ref.read(subjectActionsProvider);
    switch (action) {
      case 'edit':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => _SubjectFormSheet(ref: ref, subject: subject),
        );
      case 'pin':
        await actions.togglePin(subject.id);
        ref.invalidate(subjectsProvider);
      case 'archive':
        await actions.toggleArchive(subject.id);
        ref.invalidate(subjectsProvider);
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('确认删除'),
            content: Text('删除「${subject.name}」后不可恢复，相关资料和对话也会一并删除。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
            ],
          ),
        );
        if (ok == true) {
          await actions.delete(subject.id);
          ref.invalidate(subjectsProvider);
        }
    }
  }
}

class _SubjectFormSheet extends StatefulWidget {
  final WidgetRef ref;
  final Subject? subject;
  const _SubjectFormSheet({required this.ref, this.subject});

  @override
  State<_SubjectFormSheet> createState() => _SubjectFormSheetState();
}

class _SubjectFormSheetState extends State<_SubjectFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _descCtrl;
  bool _loading = false;

  bool get _isEdit => widget.subject != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.subject?.name ?? '');
    _categoryCtrl = TextEditingController(text: widget.subject?.category ?? '');
    _descCtrl = TextEditingController(text: widget.subject?.description ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final actions = widget.ref.read(subjectActionsProvider);
    if (_isEdit) {
      await actions.update(
        widget.subject!.id,
        name: _nameCtrl.text.trim(),
        category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      );
    } else {
      await actions.create(
        _nameCtrl.text.trim(),
        category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      );
    }
    widget.ref.invalidate(subjectsProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_isEdit ? '编辑学科' : '新建学科', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '学科名称 *', border: OutlineInputBorder()), autofocus: true),
          const SizedBox(height: 12),
          TextField(controller: _categoryCtrl, decoration: const InputDecoration(labelText: '分类（可选）', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: '描述（可选）', border: OutlineInputBorder()), maxLines: 2),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_isEdit ? '保存' : '创建'),
          ),
        ],
      ),
    );
  }
}
