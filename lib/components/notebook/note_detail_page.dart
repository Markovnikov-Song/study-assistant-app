import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/chat_message.dart';
import '../../models/notebook.dart';
import '../../providers/notebook_provider.dart';
import '../../widgets/markdown_latex_view.dart';
import '../../tools/speech/speech_input_button.dart';

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
  // 默认进入预览模式，点击"编辑"再切换
  bool _isEditing = false;
  bool _isSaving = false;

  late final TextEditingController _titleCtrl;
  QuillController? _quillCtrl;
  bool _initialized = false;

  static final _mdToDelta = MarkdownToDelta(
    markdownDocument: md.Document(extensionSet: md.ExtensionSet.gitHubFlavored),
  );
  static final _deltaToMd = DeltaToMarkdown();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _quillCtrl?.dispose();
    super.dispose();
  }

  void _initEditor(Note note) {
    if (_initialized) return;
    _initialized = true;
    _titleCtrl.text = note.title ?? '';
    _quillCtrl?.dispose();
    final delta = note.originalContent.trim().isEmpty
        ? (Delta()..insert('\n'))
        : _mdToDelta.convert(note.originalContent);
    _quillCtrl = QuillController(
      document: Document.fromDelta(delta),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  String get _currentMarkdown =>
      _quillCtrl != null ? _deltaToMd.convert(_quillCtrl!.document.toDelta()).trim() : '';

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(noteDetailProvider(widget.noteId).notifier).updateNote(
        title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        originalContent: _currentMarkdown,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _polishContent() async {
    final text = _currentMarkdown;
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先输入笔记内容')));
      return;
    }
    try {
      await ref.read(noteDetailProvider(widget.noteId).notifier).updateNote(originalContent: text);
      final polished = await ref.read(notebookServiceProvider).polishNote(widget.noteId);
      if (mounted) {
        final adopt = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('AI 润色结果'),
            content: SingleChildScrollView(child: MarkdownLatexView(data: polished)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('放弃')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('采用')),
            ],
          ),
        );
        if (adopt == true && mounted) {
          final delta = _mdToDelta.convert(polished);
          _quillCtrl?.dispose();
          _quillCtrl = QuillController(
            document: Document.fromDelta(delta),
            selection: const TextSelection.collapsed(offset: 0),
          );
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('润色失败：$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _generateTitle() async {
    try {
      await ref.read(noteDetailProvider(widget.noteId).notifier).generateTitle();
      final note = ref.read(noteDetailProvider(widget.noteId)).valueOrNull;
      if (note != null && mounted) {
        _titleCtrl.text = note.title ?? '';
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI 标题已生成')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI 生成失败，请稍后重试')));
    }
  }

  Future<void> _importToRag(Note note) async {
    if (_currentMarkdown.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('笔记内容为空，无法导入')));
      return;
    }
    try {
      // 先保存最新内容再导入
      await ref.read(noteDetailProvider(widget.noteId).notifier).updateNote(originalContent: _currentMarkdown);
      await ref.read(noteDetailProvider(widget.noteId).notifier).importToRag();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已成功导入资料库')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导入失败，请重试')));
    }
  }

  void _showDeleteDialog(Note note) {
    final router = GoRouter.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除笔记'),
        content: const Text('确定要删除这条笔记吗？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(notebookServiceProvider).deleteNote(widget.noteId);
                ref.invalidate(notebookNotesProvider(widget.notebookId));
                if (mounted) router.pop();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败：$e')));
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
      loading: () => Scaffold(appBar: AppBar(title: const Text('笔记')), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(title: const Text('笔记')), body: Center(child: Text('加载失败：$e'))),
      data: (note) {
        _initEditor(note);
        return _isEditing ? _buildEditScaffold(note) : _buildViewScaffold(note);
      },
    );
  }

  // ── 全屏编辑（默认，参考讲义布局）────────────────────────────────────────

  Widget _buildEditScaffold(Note note) {
    final quill = _quillCtrl;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _titleCtrl,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            hintText: '标题（可选）',
            border: InputBorder.none,
            isDense: true,
          ),
        ),
        actions: [
          // 语音输入
          SpeechInputButton(
            onResult: (text) {
              final ctrl = _quillCtrl;
              if (ctrl != null) {
                final index = ctrl.selection.baseOffset.clamp(0, ctrl.document.length - 1);
                ctrl.document.insert(index, text);
              }
            },
          ),
          // 保存状态指示
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            TextButton(onPressed: _save, child: const Text('保存')),
          // 更多操作
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (v) {
              if (v == 'polish') _polishContent();
              if (v == 'title') _generateTitle();
              if (v == 'import') _importToRag(note);
              if (v == 'preview') setState(() => _isEditing = false);
              if (v == 'delete') _showDeleteDialog(note);
            },
            itemBuilder: (_) => [
            const PopupMenuItem(value: 'polish', child: ListTile(leading: Icon(Icons.auto_fix_high), title: Text('AI 润色'), dense: true)),
              const PopupMenuItem(value: 'title', child: ListTile(leading: Icon(Icons.title), title: Text('AI 生成标题'), dense: true)),
              PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: Text(note.isImported ? '已导入资料库' : '导入资料库'),
                  dense: true,
                  enabled: !note.isImported,
                ),
              ),
              const PopupMenuItem(value: 'preview', child: ListTile(leading: Icon(Icons.visibility_outlined), title: Text('预览'), dense: true)),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('删除', style: TextStyle(color: Colors.red)), dense: true)),
            ],
          ),
        ],
      ),
      body: quill == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                QuillSimpleToolbar(
                  controller: quill,
                  config: const QuillSimpleToolbarConfig(
                    showFontFamily: false,
                    showFontSize: false,
                    showSubscript: false,
                    showSuperscript: false,
                    showInlineCode: true,
                    showCodeBlock: true,
                    showQuote: true,
                    showLink: false,
                    showSearchButton: false,
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: QuillEditor.basic(
                    controller: quill,
                    config: const QuillEditorConfig(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 80),
                      placeholder: '在这里写笔记…',
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── 预览模式（可选，从更多菜单进入）──────────────────────────────────────

  Widget _buildViewScaffold(Note note) {
    return Scaffold(
      appBar: AppBar(
        title: Text(note.hasTitleSet ? note.title! : '笔记预览'),
        actions: [
          TextButton(onPressed: () => setState(() => _isEditing = true), child: const Text('编辑')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (note.outline != null && note.outline!.isNotEmpty) ...[
            Text('提纲', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...note.outline!.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('• ', style: TextStyle(fontSize: 14)),
                Expanded(child: Text(item)),
              ]),
            )),
            const SizedBox(height: 16),
          ],
          MarkdownLatexView(data: note.originalContent),
          if (note.sources != null && note.sources!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSourcesSection(note.sources!),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSourcesSection(List<MessageSource> sources) {
    return ExpansionTile(
      title: Text('参考来源（${sources.length}）'),
      tilePadding: EdgeInsets.zero,
      children: sources.map((src) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        title: Text(src.filename, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        subtitle: Text(src.content, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        trailing: Text('${(src.score * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      )).toList(),
    );
  }
}
