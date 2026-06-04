import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/home/responsive_shell.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/chat/chat_page.dart';
import '../screens/splash_screen.dart';
import '../features/spec/spec_page.dart';
import '../features/toolkit/toolkit_page.dart';
import '../features/toolkit/toolkit_settings_page.dart';
import '../features/practice/practice_page.dart';
import '../features/profile/profile_page.dart';
import '../features/profile/edit_profile_page.dart';
import '../features/profile/memory_page.dart';
import '../features/profile/token_usage_page.dart';
import '../features/profile/token_detail_page.dart';
import '../features/profile/api_config_page.dart';
import '../features/profile/logs_page.dart';
import '../features/subjects/subjects_page.dart';
import '../features/resources/resources_page.dart';
import '../features/history/history_page.dart';
import '../features/subject_detail/subject_detail_page.dart';
import '../features/skill_marketplace/marketplace_page.dart';
import '../features/skill_creation/dialog_creation_page.dart';
import '../features/workshop/workshop_builder_page.dart';
import '../features/workshop/workshop_page.dart';
import '../features/workshop/mini_app_run_page.dart';
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
import '../core/capability/capability_execution_contract.dart';
import '../features/memory_drill/memory_drill_page.dart';
import '../features/skill_runner/my_skills_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/calendar/widgets/countdown_list_page.dart';
import '../features/calendar/widgets/stats_panel.dart';
import '../features/profile/notification_settings_page.dart';
import '../features/profile/settings_page.dart';
import '../providers/auth_provider.dart';
import 'app_routes.dart';
import 'mindmap_subject_picker_page.dart';
export 'app_routes.dart';

/// Root navigator for full-screen routes (course space, mindmap, chat detail, …).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Nested navigator inside [ShellRoute] (bottom / side tabs).
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

