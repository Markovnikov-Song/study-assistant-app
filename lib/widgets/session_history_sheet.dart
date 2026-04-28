import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../providers/history_provider.dart';
import '../routes/app_router.dart';
import '../widgets/message_search_delegate.dart';

/// 通用历史记录底部弹窗，支持按 session 类型筛选
/// [subjectId] 当前学科
/// [initialType] 默认选中的类型（null = 全部）
void showSessionHistorySheet(
  BuildContext context,
  WidgetRef ref, {
  required int subjectId,
  String? initialType,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SessionHistorySheet(
      subjectId: subjectId,
      initialType: initialType,
    ),
  );
}

class _SessionHistorySheet extends ConsumerStatefulWidget {
  final int subjectId;
  final String? initialType;
  const _SessionHistorySheet({required this.subjectId, this.initialType});

  @override
  ConsumerState<_SessionHistorySheet> createState() => _SessionHistorySheetState();
}

class _SessionHistorySheetState extends ConsumerState<_SessionHistorySheet> {
  late String? _selectedType;

  static const _filters = [
    (null, '全部'),
    ('qa', '问答'),
    ('solve', '解题'),
    ('mindmap', '导图'),
    ('exam', '出题'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(t.year, t.month, t.day);
    final hm = '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
    if (d == today) return '今天 $hm';
    if (d == yesterday) return '昨天 $hm';
    if (t.year == now.year) return '${t.month}月${t.day}日 $hm';
    return '${t.year}年${t.month}月${t.day}日';
  }

  List<ConversationSession> _filter(List<ConversationSession> all) {
    if (_selectedType == null) return all;
    return all.where((s) => s.sessionType.name == _selectedType).toList();
  }

  Future<void> _loadSession(ConversationSession s) async {
    final typeKey = s.sessionType.name;
    final key = (widget.subjectId.toString(), typeKey);
    await ref.read(chatProvider(key).notifier).loadSession(s.id);
    if (!mounted) return;
    // 根据会话类型跳转到对应工具页
    switch (s.sessionType) {
      case SessionType.solve:
        Navigator.pop(context);
        context.push(AppRoutes.toolkitSolve);
      case SessionType.exam:
        Navigator.pop(context);
        context.push(AppRoutes.toolkitQuiz);
      default:
        Navigator.pop(context);
    }
  }

  Future<void> _deleteSession(ConversationSession s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定删除「${s.title ?? '未命名对话'}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await ref.read(chatServiceProvider).deleteSession(s.id);
        ref.invalidate(sessionsProvider(widget.subjectId));
        ref.invalidate(allSessionsProvider); // 同步刷新「我的」历史记录页
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败：$e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsProvider(widget.subjectId));

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          // 拖动把手
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
            child: Row(
              children: [
                Text('历史记录', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.search, size: 20),
                  tooltip: '搜索',
                  onPressed: () {
                    Navigator.pop(context);
                    showSearch(context: context, delegate: MessageSearchDelegate(ref));
                  },
                ),
              ],
            ),
          ),
          // 筛选 Chip 栏
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _filters.map((f) {
                final selected = _selectedType == f.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f.$2, style: const TextStyle(fontSize: 13)),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedType = f.$1),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),
          // 列表
          Expanded(
            child: sessionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (all) {
                final sessions = _filter(all);
                if (sessions.isEmpty) {
                  return const Center(child: Text('暂无历史记录', style: TextStyle(color: Colors.grey)));
                }
                return ListView.separated(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
                  itemBuilder: (_, i) {
                    final s = sessions[i];
                    return ListTile(
                      leading: Text(s.typeLabel, style: const TextStyle(fontSize: 20)),
                      title: Text(s.title ?? '未命名对话', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(_formatTime(s.createdAt), style: const TextStyle(fontSize: 12)),
                      onTap: () => _loadSession(s),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                        onPressed: () => _deleteSession(s),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
