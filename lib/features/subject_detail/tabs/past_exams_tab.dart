import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/document.dart';
import '../../../providers/exam_provider.dart';

class PastExamsTab extends ConsumerWidget {
  final int subjectId;
  const PastExamsTab({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examsAsync = ref.watch(pastExamsProvider(subjectId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: () => ref.read(examActionsProvider(subjectId)).pickAndUpload(),
            icon: const Icon(Icons.upload_file),
            label: const Text('上传历年题（PDF / 图片 / Word）'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: examsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败：$e')),
            data: (exams) {
              if (exams.isEmpty) {
                return const Center(child: Text('暂无历年题，请上传文件'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: exams.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _ExamFileCard(exam: exams[i], subjectId: subjectId),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExamFileCard extends ConsumerWidget {
  final PastExamFile exam;
  final int subjectId;
  const _ExamFileCard({required this.exam, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusIcons = {
      DocumentStatus.completed: const Icon(Icons.check_circle, color: Colors.green),
      DocumentStatus.processing: const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      DocumentStatus.failed: const Icon(Icons.error, color: Colors.red),
      DocumentStatus.pending: const Icon(Icons.hourglass_empty, color: Colors.orange),
    };

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: statusIcons[exam.status],
            title: Text(exam.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${exam.questionCount} 道题'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await ref.read(examActionsProvider(subjectId)).delete(exam.id);
                ref.invalidate(pastExamsProvider(subjectId));
              },
            ),
          ),
          if (exam.status == DocumentStatus.completed && exam.questionCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: OutlinedButton(
                onPressed: () => _showQuestions(context, ref),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(36)),
                child: Text('查看题目（${exam.questionCount} 道）'),
              ),
            ),
        ],
      ),
    );
  }

  void _showQuestions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _QuestionsSheet(examId: exam.id, subjectId: subjectId),
    );
  }
}

class _QuestionsSheet extends ConsumerWidget {
  final int examId;
  final int subjectId;
  const _QuestionsSheet({required this.examId, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questionsAsync = ref.watch(examQuestionsProvider(examId));
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('题目列表', style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: questionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (questions) => ListView.builder(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: questions.length,
                itemBuilder: (_, i) {
                  final q = questions[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('第 ${q['question_number']} 题', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(q['content'] as String),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
