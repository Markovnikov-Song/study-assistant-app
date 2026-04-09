import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/chat_message.dart';
import '../../models/notebook.dart';
import '../../providers/notebook_provider.dart';
import '../../routes/app_router.dart';
import '../../widgets/markdown_latex_view.dart';

class NoteDetailPage extends ConsumerStatefulWidget {
  final int notebookId;
  final int noteId;

  const NoteDetailPage({
    super.key,
    required this.notebookId,
    required this.noteId,
  });

  @override
  ConsumerState<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends ConsumerState<NoteDetailPage> {
  bool _isEditing = false;
  bool _isGenerating = false;
  bool _isImporting = false;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _contentCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _enterEditMode(Note note) {
    _titleCtrl.text = note.title ?? '';
    _contentCtrl.text = note.originalContent;
    setState(() => _isEditing = true);
  }

  Future<void> _saveEdit() async {
    final notifier = ref.read(noteDetailProvider(widget.noteId).notifier);
    try {
      await notifier.updateNote(
        title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        originalContent: _contentCtrl.text,
      );
      if (mounted) setState(() => _isEditing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    }
  }

  Future<void> _generateTitle() async {
    setState(() => _isGenerating = true);
    try {
      await ref.read(noteDetailProvider(widget.noteId).notifier).generateTitle();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI 标题提纲已生成')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI 生成失败，请手动填写或稍后重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _importToRag(Note note) async {
    if (note.originalContent.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('笔记内容为空，无法导入')),
      );
      return;
    }
    setState(() => _isImporting = true);
    try {
      await ref.read(noteDetailProvider(widget.noteId).notifier).importToRag();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已成功导入资料库')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导入失败，请重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showDeleteDialog(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除笔记'),
        content: const Text('确定要删除这条笔记吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref
                    .read(notebookServiceProvider)
                    .deleteNote(widget.noteId);
                ref.invalidate(notebookNotesProvider(widget.notebookId));
                if (mounted) router.pop();
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('删除失败：$e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noteAsync = ref.watch(noteDetailProvider(widget.noteId));

    return noteAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('笔记详情')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('笔记详情')),
        body: Center(child: Text('加载失败：$e')),
      ),
      data: (note) => _isEditing
          ? _buildEditScaffold(note)
          : _buildViewScaffold(note),
    );
  }

  Widget _buildViewScaffold(Note note) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('笔记详情'),
        actions: [
          TextButton(
            onPressed: () => _enterEditMode(note),
            child: const Text('编辑'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) {
              if (value == 'delete') _showDeleteDialog(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTitleSection(note),
          if (note.outline != null && note.outline!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildOutlineSection(note.outline!),
          ],
          const SizedBox(height: 16),
          _buildContentSection(note),
          if (note.sources != null && note.sources!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSourcesSection(note.sources!),
          ],
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(note),
    );
  }

  Widget _buildTitleSection(Note note) {
    final theme = Theme.of(context);
    final hasTitle = note.hasTitleSet;
    return Text(
      note.displayTitle,
      style: hasTitle
          ? theme.textTheme.titleLarge
          : theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              fontStyle: FontStyle.italic,
            ),
    );
  }

  Widget _buildOutlineSection(List<String> outline) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('提纲', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ...outline.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 14)),
                Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentSection(Note note) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('原始内容', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        MarkdownLatexView(data: note.originalContent),
      ],
    );
  }

  Widget _buildSourcesSection(List<MessageSource> sources) {
    return ExpansionTile(
      title: Text('参考来源（${sources.length}）'),
      tilePadding: EdgeInsets.zero,
      children: sources.map((src) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Text(
            src.filename,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
          subtitle: Text(
            src.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Text(
            '${(src.score * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomBar(Note note) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: _isGenerating ? null : _generateTitle,
                child: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('✨ AI 生成标题提纲'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: note.isImported
                  ? FilledButton(
                      onPressed: () {
                        if (note.subjectId != null) {
                          context.push(AppRoutes.subjectDetailPath(note.subjectId!));
                        }
                      },
                      child: const Text('✅ 已导入（查看）'),
                    )
                  : FilledButton.tonal(
                      onPressed: _isImporting ? null : () => _importToRag(note),
                      child: _isImporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('📚 导入资料库'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditScaffold(Note note) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑笔记'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _isEditing = false),
        ),
        actions: [
          TextButton(
            onPressed: _saveEdit,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleCtrl,
            maxLength: 64,
            decoration: const InputDecoration(
              labelText: '标题（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentCtrl,
            maxLines: null,
            minLines: 8,
            decoration: const InputDecoration(
              labelText: '正文',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saveEdit,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
