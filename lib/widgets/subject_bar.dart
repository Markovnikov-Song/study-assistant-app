import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subject.dart';
import '../providers/current_subject_provider.dart';
import '../providers/subject_provider.dart';

class SubjectBarTitle extends ConsumerWidget {
  const SubjectBarTitle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentSubjectProvider);
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => SubjectPickerSheet(ref: ref),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📚', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(current?.name ?? '选择学科', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(width: 2),
          const Icon(Icons.expand_more, size: 20),
        ],
      ),
    );
  }
}

class SubjectPickerSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const SubjectPickerSheet({super.key, required this.ref});

  @override
  ConsumerState<SubjectPickerSheet> createState() => _SubjectPickerSheetState();
}

class _SubjectPickerSheetState extends ConsumerState<SubjectPickerSheet> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectsProvider);
    final current = ref.watch(currentSubjectProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.55, maxChildSize: 0.9, expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Center(child: Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Text('切换学科', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => CreateSubjectSheet(ref: ref));
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('新建'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: subjectsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (subjects) {
                final active = subjects.where((s) => !s.isArchived).toList();
                final archived = subjects.where((s) => s.isArchived).toList();
                return Stack(
                  children: [
                    ListView(
                      controller: ctrl,
                      padding: const EdgeInsets.only(bottom: 64),
                      children: [
                        ...active.map((s) => _SubjectTile(
                          subject: s, isSelected: current?.id == s.id,
                          onSelect: () { ref.read(currentSubjectProvider.notifier).state = s; Navigator.pop(context); },
                        )),
                        if (_showArchived && archived.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text('已归档', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ),
                          ...archived.map((s) => _SubjectTile(
                            subject: s, isSelected: current?.id == s.id,
                            onSelect: () { ref.read(currentSubjectProvider.notifier).state = s; Navigator.pop(context); },
                          )),
                        ],
                      ],
                    ),
                    if (archived.isNotEmpty)
                      Positioned(
                        right: 16, bottom: 16,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _showArchived = !_showArchived),
                          icon: Icon(_showArchived ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16),
                          label: Text(_showArchived ? '隐藏已归档学科' : '显示已归档学科（${archived.length}）', style: const TextStyle(fontSize: 13)),
                          style: TextButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectTile extends ConsumerWidget {
  final Subject subject;
  final bool isSelected;
  final VoidCallback onSelect;
  const _SubjectTile({required this.subject, required this.isSelected, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? cs.primary : cs.outline, size: 22),
      title: Text(subject.name, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
      subtitle: subject.category != null ? Text(subject.category!, style: const TextStyle(fontSize: 12)) : null,
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 18),
        onSelected: (v) async {
          final actions = ref.read(subjectActionsProvider);
          if (v == 'pin') { await actions.togglePin(subject.id); ref.invalidate(subjectsProvider); }
          if (v == 'archive') { await actions.toggleArchive(subject.id); ref.invalidate(subjectsProvider); }
          if (v == 'delete') {
            await actions.delete(subject.id);
            ref.invalidate(subjectsProvider);
            if (ref.read(currentSubjectProvider)?.id == subject.id) ref.read(currentSubjectProvider.notifier).state = null;
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'pin', child: Text(subject.isPinned ? '取消置顶' : '📌 置顶')),
          PopupMenuItem(value: 'archive', child: Text(subject.isArchived ? '📤 取消归档' : '📦 归档')),
          const PopupMenuItem(value: 'delete', child: Text('🗑 删除')),
        ],
      ),
      onTap: onSelect,
    );
  }
}

class CreateSubjectSheet extends StatefulWidget {
  final WidgetRef ref;
  const CreateSubjectSheet({super.key, required this.ref});

  @override
  State<CreateSubjectSheet> createState() => _CreateSubjectSheetState();
}

class _CreateSubjectSheetState extends State<CreateSubjectSheet> {
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() { _nameCtrl.dispose(); _categoryCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final subject = await widget.ref.read(subjectActionsProvider).createAndReturn(
      _nameCtrl.text.trim(),
      category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
    );
    widget.ref.invalidate(subjectsProvider);
    if (subject != null) widget.ref.read(currentSubjectProvider.notifier).state = subject;
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
          Text('新建学科', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '学科名称 *', border: OutlineInputBorder()), autofocus: true),
          const SizedBox(height: 12),
          TextField(controller: _categoryCtrl, decoration: const InputDecoration(labelText: '分类（可选）', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('创建'),
          ),
        ],
      ),
    );
  }
}
