import 'package:flutter/material.dart';
import '../../models/graph_dimension.dart';

/// 多维图谱视图 - 支持知识/能力/问题/素质/思政五维切换
class MultiDimensionGraphView extends StatefulWidget {
  final String sessionId;
  final List<String> nodeIds;
  final Map<String, String> nodeLabels;  // nodeId -> 显示文本
  final Map<String, String>? dimensionMappings;  // nodeId -> 维度值
  
  const MultiDimensionGraphView({
    super.key,
    required this.sessionId,
    required this.nodeIds,
    required this.nodeLabels,
    this.dimensionMappings,
  });

  @override
  State<MultiDimensionGraphView> createState() => _MultiDimensionGraphViewState();
}

class _MultiDimensionGraphViewState extends State<MultiDimensionGraphView> {
  GraphDimension _currentDimension = GraphDimension.knowledge;
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        // 维度切换 Tab
        Container(
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: GraphDimension.values.map((dim) {
              final isSelected = dim == _currentDimension;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(dim.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _currentDimension = dim;
                      });
                    }
                  },
                  selectedColor: theme.colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: isSelected 
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        
        // 图谱视图
        Expanded(
          child: _buildGraphView(theme),
        ),
        
        // 维度说明
        _buildDimensionLegend(theme),
      ],
    );
  }
  
  Widget _buildGraphView(ThemeData theme) {
    // 根据当前维度渲染不同的视图
    // 知识维度：显示节点名称
    // 能力维度：显示能力名称
    // 问题维度：显示问题类型
    // 等等
    
    if (widget.dimensionMappings == null || widget.dimensionMappings!.isEmpty) {
      // 无映射数据时，显示提示
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _currentDimension == GraphDimension.knowledge
                  ? '暂无维度映射数据'
                  : '点击节点查看 ${_currentDimension.label} 信息',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (_currentDimension != GraphDimension.knowledge)
              FilledButton.tonal(
                onPressed: _showDimensionMappingDialog,
                child: const Text('添加维度映射'),
              ),
          ],
        ),
      );
    }
    
    // 渲染节点列表
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.nodeIds.length,
      itemBuilder: (context, index) {
        final nodeId = widget.nodeIds[index];
        final label = widget.nodeLabels[nodeId] ?? nodeId;
        final dimensionValue = widget.dimensionMappings?[nodeId];
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getDimensionColor(theme),
              child: Text(
                '${index + 1}',
                style: TextStyle(color: theme.colorScheme.onPrimary),
              ),
            ),
            title: Text(label),
            subtitle: dimensionValue != null
                ? Text(
                    '${_currentDimension.label}: $dimensionValue',
                    style: TextStyle(color: _getDimensionColor(theme)),
                  )
                : null,
            trailing: dimensionValue != null
                ? Icon(_getDimensionIcon(), color: _getDimensionColor(theme))
                : null,
            onTap: () => _showNodeDetail(nodeId, label, dimensionValue),
          ),
        );
      },
    );
  }
  
  Widget _buildDimensionLegend(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _legendItem(theme, Icons.school, '知识', theme.colorScheme.primary),
          _legendItem(theme, Icons.psychology, '能力', Colors.orange),
          _legendItem(theme, Icons.quiz, '问题', Colors.blue),
          _legendItem(theme, Icons.emoji_events, '素质', Colors.green),
          _legendItem(theme, Icons.flag, '思政', Colors.red),
        ],
      ),
    );
  }
  
  Widget _legendItem(ThemeData theme, IconData icon, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
  
  Color _getDimensionColor(ThemeData theme) {
    switch (_currentDimension) {
      case GraphDimension.knowledge:
        return theme.colorScheme.primary;
      case GraphDimension.capability:
        return Colors.orange;
      case GraphDimension.problem:
        return Colors.blue;
      case GraphDimension.quality:
        return Colors.green;
      case GraphDimension.ideological:
        return Colors.red;
    }
  }
  
  IconData _getDimensionIcon() {
    switch (_currentDimension) {
      case GraphDimension.knowledge:
        return Icons.school;
      case GraphDimension.capability:
        return Icons.psychology;
      case GraphDimension.problem:
        return Icons.quiz;
      case GraphDimension.quality:
        return Icons.emoji_events;
      case GraphDimension.ideological:
        return Icons.flag;
    }
  }
  
  void _showNodeDetail(String nodeId, String label, String? dimensionValue) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (dimensionValue != null) ...[
                Text(
                  '${_currentDimension.label}信息',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _getDimensionColor(Theme.of(context)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(dimensionValue),
              ] else ...[
                const Text('暂无映射数据'),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('关闭'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showDimensionMappingDialog();
                      },
                      child: const Text('编辑映射'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showDimensionMappingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('添加${_currentDimension.label}映射'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: '输入${_currentDimension.label}信息',
                hintText: _getHintText(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              // TODO: 保存映射到后端
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('映射已保存')),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
  
  String _getHintText() {
    switch (_currentDimension) {
      case GraphDimension.knowledge:
        return '知识点名称';
      case GraphDimension.capability:
        return '如：工程分析能力、计算能力';
      case GraphDimension.problem:
        return '如：计算题、分析题、选择题';
      case GraphDimension.quality:
        return '如：团队协作、创新思维';
      case GraphDimension.ideological:
        return '如：工程师伦理、家国情怀';
    }
  }
}