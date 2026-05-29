import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_router.dart';
import 'mini_app_models.dart';
import 'mini_app_providers.dart';

class WorkshopBuilderPage extends ConsumerStatefulWidget {
  final String? initialRequest;

  const WorkshopBuilderPage({super.key, this.initialRequest});

  @override
  ConsumerState<WorkshopBuilderPage> createState() =>
      _WorkshopBuilderPageState();
}

class _WorkshopBuilderPageState extends ConsumerState<WorkshopBuilderPage> {
  late final TextEditingController _requestController;
  final _answerController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_Bubble> _bubbles = [];
  MiniAppInterviewTurn? _turn;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _requestController = TextEditingController(
      text: widget.initialRequest?.trim().isNotEmpty == true
          ? widget.initialRequest!.trim()
          : '我想做一个高一英语百词斩式背单词小程序',
    );
  }

  @override
  void dispose() {
    _requestController.dispose();
    _answerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final text = _requestController.text.trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _turn = null;
      _bubbles
        ..clear()
        ..add(_Bubble.user(text));
    });

    try {
      final turn = await ref
          .read(miniAppServiceProvider)
          .startInterview(initialRequest: text);
      setState(() {
        _turn = turn;
        if (turn.question != null) {
          _bubbles.add(_Bubble.assistant(turn.question!));
        }
      });
      _jumpToBottom();
    } catch (error) {
      _showError('启动访谈失败：$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _answer() async {
    final current = _turn;
    final text = _answerController.text.trim();
    if (current == null || text.isEmpty || _loading) return;
    _answerController.clear();
    setState(() {
      _loading = true;
      _bubbles.add(_Bubble.user(text));
    });

    try {
      final next = await ref
          .read(miniAppServiceProvider)
          .answerInterview(sessionId: current.sessionId, answer: text);
      ref.invalidate(miniAppsProvider);
      setState(() {
        _turn = next;
        if (next.question != null) {
          _bubbles.add(_Bubble.assistant(next.question!));
        } else if (next.draft != null) {
          _bubbles.add(
            _Bubble.assistant(
              '已生成一套可校验的学习小软件草稿：包含方法模板、内容包、积木图谱和发布检查文档。你可以先看文档，也可以直接运行试用。',
            ),
          );
        }
      });
      _jumpToBottom();
    } catch (error) {
      _showError('提交回答失败：$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final draft = _turn?.draft;
    final isCollecting = _turn != null && !_turn!.isReady;

    return Scaffold(
      appBar: AppBar(title: const Text('创建学习小软件'), centerTitle: false),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 980;
          return Row(
            children: [
              Expanded(
                flex: isWide ? 5 : 1,
                child: Column(
                  children: [
                    if (_turn == null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _RequestCard(
                          controller: _requestController,
                          loading: _loading,
                          onStart: _start,
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        itemCount: _bubbles.length + (_loading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _bubbles.length) {
                            return const _TypingBubble();
                          }
                          return _ChatBubble(bubble: _bubbles[index]);
                        },
                      ),
                    ),
                    if (isCollecting)
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _answerController,
                                  minLines: 1,
                                  maxLines: 4,
                                  textInputAction: TextInputAction.send,
                                  decoration: const InputDecoration(
                                    hintText: '回答助教的问题',
                                    border: OutlineInputBorder(),
                                  ),
                                  onSubmitted: (_) => _answer(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.icon(
                                onPressed: _loading ? null : _answer,
                                icon: const Icon(Icons.send_rounded),
                                label: const Text('发送'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (isWide) VerticalDivider(width: 1, color: cs.outlineVariant),
              if (isWide)
                SizedBox(width: 430, child: _DraftSidePanel(draft: draft)),
            ],
          );
        },
      ),
      bottomNavigationBar: draft == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.go(R.workshop),
                        icon: const Icon(Icons.apps_rounded),
                        label: const Text('回到工坊'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.push(R.workshopApp(draft.id)),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('运行试用'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onStart;

  const _RequestCard({
    required this.controller,
    required this.loading,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '先说需求，助教会追问并生成标准文档',
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '文档会反向驱动后端的隐形积木画布，学生不用写代码，也不会把不兼容的模块硬拼在一起。',
            style: TextStyle(color: cs.onPrimaryContainer, height: 1.45),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              filled: true,
              labelText: '你想做什么学习小软件？',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: loading ? null : onStart,
            icon: const Icon(Icons.forum_rounded),
            label: const Text('开始访谈'),
          ),
        ],
      ),
    );
  }
}

class _DraftSidePanel extends StatelessWidget {
  final MiniAppRecord? draft;

  const _DraftSidePanel({required this.draft});

  @override
  Widget build(BuildContext context) {
    if (draft == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '完成几轮访谈后，这里会出现需求说明、教学模板、内容包、积木装配和发布检查文档。',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return _DocumentPreview(app: draft!);
  }
}

class _DocumentPreview extends StatelessWidget {
  final MiniAppRecord app;

  const _DocumentPreview({required this.app});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          app.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Pill(label: app.status),
            _Pill(label: app.validation.ok ? '校验通过' : '需要修改'),
          ],
        ),
        if (app.validation.errors.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final error in app.validation.errors)
            Text('错误：$error', style: TextStyle(color: cs.error)),
        ],
        if (app.validation.warnings.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final warning in app.validation.warnings)
            Text('提示：$warning', style: TextStyle(color: cs.tertiary)),
        ],
        const SizedBox(height: 14),
        for (final entry in app.documents.entries)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            initiallyExpanded:
                entry.key.contains('method') ||
                entry.key.contains('requirements'),
            title: Text(
              _documentTitle(entry.key),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  entry.value,
                  style: const TextStyle(height: 1.45),
                ),
              ),
            ],
          ),
      ],
    );
  }

  String _documentTitle(String key) {
    const titles = {
      'requirements.md': '需求说明',
      'learning_method_template.md': '教学方法模板',
      'content_pack.md': '内容包',
      'module_catalog.md': '模块清单',
      'graph.md': '积木装配图',
      'release_quality_checklist.md': '发布检查',
    };
    return titles[key] ?? key;
  }
}

class _Bubble {
  final bool isUser;
  final String text;

  const _Bubble(this.isUser, this.text);

  factory _Bubble.user(String text) => _Bubble(true, text);
  factory _Bubble.assistant(String text) => _Bubble(false, text);
}

class _ChatBubble extends StatelessWidget {
  final _Bubble bubble;

  const _ChatBubble({required this.bubble});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: bubble.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: bubble.isUser ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          bubble.text,
          style: TextStyle(
            color: bubble.isUser ? cs.onPrimary : cs.onSurface,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}
