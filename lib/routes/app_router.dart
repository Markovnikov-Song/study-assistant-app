import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/motion/app_motion.dart';
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
        pageBuilder: (context, state) =>
            _motionPage(context, state, const SplashScreen(), root: true),
      ),
      GoRoute(
        path: R.onboarding,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _motionPage(
          context,
          state,
          OnboardingPage(replay: state.uri.queryParameters['replay'] == '1'),
          motion: AppRouteMotion.modal,
        ),
      ),

      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(
        path: R.login,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _motionPage(context, state, const LoginPage(), root: true),
      ),
      GoRoute(
        path: R.register,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _motionPage(context, state, const RegisterPage()),
      ),

      // ── 独立全屏页面（push 覆盖 shell）────────────────────────────────────
      GoRoute(
        path: R.spec,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _motionPage(
          context,
          state,
          SpecPage(
            prefilledSubjectIds: (state.uri.queryParameters['subjects'] ?? '')
                .split(',')
                .where((s) => s.isNotEmpty)
                .map(int.tryParse)
                .whereType<int>()
                .toList(),
            prefilledContext: state.uri.queryParameters['context'],
          ),
          motion: AppRouteMotion.modal,
        ),
      ),
      GoRoute(
        path: R.profileEdit,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _motionPage(context, state, const EditProfilePage()),
      ),
      GoRoute(
        path: R.profileMemory,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _motionPage(context, state, const MemoryPage()),
      ),
      GoRoute(
        path: R.profileSubjects,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _motionPage(context, state, const SubjectsPage()),
      ),
      GoRoute(
        path: R.profileTokenUsage,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _motionPage(context, state, const TokenUsagePage()),
      ),
      GoRoute(
        path: R.profileTokenDetail,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _motionPage(context, state, const TokenDetailPage()),
      ),
      GoRoute(
        path: R.profileNotifications,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _motionPage(context, state, const NotificationSettingsPage()),
      ),
      GoRoute(
        path: R.profileApiConfig,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _motionPage(context, state, const ApiConfigPage()),
      ),
      GoRoute(
        path: R.profileLogs,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _motionPage(context, state, const LogsPage()),
      ),
      GoRoute(
        path: R.profileSettings,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _motionPage(context, state, const SettingsPage()),
      ),
      GoRoute(
        path: R.profileResources,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _motionPage(context, state, const ResourcesPage()),
      ),
      GoRoute(
        path: R.profileHistory,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _motionPage(context, state, const HistoryPage()),
      ),
      GoRoute(
        path: R.skillMarketplace,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _motionPage(context, state, const MarketplacePage()),
      ),
      GoRoute(
        path: R.skillDialogCreate,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _motionPage(context, state, const DialogCreationPage()),
      ),
      GoRoute(
        path: R.workshop,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _motionPage(context, state, const WorkshopPage()),
      ),
      GoRoute(
        path: R.workshopBuilder,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _motionPage(
          context,
          state,
          WorkshopBuilderPage(
            initialRequest: state.uri.queryParameters['request'],
          ),
          motion: AppRouteMotion.drillIn,
        ),
      ),
      GoRoute(
        path: '/workshop/apps/:appId',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _motionPage(
          context,
          state,
          MiniAppRunPage(appId: state.pathParameters['appId']!),
          motion: AppRouteMotion.drillIn,
        ),
      ),
      GoRoute(
        path: R.mindmapEntry,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _motionPage(
          context,
          state,
          MindmapEntryPage(
            initialSubjectId: int.tryParse(
              state.uri.queryParameters['subject'] ?? '',
            ),
            generateOnSelect: state.uri.queryParameters['generate'] == '1',
          ),
        ),
      ),
      GoRoute(
        path: '/profile/resources/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _motionPage(
          context,
          state,
          SubjectDetailPage(subjectId: int.parse(state.pathParameters['id']!)),
          motion: AppRouteMotion.drillIn,
        ),
      ),

      // Chat 子路由（独立全屏，不在 shell 内）
      GoRoute(
        path: '/chat/:chatId',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _motionPage(
          context,
          state,
          ChatPage(chatId: state.pathParameters['chatId']),
          motion: AppRouteMotion.drillIn,
        ),
        routes: [
          GoRoute(
            path: 'subject/:subjectId',
            pageBuilder: (context, state) => _motionPage(
              context,
              state,
              ChatPage(
                chatId: state.pathParameters['chatId'],
                subjectId: int.tryParse(
                  state.pathParameters['subjectId'] ?? '',
                ),
              ),
              motion: AppRouteMotion.drillIn,
            ),
          ),
          GoRoute(
            path: 'task/:taskId',
            pageBuilder: (context, state) => _motionPage(
              context,
              state,
              ChatPage(
                chatId: state.pathParameters['chatId'],
                taskId: state.pathParameters['taskId'],
              ),
              motion: AppRouteMotion.drillIn,
            ),
          ),
        ],
      ),
      // 费曼学习对话路由
      GoRoute(
        path: '/chat/feynman',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _motionPage(
          context,
          state,
          ChatPage(
            chatId: 'feynman_${DateTime.now().millisecondsSinceEpoch}',
            feynmanTopic: state.uri.queryParameters['topic'],
            subjectId: int.tryParse(
              state.uri.queryParameters['subject_id'] ?? '',
            ),
          ),
          motion: AppRouteMotion.drillIn,
        ),
      ),

      // 工具箱子路由
      GoRoute(
        path: R.toolkitMistakeBook,
        pageBuilder: (context, state) =>
            _motionPage(context, state, const MistakeBookPage()),
      ),
      GoRoute(
        path: '/toolkit/review',
        pageBuilder: (context, state) =>
            _motionPage(context, state, const MistakeBookPage()),
      ),
      GoRoute(
        path: R.toolkitSolve,
        pageBuilder: (context, state) =>
            _motionPage(context, state, const SolvePage()),
      ),
      GoRoute(
        path: R.toolkitPractice,
        pageBuilder: (context, state) => _motionPage(
          context,
          state,
          PracticePage(
            execution: CapabilityExecutionContext.fromQuery(
              state.uri.queryParameters,
              capabilityId: 'practice.start',
            ),
          ),
        ),
      ),
      GoRoute(
        path: R.toolkitQuiz,
        pageBuilder: (context, state) => _motionPage(
          context,
          state,
          QuizPage(
            execution: CapabilityExecutionContext.fromQuery(
              state.uri.queryParameters,
              capabilityId: 'quiz.generate',
            ),
          ),
        ),
      ),
      GoRoute(
        path: R.toolkitMemoryDrill,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _motionPage(
          context,
          state,
          MemoryDrillPage(
            execution: CapabilityExecutionContext.fromQuery(
              state.uri.queryParameters,
              capabilityId: 'memory.drill',
            ),
          ),
          motion: AppRouteMotion.drillIn,
        ),
      ),
      GoRoute(
        path: R.toolkitSettings,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _motionPage(context, state, const ToolkitSettingsPage()),
      ),
      GoRoute(
        path: '/my-skills',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _motionPage(context, state, const MySkillsPage()),
      ),
      GoRoute(
        path: R.toolkitCalendar,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _motionPage(
          context,
          state,
          CalendarPage(
            renderMode: state.uri.queryParameters['mode'] ?? 'full',
            sceneSource: state.uri.queryParameters['source'] ?? 'user_active',
            subjectId: int.tryParse(state.uri.queryParameters['subject'] ?? ''),
            prefillDate: state.uri.queryParameters['date'] != null
                ? DateTime.tryParse(state.uri.queryParameters['date']!)
                : null,
          ),
          motion: AppRouteMotion.drillIn,
        ),
        routes: [
          GoRoute(
            path: 'task/:taskId',
            pageBuilder: (context, state) => _motionPage(
              context,
              state,
              CalendarPage(taskId: state.pathParameters['taskId']),
              motion: AppRouteMotion.drillIn,
            ),
          ),
          GoRoute(
            path: 'countdown',
            pageBuilder: (context, state) =>
                _motionPage(context, state, const CountdownListPage()),
          ),
          GoRoute(
            path: 'stats',
            pageBuilder: (context, state) =>
                _motionPage(context, state, const StatsPanel()),
          ),
        ],
      ),
      GoRoute(
        path: R.toolkitMindmapWorkshop,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final subjectId = int.tryParse(
            state.uri.queryParameters['subject'] ?? '',
          );
          final generateOnSelect = state.uri.queryParameters['generate'] == '1';
          if (subjectId != null) {
            // 直接进指定学科的详情页
            return _motionPage(
              context,
              state,
              CourseSpacePage(
                subjectId: subjectId,
                openGenerateOnStart: generateOnSelect,
              ),
              motion: AppRouteMotion.drillIn,
            );
          }
          // 没有指定学科，显示学科选择页
          return _motionPage(
            context,
            state,
            MindmapSubjectPickerPage(generateOnSelect: generateOnSelect),
          );
        },
      ),
      GoRoute(
        path: R.toolkitNotebooks,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _motionPage(context, state, const NotebookListPage()),
        routes: [
          GoRoute(
            path: ':notebookId',
            pageBuilder: (context, state) => _motionPage(
              context,
              state,
              NotebookDetailPage(
                notebookId: int.parse(state.pathParameters['notebookId']!),
              ),
              motion: AppRouteMotion.drillIn,
            ),
            routes: [
              GoRoute(
                path: 'notes/:noteId',
                pageBuilder: (context, state) => _motionPage(
                  context,
                  state,
                  NoteDetailPage(
                    notebookId: int.parse(state.pathParameters['notebookId']!),
                    noteId: int.parse(state.pathParameters['noteId']!),
                  ),
                  motion: AppRouteMotion.drillIn,
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
        pageBuilder: (context, state) => _motionPage(
          context,
          state,
          CourseSpacePage(
            subjectId: int.parse(state.pathParameters['subjectId']!),
            openGenerateOnStart: state.uri.queryParameters['generate'] == '1',
          ),
          motion: AppRouteMotion.drillIn,
        ),
        routes: [
          GoRoute(
            path: 'mindmap/:sessionId',
            pageBuilder: (context, state) => _motionPage(
              context,
              state,
              EditableMindMapPage(
                subjectId: int.parse(state.pathParameters['subjectId']!),
                sessionId: int.parse(state.pathParameters['sessionId']!),
              ),
              motion: AppRouteMotion.drillIn,
            ),
            routes: [
              GoRoute(
                path: 'lecture',
                pageBuilder: (context, state) => _motionPage(
                  context,
                  state,
                  LecturePage(
                    subjectId: int.parse(state.pathParameters['subjectId']!),
                    sessionId: int.parse(state.pathParameters['sessionId']!),
                    nodeId: state.uri.queryParameters['node_id'] ?? '',
                  ),
                  motion: AppRouteMotion.drillIn,
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
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                _motionPage(context, state, const ChatPage(), root: true),
          ),
          GoRoute(
            path: R.courseSpace,
            pageBuilder: (context, state) =>
                _motionPage(context, state, const LibraryPage(), root: true),
          ),
          GoRoute(
            path: R.toolkit,
            pageBuilder: (context, state) =>
                _motionPage(context, state, const ToolkitPage(), root: true),
          ),
          GoRoute(
            path: R.profile,
            pageBuilder: (context, state) =>
                _motionPage(context, state, const ProfilePage(), root: true),
          ),
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

Page<void> _motionPage(
  BuildContext context,
  GoRouterState state,
  Widget child, {
  bool root = false,
  AppRouteMotion motion = AppRouteMotion.standard,
}) {
  return AppMotion.page<void>(
    context,
    state,
    child,
    motion: root ? AppRouteMotion.root : motion,
  );
}
