import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

class AuthState {
  final Map<String, dynamic>? user;
  final String? token;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
  });

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  AuthState copyWith({
    Map<String, dynamic>? user,
    String? token,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _autoLogin();
  }

  Future<void> _autoLogin() async {
    await ApiService.instance.init();
    final token = ApiService.instance.token;
    if (token != null) {
      state = state.copyWith(isLoading: true, token: token);
      try {
        final user = await ApiService.instance.getMe();
        if (user != null) {
          state = state.copyWith(user: user, isLoading: false);
        } else {
          state = const AuthState();
        }
      } catch (_) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await ApiService.instance.login(email, password);
      final token = res['access_token'] as String;
      final user = res['user'] as Map<String, dynamic>;
      state = AuthState(user: user, token: token, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> register(String email, String password, String fullName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await ApiService.instance.register(email, password, fullName);
      final token = res['access_token'] as String;
      final user = res['user'] as Map<String, dynamic>;
      state = AuthState(user: user, token: token, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<void> logout() async {
    await ApiService.instance.saveToken(null);
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
