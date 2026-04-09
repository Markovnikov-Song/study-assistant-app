import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    initialLocation: AppRoutes.chat,
    refreshListenable: notifier,
    redirect: (context, state) {
      final loggedIn = ref.read(authProvider).isAuthenticated;
      final isAuth = state.matchedLocation == AppRoutes.login || state.matchedLocation == AppRoutes.register;
      if (!loggedIn && !isAuth) return AppRoutes.login;
      if (loggedIn && isAuth) return AppRoutes.chat;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.login,    builder: (_, _) => const LoginPage()),
      GoRoute(path: AppRoutes.register, builder: (_, _) => const RegisterPage()),
      ShellRoute(
        builder: (_, _, child) => ShellPage(child: child),
        routes: [
          GoRoute(path: AppRoutes.chat,    builder: (_, _) => const ChatPage()),
          GoRoute(path: AppRoutes.solve,   builder: (_, _) => const SolvePage()),
          GoRoute(path: AppRoutes.mindmap, builder: (_, _) => const MindMapPage()),
          GoRoute(path: AppRoutes.quiz,    builder: (_, _) => const QuizPage()),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, _) => const ProfilePage(),
            routes: [
              GoRoute(path: 'subjects',  builder: (_, _) => const SubjectsPage()),
              GoRoute(path: 'resources', builder: (_, _) => const ResourcesPage()),
              GoRoute(path: 'history',   builder: (_, _) => const HistoryPage()),
              GoRoute(path: 'edit',      builder: (_, _) => const EditProfilePage()),
              GoRoute(
                path: 'resources/:id',
                builder: (_, state) => SubjectDetailPage(subjectId: int.parse(state.pathParameters['id']!)),
              ),
              GoRoute(
                path: 'notebooks',
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
            ],
          ),
        ],
      ),
    ],
  );
});

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen(authProvider, (_, _) => notifyListeners());
  }
}
