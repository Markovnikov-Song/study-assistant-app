import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/document.dart';
import '../../providers/chat_provider.dart';
import '../../providers/current_subject_provider.dart';
import '../../providers/document_provider.dart';
import '../../widgets/session_history_sheet.dart';
import '../../widgets/subject_bar.dart';
import '../../widgets/no_subject_hint.dart';

import 'mindmap_view_stub.dart'
    if (dart.library.html) 'mindmap_view_web.dart'
    if (dart.library.io) 'mindmap_view_native.dart';

class MindMapPage extends ConsumerStatefulWidget {
  const MindMapPage({super.key});
  @override
  ConsumerState<MindMapPage> createState() => _MindMapPageState();
}

class _MindMapPageState extends ConsumerState<MindMapPage> {
  final Set<int> _selectedDocIds = {};

  @override
  Widget build(BuildContext context) {
    final subject = ref.watch(currentSubjectProvider);
    final generating = subject != null &&
        ref.watch(chatProvider((subject.id, 'mindmap'))).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const SubjectBarTitle(),
        centerTitle: false,
        actions: [
          if (subject != null)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: '历史记录',
              onPressed: () => showSessionHistorySheet(context, ref,
                  subjectId: subject.id, initialType: 'mindmap'),
            ),
        ],
      ),
      body: subject == null
          ? const NoSubjectHint()
          : _MindMapBody(
              subjectId: subject.id,
              selectedDocIds: _selectedDocIds,
              generating: generating,
              onDocSelectionChanged: (id, selected) => setState(() {
                if (selected) {
                  _selectedDocIds.add(id);
                } else {
                  _selectedDocIds.remove(id);
                }
              }),
              onGenerate: _generate,
            ),
    );
  }

  Future<void> _generate() async {
    final sid = ref.read(currentSubjectProvider)?.id;
    if (sid == null) return;
    final docId =
        _selectedDocIds.length == 1 ? _selectedDocIds.first : null;
    await ref
        .read(chatProvider((sid, 'mindmap')).notifier)
        .generateMindMap(docId: docId);
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _MindMapBody extends ConsumerStatefulWidget {
  final int subjectId;
  final Set<int> selectedDocIds;
  final bool generating;
  final void Function(int id, bool selected) onDocSelectionChanged;
  final VoidCallback onGenerate;

  const _MindMapBody({
    required this.subjectId,
    required this.selectedDocIds,
    required this.generating,
    required this.onDocSelectionChanged,
    required this.onGenerate,
  });

  @override
  ConsumerState<_MindMapBody> createState() => _MindMapBodyState();
}

class _MindMapBodyState extends ConsumerState<_MindMapBody> {
  String? _lastContent;
  String? _currentHtml;
  bool _customGenerating = false;

  String _buildHtml(String markdown) {
    final escaped = jsonEncode(markdown);
    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { background: #fff; overflow: hidden; }
  #mindmap { width: 100vw; height: 100vh; }
</style>
</head>
<body>
<svg id="mindmap"></svg>
<script src="https://cdn.jsdelivr.net/npm/d3@7"></script>
<script src="https://cdn.jsdelivr.net/npm/markmap-view@0.17"></script>
<script src="https://cdn.jsdelivr.net/npm/markmap-lib@0.17"></script>
<script>
(async () => {
  const md = $escaped;
  const { Transformer } = window.markmap;
  const transformer = new Transformer();
  const { root } = transformer.transform(md);
  const { Markmap } = window.markmap;
  const mm = Markmap.create('#mindmap', {
    duration: 300,
    maxWidth: 300,
    color: (node) => {
      const colors = ['#4f8ef7','#f7874f','#4fc97f','#c94f8e','#8e4fc9'];
      return colors[node.depth % colors.length];
    },
  }, root);
  mm.fit();
})();
</script>
</body>
</html>''';
  }

  void _showCustomMindMapSheet(BuildContext context) {
    final topicCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('自建思维导图', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text('输入主题或一段文字，AI 自动生成结构化导图',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: topicCtrl,
                maxLines: 5,
                minLines: 2,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '例如：牛顿三大定律\n或粘贴一段笔记内容…',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _customGenerating
                    ? null
                    : () async {
                        final topic = topicCtrl.text.trim();
                        if (topic.isEmpty) return;
                        Navigator.pop(ctx);
                        setState(() {
                          _customGenerating = true;
                          _currentHtml = null;
                          _lastContent = null;
                        });
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final service = ref.read(chatServiceProvider);
                          final subjectId =
                              ref.read(currentSubjectProvider)?.id;
                          final content =
                              await service.generateCustomMindMap(topic,
                                  subjectId: subjectId);
                          if (mounted) {
                            setState(() {
                              _currentHtml = _buildHtml(content);
                              _lastContent = content;
                            });
                          }
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                                content: Text('生成失败：$e'),
                                backgroundColor: Colors.red),
                          );
                        } finally {
                          if (mounted) {
                            setState(() => _customGenerating = false);
                          }
                        }
                      },
                icon: _customGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome),
                label: Text(_customGenerating ? '生成中…' : '生成'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDocPicker(List<StudyDocument> docs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                        child: Text('选择资料范围',
                            style: Theme.of(ctx).textTheme.titleMedium)),
                    TextButton(
                      onPressed: () {
                        for (final d in docs) {
                          if (!widget.selectedDocIds.contains(d.id)) {
                            widget.onDocSelectionChanged(d.id, true);
                          }
                        }
                        setModalState(() {});
                      },
                      child: const Text('全选'),
                    ),
                    TextButton(
                      onPressed: () {
                        for (final d in docs) {
                          widget.onDocSelectionChanged(d.id, false);
                        }
                        setModalState(() {});
                      },
                      child: const Text('清空'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final doc = docs[i];
                    final isSelected =
                        widget.selectedDocIds.contains(doc.id);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(doc.filename,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      controlAffinity: ListTileControlAffinity.trailing,
                      onChanged: (v) {
                        widget.onDocSelectionChanged(doc.id, v ?? false);
                        setModalState(() {});
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44)),
                  child: Text(widget.selectedDocIds.isEmpty
                      ? '确定（全部资料）'
                      : '确定（已选 ${widget.selectedDocIds.length} 个）'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider(widget.subjectId));
    final chatState =
        ref.watch(chatProvider((widget.subjectId, 'mindmap')));

    final content = chatState.maybeWhen(
      data: (msgs) =>
          msgs.isNotEmpty && !msgs.last.isUser ? msgs.last.content : null,
      orElse: () => null,
    );

    // 当 provider 内容变化时更新 HTML
    if (content != null && content != _lastContent) {
      _lastContent = content;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentHtml = _buildHtml(content));
      });
    }

    final isLoading = widget.generating || _customGenerating;

    return Column(
      children: [
        // 资料选择栏
        docsAsync.when(
          loading: () =>
              const SizedBox(height: 4, child: LinearProgressIndicator()),
          error: (_, _) => const SizedBox.shrink(),
          data: (docs) {
            final completed = docs
                .where((d) => d.status == DocumentStatus.completed)
                .toList();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: completed.isEmpty
                    ? null
                    : () => _showDocPicker(completed),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_outlined,
                          size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          completed.isEmpty
                              ? '暂无已完成的资料'
                              : widget.selectedDocIds.isEmpty
                                  ? '全部资料'
                                  : '已选 ${widget.selectedDocIds.length} 个资料',
                          style: TextStyle(
                            fontSize: 14,
                            color: completed.isEmpty
                                ? Theme.of(context).colorScheme.outline
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down,
                          color: Theme.of(context).colorScheme.outline),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // 导图内容区
        Expanded(
          child: isLoading && _currentHtml == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        '正在生成思维导图…',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.outline),
                      ),
                    ],
                  ),
                )
              : _currentHtml == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.account_tree_outlined,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant),
                          const SizedBox(height: 12),
                          const Text('点击下方按钮生成思维导图',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : buildMindMapView(_currentHtml!),
        ),

        // 底部操作栏
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Row(
            children: [
              if (_currentHtml != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        saveMindMapImage(context, null),
                    icon: const Icon(Icons.save_alt, size: 16),
                    label: const Text('保存图片'),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              OutlinedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => _showCustomMindMapSheet(context),
                icon: const Icon(Icons.edit_note, size: 16),
                label: const Text('自建'),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: isLoading
                      ? null
                      : () {
                          setState(() {
                            _currentHtml = null;
                            _lastContent = null;
                          });
                          widget.onGenerate();
                        },
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome),
                  label: Text(isLoading
                      ? '生成中…'
                      : (_currentHtml != null ? '重新生成' : '生成思维导图')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
