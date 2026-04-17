import 'package:flutter/material.dart';
import '../../components/chat/chat_page.dart';
import '../../components/solve/solve_page.dart';
import '../../components/mindmap/mindmap_page.dart';
import '../../components/quiz/quiz_page.dart';

/// 答疑室：整合问答、解题、导图、出题四个功能
class ClassroomPage extends StatefulWidget {
  const ClassroomPage({super.key});

  @override
  State<ClassroomPage> createState() => _ClassroomPageState();
}

class _ClassroomPageState extends State<ClassroomPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  static const _tabs = [
    Tab(text: '问答'),
    Tab(text: '解题'),
    Tab(text: '导图'),
    Tab(text: '出题'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: _tabs,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          indicatorSize: TabBarIndicatorSize.label,
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          ChatPage(),
          SolvePage(),
          MindMapPage(),
          QuizPage(),
        ],
      ),
    );
  }
}
