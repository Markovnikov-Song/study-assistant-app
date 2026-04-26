import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/chat/chat_page.dart';
import '../../components/solve/solve_page.dart';
import '../../components/mindmap/mindmap_page.dart';
import '../../components/quiz/quiz_page.dart';
import '../skill_runner/skill_runner_page.dart';
import '../../core/network/dio_client.dart';
import '../../providers/current_subject_provider.dart';

/// 全局 provider：记录答疑室应该跳转到哪个 tab（0=问答,1=解题,2=导图,3=出题）
/// 由历史记录页、session_history_sheet 等在跳转前写入，ClassroomPage 监听后跳转并重置
final classroomInitialTabProvider = StateProvider<int>((ref) => 0);

/// 答疑室：整合问答、解题、导图、出题四个功能
class ClassroomPage extends ConsumerStatefulWidget {
  const ClassroomPage({super.key});

  @override
  ConsumerState<ClassroomPage> createState() => _ClassroomPageState();
}

class _ClassroomPageState extends ConsumerState<ClassroomPage>
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
    final initialTab = ref.read(classroomInitialTabProvider);
    _tabCtrl = TabController(length: 4, vsync: this, initialIndex: initialTab);
    // 读取后重置，避免下次进入时仍跳到同一 tab
    if (initialTab != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(classroomInitialTabProvider.notifier).state = 0;
      });
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 监听 classroomInitialTabProvider：当历史记录/session sheet 设置了目标 tab 时跳转
    // PageView 复用同一个 ClassroomPage 实例，initState 不会再次触发，所以用 listen
    ref.listen<int>(classroomInitialTabProvider, (_, tabIndex) {
      if (tabIndex != _tabCtrl.index) {
        _tabCtrl.animateTo(tabIndex);
      }
      // 跳转后重置，避免重复触发
      if (tabIndex != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.read(classroomInitialTabProvider.notifier).state = 0;
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Skill 快速入口条
              _SkillQuickBar(),
              TabBar(
                controller: _tabCtrl,
                tabs: _tabs,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                indicatorSize: TabBarIndicatorSize.label,
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Consumer(builder: (context, ref, _) {
            final subject = ref.watch(currentSubjectProvider);
            return ChatPage(subjectId: subject?.id);
          }),
          const SolvePage(),
          const MindMapPage(),
          const QuizPage(),
        ],
      ),
    );
  }
}

// ── Skill 快速入口条 ───────────────────────────────────────────────────────────

final _quickSkillsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await DioClient.instance.dio.get('/api/agent/skills');
  final data = res.data as Map<String, dynamic>;
  final skills = ((data['skills'] as List?) ?? []).cast<Map<String, dynamic>>();
  return skills.take(5).toList(); // 只显示前 5 个
});

class _SkillQuickBar extends ConsumerWidget {
  const _SkillQuickBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skillsAsync = ref.watch(_quickSkillsProvider);
    final cs = Theme.of(context).colorScheme;

    return skillsAsync.when(
      loading: () => const SizedBox(height: 40),
      error: (_, _) => const SizedBox.shrink(),
      data: (skills) {
        if (skills.isEmpty) return const SizedBox.shrink();
        return Container(
          height: 40,
          color: cs.surfaceContainerLow,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 6),
                child: Icon(Icons.auto_awesome,
                    size: 14, color: cs.primary),
              ),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: skills.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final skill = skills[i];
                    final name = skill['name'] as String? ?? '';
                    return ActionChip(
                      label: Text(name,
                          style: const TextStyle(fontSize: 12)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SkillRunnerPage(
                            skillId: skill['id'] as String,
                            skillName: name,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
