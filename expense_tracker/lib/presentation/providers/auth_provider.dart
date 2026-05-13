import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/failures.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login.dart';
import '../../domain/usecases/signup.dart';
import '../../core/di.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;

  AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({bool? isAuthenticated, bool? isLoading, String? error}) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _authRepo;
  late final Login _login;
  late final Signup _signup;

  @override
  AuthState build() {
    final di = DI();
    _authRepo = di.authRepo;
    _login = di.login;
    _signup = di.signup;
    return AuthState();
  }

  Future<void> checkAuth() async {
    final authenticated = await _authRepo.isAuthenticated();
    if (authenticated != state.isAuthenticated) {
      state = AuthState(isAuthenticated: authenticated);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _login(email, password);
      state = AuthState(isAuthenticated: true);
    } on Failure catch (f) {
      state = state.copyWith(isLoading: false, error: f.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Login failed');
    }
  }

  Future<void> signup(String email, String password, String name) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _signup(email, password, name);
      state = AuthState(isAuthenticated: true);
    } on Failure catch (f) {
      state = state.copyWith(isLoading: false, error: f.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Signup failed');
    }
  }

  Future<void> logout() async {
    await _authRepo.logout();
    state = AuthState(isAuthenticated: false);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
