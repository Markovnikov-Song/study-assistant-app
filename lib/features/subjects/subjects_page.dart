import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/subject.dart';
import '../../providers/subject_provider.dart';
import '../../routes/app_router.dart';
import '../../providers/auth_provider.dart';

class SubjectsPage extends ConsumerWidget {
  const SubjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的学科'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '对话历史',
            onPressed: () => context.push(AppRoutes.history),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '登出',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go(AppRoutes.login);
            },
          ),
        ],
      ),
      body: subjectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (subjects) {
          final pinned = subjects.where((s) => s.isPinned && !s.isArchived).toList();
          final normal = subjects.where((s) => !s.isPinned && !s.isArchived).toList();
          final archived = subjects.where((s) => s.isArchived).toList();

          if (subjects.isEmpty) {
            return const Center(child: Text('还没有学科，点击右下角创建一个'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pinned.isNotEmpty) ...[
                const _SectionLabel('📌 置顶'),
                ...pinned.map((s) => _SubjectCard(subject: s)),
                const SizedBox(height: 8),
              ],
              if (normal.isNotEmpty) ...[
                if (pinned.isNotEmpty) const _SectionLabel('全部学科'),
                ...normal.map((s) => _SubjectCard(subject: s)),
              ],
              if (archived.isNotEmpty) ...[
                const SizedBox(height: 8),
                _ArchivedSection(subjects: archived),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateSubjectSheet(ref: ref),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );
}

class _SubjectCard extends ConsumerWidget {
  final Subject subject;
  const _SubjectCard({required this.subject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(subject.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subject.category != null ? Text(subject.category!) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SubjectMenu(subject: subject),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => context.push(AppRoutes.subjectDetailPath(subject.id)),
      ),
    );
  }
}

class _SubjectMenu extends ConsumerWidget {
  final Subject subject;
  const _SubjectMenu({required this.subject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        final notifier = ref.read(subjectActionsProvider);
        switch (value) {
          case 'pin':
            await notifier.togglePin(subject.id);
            ref.invalidate(subjectsProvider);
          case 'archive':
            await notifier.toggleArchive(subject.id);
            ref.invalidate(subjectsProvider);
          case 'edit':
            if (context.mounted) _showEditDialog(context, ref);
          case 'delete':
            if (context.mounted) _showDeleteConfirm(context, ref);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'pin',
          child: Text(subject.isPinned ? '取消置顶' : '📌 置顶'),
        ),
        const PopupMenuItem(value: 'edit', child: Text('✏️ 编辑')),
        const PopupMenuItem(value: 'archive', child: Text('📦 归档')),
        const PopupMenuItem(value: 'delete', child: Text('🗑 删除')),
      ],
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditSubjectSheet(subject: subject, ref: ref),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${subject.name}」吗？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(subjectActionsProvider).delete(subject.id);
              ref.invalidate(subjectsProvider);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _ArchivedSection extends ConsumerWidget {
  final List<Subject> subjects;
  const _ArchivedSection({required this.subjects});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpansionTile(
      title: Text('📦 归档学科（${subjects.length}）'),
      children: subjects
          .map((s) => ListTile(
                title: Text(s.name),
                subtitle: s.category != null ? Text(s.category!) : null,
                trailing: TextButton(
                  onPressed: () async {
                    await ref.read(subjectActionsProvider).toggleArchive(s.id);
                    ref.invalidate(subjectsProvider);
                  },
                  child: const Text('恢复'),
                ),
              ))
          .toList(),
    );
  }
}

// ── 创建学科底部弹窗 ──────────────────────────────────────────────────────
class _CreateSubjectSheet extends StatefulWidget {
  final WidgetRef ref;
  const _CreateSubjectSheet({required this.ref});

  @override
  State<_CreateSubjectSheet> createState() => _CreateSubjectSheetState();
}

class _CreateSubjectSheetState extends State<_CreateSubjectSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await widget.ref.read(subjectActionsProvider).create(
          _nameCtrl.text.trim(),
          category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        );
    widget.ref.invalidate(subjectsProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('创建学科', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '学科名称 *', border: OutlineInputBorder()),
              validator: (v) => v!.trim().isEmpty ? '请输入学科名称' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(labelText: '分类（可选）', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: '描述（可选）', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 编辑学科底部弹窗 ──────────────────────────────────────────────────────
class _EditSubjectSheet extends StatefulWidget {
  final Subject subject;
  final WidgetRef ref;
  const _EditSubjectSheet({required this.subject, required this.ref});

  @override
  State<_EditSubjectSheet> createState() => _EditSubjectSheetState();
}

class _EditSubjectSheetState extends State<_EditSubjectSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _descCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.subject.name);
    _categoryCtrl = TextEditingController(text: widget.subject.category ?? '');
    _descCtrl = TextEditingController(text: widget.subject.description ?? '');
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
    await widget.ref.read(subjectActionsProvider).update(
          widget.subject.id,
          name: _nameCtrl.text.trim(),
          category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        );
    widget.ref.invalidate(subjectsProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('编辑学科', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '学科名称 *', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _categoryCtrl, decoration: const InputDecoration(labelText: '分类', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: '描述', border: OutlineInputBorder()), maxLines: 2),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('保存'),
          ),
        ],
      ),
    );
  }
}
