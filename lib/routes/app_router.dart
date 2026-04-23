import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/home/responsive_shell.dart';
import '../features/chat/chat_page.dart';
import '../features/spec/spec_page.dart';
import '../features/toolkit/toolkit_page.dart';
import '../features/profile/profile_page.dart';
import '../features/profile/edit_profile_page.dart';
import '../features/profile/memory_page.dart';
import '../features/subjects/subjects_page.dart';
import '../features/resources/resources_page.dart';
import '../features/history/history_page.dart';
import '../features/subject_detail/subject_detail_page.dart';
import '../features/skill_marketplace/marketplace_page.dart';
import '../features/skill_creation/dialog_creation_page.dart';
import '../components/library/library_page.dart';
import '../components/library/course_space_page.dart';
import '../components/library/editable_mindmap_page.dart';
import '../components/library/lecture/lecture_page.dart';
import '../components/mistake_book/mistake_book_page.dart';
import '../components/notebook/notebook_list_page.dart';
import '../components/notebook/notebook_detail_page.dart';
import '../components/notebook/note_detail_page.dart';
import '../components/solve/solve_page.dart';
import '../components/quiz/quiz_page.dart';
import '../components/mindmap_entry/mindmap_entry_page.dart';
import '../features/skill_runner/my_skills_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/calendar/widgets/countdown_list_page.dart';
import '../features/calendar/widgets/stats_panel.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 所有路由路径常量，集中定义，全项目唯一来源
// ─────────────────────────────────────────────────────────────────────────────
class R {
  R._();

  // Auth
  static const login    = '/login';
  static const register = '/register';

  // Shell Tabs
  static const chat        = '/';
  static const courseSpace = '/course-space';
  static const toolkit     = '/toolkit';
  static const profile     = '/profile';

  // Chat 子路由
  static String chatSession(String chatId)                        => '/chat/$chatId';
  static String chatSubject(String chatId, int subjectId)         => '/chat/$chatId/subject/$subjectId';
  static String chatTask(String chatId, String taskId)            => '/chat/$chatId/task/$taskId';
  static const spec = '/spec';

  // 课程空间
  static String courseSpaceSubject(int subjectId)                 => '/course-space/$subjectId';
  static String mindmap(int subjectId, int sessionId)             => '/course-space/$subjectId/mindmap/$sessionId';
  static String lecture(int subjectId, int sessionId, String nodeId)
      => '/course-space/$subjectId/mindmap/$sessionId/lecture?node_id=${Uri.encodeQueryComponent(nodeId)}';

  // 工具箱
  static const toolkitMistakeBook = '/toolkit/mistake-book';
  static const toolkitNotebooks   = '/toolkit/notebooks';
  static String notebookDetail(int id)                            => '/toolkit/notebooks/$id';
  static String noteDetail(int nbId, int noteId)                  => '/toolkit/notebooks/$nbId/notes/$noteId';
  static const toolkitSolve = '/toolkit/solve';
  static const toolkitQuiz  = '/toolkit/quiz';

  // 我的
  static const profileEdit     = '/profile/edit';
  static const profileMemory   = '/profile/memory';
  static const profileSubjects = '/profile/subjects';
  static const profileResources = '/profile/resources';
  static const profileHistory  = '/profile/history';
  static String subjectDetail(int id)                             => '/profile/resources/$id';

  // 其他独立页面
  static const skillMarketplace  = '/skill-marketplace';
  static const skillDialogCreate = '/skill-create-dialog';
  static const mindmapEntry      = '/mindmap-entry';
  static String mindmapEntryForSubject(int subjectId) => '/mindmap-entry?subject=$subjectId';

  // Calendar Planner
  static const toolkitCalendar          = '/toolkit/calendar';
  static String toolkitCalendarTask(String id) => '/toolkit/calendar/task/$id';
  static const toolkitCalendarCountdown = '/toolkit/calendar/countdown';
  static const toolkitCalendarStats     = '/toolkit/calendar/stats';

  // ── 向后兼容旧路由（其他文件仍引用，映射到新路由）──────────────────────────
  // 旧的 /library/:subjectId/mindmap/:sessionId/lecture 仍可用
  static String legacyMindmap(int subjectId, int sessionId)       => '/course-space/$subjectId/mindmap/$sessionId';
  static String legacyLecture(int subjectId, int sessionId, String nodeId)
      => lecture(subjectId, sessionId, nodeId);

