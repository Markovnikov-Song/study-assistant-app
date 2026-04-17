import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/subject_provider.dart';
import '../subject_detail/tabs/docs_tab.dart';
import '../subject_detail/tabs/past_exams_tab.dart';
import '../subject_detail/tabs/settings_tab.dart';

class SubjectDetailPage extends ConsumerWidget {
  final int subjectId;
  const SubjectDetailPage({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);
    final name = subjectsAsync.maybeWhen(
      data: (list) => list.where((s) => s.id == subjectId).firstOrNull?.name ?? '资料管理',
      orElse: () => '资料管理',
    );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(name),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.folder_outlined), text: '资料'),
              Tab(icon: Icon(Icons.assignment_outlined), text: '历年题'),
              Tab(icon: Icon(Icons.settings_outlined), text: '设置'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            DocsTab(subjectId: subjectId),
            PastExamsTab(subjectId: subjectId),
            SettingsTab(subjectId: subjectId),
          ],
        ),
      ),
    );
  }
}
