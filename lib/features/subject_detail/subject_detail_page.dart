import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/subject_provider.dart';
import 'tabs/chat_tab.dart';
import 'tabs/docs_tab.dart';
import 'tabs/past_exams_tab.dart';
import 'tabs/quiz_gen_tab.dart';

class SubjectDetailPage extends ConsumerWidget {
  final int subjectId;
  const SubjectDetailPage({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);

    final subjectName = subjectsAsync.maybeWhen(
      data: (list) => list.where((s) => s.id == subjectId).firstOrNull?.name ?? '学科详情',
      orElse: () => '学科详情',
    );

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(subjectName),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.chat_outlined), text: '学习助手'),
              Tab(icon: Icon(Icons.folder_outlined), text: '资料管理'),
              Tab(icon: Icon(Icons.assignment_outlined), text: '历年题'),
              Tab(icon: Icon(Icons.auto_awesome_outlined), text: 'AI 出题'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ChatTab(subjectId: subjectId),
            DocsTab(subjectId: subjectId),
            PastExamsTab(subjectId: subjectId),
            QuizGenTab(subjectId: subjectId),
          ],
        ),
      ),
    );
  }
}