  // 旧方法别名（保持向后兼容）
  static String subjectDetailPath(int id)  => subjectDetail(id);
  static String courseSpacePath(int id)    => courseSpaceSubject(id);
  static String courseSpaceById(int id)    => courseSpaceSubject(id);
  static String editableMindMap(int subjectId, int sessionId) => mindmap(subjectId, sessionId);
  static String lecturePage(int subjectId, int sessionId, String nodeId)
      => lecture(subjectId, sessionId, nodeId);
  static String notebookDetail_(int id)    => notebookDetail(id);
  static String noteDetail_(int nbId, int noteId) => noteDetail(nbId, noteId);
}

// 旧名称别名，让其他文件的 AppRoutes.xxx 不报错
typedef AppRoutes = R;

// ─────────────────────────────────────────────────────────────────────────────
// Router Provider
// ─────────────────────────────────────────────────────────────────────────────
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    initialLocation: R.chat,
    refreshListenable: notifier,
    redirect: (context, state) {
      final loggedIn = notifier.isLoggedIn;
      final loc = state.matchedLocation;
      final isAuth = loc == R.login || loc == R.register;
      if (!loggedIn && !isAuth) return R.login;
      if (loggedIn && isAuth) return R.chat;
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('页面不存在: ${state.uri}')),
    ),
    routes: [
      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(path: R.login,    builder: (_, _) => const LoginPage()),
      GoRoute(path: R.register, builder: (_, _) => const RegisterPage()),

      // ── 独立全屏页面（push 覆盖 shell）────────────────────────────────────
      GoRoute(path: R.spec,              builder: (_, _) => const SpecPage()),
      GoRoute(path: R.profileEdit,       builder: (_, _) => const EditProfilePage()),
      GoRoute(path: R.profileMemory,     builder: (_, _) => const MemoryPage()),
      GoRoute(path: R.profileSubjects,   builder: (_, _) => const SubjectsPage()),
      GoRoute(path: R.profileResources,  builder: (_, _) => const ResourcesPage()),
      GoRoute(path: R.profileHistory,    builder: (_, _) => const HistoryPage()),
      GoRoute(path: R.skillMarketplace,  builder: (_, _) => const MarketplacePage()),
      GoRoute(path: R.skillDialogCreate, builder: (_, _) => const DialogCreationPage()),
      GoRoute(
        path: R.mindmapEntry,
        builder: (_, state) => MindmapEntryPage(
          initialSubjectId: int.tryParse(state.uri.queryParameters['subject'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/profile/resources/:id',
        builder: (_, state) => SubjectDetailPage(
          subjectId: int.parse(state.pathParameters['id']!),
        ),
      ),

      // Chat 子路由（独立全屏，不在 shell 内）
      GoRoute(
        path: '/chat/:chatId',
        builder: (_, state) => ChatPage(chatId: state.pathParameters['chatId']),
        routes: [
          GoRoute(
            path: 'subject/:subjectId',
            builder: (_, state) => ChatPage(
              chatId: state.pathParameters['chatId'],
              subjectId: int.tryParse(state.pathParameters['subjectId'] ?? ''),
            ),
          ),
          GoRoute(
            path: 'task/:taskId',
            builder: (_, state) => ChatPage(
              chatId: state.pathParameters['chatId'],
              taskId: state.pathParameters['taskId'],
            ),
          ),
        ],
      ),

      // 工具箱子路由
      GoRoute(path: R.toolkitMistakeBook, builder: (_, _) => const MistakeBookPage()),
      GoRoute(path: R.toolkitSolve,       builder: (_, _) => const SolvePage()),
      GoRoute(path: R.toolkitQuiz,        builder: (_, _) => const QuizPage()),
      GoRoute(path: '/my-skills',         builder: (_, _) => const MySkillsPage()),
      GoRoute(
        path: R.toolkitCalendar,
        builder: (_, state) => CalendarPage(
          renderMode: state.uri.queryParameters['mode'] ?? 'full',
          sceneSource: state.uri.queryParameters['source'] ?? 'user_active',
          subjectId: int.tryParse(state.uri.queryParameters['subject'] ?? ''),
          prefillDate: state.uri.queryParameters['date'] != null
              ? DateTime.tryParse(state.uri.queryParameters['date']!)
              : null,
        ),
        routes: [
          GoRoute(
            path: 'task/:taskId',
            builder: (_, state) => CalendarPage(
              taskId: state.pathParameters['taskId'],
            ),
          ),
          GoRoute(
            path: 'countdown',
            builder: (_, _) => const CountdownListPage(),
          ),
          GoRoute(
            path: 'stats',
            builder: (_, _) => const StatsPanel(),
          ),
        ],
      ),
      GoRoute(
        path: '/toolkit/mindmap-workshop',
        builder: (_, state) {
          final subjectId = int.tryParse(state.uri.queryParameters['subject'] ?? '');
          if (subjectId != null) {
            // 直接进指定学科的详情页
            return CourseSpacePage(subjectId: subjectId);
          }
          // 没有指定学科，显示学科选择页
          return const _MindmapSubjectPickerPage();
        },
      ),
      GoRoute(
        path: R.toolkitNotebooks,
        builder: (_, _) => const NotebookListPage(),
        routes: [
          GoRoute(
            path: ':notebookId',
            builder: (_, state) => NotebookDetailPage(
              notebookId: int.parse(state.pathParameters['notebookId']!),
            ),
            routes: [
              GoRoute(
                path: 'notes/:noteId',
                builder: (_, state) => NoteDetailPage(
                  notebookId: int.parse(state.pathParameters['notebookId']!),
                  noteId: int.parse(state.pathParameters['noteId']!),
                ),
              ),
            ],
          ),
        ],
      ),

      // 课程空间子路由（独立全屏）
      GoRoute(
        path: '/course-space/:subjectId',
        builder: (_, state) => CourseSpacePage(
          subjectId: int.parse(state.pathParameters['subjectId']!),
        ),
        routes: [
          GoRoute(
            path: 'mindmap/:sessionId',
            builder: (_, state) => EditableMindMapPage(
              subjectId: int.parse(state.pathParameters['subjectId']!),
              sessionId: int.parse(state.pathParameters['sessionId']!),
            ),
            routes: [
              GoRoute(
                path: 'lecture',
                builder: (_, state) => LecturePage(
                  subjectId: int.parse(state.pathParameters['subjectId']!),
                  sessionId: int.parse(state.pathParameters['sessionId']!),
                  nodeId: state.uri.queryParameters['node_id'] ?? '',
                ),
              ),
            ],
          ),
        ],
      ),

      // ── Shell（底部 4 Tab / 桌面侧边栏）────────────────────────────────
      ShellRoute(
        builder: (context, state, child) {
          final location = state.matchedLocation;
          return ResponsiveShell(
            location: location,
            child: child,
          );
        },
        routes: [
          GoRoute(path: '/',               builder: (_, _) => const ChatPage()),
          GoRoute(path: R.courseSpace,     builder: (_, _) => const LibraryPage()),
          GoRoute(path: R.toolkit,         builder: (_, _) => const ToolkitPage()),
          GoRoute(path: R.profile,         builder: (_, _) => const ProfilePage()),
        ],
      ),
    ],
  );
});