// Router provider.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final loggedIn = notifier.isLoggedIn;
      final isRestoring = notifier.isRestoring;
      final loc = state.matchedLocation;
      final isAuth = loc == R.login || loc == R.register;
      final isSplash = loc == '/splash';
      final isOnboarding = loc == R.onboarding;
      // Splash 页面和恢复中不做登录检查
      if (isSplash || isOnboarding || isRestoring) return null;
      if (!loggedIn && !isAuth) return R.login;
      if (loggedIn && isAuth) return R.chat;
      return null;
    },
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('页面不存在: ${state.uri}'))),
    routes: [
      // ── Splash（开屏动画）──────────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: R.onboarding,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            OnboardingPage(replay: state.uri.queryParameters['replay'] == '1'),
      ),

      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(
        path: R.login,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const LoginPage(),
      ),
      GoRoute(
        path: R.register,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const RegisterPage(),
      ),

      // ── 独立全屏页面（push 覆盖 shell）────────────────────────────────────
      GoRoute(
        path: R.spec,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => SpecPage(
          prefilledSubjectIds: (state.uri.queryParameters['subjects'] ?? '')
              .split(',')
              .where((s) => s.isNotEmpty)
              .map(int.tryParse)
              .whereType<int>()
              .toList(),
          prefilledContext: state.uri.queryParameters['context'],
        ),
      ),
      GoRoute(
        path: R.profileEdit,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const EditProfilePage(),
      ),
      GoRoute(
        path: R.profileMemory,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const MemoryPage(),
      ),
      GoRoute(
        path: R.profileSubjects,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const SubjectsPage(),
      ),
      GoRoute(
        path: R.profileTokenUsage,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const TokenUsagePage(),
      ),
      GoRoute(
        path: R.profileTokenDetail,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const TokenDetailPage(),
      ),
      GoRoute(
        path: R.profileNotifications,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const NotificationSettingsPage(),
      ),
      GoRoute(
        path: R.profileApiConfig,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const ApiConfigPage(),
      ),
      GoRoute(
        path: R.profileLogs,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const LogsPage(),
      ),
      GoRoute(
        path: R.profileSettings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const SettingsPage(),
      ),
      GoRoute(
        path: R.profileResources,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const ResourcesPage(),
      ),
      GoRoute(
        path: R.profileHistory,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const HistoryPage(),
      ),
      GoRoute(
        path: R.skillMarketplace,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const MarketplacePage(),
      ),
      GoRoute(
        path: R.skillDialogCreate,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const DialogCreationPage(),
      ),
      GoRoute(
        path: R.workshop,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const WorkshopPage(),
      ),
      GoRoute(
        path: R.workshopBuilder,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => WorkshopBuilderPage(
          initialRequest: state.uri.queryParameters['request'],
        ),
      ),
      GoRoute(
        path: '/workshop/apps/:appId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            MiniAppRunPage(appId: state.pathParameters['appId']!),
      ),
      GoRoute(
        path: R.mindmapEntry,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => MindmapEntryPage(
          initialSubjectId: int.tryParse(
            state.uri.queryParameters['subject'] ?? '',
          ),
          generateOnSelect: state.uri.queryParameters['generate'] == '1',
        ),
      ),
      GoRoute(
        path: '/profile/resources/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => SubjectDetailPage(
          subjectId: int.parse(state.pathParameters['id']!),
        ),
      ),

      // Chat 子路由（独立全屏，不在 shell 内）
      GoRoute(
        path: '/chat/:chatId',
        parentNavigatorKey: rootNavigatorKey,
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
      // 费曼学习对话路由
      GoRoute(
        path: '/chat/feynman',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => ChatPage(
          chatId: 'feynman_${DateTime.now().millisecondsSinceEpoch}',
          feynmanTopic: state.uri.queryParameters['topic'],
          subjectId: int.tryParse(
            state.uri.queryParameters['subject_id'] ?? '',
          ),
        ),
      ),

      // 工具箱子路由
      GoRoute(
        path: R.toolkitMistakeBook,
        builder: (_, _) => const MistakeBookPage(),
      ),
      GoRoute(path: '/toolkit/review', builder: (_, _) => const MistakeBookPage()),
      GoRoute(path: R.toolkitSolve, builder: (_, _) => const SolvePage()),
      GoRoute(
        path: R.toolkitPractice,
        builder: (_, state) => PracticePage(
          execution: CapabilityExecutionContext.fromQuery(
            state.uri.queryParameters,
            capabilityId: 'practice.start',
          ),
        ),
      ),
      GoRoute(
        path: R.toolkitQuiz,
        builder: (_, state) => QuizPage(
          execution: CapabilityExecutionContext.fromQuery(
            state.uri.queryParameters,
            capabilityId: 'quiz.generate',
          ),
        ),
      ),
      GoRoute(
        path: R.toolkitMemoryDrill,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => MemoryDrillPage(
          execution: CapabilityExecutionContext.fromQuery(
            state.uri.queryParameters,
            capabilityId: 'memory.drill',
          ),
        ),
      ),
      GoRoute(
        path: R.toolkitSettings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const ToolkitSettingsPage(),
      ),
      GoRoute(
        path: '/my-skills',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const MySkillsPage(),
      ),
      GoRoute(
        path: R.toolkitCalendar,
        parentNavigatorKey: rootNavigatorKey,
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
            builder: (_, state) =>
                CalendarPage(taskId: state.pathParameters['taskId']),
          ),
          GoRoute(
            path: 'countdown',
            builder: (_, _) => const CountdownListPage(),
          ),
          GoRoute(path: 'stats', builder: (_, _) => const StatsPanel()),
        ],
      ),
      GoRoute(
        path: R.toolkitMindmapWorkshop,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) {
          final subjectId = int.tryParse(
            state.uri.queryParameters['subject'] ?? '',
          );
          final generateOnSelect = state.uri.queryParameters['generate'] == '1';
          if (subjectId != null) {
            // 直接进指定学科的详情页
            return CourseSpacePage(
              subjectId: subjectId,
              openGenerateOnStart: generateOnSelect,
            );
          }
          // 没有指定学科，显示学科选择页
          return MindmapSubjectPickerPage(generateOnSelect: generateOnSelect);
        },
      ),
      GoRoute(
        path: R.toolkitNotebooks,
        parentNavigatorKey: rootNavigatorKey,
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
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => CourseSpacePage(
          subjectId: int.parse(state.pathParameters['subjectId']!),
          openGenerateOnStart: state.uri.queryParameters['generate'] == '1',
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
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          final location = state.uri.path.isEmpty ? '/' : state.uri.path;
          return ResponsiveShell(location: location, child: child);
        },
        routes: [
          GoRoute(path: '/', builder: (_, _) => const ChatPage()),
          GoRoute(path: R.courseSpace, builder: (_, _) => const LibraryPage()),
          GoRoute(path: R.toolkit, builder: (_, _) => const ToolkitPage()),
          GoRoute(path: R.profile, builder: (_, _) => const ProfilePage()),
        ],
      ),
    ],
  );
});

class _RouterNotifier extends ChangeNotifier {
  bool isLoggedIn = false;
  bool isRestoring = true;

  _RouterNotifier(Ref ref) {
    ref.listen(authProvider, (_, next) {
      isLoggedIn = next.isAuthenticated;
      isRestoring = next.isRestoring;
      notifyListeners();
    });
    isLoggedIn = ref.read(authProvider).isAuthenticated;
    isRestoring = ref.read(authProvider).isRestoring;
  }
}
