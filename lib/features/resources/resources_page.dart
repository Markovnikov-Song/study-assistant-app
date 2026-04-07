import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/subject.dart';
import '../../providers/subject_provider.dart';
import '../subject_detail/subject_detail_page.dart';

class ResourcesPage extends ConsumerWidget {
  const ResourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('资料管理')),
      body: subjectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (subjects) {
          final active = subjects.where((s) => !s.isArchived).toList();
          if (active.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('还没有学科，请先在学科管理中新建', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: active.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _SubjectResourceCard(subject: active[i]),
          );
        },
      ),
    );
  }
}

class _SubjectResourceCard extends StatelessWidget {
  final Subject subject;
  const _SubjectResourceCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SubjectDetailPage(subjectId: subject.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    subject.name.isNotEmpty ? subject.name[0] : '?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    if (subject.category != null)
                      Text(subject.category!, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
