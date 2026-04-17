import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/mindmap_library.dart';
import '../../providers/library_provider.dart';
import '../../routes/app_router.dart';

/// SchoolPage — 学校主页，展示学科课程卡片列表（含学习进度）
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SubjectWithProgress> _sorted(List<SubjectWithProgress> list) {
    final filtered = _query.isEmpty
        ? list
        : list.where((s) {
            final q = _query.toLowerCase();
            return s.subject.name.toLowerCase().contains(q) ||
                (s.subject.category?.toLowerCase().contains(q) ?? false);
          }).toList();

    filtered.sort((a, b) {
      // Pinned first
      final pinCmp = (b.subject.isPinned ? 1 : 0) - (a.subject.isPinned ? 1 : 0);
      if (pinCmp != 0) return pinCmp;
      // Then by last visited desc
      final aTime = a.lastVisitedAt ?? DateTime(0);
      final bTime = b.lastVisitedAt ?? DateTime(0);
      return bTime.compareTo(aTime);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(schoolSubjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('学校'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索学科名称或分类…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: subjectsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败：$e')),
              data: (subjects) {
                final sorted = _sorted(subjects);
                if (sorted.isEmpty) {
                  return _EmptyState(hasQuery: _query.isNotEmpty);
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(schoolSubjectsProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _SubjectCard(item: sorted[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  const _EmptyState({this.hasQuery = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              hasQuery ? '没有匹配的学科' : '学校还是空的',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
            if (!hasQuery) ...[
              const SizedBox(height: 8),
              Text(
                '去「我的」→「学科管理」创建学科，\n再生成思维导图，课程就会出现在这里',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final SubjectWithProgress item;
  const _SubjectCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subject = item.subject;
    final percent = item.totalNodes == 0
        ? 0.0
        : item.litNodes / item.totalNodes;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    subject.name.isNotEmpty ? subject.name[0] : '?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              subject.name,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (subject.isPinned)
                            Icon(Icons.push_pin, size: 14, color: cs.primary),
                        ],
                      ),
                      if (subject.category != null && subject.category!.isNotEmpty)
                        Text(
                          subject.category!,
                          style: TextStyle(fontSize: 12, color: cs.outline),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 6,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(percent * 100).floor()}%',
                  style: TextStyle(fontSize: 12, color: cs.outline),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${item.litNodes}/${item.totalNodes} 个知识点 · ${item.sessionCount} 份大纲',
              style: TextStyle(fontSize: 12, color: cs.outline),
            ),
            if (item.lastVisitedAt != null) ...[
              const SizedBox(height: 2),
              Text(
                '最近访问：${_formatDate(item.lastVisitedAt!)}',
                style: TextStyle(fontSize: 11, color: cs.outline),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => context.push(AppRoutes.courseSpace(subject.id)),
                child: const Text('开始学习'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
