import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/solve_session.dart';
import '../services/solve_history_service.dart';

/// 解题历史记录底部弹出面板
///
/// 展示当前用户的所有解题历史会话，支持：
/// - 下拉刷新
/// - 滑动删除（带确认对话框）
/// - 点击恢复会话（通过 [onSessionSelected] 回调）
class SolveHistorySheet extends StatefulWidget {
  /// 用户选中某条历史会话时的回调
  final void Function(SolveHistorySession session) onSessionSelected;

  const SolveHistorySheet({
    super.key,
    required this.onSessionSelected,
  });

  @override
  State<SolveHistorySheet> createState() => _SolveHistorySheetState();
}

class _SolveHistorySheetState extends State<SolveHistorySheet> {
  final _service = SolveHistoryService();
  List<SolveHistorySession> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions = await _service.fetchSessions();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  /// 删除会话，删除前弹出确认对话框
  Future<void> _deleteSession(SolveHistorySession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记录'),
        content: Text('确认删除「${session.title}」？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _service.deleteSession(session.id);
      if (!mounted) return;
      setState(() {
        _sessions.removeWhere((s) => s.id == session.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('删除失败，请重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // 顶部拖拽把手
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
              child: Row(
                children: [
                  Text(
                    '解题历史',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 内容区域
            Expanded(
              child: _buildBody(scrollController),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text('加载失败，请重试'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadSessions,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_sessions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              '暂无历史记录',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView.separated(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _sessions.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final session = _sessions[index];
          return _SessionTile(
            session: session,
            onTap: () {
              Navigator.pop(context);
              widget.onSessionSelected(session);
            },
            onDelete: () => _deleteSession(session),
          );
        },
      ),
    );
  }
}

// ── 单条会话列表项 ─────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  final SolveHistorySession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final timeStr = DateFormat('MM-dd HH:mm').format(session.createdAt.toLocal());

    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      // 滑动删除时先弹确认对话框，取消则恢复
      confirmDismiss: (_) async {
        onDelete();
        // 返回 false 让 Dismissible 不自动移除（由 _deleteSession 控制状态）
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: cs.errorContainer,
        child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: _ThumbnailWidget(thumbnail: session.thumbnail),
        title: Text(
          session.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          timeStr,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ── 缩略图组件 ────────────────────────────────────────────────────────────────

class _ThumbnailWidget extends StatelessWidget {
  final String? thumbnail;

  const _ThumbnailWidget({this.thumbnail});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (thumbnail == null || thumbnail!.isEmpty) {
      // 无图片时显示占位图标
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.calculate_outlined,
          color: cs.onSurfaceVariant,
          size: 24,
        ),
      );
    }

    // 尝试解码 Base64 缩略图
    Uint8List? bytes;
    try {
      final data = thumbnail!.contains(',')
          ? thumbnail!.split(',').last
          : thumbnail!;
      bytes = base64Decode(data);
    } catch (_) {
      bytes = null;
    }

    if (bytes == null) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.image_not_supported_outlined,
          color: cs.onSurfaceVariant,
          size: 24,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        bytes,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 48,
          height: 48,
          color: cs.surfaceContainerHighest,
          child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}
