import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mini_app_models.dart';
import 'mini_app_providers.dart';

class WorkshopBlocksPage extends ConsumerStatefulWidget {
  const WorkshopBlocksPage({super.key});

  @override
  ConsumerState<WorkshopBlocksPage> createState() => _WorkshopBlocksPageState();
}

class _WorkshopBlocksPageState extends ConsumerState<WorkshopBlocksPage> {
  String? _categoryId;
  String? _blockId;
  Map<String, dynamic>? _workflow;
  int? _editingIndex;
  bool _validating = false;
  WorkshopWorkflowValidationResult? _validationResult;

  @override
  Widget build(BuildContext context) {
    final registryAsync = ref.watch(workshopWorkflowRegistryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('积木脚本工坊'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(workshopWorkflowRegistryProvider);
              ref.invalidate(workshopResourceActorTypesProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新积木清单',
          ),
        ],
      ),
      body: registryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: '积木清单加载失败：$error',
          onRetry: () => ref.invalidate(workshopWorkflowRegistryProvider),
        ),
        data: _buildRegistry,
      ),
    );
  }

  Widget _buildRegistry(WorkshopWorkflowRegistry registry) {
    final workflow = _currentWorkflow(registry);
    final categories = registry.categories;
    final activeCategory = _categoryId ?? categories.firstOrNull?.id ?? '';
    final categoryBlocks = registry.blocksForCategory(activeCategory);
    final selectedBlock = _resolveSelectedBlock(registry, categoryBlocks);
    final selectedBodyBlock = _bodyBlockAt(workflow, _editingIndex);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1080;
        if (!isWide) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              _BlockLibraryPanel(
                registry: registry,
                activeCategory: activeCategory,
                selectedBlockId: selectedBlock?.id,
                onCategorySelected: _selectCategory,
                onBlockSelected: (block) => setState(() => _blockId = block.id),
                onAddBlock: (block) => _addBlockToWorkflow(registry, block),
              ),
              const SizedBox(height: 14),
              _WorkflowScriptPanel(
                registry: registry,
                workflow: workflow,
                editingIndex: _editingIndex,
                onEditBodyBlock: _selectBodyBlock,
                onRemoveBodyBlock: (index) => _removeBodyBlock(registry, index),
                onMoveBodyBlock: (from, to) =>
                    _moveBodyBlock(registry, from, to),
              ),
              const SizedBox(height: 14),
              _InspectorPanel(
                registry: registry,
                selectedBlock: selectedBlock,
                selectedBodyBlock: selectedBodyBlock,
                selectedBodyIndex: _editingIndex,
                validationResult: _validationResult,
                validating: _validating,
                onAddBlock: selectedBlock == null
                    ? null
                    : () => _addBlockToWorkflow(registry, selectedBlock),
                onApplyBlockJson: _applyBodyBlockJson,
                onValidate: () => _validateCurrentWorkflow(workflow),
                onCopy: () => _copyCurrentWorkflow(workflow),
                onReset: () => _resetWorkflow(registry),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 320,
              child: _BlockLibraryPanel(
                registry: registry,
                activeCategory: activeCategory,
                selectedBlockId: selectedBlock?.id,
                onCategorySelected: _selectCategory,
                onBlockSelected: (block) => setState(() => _blockId = block.id),
                onAddBlock: (block) => _addBlockToWorkflow(registry, block),
              ),
            ),
            VerticalDivider(
              width: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(
              child: _WorkflowScriptPanel(
                registry: registry,
                workflow: workflow,
                editingIndex: _editingIndex,
                onEditBodyBlock: _selectBodyBlock,
                onRemoveBodyBlock: (index) => _removeBodyBlock(registry, index),
                onMoveBodyBlock: (from, to) =>
                    _moveBodyBlock(registry, from, to),
              ),
            ),
            VerticalDivider(
              width: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            SizedBox(
              width: 380,
              child: _InspectorPanel(
                registry: registry,
                selectedBlock: selectedBlock,
                selectedBodyBlock: selectedBodyBlock,
                selectedBodyIndex: _editingIndex,
                validationResult: _validationResult,
                validating: _validating,
                onAddBlock: selectedBlock == null
                    ? null
                    : () => _addBlockToWorkflow(registry, selectedBlock),
                onApplyBlockJson: _applyBodyBlockJson,
                onValidate: () => _validateCurrentWorkflow(workflow),
                onCopy: () => _copyCurrentWorkflow(workflow),
                onReset: () => _resetWorkflow(registry),
              ),
            ),
          ],
        );
      },
    );
  }

  WorkshopBlockDefinition? _resolveSelectedBlock(
    WorkshopWorkflowRegistry registry,
    List<WorkshopBlockDefinition> categoryBlocks,
  ) {
    final selectedId = _blockId;
    if (selectedId != null) {
      final match = registry.blocks.where((block) => block.id == selectedId);
      if (match.isNotEmpty) return match.first;
    }
    return categoryBlocks.firstOrNull ?? registry.blocks.firstOrNull;
  }

  void _selectCategory(String categoryId) {
    setState(() {
      _categoryId = categoryId;
      final registry = ref.read(workshopWorkflowRegistryProvider).valueOrNull;
      _blockId = registry?.blocksForCategory(categoryId).firstOrNull?.id;
    });
  }

  void _selectBodyBlock(int index) {
    setState(() => _editingIndex = index);
  }

  void _addBlockToWorkflow(
    WorkshopWorkflowRegistry registry,
    WorkshopBlockDefinition block,
  ) {
    if (!_canAddToScript(block)) {
      _showSnack('帽子积木只能作为脚本开头，不能加入脚本体');
      return;
    }
    setState(() {
      final workflow = _currentWorkflow(registry);
      final body = _firstScriptBody(workflow, registry);
      body.add(_createBlockInstance(block, workflow));
      _editingIndex = body.length - 1;
      _blockId = block.id;
      _validationResult = null;
    });
  }

  void _removeBodyBlock(WorkshopWorkflowRegistry registry, int index) {
    setState(() {
      final body = _firstScriptBody(_currentWorkflow(registry), registry);
      if (index < 0 || index >= body.length) return;
      body.removeAt(index);
      if (body.isEmpty) {
        _editingIndex = null;
      } else {
        _editingIndex = index.clamp(0, body.length - 1);
      }
      _validationResult = null;
    });
  }

  void _moveBodyBlock(WorkshopWorkflowRegistry registry, int from, int to) {
    setState(() {
      final body = _firstScriptBody(_currentWorkflow(registry), registry);
      if (from < 0 || from >= body.length || to < 0 || to >= body.length) {
        return;
      }
      final block = body.removeAt(from);
      body.insert(to, block);
      _editingIndex = to;
      _validationResult = null;
    });
  }

  void _applyBodyBlockJson(int index, String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map) {
        _showSnack('积木 JSON 必须是对象');
        return;
      }
      final block = decoded.cast<String, dynamic>();
      if ((block['block']?.toString() ?? '').isEmpty) {
        _showSnack('积木 JSON 必须包含 block 字段');
        return;
      }
      setState(() {
        final registry = ref.read(workshopWorkflowRegistryProvider).valueOrNull;
        if (registry == null) return;
        final body = _firstScriptBody(_currentWorkflow(registry), registry);
        if (index < 0 || index >= body.length) return;
        body[index] = block;
        _editingIndex = index;
        _validationResult = null;
      });
      _showSnack('已应用积木 JSON');
    } catch (error) {
      _showSnack('JSON 解析失败：$error');
    }
  }

  Future<void> _validateCurrentWorkflow(Map<String, dynamic> workflow) async {
    if (_validating) return;
    setState(() => _validating = true);
    try {
      final result = await ref
          .read(miniAppServiceProvider)
          .validateWorkflow(workflow: _cloneMap(workflow));
      if (!mounted) return;
      setState(() => _validationResult = result);
    } catch (error) {
      if (!mounted) return;
      _showSnack('校验失败：$error');
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  Future<void> _copyCurrentWorkflow(Map<String, dynamic> workflow) async {
    final text = const JsonEncoder.withIndent('  ').convert(workflow);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _showSnack('已复制当前 workflow JSON');
  }

  void _resetWorkflow(WorkshopWorkflowRegistry registry) {
    setState(() {
      _workflow = _initialWorkflow(registry);
      _editingIndex = null;
      _validationResult = null;
    });
  }

  Map<String, dynamic> _currentWorkflow(WorkshopWorkflowRegistry registry) {
    return _workflow ??= _initialWorkflow(registry);
  }

  Map<String, dynamic> _initialWorkflow(WorkshopWorkflowRegistry registry) {
    final source = registry.exampleWorkflow.isEmpty
        ? <String, dynamic>{}
        : _cloneMap(registry.exampleWorkflow);
    source['schema_version'] ??= registry.runtimeSchemaVersion;
    _firstScriptBody(source, registry);
    return source;
  }

  List<dynamic> _firstScriptBody(
    Map<String, dynamic> workflow,
    WorkshopWorkflowRegistry registry,
  ) {
    final scripts = _scripts(workflow);
    if (scripts.isEmpty) {
      scripts.add({
        'id': 'script_on_start',
        'hat': {'block': _defaultHatBlockId(registry)},
        'body': <dynamic>[],
      });
    }

    final rawScript = scripts.first;
    final script = rawScript is Map<String, dynamic>
        ? rawScript
        : rawScript is Map
        ? rawScript.cast<String, dynamic>()
        : <String, dynamic>{
            'id': 'script_on_start',
            'hat': {'block': _defaultHatBlockId(registry)},
          };
    if (rawScript != script) scripts[0] = script;
    script['id'] ??= 'script_on_start';
    script['hat'] ??= {'block': _defaultHatBlockId(registry)};
    final rawBody = script['body'];
    if (rawBody is List) return rawBody;
    final body = <dynamic>[];
    script['body'] = body;
    return body;
  }

  List<dynamic> _scripts(Map<String, dynamic> workflow) {
    final rawScripts = workflow['scripts'];
    if (rawScripts is List) return rawScripts;
    final scripts = <dynamic>[];
    workflow['scripts'] = scripts;
    return scripts;
  }

  String _defaultHatBlockId(WorkshopWorkflowRegistry registry) {
    return registry.blocks
            .where((block) => block.shape == 'hat')
            .firstOrNull
            ?.id ??
        'event.on_start';
  }

  Map<String, dynamic>? _bodyBlockAt(
    Map<String, dynamic> workflow,
    int? index,
  ) {
    if (index == null) return null;
    final scripts = workflow['scripts'];
    if (scripts is! List || scripts.isEmpty) return null;
    final script = scripts.first;
    if (script is! Map) return null;
    final body = script['body'];
    if (body is! List || index < 0 || index >= body.length) return null;
    final block = body[index];
    if (block is Map<String, dynamic>) return block;
    if (block is Map) return block.cast<String, dynamic>();
    return null;
  }

  Map<String, dynamic> _createBlockInstance(
    WorkshopBlockDefinition block,
    Map<String, dynamic> workflow,
  ) {
    final instance = <String, dynamic>{'block': block.id};
    final params = <String, dynamic>{};

    for (final param in block.params) {
      if (param.slot == 'substack') {
        instance[param.name] = <dynamic>[];
      } else if (param.name == 'condition' ||
          param.slot == 'boolean_expression') {
        instance['condition'] = _defaultBooleanExpression();
      } else {
        params[param.name] = _defaultParamValue(block, param);
      }
    }

    if (params.isNotEmpty) instance['params'] = params;
    final output = _suggestOutputName(block, workflow);
    if (output != null) instance['output'] = output;
    return instance;
  }

  dynamic _defaultParamValue(
    WorkshopBlockDefinition block,
    WorkshopBlockParam param,
  ) {
    if (param.defaultValue != null) return _cloneValue(param.defaultValue);
    return switch (param.slot) {
      'number' => 1,
      'text' => switch (param.name) {
        'variable' => 'result',
        'item_name' => 'item',
        _ => param.name,
      },
      'enum' => param.options.firstOrNull ?? '',
      'reporter_expression' => _defaultReporterValue(param.name),
      'resource_query' => {
        'subject_id': r'$current_subject',
        'resource_types': ['lecture', 'note'],
        'limit': 10,
      },
      'resource_ref' => {
        'type': param.accepts.firstOrNull ?? 'note',
        'id': r'$selected_resource',
      },
      'llm_config' => {
        'model': 'default',
        'temperature': 0.2,
        'must_cite_resources': true,
        'on_failure': 'fallback_to_rule',
      },
      'write_policy' => {
        'target': block.sideEffects.firstOrNull ?? 'workshop.generated_artifact',
        'idempotency_key': '\$run_id:${_safeOutputName(block.id)}',
        'bind_version': true,
      },
      _ => '',
    };
  }

  String _defaultReporterValue(String paramName) {
    return switch (paramName) {
      'materials' => r'$materials',
      'items' => r'$materials',
      'question' => r'$question',
      'answer_event' => r'$answer_event',
      'artifact' => r'$artifact',
      'value' => 'value',
      _ => r'$result',
    };
  }

  Map<String, dynamic> _defaultBooleanExpression() {
    return {
      'block': 'judge.answer_correct',
      'params': {'answer_event': r'$answer_event'},
    };
  }

  String? _suggestOutputName(
    WorkshopBlockDefinition block,
    Map<String, dynamic> workflow,
  ) {
    final base = switch (block.id) {
      'resource.query' => 'materials',
      'content.extract_knowledge_points' => 'knowledge_points',
      'llm.generate_quiz' => 'questions',
      'interaction.show_question' => 'answer_event',
      _ => block.outputs.firstOrNull?.name ??
          (block.returns == null ? null : _safeOutputName(block.returns!)),
    };
    if (base == null || base.isEmpty) return null;
    return _uniqueOutputName(workflow, _safeOutputName(base));
  }

  String _uniqueOutputName(Map<String, dynamic> workflow, String base) {
    final used = <String>{};
    void visit(dynamic item) {
      if (item is Map) {
        final output = item['output']?.toString();
        if (output != null && output.isNotEmpty) used.add(output);
        for (final key in ['body', 'then', 'else']) {
          final children = item[key];
          if (children is List) {
            for (final child in children) {
              visit(child);
            }
          }
        }
      } else if (item is List) {
        for (final child in item) {
          visit(child);
        }
      }
    }

    visit(workflow['scripts']);
    if (!used.contains(base)) return base;
    var index = 2;
    while (used.contains('${base}_$index')) {
      index += 1;
    }
    return '${base}_$index';
  }

  String _safeOutputName(String value) {
    final cleaned = value
        .replaceAll('.', '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_')
        .toLowerCase();
    final trimmed = cleaned.replaceAll(RegExp(r'_+'), '_').trim();
    final withoutEdges = trimmed.replaceAll(RegExp(r'^_|_$'), '');
    if (withoutEdges.isEmpty) return 'value';
    if (RegExp(r'^[0-9]').hasMatch(withoutEdges)) {
      return 'v_$withoutEdges';
    }
    return withoutEdges;
  }

  bool _canAddToScript(WorkshopBlockDefinition block) => block.shape != 'hat';

  Map<String, dynamic> _cloneMap(Map<String, dynamic> value) {
    return (jsonDecode(jsonEncode(value)) as Map).cast<String, dynamic>();
  }

  dynamic _cloneValue(dynamic value) {
    return jsonDecode(jsonEncode(value));
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BlockLibraryPanel extends StatelessWidget {
  final WorkshopWorkflowRegistry registry;
  final String activeCategory;
  final String? selectedBlockId;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<WorkshopBlockDefinition> onBlockSelected;
  final ValueChanged<WorkshopBlockDefinition> onAddBlock;

  const _BlockLibraryPanel({
    required this.registry,
    required this.activeCategory,
    required this.selectedBlockId,
    required this.onCategorySelected,
    required this.onBlockSelected,
    required this.onAddBlock,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final blocks = registry.blocksForCategory(activeCategory);
    return Container(
      color: cs.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _PanelTitle(icon: Icons.category_rounded, title: '积木分类'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: registry.categories.map((category) {
              final selected = category.id == activeCategory;
              return FilterChip(
                selected: selected,
                label: Text(category.name),
                avatar: CircleAvatar(
                  backgroundColor: _colorFromHex(category.color),
                  radius: 7,
                ),
                onSelected: (_) => onCategorySelected(category.id),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Text(
            '积木',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (blocks.isEmpty)
            Text('这个分类还没有积木', style: TextStyle(color: cs.onSurfaceVariant))
          else
            ...blocks.map(
              (block) => _BlockListItem(
                block: block,
                selected: block.id == selectedBlockId,
                onTap: () => onBlockSelected(block),
                onAdd: block.shape == 'hat' ? null : () => onAddBlock(block),
              ),
            ),
        ],
      ),
    );
  }
}

class _BlockListItem extends StatelessWidget {
  final WorkshopBlockDefinition block;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  const _BlockListItem({
    required this.block,
    required this.selected,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? cs.primaryContainer : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        block.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? cs.onPrimaryContainer : cs.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _TinyBadge(label: block.shape),
                          if (block.params.isNotEmpty)
                            _TinyBadge(label: '${block.params.length} 参数'),
                          if (block.sideEffects.isNotEmpty)
                            const _TinyBadge(label: '写回'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  tooltip: onAdd == null ? '帽子积木只能作为脚本开头' : '加入脚本',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkflowScriptPanel extends StatelessWidget {
  final WorkshopWorkflowRegistry registry;
  final Map<String, dynamic> workflow;
  final int? editingIndex;
  final ValueChanged<int> onEditBodyBlock;
  final ValueChanged<int> onRemoveBodyBlock;
  final void Function(int from, int to) onMoveBodyBlock;

  const _WorkflowScriptPanel({
    required this.registry,
    required this.workflow,
    required this.editingIndex,
    required this.onEditBodyBlock,
    required this.onRemoveBodyBlock,
    required this.onMoveBodyBlock,
  });

  @override
  Widget build(BuildContext context) {
    final actors = ((workflow['actors'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    final scripts = ((workflow['scripts'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    final blockById = {for (final block in registry.blocks) block.id: block};

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const _PanelTitle(icon: Icons.account_tree_rounded, title: '当前脚本栈'),
        const SizedBox(height: 6),
        Text(
          '先编辑第一个脚本栈：加入积木、调整顺序、改 JSON 参数，然后用后端 validator 校验。',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        _StageSummary(registry: registry, actors: actors),
        const SizedBox(height: 14),
        if (scripts.isEmpty)
          const _EmptyScriptHint()
        else
          for (final entry in scripts.asMap().entries)
            _ScriptView(
              script: entry.value,
              blockById: blockById,
              editable: entry.key == 0,
              editingIndex: editingIndex,
              onEditBodyBlock: onEditBodyBlock,
              onRemoveBodyBlock: onRemoveBodyBlock,
              onMoveBodyBlock: onMoveBodyBlock,
            ),
      ],
    );
  }
}

class _StageSummary extends StatelessWidget {
  final WorkshopWorkflowRegistry registry;
  final List<Map<String, dynamic>> actors;

  const _StageSummary({required this.registry, required this.actors});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dataset_linked_rounded, color: cs.primary),
              const SizedBox(width: 8),
              const Text('资料角色', style: TextStyle(fontWeight: FontWeight.w900)),
              const Spacer(),
              _TinyBadge(label: '${registry.resourceActorTypes.length} 类型'),
            ],
          ),
          const SizedBox(height: 10),
          if (actors.isEmpty)
            Text(
              '当前 workflow 没有绑定资料角色',
              style: TextStyle(color: cs.onSurfaceVariant),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actors.map((actor) {
                return Chip(
                  avatar: const Icon(Icons.layers_rounded, size: 16),
                  label: Text(
                    '${actor['name'] ?? actor['id']} · ${actor['type']}',
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _ScriptView extends StatelessWidget {
  final Map<String, dynamic> script;
  final Map<String, WorkshopBlockDefinition> blockById;
  final bool editable;
  final int? editingIndex;
  final ValueChanged<int> onEditBodyBlock;
  final ValueChanged<int> onRemoveBodyBlock;
  final void Function(int from, int to) onMoveBodyBlock;

  const _ScriptView({
    required this.script,
    required this.blockById,
    required this.editable,
    required this.editingIndex,
    required this.onEditBodyBlock,
    required this.onRemoveBodyBlock,
    required this.onMoveBodyBlock,
  });

  @override
  Widget build(BuildContext context) {
    final hat = (script['hat'] as Map?)?.cast<String, dynamic>() ?? const {};
    final body = ((script['body'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BlockNode(
          block: hat,
          blockById: blockById,
          fallbackLabel: script['id']?.toString() ?? 'script',
          depth: 0,
          selected: false,
        ),
        if (body.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 18, bottom: 10),
            child: Text('脚本体还是空的，先从左侧加入一个积木。'),
          )
        else
          for (final entry in body.asMap().entries)
            _BlockNode(
              block: entry.value,
              blockById: blockById,
              depth: 1,
              selected: editable && entry.key == editingIndex,
              onEdit: editable ? () => onEditBodyBlock(entry.key) : null,
              onRemove: editable ? () => onRemoveBodyBlock(entry.key) : null,
              onMoveUp: editable && entry.key > 0
                  ? () => onMoveBodyBlock(entry.key, entry.key - 1)
                  : null,
              onMoveDown: editable && entry.key < body.length - 1
                  ? () => onMoveBodyBlock(entry.key, entry.key + 1)
                  : null,
            ),
      ],
    );
  }
}

class _BlockNode extends StatelessWidget {
  final Map<String, dynamic> block;
  final Map<String, WorkshopBlockDefinition> blockById;
  final String? fallbackLabel;
  final int depth;
  final bool selected;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _BlockNode({
    required this.block,
    required this.blockById,
    required this.depth,
    required this.selected,
    this.fallbackLabel,
    this.onEdit,
    this.onRemove,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final blockId = block['block']?.toString() ?? '';
    final definition = blockById[blockId];
    final children = _childrenOf(block);
    final output = block['output']?.toString();
    final params = (block['params'] as Map?)?.cast<String, dynamic>() ?? const {};
    final color = _shapeColor(definition?.shape);

    return Padding(
      padding: EdgeInsets.only(left: depth * 18.0, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: color.withValues(alpha: selected ? 0.18 : 0.12),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? color.withValues(alpha: 0.85)
                        : color.withValues(alpha: 0.38),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_shapeIcon(definition?.shape), size: 18, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            definition?.label ?? fallbackLabel ?? blockId,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (output != null && output.isNotEmpty)
                          _TinyBadge(label: '\$$output'),
                        if (onEdit != null) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: onEdit,
                            icon: const Icon(Icons.tune_rounded),
                            tooltip: '编辑积木 JSON',
                          ),
                          IconButton(
                            onPressed: onMoveUp,
                            icon: const Icon(Icons.keyboard_arrow_up_rounded),
                            tooltip: '上移',
                          ),
                          IconButton(
                            onPressed: onMoveDown,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            tooltip: '下移',
                          ),
                          IconButton(
                            onPressed: onRemove,
                            icon: const Icon(Icons.delete_outline_rounded),
                            tooltip: '删除积木',
                          ),
                        ],
                      ],
                    ),
                    if (params.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _compactJson(params),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (block['condition'] is Map)
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 6),
              child: Text(
                '条件：${(block['condition'] as Map)['block']}',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ),
          for (final entry in children.entries) ...[
            Padding(
              padding: EdgeInsets.only(left: (depth + 1) * 18.0, top: 6),
              child: Text(
                _substackLabel(entry.key),
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            for (final child in entry.value)
              _BlockNode(
                block: child,
                blockById: blockById,
                depth: depth + 1,
                selected: false,
              ),
          ],
        ],
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _childrenOf(
    Map<String, dynamic> map,
  ) {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final key in ['body', 'then', 'else']) {
      final list = ((map[key] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
      if (list.isNotEmpty) result[key] = list;
    }
    return result;
  }
}

class _InspectorPanel extends StatelessWidget {
  final WorkshopWorkflowRegistry registry;
  final WorkshopBlockDefinition? selectedBlock;
  final Map<String, dynamic>? selectedBodyBlock;
  final int? selectedBodyIndex;
  final WorkshopWorkflowValidationResult? validationResult;
  final bool validating;
  final VoidCallback? onAddBlock;
  final void Function(int index, String rawJson) onApplyBlockJson;
  final VoidCallback onValidate;
  final VoidCallback onCopy;
  final VoidCallback onReset;

  const _InspectorPanel({
    required this.registry,
    required this.selectedBlock,
    required this.selectedBodyBlock,
    required this.selectedBodyIndex,
    required this.validationResult,
    required this.validating,
    required this.onAddBlock,
    required this.onApplyBlockJson,
    required this.onValidate,
    required this.onCopy,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final block = selectedBlock;
    final bodyBlock = selectedBodyBlock;
    final bodyIndex = selectedBodyIndex;
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PanelTitle(icon: Icons.tune_rounded, title: '参数与校验'),
        const SizedBox(height: 12),
        if (block == null)
          Text('请选择一个积木', style: TextStyle(color: cs.onSurfaceVariant))
        else
          _SelectedBlockPanel(block: block, onAddBlock: onAddBlock),
        const SizedBox(height: 14),
        if (bodyBlock == null || bodyIndex == null)
          _EditorHintPanel(types: registry.resourceActorTypes)
        else
          _BodyBlockEditorPanel(
            key: ValueKey('body-block-$bodyIndex-${bodyBlock['block']}'),
            index: bodyIndex,
            block: bodyBlock,
            blockById: {for (final block in registry.blocks) block.id: block},
            onApply: (rawJson) => onApplyBlockJson(bodyIndex, rawJson),
          ),
        const SizedBox(height: 14),
        _ResourceTypePanel(types: registry.resourceActorTypes),
        const SizedBox(height: 14),
        _ValidationPanel(
          result: validationResult,
          validating: validating,
          onValidate: onValidate,
          onCopy: onCopy,
          onReset: onReset,
        ),
      ],
    );
  }
}

class _SelectedBlockPanel extends StatelessWidget {
  final WorkshopBlockDefinition block;
  final VoidCallback? onAddBlock;

  const _SelectedBlockPanel({required this.block, required this.onAddBlock});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(block.label, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _TinyBadge(label: block.id),
              _TinyBadge(label: block.shape),
              _TinyBadge(label: block.category),
              if (block.returns != null) _TinyBadge(label: '返回 ${block.returns}'),
              if (block.outputs.isNotEmpty)
                _TinyBadge(label: '输出 ${block.outputs.first.name}'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '参数插槽',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          if (block.params.isEmpty)
            Text('无参数', style: TextStyle(color: cs.onSurfaceVariant))
          else
            ...block.params.map((param) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.input_rounded, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${param.name} · ${param.slot}'
                        '${param.required ? ' · 必填' : ''}'
                        '${param.options.isNotEmpty ? ' · ${param.options.join('/')}' : ''}',
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (block.failurePolicyRequired || block.requiresIdempotencyKey) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (block.failurePolicyRequired) 'LLM 必须配置失败策略',
                if (block.requiresIdempotencyKey) '写回必须配置幂等 key',
              ].join('；'),
              style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAddBlock,
            icon: const Icon(Icons.add_rounded),
            label: const Text('加入脚本'),
          ),
        ],
      ),
    );
  }
}

class _BodyBlockEditorPanel extends StatefulWidget {
  final int index;
  final Map<String, dynamic> block;
  final Map<String, WorkshopBlockDefinition> blockById;
  final ValueChanged<String> onApply;

  const _BodyBlockEditorPanel({
    super.key,
    required this.index,
    required this.block,
    required this.blockById,
    required this.onApply,
  });

  @override
  State<_BodyBlockEditorPanel> createState() => _BodyBlockEditorPanelState();
}

class _BodyBlockEditorPanelState extends State<_BodyBlockEditorPanel> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatBlock(widget.block));
  }

  @override
  void didUpdateWidget(covariant _BodyBlockEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index || oldWidget.block != widget.block) {
      _controller.text = _formatBlock(widget.block);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final blockId = widget.block['block']?.toString() ?? '';
    final definition = widget.blockById[blockId];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.data_object_rounded, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '编辑第 ${widget.index + 1} 个积木',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _controller.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制积木 JSON')),
                  );
                },
                icon: const Icon(Icons.copy_rounded),
                tooltip: '复制积木 JSON',
              ),
            ],
          ),
          if (definition != null) ...[
            const SizedBox(height: 6),
            Text(
              definition.label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            minLines: 8,
            maxLines: 16,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              labelText: '积木 JSON',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => widget.onApply(_controller.text),
            icon: const Icon(Icons.done_rounded),
            label: const Text('应用 JSON'),
          ),
        ],
      ),
    );
  }

  String _formatBlock(Map<String, dynamic> block) {
    return const JsonEncoder.withIndent('  ').convert(block);
  }
}

class _EditorHintPanel extends StatelessWidget {
  final List<WorkshopResourceActorType> types;

  const _EditorHintPanel({required this.types});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('选中脚本里的积木后，可以直接修改 JSON 参数。'),
          const SizedBox(height: 8),
          Text(
            '资料角色会像 Scratch 的角色一样被脚本引用，当前已登记 ${types.length} 类。',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ResourceTypePanel extends StatelessWidget {
  final List<WorkshopResourceActorType> types;

  const _ResourceTypePanel({required this.types});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '可引用资料',
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: types.map((type) {
              return Tooltip(
                message: type.sourceFeature,
                child: _TinyBadge(
                  label: '${type.name}${type.write ? ' 可写' : ''}',
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ValidationPanel extends StatelessWidget {
  final WorkshopWorkflowValidationResult? result;
  final bool validating;
  final VoidCallback onValidate;
  final VoidCallback onCopy;
  final VoidCallback onReset;

  const _ValidationPanel({
    required this.result,
    required this.validating,
    required this.onValidate,
    required this.onCopy,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final validation = result?.validation;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                validation?.ok == true
                    ? Icons.verified_rounded
                    : Icons.rule_rounded,
                color: validation?.ok == true ? Colors.green : cs.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'workflow 校验',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: validating ? null : onValidate,
            icon: validating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.fact_check_rounded),
            label: Text(validating ? '校验中' : '校验当前脚本'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('复制 workflow'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded),
                tooltip: '重置为示例',
              ),
            ],
          ),
          if (validation != null) ...[
            const SizedBox(height: 12),
            _TinyBadge(label: validation.ok ? '通过' : '未通过'),
            const SizedBox(height: 8),
            ...validation.errors.map(
              (error) => Text('错误：$error', style: TextStyle(color: cs.error)),
            ),
            ...validation.warnings.map(
              (warning) => Text(
                '提示：$warning',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyScriptHint extends StatelessWidget {
  const _EmptyScriptHint();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        '当前没有脚本。系统会补一个默认“开始运行”脚本。',
        style: TextStyle(color: cs.onSurfaceVariant),
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _PanelTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final String label;

  const _TinyBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 40),
          const SizedBox(height: 10),
          Text(message),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

Color _colorFromHex(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  final value = int.tryParse(
    cleaned.length == 6 ? 'FF$cleaned' : cleaned,
    radix: 16,
  );
  return Color(value ?? 0xFF64748B);
}

Color _shapeColor(String? shape) {
  return switch (shape) {
    'hat' => const Color(0xFFF59E0B),
    'c_block' => const Color(0xFFEA580C),
    'reporter' => const Color(0xFF2563EB),
    'boolean' => const Color(0xFF16A34A),
    'cap' => const Color(0xFFDC2626),
    _ => const Color(0xFF6366F1),
  };
}

IconData _shapeIcon(String? shape) {
  return switch (shape) {
    'hat' => Icons.flag_rounded,
    'c_block' => Icons.account_tree_rounded,
    'reporter' => Icons.data_object_rounded,
    'boolean' => Icons.rule_rounded,
    'cap' => Icons.stop_circle_rounded,
    _ => Icons.extension_rounded,
  };
}

String _compactJson(Map<String, dynamic> value) {
  final text = jsonEncode(value);
  if (text.length <= 180) return text;
  return '${text.substring(0, 177)}...';
}

String _substackLabel(String key) {
  return switch (key) {
    'body' => '循环体',
    'then' => '那么',
    'else' => '否则',
    _ => key,
  };
}
