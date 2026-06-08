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
    final categories = registry.categories;
    final activeCategory = _categoryId ?? categories.firstOrNull?.id ?? '';
    final categoryBlocks = registry.blocksForCategory(activeCategory);
    final selectedBlock = _resolveSelectedBlock(registry, categoryBlocks);

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
              ),
              const SizedBox(height: 14),
              _WorkflowScriptPanel(registry: registry),
              const SizedBox(height: 14),
              _InspectorPanel(
                registry: registry,
                selectedBlock: selectedBlock,
                validationResult: _validationResult,
                validating: _validating,
                onValidate: () => _validateExampleWorkflow(registry),
                onCopy: () => _copyExampleWorkflow(registry),
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
              ),
            ),
            VerticalDivider(
              width: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(child: _WorkflowScriptPanel(registry: registry)),
            VerticalDivider(
              width: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            SizedBox(
              width: 380,
              child: _InspectorPanel(
                registry: registry,
                selectedBlock: selectedBlock,
                validationResult: _validationResult,
                validating: _validating,
                onValidate: () => _validateExampleWorkflow(registry),
                onCopy: () => _copyExampleWorkflow(registry),
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

  Future<void> _validateExampleWorkflow(
    WorkshopWorkflowRegistry registry,
  ) async {
    if (_validating) return;
    setState(() => _validating = true);
    try {
      final result = await ref
          .read(miniAppServiceProvider)
          .validateWorkflow(workflow: registry.exampleWorkflow);
      if (!mounted) return;
      setState(() => _validationResult = result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('校验失败：$error')));
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  Future<void> _copyExampleWorkflow(WorkshopWorkflowRegistry registry) async {
    final text = const JsonEncoder.withIndent(
      '  ',
    ).convert(registry.exampleWorkflow);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制示例 workflow JSON')));
  }
}

class _BlockLibraryPanel extends StatelessWidget {
  final WorkshopWorkflowRegistry registry;
  final String activeCategory;
  final String? selectedBlockId;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<WorkshopBlockDefinition> onBlockSelected;

  const _BlockLibraryPanel({
    required this.registry,
    required this.activeCategory,
    required this.selectedBlockId,
    required this.onCategorySelected,
    required this.onBlockSelected,
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

  const _BlockListItem({
    required this.block,
    required this.selected,
    required this.onTap,
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
        ),
      ),
    );
  }
}

class _WorkflowScriptPanel extends StatelessWidget {
  final WorkshopWorkflowRegistry registry;

  const _WorkflowScriptPanel({required this.registry});

  @override
  Widget build(BuildContext context) {
    final workflow = registry.exampleWorkflow;
    final actors = ((workflow['actors'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    final scripts = ((workflow['scripts'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const _PanelTitle(icon: Icons.account_tree_rounded, title: '示例脚本栈'),
        const SizedBox(height: 10),
        _StageSummary(registry: registry, actors: actors),
        const SizedBox(height: 14),
        for (final script in scripts)
          _ScriptView(
            script: script,
            blockById: {for (final block in registry.blocks) block.id: block},
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
              '示例 workflow 没有绑定资料角色',
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

  const _ScriptView({required this.script, required this.blockById});

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
        ),
        for (final block in body)
          _BlockNode(block: block, blockById: blockById, depth: 1),
      ],
    );
  }
}

class _BlockNode extends StatelessWidget {
  final Map<String, dynamic> block;
  final Map<String, WorkshopBlockDefinition> blockById;
  final String? fallbackLabel;
  final int depth;

  const _BlockNode({
    required this.block,
    required this.blockById,
    required this.depth,
    this.fallbackLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final blockId = block['block']?.toString() ?? '';
    final definition = blockById[blockId];
    final children = _childrenOf(block);
    final output = block['output']?.toString();
    final color = _shapeColor(definition?.shape);

    return Padding(
      padding: EdgeInsets.only(left: depth * 18.0, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.38)),
            ),
            child: Row(
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
              ],
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
                entry.key,
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            for (final child in entry.value)
              _BlockNode(block: child, blockById: blockById, depth: depth + 1),
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
  final WorkshopWorkflowValidationResult? validationResult;
  final bool validating;
  final VoidCallback onValidate;
  final VoidCallback onCopy;

  const _InspectorPanel({
    required this.registry,
    required this.selectedBlock,
    required this.validationResult,
    required this.validating,
    required this.onValidate,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final block = selectedBlock;
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PanelTitle(icon: Icons.tune_rounded, title: '参数与校验'),
        const SizedBox(height: 12),
        if (block == null)
          Text('请选择一个积木', style: TextStyle(color: cs.onSurfaceVariant))
        else
          _SelectedBlockPanel(block: block),
        const SizedBox(height: 14),
        _ResourceTypePanel(types: registry.resourceActorTypes),
        const SizedBox(height: 14),
        _ValidationPanel(
          result: validationResult,
          validating: validating,
          onValidate: onValidate,
          onCopy: onCopy,
        ),
      ],
    );
  }
}

class _SelectedBlockPanel extends StatelessWidget {
  final WorkshopBlockDefinition block;

  const _SelectedBlockPanel({required this.block});

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
            block.label,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _TinyBadge(label: block.id),
              _TinyBadge(label: block.shape),
              _TinyBadge(label: block.category),
              if (block.returns != null)
                _TinyBadge(label: '返回 ${block.returns}'),
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

  const _ValidationPanel({
    required this.result,
    required this.validating,
    required this.onValidate,
    required this.onCopy,
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
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: validating ? null : onValidate,
                  icon: validating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fact_check_rounded),
                  label: Text(validating ? '校验中' : '校验示例'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded),
                tooltip: '复制示例 workflow JSON',
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
