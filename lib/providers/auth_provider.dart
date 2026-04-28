import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../core/storage/storage_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  final bool isRestoring; // 正在从本地 token 恢复登录状态

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isRestoring = false,
  });
  bool get isAuthenticated => user != null;

  AuthState copyWith({User? user, bool? isLoading, String? error, bool? isRestoring}) => AuthState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        isRestoring: isRestoring ?? this.isRestoring,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _service;
  AuthNotifier(this._service) : super(const AuthState(isRestoring: true)) {
    _restoreSession();
  }

  /// App 启动时从本地 token 恢复登录状态，避免删后台后要重新登录
  Future<void> _restoreSession() async {
    final token = await StorageService.instance.getToken();
    if (token != null && token.isNotEmpty) {
      try {
        final user = await _service.getMe();
        if (mounted) state = AuthState(user: user, isRestoring: false);
      } catch (_) {
        await StorageService.instance.clearTokens();
        if (mounted) state = const AuthState(isRestoring: false);
      }
    } else {
      if (mounted) state = const AuthState(isRestoring: false);
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _service.login(username, password);
      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<bool> register(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _service.register(username, password);
      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _service.logout();
    state = const AuthState();
  }

  void updateUsername(String newUsername) {
    if (state.user == null) return;
    state = state.copyWith(user: state.user!.copyWith(username: newUsername));
  }

  void updateAvatar(String base64) {
    if (state.user == null) return;
    state = state.copyWith(user: state.user!.copyWith(avatarBase64: base64));
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(authServiceProvider)),
);
