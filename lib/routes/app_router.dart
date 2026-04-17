import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/home/shell_page.dart';
import '../features/classroom/classroom_page.dart';
import '../components/library/library_page.dart';
import '../components/library/course_space_page.dart';
import '../components/library/editable_mindmap_page.dart';
import '../components/library/lecture/lecture_page.dart';
import '../components/mistake_book/stationery_page.dart';
import '../components/mistake_book/mistake_book_page.dart';
import '../features/profile/profile_page.dart';
import '../features/subjects/subjects_page.dart';
import '../features/resources/resources_page.dart';
import '../features/subject_detail/subject_detail_page.dart';
import '../features/history/history_page.dart';
import '../components/notebook/notebook_list_page.dart';
import '../components/notebook/notebook_detail_page.dart';
import '../components/notebook/note_detail_page.dart';
import '../features/profile/edit_profile_page.dart';
import '../features/profile/memory_page.dart';
import '../providers/auth_provider.dart';
import '../features/skill_marketplace/marketplace_page.dart';
import '../features/skill_creation/dialog_creation_page.dart';

class AppRoutes {
  static const login       = '/login';
  static const register    = '/register';
  static const classroom   = '/classroom';  // 答疑室
  static const library     = '/library';    // 学校（学科 → 大纲 → 思维导图 → 讲义）
  static const stationery  = '/stationery'; // 文具盒
  static const mistakeBook = '/mistakes'; // 错题本（顶层路由，push 覆盖 shell）
  static const profile     = '/profile';
  static const subjects    = '/profile/subjects';
  static const resources   = '/profile/resources';
  static const history     = '/profile/history';
  static const notebooks   = '/profile/notebooks';
  static const profileEdit = '/profile/edit';
  static const memory      = '/profile/memory';

  // 答疑室内部子功能别名（跳转到答疑室即可）
  static const chat     = '/classroom';
  static const solve    = '/classroom';
  static const mindmap  = '/classroom';
  static const quiz     = '/classroom';

  static String subjectDetailPath(int id) => '/profile/resources/$id';
  static String notebookDetail(int id) => '/profile/notebooks/$id';
  static String noteDetail(int nbId, int noteId) => '/profile/notebooks/$nbId/notes/$noteId';

  // Skill 生态路由
  static const skillMarketplace  = '/skill-marketplace';   // 学习方法库（DIY 模式入口）
  static const skillDialogCreate = '/skill-create-dialog'; // 对话式创建学习方法

  // Library nested routes
  static String courseSpace(int subjectId) => '/library/$subjectId';
  static String editableMindMap(int subjectId, int sessionId) =>
      '/library/$subjectId/mindmap/$sessionId';
  static String lecturePage(int subjectId, int sessionId, String nodeId) =>
      '/library/$subjectId/mindmap/$sessionId/lecture?node_id=${Uri.encodeQueryComponent(nodeId)}';
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    initialLocation: AppRoutes.classroom,
    refreshListenable: notifier,
    redirect: (context, state) {
      final loggedIn = notifier.isLoggedIn;
      final isAuth = state.matchedLocation == AppRoutes.login || state.matchedLocation == AppRoutes.register;
      if (!loggedIn && !isAuth) return AppRoutes.login;
      if (loggedIn && isAuth) return AppRoutes.classroom;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.login,    builder: (_, _) => const LoginPage()),
      GoRoute(path: AppRoutes.register, builder: (_, _) => const RegisterPage()),
      // profile 子页面放在顶层，push 时覆盖整个 shell
      GoRoute(path: AppRoutes.profileEdit, builder: (_, _) => const EditProfilePage()),
      GoRoute(path: AppRoutes.memory,      builder: (_, _) => const MemoryPage()),
      GoRoute(path: AppRoutes.subjects,    builder: (_, _) => const SubjectsPage()),
      GoRoute(path: AppRoutes.resources,   builder: (_, _) => const ResourcesPage()),
      GoRoute(path: AppRoutes.history,     builder: (_, _) => const HistoryPage()),
      GoRoute(path: AppRoutes.mistakeBook, builder: (_, _) => const MistakeBookPage()),
      GoRoute(path: AppRoutes.skillMarketplace,  builder: (_, _) => const MarketplacePage()),
      GoRoute(path: AppRoutes.skillDialogCreate, builder: (_, _) => const DialogCreationPage()),
      GoRoute(
        path: '/profile/resources/:id',
        builder: (_, state) => SubjectDetailPage(subjectId: int.parse(state.pathParameters['id']!)),
      ),
      // library 子页面也放顶层，push 时覆盖整个 shell
      GoRoute(
        path: '/library/:subjectId',
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
      ),      GoRoute(
        path: AppRoutes.notebooks,
        builder: (_, _) => const NotebookListPage(),
        routes: [
          GoRoute(
            path: ':nbId',
            builder: (_, state) => NotebookDetailPage(
              notebookId: int.parse(state.pathParameters['nbId']!),
            ),
            routes: [
              GoRoute(
                path: 'notes/:noteId',
                builder: (_, state) => NoteDetailPage(
                  notebookId: int.parse(state.pathParameters['nbId']!),
                  noteId: int.parse(state.pathParameters['noteId']!),
                ),
              ),
            ],
          ),
        ],
      ),
      ShellRoute(
        builder: (_, _, child) => ShellPage(child: child),
        routes: [
          GoRoute(path: AppRoutes.classroom,  builder: (_, _) => const ClassroomPage()),
          GoRoute(
            path: AppRoutes.library,
            builder: (_, _) => const LibraryPage(),
          ),
          GoRoute(
            path: AppRoutes.stationery,
            builder: (_, _) => const StationeryPage(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, _) => const ProfilePage(),
          ),
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

// Placeholder pages — will be replaced by full implementations in later tasks.