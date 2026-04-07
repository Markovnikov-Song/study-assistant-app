import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage/storage_service.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/subjects/subjects_page.dart';
import '../features/subject_detail/subject_detail_page.dart';
import '../features/history/history_page.dart';

class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const subjects = '/';
  static const subjectDetail = '/subject/:id';
  static const history = '/history';

  static String subjectDetailPath(int id) => '/subject/$id';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: StorageService.instance.isLoggedIn
        ? AppRoutes.subjects
        : AppRoutes.login,
    redirect: (context, state) {
      final isLoggedIn = StorageService.instance.isLoggedIn;
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;
      if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;
      if (isLoggedIn && isAuthRoute) return AppRoutes.subjects;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginPage()),
      GoRoute(path: AppRoutes.register, builder: (_, __) => const RegisterPage()),
      GoRoute(path: AppRoutes.subjects, builder: (_, __) => const SubjectsPage()),
      GoRoute(
        path: AppRoutes.subjectDetail,
        builder: (_, state) {
          final id = int.parse(state.pathParameters['id']!);
          return SubjectDetailPage(subjectId: id);
        },
      ),
      GoRoute(path: AppRoutes.history, builder: (_, __) => const HistoryPage()),
    ],
  );
});