class _RouterNotifier extends ChangeNotifier {
  bool isLoggedIn = false;

  _RouterNotifier(Ref ref) {
    ref.listen(authProvider, (_, next) {
      isLoggedIn = next.isAuthenticated;
      notifyListeners();
    });
    isLoggedIn = ref.read(authProvider).isAuthenticated;
  }
}

// ── 脑图工坊学科选择页（无 subjectId 时显示）────────────────────────────────

class _MindmapSubjectPickerPage extends ConsumerWidget {
  const _MindmapSubjectPickerPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(schoolSubjectsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('脑图工坊'),
        centerTitle: false,
      ),
      body: subjectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (subjects) {
          if (subjects.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.school_outlined, size: 64, color: cs.outlineVariant),
                    const SizedBox(height: 16),
                    Text('还没有学科', style: TextStyle(color: cs.outline, fontSize: 15)),
                    const SizedBox(height: 8),
                    Text('去「我的 → 学科管理」创建学科',
                        style: TextStyle(color: cs.outline, fontSize: 13)),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: subjects.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final item = subjects[i];
              final pct = item.totalNodes == 0
                  ? 0
                  : (item.litNodes / item.totalNodes * 100).floor();
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push(
                    AppRoutes.courseSpaceById(item.subject.id),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.account_tree_outlined,
                              color: cs.onPrimaryContainer),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.subject.name,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                '${item.sessionCount} 份导图  ·  进度 $pct%',
                                style: TextStyle(
                                    fontSize: 12, color: cs.outline),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: cs.outline),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
