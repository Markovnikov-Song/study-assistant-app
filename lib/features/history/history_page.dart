import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../../models/chat_message.dart';
import '../../providers/chat_provider.dart';
import '../../providers/current_subject_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/subject_provider.dart';
import '../../routes/app_router.dart';
import '../../services/history_service.dart';
import '../../widgets/message_search_delegate.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});
  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  int? _filterSubjectId;
  String? _filterType;
  final Set<int> _selected = {};
  bool _selectMode = false;

  static const _typeOptions = [
    (null, '全部'),
    ('qa', '问答'),
    ('solve', '解题'),
    ('mindmap', '导图'),
    ('exam', '出题'),
  ];

  List<HistorySessionItem> _filter(List<HistorySessionItem> all) => all
      .where((s) => _filterSubjectId == null || s.subjectId == _filterSubjectId)
      .where((s) => _filterType == null || s.sessionType.name == _filterType)
      .toList();

  Future<void> _delete(int id) async {
    try {
      await DioClient.instance.dio.delete('${ApiConstants.sessions}/$id');
      ref.invalidate(allSessionsProvider);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除失败')));
    }
  }

  Future<void> _openSession(HistorySessionItem s) async {
    if (s.subjectId != null) {
      final subjects = ref.read(subjectsProvider).valueOrNull ?? [];
      final subject = subjects.where((sub) => sub.id == s.subjectId).firstOrNull;
      if (subject != null) ref.read(currentSubjectProvider.notifier).state = subject;
      final key = (s.subjectId!.toString(), s.sessionType.name);
      await ref.read(chatProvider(key).notifier).loadSession(s.id);
    }
    if (!mounted) return;
    // 根据会话类型跳转到对应工具页
    switch (s.sessionType) {
      case SessionType.solve:
        context.push(AppRoutes.toolkitSolve);
      case SessionType.exam:
        context.push(AppRoutes.toolkitQuiz);
      default:
        context.go(AppRoutes.chat);
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(allSessionsProvider);
    final subjectsAsync = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: _selectMode ? Text('已选 ${_selected.length} 条') : const Text('对话历史'),
        actions: [
          if (!_selectMode)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: '搜索聊天记录',
              onPressed: () => showSearch(context: context, delegate: MessageSearchDelegate(ref)),
            ),
          if (_selectMode) ...[
            TextButton(onPressed: () => setState(() { _selected.clear(); _selectMode = false; }), child: const Text('取消')),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _selected.isEmpty ? null : () async {
                final ids = List<int>.from(_selected);
                setState(() { _selected.clear(); _selectMode = false; });
                for (final id in ids) { await _delete(id); }
              },
            ),
          ] else
            historyAsync.maybeWhen(
              data: (all) => PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'select') setState(() => _selectMode = true);
                  if (v == 'deleteAll') {
                    final filtered = _filter(all);
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('删除全部'),
                        content: Text('确定删除当前筛选的 ${filtered.length} 条记录？'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('删除')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      for (final s in filtered) { await _delete(s.id); }
                    }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'select', child: Text('多选')),
                  const PopupMenuItem(value: 'deleteAll', child: Text('删除全部', style: TextStyle(color: Colors.red))),
                ],
              ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: subjectsAsync.maybeWhen(
                    data: (subjects) {
                      final active = subjects.where((s) => !s.isArchived).toList();
                      return DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _filterSubjectId,
                          isDense: true,
                          isExpanded: true,
                          hint: const Text('全部学科', style: TextStyle(fontSize: 13)),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('全部学科', style: TextStyle(fontSize: 13))),
                            ...active.map((s) => DropdownMenuItem<int?>(
                              value: s.id,
                              child: Text(s.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                            )),
                          ],
                          onChanged: (v) => setState(() => _filterSubjectId = v),
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _filterType,
                    isDense: true,
                    items: _typeOptions.map((t) => DropdownMenuItem<String?>(
                      value: t.$1,
                      child: Text(t.$2, style: const TextStyle(fontSize: 13)),
                    )).toList(),
                    onChanged: (v) => setState(() => _filterType = v),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败：$e')),
              data: (all) {
                final sessions = _filter(all);
                if (sessions.isEmpty) return const Center(child: Text('暂无对话历史', style: TextStyle(color: Colors.grey)));
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final s = sessions[i];
                    final isSelected = _selected.contains(s.id);
                    return Card(
                      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                      child: ListTile(
                        leading: _selectMode
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (_) => setState(() {
                                  if (isSelected) { _selected.remove(s.id); } else { _selected.add(s.id); }
                                }),
                              )
                            : Text(s.typeLabel, style: const TextStyle(fontSize: 22)),
                        title: Text(s.title ?? '未命名对话', maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${s.subjectName != null ? '${s.subjectName!} · ' : ''}'
                          '${s.createdAt.year}-${s.createdAt.month.toString().padLeft(2, '0')}-${s.createdAt.day.toString().padLeft(2, '0')} '
                          '${s.createdAt.hour}:${s.createdAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: _selectMode ? null : IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              useRootNavigator: false,
                              builder: (_) => AlertDialog(
                                title: const Text('删除记录'),
                                content: Text('确定删除「${s.title ?? '未命名对话'}」？'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                                  TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('删除')),
                                ],
                              ),
                            );
                            if (ok == true) await _delete(s.id);
                          },
                        ),
                        onTap: _selectMode
                            ? () => setState(() {
                                if (isSelected) { _selected.remove(s.id); } else { _selected.add(s.id); }
                              })
                            : () => _openSession(s),
                        onLongPress: () => setState(() { _selectMode = true; _selected.add(s.id); }),
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
