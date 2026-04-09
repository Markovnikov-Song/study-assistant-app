import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage/storage_service.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/home/shell_page.dart';
import '../features/chat/chat_page.dart';
import '../features/solve/solve_page.dart';
import '../features/mindmap/mindmap_page.dart';
import '../features/quiz/quiz_page.dart';
import '../features/profile/profile_page.dart';
import '../features/subjects/subjects_page.dart';
import '../features/resources/resources_page.dart';
import '../features/subject_detail/subject_detail_page.dart';
import '../features/history/history_page.dart';
import '../features/notebook/notebook_list_page.dart';
import '../features/notebook/notebook_detail_page.dart';
import '../features/notebook/note_detail_page.dart';
import '../features/profile/edit_profile_page.dart';
import '../providers/auth_provider.dart';

class AppRoutes {
  static const login     = '/login';
  static const register  = '/register';
  static const chat      = '/chat';
  static const solve     = '/solve';
  static const mindmap   = '/mindmap';
  static const quiz      = '/quiz';
  static const profile   = '/profile';
  static const subjects  = '/profile/subjects';
  static const resources = '/profile/resources';
  static const history   = '/profile/history';
  static const notebooks   = '/profile/notebooks';
  static const profileEdit = '/profile/edit';

  static String subjectDetailPath(int id) => '/profile/resources/$id';
  static String notebookDetail(int id) => '/profile/notebooks/$id';
  static String noteDetail(int nbId, int noteId) => '/profile/notebooks/$nbId/notes/$noteId';
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    initialLocation: StorageService.instance.isLoggedIn ? AppRoutes.chat : AppRoutes.login,
    refreshListenable: notifier,
    redirect: (context, state) {
      final loggedIn = ref.read(authProvider).isAuthenticated;
      final isAuth = state.matchedLocation == AppRoutes.login || state.matchedLocation == AppRoutes.register;
      if (!loggedIn && !isAuth) return AppRoutes.login;
      if (loggedIn && isAuth) return AppRoutes.chat;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.login,    builder: (_, __) => const LoginPage()),
      GoRoute(path: AppRoutes.register, builder: (_, __) => const RegisterPage()),
      ShellRoute(
        builder: (_, __, child) => ShellPage(child: child),
        routes: [
          GoRoute(path: AppRoutes.chat,    builder: (_, __) => const ChatPage()),
          GoRoute(path: AppRoutes.solve,   builder: (_, __) => const SolvePage()),
          GoRoute(path: AppRoutes.mindmap, builder: (_, __) => const MindMapPage()),
          GoRoute(path: AppRoutes.quiz,    builder: (_, __) => const QuizPage()),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, __) => const ProfilePage(),
            routes: [
              GoRoute(path: 'subjects',  builder: (_, __) => const SubjectsPage()),
              GoRoute(path: 'resources', builder: (_, __) => const ResourcesPage()),
              GoRoute(path: 'history',   builder: (_, __) => const HistoryPage()),
              GoRoute(path: 'edit',      builder: (_, __) => const EditProfilePage()),
              GoRoute(
                path: 'resources/:id',
                builder: (_, state) => SubjectDetailPage(subjectId: int.parse(state.pathParameters['id']!)),
              ),
              GoRoute(
                path: 'notebooks',
                builder: (_, __) => const NotebookListPage(),
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
            ],
          ),
        ],
      ),
    ],
  );
});

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}
