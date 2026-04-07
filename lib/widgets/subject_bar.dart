import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subject.dart';
import '../providers/current_subject_provider.dart';
import '../providers/subject_provider.dart';

/// 顶部学科切换栏，所有功能页共用
class SubjectBar extends ConsumerWidget implements PreferredSizeWidget {
  const SubjectBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentSubjectProvider);
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showSubjectSheet(context, ref),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📚', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    current?.name ?? '请选择学科',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: current == null ? cs.outline : cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more, size: 18, color: cs.outline),
                ],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => _showCreateSheet(context, ref),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('新建', style: TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  void _showSubjectSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SubjectPickerSheet(ref: ref),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateSubjectSheet(ref: ref),
    );
  }
}

// ── 学科选择抽屉 ──────────────────────────────────────────────────────────
class _SubjectPickerSheet extends ConsumerWidget {
  final WidgetRef ref;
  const _SubjectPickerSheet({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);
    final current = ref.watch(currentSubjectProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text('选择学科', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _CreateSubjectSheet(ref: ref),
                    );
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('新建学科'),
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
                return ListView(
                  controller: ctrl,
                  children: [
                    ...active.map((s) => _SubjectTile(
                          subject: s,
                          isSelected: current?.id == s.id,
                          onTap: () {
                            ref.read(currentSubjectProvider.notifier).state = s;
                            Navigator.pop(context);
                          },
                          ref: ref,
                        )),
                    if (archived.isNotEmpty)
                      ExpansionTile(
                        title: Text('归档学科（${archived.length}）',
                            style: const TextStyle(fontSize: 13, color: Colors.grey)),
                        children: archived
                            .map((s) => _SubjectTile(
                                  subject: s,
                                  isSelected: current?.id == s.id,
                                  onTap: () {
                                    ref.read(currentSubjectProvider.notifier).state = s;
                                    Navigator.pop(context);
                                  },
                                  ref: ref,
                                ))
                            .toList(),
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
  final VoidCallback onTap;
  final WidgetRef ref;
  const _SubjectTile({required this.subject, required this.isSelected, required this.onTap, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: isSelected
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
          : const Icon(Icons.circle_outlined, color: Colors.grey),
      title: Text(subject.name, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
      subtitle: subject.category != null ? Text(subject.category!) : null,
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 18),
        onSelected: (v) async {
          final actions = ref.read(subjectActionsProvider);
          if (v == 'pin') { await actions.togglePin(subject.id); ref.invalidate(subjectsProvider); }
          if (v == 'archive') { await actions.toggleArchive(subject.id); ref.invalidate(subjectsProvider); }
          if (v == 'delete') {
            await actions.delete(subject.id);
            ref.invalidate(subjectsProvider);
            if (ref.read(currentSubjectProvider)?.id == subject.id) {
              ref.read(currentSubjectProvider.notifier).state = null;
            }
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'pin', child: Text(subject.isPinned ? '取消置顶' : '📌 置顶')),
          const PopupMenuItem(value: 'archive', child: Text('📦 归档')),
          const PopupMenuItem(value: 'delete', child: Text('🗑 删除')),
        ],
      ),
      onTap: onTap,
    );
  }
}

// ── 新建学科表单 ──────────────────────────────────────────────────────────
class _CreateSubjectSheet extends StatefulWidget {
  final WidgetRef ref;
  const _CreateSubjectSheet({required this.ref});

  @override
  State<_CreateSubjectSheet> createState() => _CreateSubjectSheetState();
}

class _CreateSubjectSheetState extends State<_CreateSubjectSheet> {
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
