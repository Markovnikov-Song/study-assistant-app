// Learning OS — MCP 连接状态指示器 Widget
// 需求 3.5：在 UI 层展示当前 MCP 连接状态，区分三种状态。
// 设计为轻量 Widget，可嵌入 AppBar actions 或 SubjectBar 旁边。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/mcp/mcp_models.dart';
import '../core/mcp/mcp_status_provider.dart';

/// MCP 连接状态指示器。
///
/// 展示三种状态：
/// - 全部在线：绿色圆点 + "全部在线"
/// - 仅本地：橙色圆点 + "仅本地"
/// - 离线模式：灰色圆点 + "离线模式"
///
/// 点击后展示详细的连接状态弹窗（服务器列表、工具数量）。
class McpStatusIndicator extends ConsumerWidget {
  /// 是否显示文字标签（紧凑模式只显示圆点）
  final bool showLabel;

  const McpStatusIndicator({super.key, this.showLabel = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(mcpStatusProvider);

    return statusAsync.when(
      data: (summary) => _buildIndicator(context, summary),
      loading: () => _buildDot(context, Colors.grey.shade400, '连接中…'),
      error: (_, _) => _buildDot(context, Colors.grey.shade400, '离线模式'),
    );
  }

  Widget _buildIndicator(BuildContext context, MCPConnectionSummary summary) {
    final (color, label) = switch (summary.state) {
      MCPConnectionState.allOnline => (Colors.green.shade500, '全部在线'),
      MCPConnectionState.localOnly => (Colors.orange.shade500, '仅本地'),
      MCPConnectionState.offline   => (Colors.grey.shade500, '离线模式'),
    };

    return GestureDetector(
      onTap: () => _showDetailSheet(context, summary),
      child: _buildDot(context, color, label),
    );
  }

  Widget _buildDot(BuildContext context, Color color, String label) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );

    if (!showLabel) return dot;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  void _showDetailSheet(BuildContext context, MCPConnectionSummary summary) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _McpStatusDetailSheet(summary: summary),
    );
  }
}

/// MCP 状态详情底部弹窗。
class _McpStatusDetailSheet extends StatelessWidget {
  final MCPConnectionSummary summary;

  const _McpStatusDetailSheet({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final stateColor = switch (summary.state) {
      MCPConnectionState.allOnline => Colors.green.shade600,
      MCPConnectionState.localOnly => Colors.orange.shade600,
      MCPConnectionState.offline   => Colors.grey.shade600,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: stateColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'MCP 工具状态：${summary.state.label}',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '可用工具数：${summary.totalTools}',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // 已连接服务器
          if (summary.connectedServers.isNotEmpty) ...[
            Text('已连接', style: tt.labelMedium?.copyWith(color: Colors.green.shade700)),
            const SizedBox(height: 4),
            ...summary.connectedServers.map(
              (id) => _ServerTile(serverId: id, connected: true),
            ),
            const SizedBox(height: 12),
          ],

          // 失败服务器
          if (summary.failedServers.isNotEmpty) ...[
            Text('不可用', style: tt.labelMedium?.copyWith(color: Colors.red.shade700)),
            const SizedBox(height: 4),
            ...summary.failedServers.map(
              (id) => _ServerTile(serverId: id, connected: false),
            ),
          ],

          // 无任何服务器
          if (summary.connectedServers.isEmpty && summary.failedServers.isEmpty)
            Text(
              '暂无已注册的 MCP 服务器',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _ServerTile extends StatelessWidget {
  final String serverId;
  final bool connected;

  const _ServerTile({required this.serverId, required this.connected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            connected ? Icons.check_circle_outline : Icons.error_outline,
            size: 14,
            color: connected ? Colors.green.shade600 : Colors.red.shade400,
          ),
          const SizedBox(width: 6),
          Text(
            serverId,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
