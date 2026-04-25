import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:markdown_quill/markdown_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/subject.dart';
import '../../providers/notebook_provider.dart';
import '../../providers/subject_provider.dart';
import '../../tools/speech/speech_input_button.dart';

/// 新建笔记全屏页（替代原底部弹窗 _NewNoteSheet）
class NoteCreatePage extends ConsumerStatefulWidget {
  final int notebookId;
  final int? initialSubjectId;

  const NoteCreatePage({
    super.key,
    required this.notebookId,
    this.initialSubjectId,
  });

  @override
  ConsumerState<NoteCreatePage> createState() => _NoteCreatePageState();
}

class _NoteCreatePageState extends ConsumerState<NoteCreatePage> {
  final _titleCtrl = TextEditingController();
  late final QuillController _quillCtrl;
  bool _loading = false;
  late int? _selectedSubjectId;

  static final _deltaToMd = DeltaToMarkdown();

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.initialSubjectId;
    _quillCtrl = QuillController(
      document: Document.fromDelta(Delta()..insert('\n')),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _quillCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final content = _deltaToMd.convert(_quillCtrl.document.toDelta()).trim();
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
          'note_type': 'general',
        }
      ]);
      ref.invalidate(notebookNotesProvider(widget.notebookId));
      if (mounted) Navigator.pop(context, true); // true = 已创建
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
    final subjectsAsync = ref.watch(subjectsProvider);
    final subjects = subjectsAsync.maybeWhen(
      data: (list) => list.where((s) => !s.isArchived).toList(),
      orElse: () => <Subject>[],
    );
    final subjectMap = {for (final s in subjects) s.id: s.name};

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
          SpeechInputButton(
            onResult: (text) {
              final controller = _quillCtrl;
              final index = controller.selection.baseOffset;
              controller.document.insert(index, text);
            },
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: Column(
        children: [
          // 学科分区选择
          if (subjects.isNotEmpty)
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
                  ...subjectMap.entries.map((e) => Padding(
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
          // 工具栏
          QuillSimpleToolbar(
            controller: _quillCtrl,
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
          // 编辑区（全屏）
          Expanded(
            child: QuillEditor.basic(
              controller: _quillCtrl,
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
}
