import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mini_app_models.dart';
import 'mini_app_providers.dart';

class MiniAppRunPage extends ConsumerStatefulWidget {
  final String appId;

  const MiniAppRunPage({super.key, required this.appId});

  @override
  ConsumerState<MiniAppRunPage> createState() => _MiniAppRunPageState();
}

class _MiniAppRunPageState extends ConsumerState<MiniAppRunPage> {
  int _index = 0;
  int _known = 0;
  int _unknown = 0;
  bool _showAnswer = false;
  bool _saving = false;
  bool _generating = false;
  bool _startingRun = false;
  String? _runId;

  void _mark(bool known, int total, Map<String, dynamic> item) {
    setState(() {
      if (known) {
        _known += 1;
      } else {
        _unknown += 1;
      }
      _showAnswer = false;
      if (_index < total) _index += 1;
    });
    _appendPracticeEvent(known: known, item: item, completed: _index >= total);
  }

  @override
  Widget build(BuildContext context) {
    final appAsync = ref.watch(miniAppProvider(widget.appId));
    return Scaffold(
      appBar: AppBar(title: const Text('运行学习小软件'), centerTitle: false),
      body: appAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败：$error')),
        data: (app) => _buildApp(context, app),
      ),
    );
  }

  Widget _buildApp(BuildContext context, MiniAppRecord app) {
    final cs = Theme.of(context).colorScheme;
    final blockRegistry = ref.watch(miniAppBlockRegistryProvider).valueOrNull;
    _ensureRun(app.id);
    final content =
        (app.spec['content'] as Map?)?.cast<String, dynamic>() ?? {};
    final rawItems = (content['items'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    final total = items.length;

    if (total == 0) {
      return _EmptyContentView(
        app: app,
        generating: _generating,
        onGenerate: _canGenerateFromDocuments(app)
            ? () => _generateFromDocuments(app)
            : null,
      );
    }

    final completed = _index >= total;
    final progress = completed ? 1.0 : (_index / total).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    completed ? '本轮已完成' : '第 ${_index + 1} / $total 项',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  if (app.currentVersionId != null) ...[
                    const SizedBox(height: 8),
                    _ScoreChip(label: '版本 ${app.currentVersionId}'),
                  ],
                ],
              ),
            ),
            _ScoreChip(label: '已会 $_known'),
            const SizedBox(width: 8),
            _ScoreChip(label: '待复习 $_unknown'),
          ],
        ),
        const SizedBox(height: 14),
        LinearProgressIndicator(value: progress),
        const SizedBox(height: 24),
        if (completed)
          _SummaryCard(total: total, known: _known, unknown: _unknown)
        else
          _PracticeCard(
            item: items[_index],
            showAnswer: _showAnswer,
            onReveal: () => setState(() => _showAnswer = true),
            onKnown: () => _mark(true, total, items[_index]),
            onUnknown: () => _mark(false, total, items[_index]),
          ),
        const SizedBox(height: 22),
        _DocumentEditorCard(
          app: app,
          blockRegistry: blockRegistry,
          saving: _saving,
          onSaveSpec: (text) => _saveSpec(app, text),
          onSaveDocument: (name, text) => _saveDocument(app, name, text),
          onRevise: (instruction) => _reviseWithAssistant(app, instruction),
        ),
      ],
    );
  }

  void _ensureRun(String appId) {
    if (_runId != null || _startingRun) return;
    _startingRun = true;
    Future.microtask(() async {
      try {
        final run = await ref.read(miniAppServiceProvider).startRun(appId);
        if (!mounted) return;
        setState(() {
          _runId = run['run_id'] as String?;
          _startingRun = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _startingRun = false);
      }
    });
  }

  Future<void> _appendPracticeEvent({
    required bool known,
    required Map<String, dynamic> item,
    required bool completed,
  }) async {
    final runId = _runId;
    if (runId == null) return;
    try {
      await ref
          .read(miniAppServiceProvider)
          .appendRunEvent(
            runId: runId,
            nodeId: 'practice',
            eventType: known ? 'answer_known' : 'answer_unknown',
            payload: {
              'item_id': item['id'],
              'front': item['front'],
              'known_count': _known,
              'review_count': _unknown,
            },
          );
      if (completed) {
        await ref
            .read(miniAppServiceProvider)
            .appendRunEvent(
              runId: runId,
              nodeId: 'summary',
              eventType: 'session_completed',
              payload: {'known_count': _known, 'review_count': _unknown},
            );
      }
    } catch (_) {
      // Event logging should not block local practice.
    }
  }

  Future<void> _saveSpec(MiniAppRecord app, String text) async {
    late final Map<String, dynamic> spec;
    try {
      final parsed = jsonDecode(text);
      if (parsed is! Map) {
        throw const FormatException('运行配置必须是 JSON 对象');
      }
      spec = parsed.cast<String, dynamic>();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('JSON 解析失败：$error')));
      return;
    }

    setState(() => _saving = true);
    try {
      final docs = Map<String, String>.from(app.documents)
        ..['runtime_config.json'] = const JsonEncoder.withIndent(
          '  ',
        ).convert(spec);
      final updated = await ref
          .read(miniAppServiceProvider)
          .updateApp(id: app.id, spec: spec, documents: docs);
      ref.invalidate(miniAppProvider(app.id));
      ref.invalidate(miniAppsProvider);
      _resetRunState();
      if (!mounted) return;
      final message = updated.validation.ok
          ? '已保存，校验通过'
          : '已保存，但还有 ${updated.validation.errors.length} 个校验问题';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveDocument(
    MiniAppRecord app,
    String name,
    String text,
  ) async {
    setState(() => _saving = true);
    try {
      final docs = Map<String, String>.from(app.documents)..[name] = text;
      final updated = await ref
          .read(miniAppServiceProvider)
          .updateApp(id: app.id, documents: docs);
      ref.invalidate(miniAppProvider(app.id));
      ref.invalidate(miniAppsProvider);
      if (!mounted) return;
      final message = updated.validation.ok
          ? '文档已保存'
          : '文档已保存；运行配置仍有 ${updated.validation.errors.length} 个问题';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('文档保存失败：$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reviseWithAssistant(
    MiniAppRecord app,
    String instruction,
  ) async {
    final text = instruction.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      final updated = await ref
          .read(miniAppServiceProvider)
          .reviseApp(id: app.id, instruction: text);
      ref.invalidate(miniAppProvider(app.id));
      ref.invalidate(miniAppsProvider);
      _resetRunState();
      if (!mounted) return;
      final message = updated.validation.ok
          ? '助教已修订文档，校验通过'
          : '助教已修订文档，但仍有 ${updated.validation.errors.length} 个问题';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('修订失败：$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetRunState() {
    setState(() {
      _index = 0;
      _known = 0;
      _unknown = 0;
      _showAnswer = false;
    });
  }

  bool _canGenerateFromDocuments(MiniAppRecord app) {
    final content =
        (app.spec['content'] as Map?)?.cast<String, dynamic>() ?? {};
    final sourceType = content['source_type']?.toString();
    if (sourceType == 'document') return _resolveSubjectId(app) != null;
    final pipeline = content['pipeline'];
    if (pipeline is List &&
        pipeline.map((e) => e.toString()).contains('document_source_loader')) {
      return _resolveSubjectId(app) != null;
    }
    return _resolveSubjectId(app) != null;
  }

  int? _resolveSubjectId(MiniAppRecord app) {
    final content =
        (app.spec['content'] as Map?)?.cast<String, dynamic>() ?? {};
    final source = content['source'];
    if (source is Map && source['subject_id'] != null) {
      return (source['subject_id'] as num).toInt();
    }
    return app.subjectId;
  }

  Future<void> _generateFromDocuments(MiniAppRecord app) async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final result = await ref
          .read(miniAppServiceProvider)
          .generateCardsForApp(appId: app.id);
      ref.invalidate(miniAppProvider(app.id));
      ref.invalidate(miniAppsProvider);
      _resetRunState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已从资料生成 ${result.actualCardCount} 张闪卡'
            '${result.targetCardCount > 0 ? '（预估 ${result.targetCardCount} 张）' : ''}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('生成失败：$error')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }
}

class _EmptyContentView extends StatelessWidget {
  final MiniAppRecord app;
  final bool generating;
  final VoidCallback? onGenerate;

  const _EmptyContentView({
    required this.app,
    required this.generating,
    this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content =
        (app.spec['content'] as Map?)?.cast<String, dynamic>() ?? {};
    final pipeline = (content['pipeline'] as List?) ?? const [];
    final usesDocument =
        content['source_type'] == 'document' ||
        pipeline.map((e) => e.toString()).contains('document_source_loader');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style_outlined, size: 56, color: cs.primary),
            const SizedBox(height: 16),
            Text(
              usesDocument ? '尚未从资料生成闪卡' : '还没有学习内容',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              usesDocument
                  ? '将走资料导入 → 切块后处理 → 智能出题 三条积木管线。\n'
                        '卡片数量会根据资料篇幅与章节自动估算，不是固定张数。'
                  : '请手动添加学习内容，或绑定学科资料后生成闪卡。',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
            ),
            if (onGenerate != null) ...[
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: generating ? null : onGenerate,
                icon: generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(generating ? '正在生成…' : '从资料生成闪卡'),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                '请先在配置中绑定学科（subject_id），并确保资料库有已解析文档。',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool showAnswer;
  final VoidCallback onReveal;
  final VoidCallback onKnown;
  final VoidCallback onUnknown;

  const _PracticeCard({
    required this.item,
    required this.showAnswer,
    required this.onReveal,
    required this.onKnown,
    required this.onUnknown,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final front = item['front']?.toString() ?? '';
    final back = item['back']?.toString() ?? '';
    return Container(
      constraints: const BoxConstraints(minHeight: 320),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '学习卡片',
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Text(
            front,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: showAnswer
                ? Container(
                    key: const ValueKey('answer'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      back,
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontSize: 16,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : Align(
                    key: const ValueKey('hidden'),
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: onReveal,
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('显示答案'),
                    ),
                  ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onUnknown,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('待复习'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onKnown,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('已掌握'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int total;
  final int known;
  final int unknown;

  const _SummaryCard({
    required this.total,
    required this.known,
    required this.unknown,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accuracy = total == 0 ? 0 : (known / total * 100).round();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '完成',
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '共 $total 项，已掌握 $known 项，待复习 $unknown 项，掌握率 $accuracy%。',
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontSize: 16,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentEditorCard extends StatelessWidget {
  final MiniAppRecord app;
  final Map<String, dynamic>? blockRegistry;
  final bool saving;
  final ValueChanged<String> onSaveSpec;
  final void Function(String name, String text) onSaveDocument;
  final ValueChanged<String> onRevise;

  const _DocumentEditorCard({
    required this.app,
    required this.blockRegistry,
    required this.saving,
    required this.onSaveSpec,
    required this.onSaveDocument,
    required this.onRevise,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final docs = _docsWithSpec(app, blockRegistry);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '文档包',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              if (saving)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (!saving)
                TextButton.icon(
                  onPressed: () => _showReviseDialog(context),
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                  label: const Text('让助教修订'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Markdown 文档描述产品和教学设计；JSON 运行配置是可执行的，会驱动这个学习小软件。',
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: 10),
          if (!app.validation.ok) ...[
            for (final error in app.validation.errors)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('问题：$error', style: TextStyle(color: cs.error)),
              ),
          ],
          if (app.validation.warnings.isNotEmpty) ...[
            for (final warning in app.validation.warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '提示：$warning',
                  style: TextStyle(color: cs.tertiary),
                ),
              ),
          ],
          const SizedBox(height: 8),
          for (final entry in docs.entries)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                entry.key,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              trailing: _isRuntimeConfig(entry.key)
                  ? TextButton.icon(
                      onPressed: saving
                          ? null
                          : () => _showSpecEditor(context, entry.value),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('编辑'),
                    )
                  : entry.key.endsWith('.json')
                  ? const Icon(Icons.lock_outline_rounded, size: 18)
                  : TextButton.icon(
                      onPressed: saving
                          ? null
                          : () => _showDocumentEditor(
                              context,
                              entry.key,
                              entry.value,
                            ),
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('编辑'),
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
                    style: TextStyle(
                      fontFamily: entry.key.endsWith('.json')
                          ? 'monospace'
                          : null,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  bool _isRuntimeConfig(String name) {
    final normalized = name.toLowerCase();
    return normalized == 'runtime_config.json' || name.contains('配置');
  }

  Map<String, String> _docsWithSpec(
    MiniAppRecord app,
    Map<String, dynamic>? blockRegistry,
  ) {
    final docs = Map<String, String>.from(app.documents);
    docs.putIfAbsent(
      'runtime_config.json',
      () => const JsonEncoder.withIndent('  ').convert(app.spec),
    );
    docs.putIfAbsent(
      'invisible_canvas.json',
      () => const JsonEncoder.withIndent('  ').convert(app.graph),
    );
    if (blockRegistry != null) {
      docs.putIfAbsent(
        'block_registry.json',
        () => const JsonEncoder.withIndent('  ').convert(blockRegistry),
      );
    }
    docs.putIfAbsent('canvas_summary.md', () => _canvasSummary(app.graph));
    return docs;
  }

  String _canvasSummary(Map<String, dynamic> graph) {
    final nodes = ((graph['nodes'] as List?) ?? const [])
        .whereType<Map>()
        .map((node) => node.cast<String, dynamic>())
        .toList();
    final edges = ((graph['edges'] as List?) ?? const [])
        .whereType<Map>()
        .map((edge) => edge.cast<String, dynamic>())
        .toList();
    final lines = <String>[
      '# 隐形画布摘要',
      '',
      '入口：${graph['entry'] ?? 'unknown'}',
      '',
      '## 积木',
      for (final node in nodes)
        '- ${node['id'] ?? 'node'}: ${node['block'] ?? 'unknown'}',
      '',
      '## 连接',
      for (final edge in edges)
        '- ${edge['from']}.${edge['output']} -> ${edge['to']}.${edge['input']}'
            '${edge['when'] == null ? '' : ' when ${edge['when']}'}'
            '${edge['adapter'] == null ? '' : ' via ${edge['adapter']}'}',
    ];
    return lines.join('\n');
  }

  Future<void> _showSpecEditor(BuildContext context, String initialText) async {
    final controller = TextEditingController(text: initialText);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('编辑 runtime_config.json'),
          content: SizedBox(
            width: 760,
            child: TextField(
              controller: controller,
              maxLines: 24,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                helperText: '保存后会重新校验运行配置，并重置当前练习进度。',
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(controller.text),
              icon: const Icon(Icons.save_rounded),
              label: const Text('保存并校验'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result != null) onSaveSpec(result);
  }

  Future<void> _showDocumentEditor(
    BuildContext context,
    String name,
    String initialText,
  ) async {
    final controller = TextEditingController(text: initialText);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('编辑 $name'),
          content: SizedBox(
            width: 760,
            child: TextField(
              controller: controller,
              maxLines: 24,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                helperText: 'Markdown 会作为设计文档保存，不会直接改动 runtime_config.json。',
              ),
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(controller.text),
              icon: const Icon(Icons.save_rounded),
              label: const Text('保存文档'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result != null) onSaveDocument(name, result);
  }

  Future<void> _showReviseDialog(BuildContext context) async {
    final controller = TextEditingController(
      text: '每日新内容改成 10 个，复习上限 30 个，使用 SM2 复习算法',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('让助教修订文档'),
          content: SizedBox(
            width: 560,
            child: TextField(
              controller: controller,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                helperText: '可以调整每日数量、SM2/固定复习、掌握阈值，也可以追加“问题：答案”格式的卡片。',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(controller.text),
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: const Text('修订并校验'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result != null) onRevise(result);
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;

  const _ScoreChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}
