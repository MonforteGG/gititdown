import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/error/failures.dart';
import '../../core/utils/usecase.dart';
import '../../domain/entities/user_config.dart';
import '../../domain/usecases/login.dart';
import '../../domain/usecases/logout.dart';
import 'dependency_providers.dart';

// Auth State
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final UserConfig? userConfig;
  final Failure? failure;

  const AuthState({
    this.status = AuthStatus.initial,
    this.userConfig,
    this.failure,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserConfig? userConfig,
    Failure? failure,
  }) {
    return AuthState(
      status: status ?? this.status,
      userConfig: userConfig ?? this.userConfig,
      failure: failure ?? this.failure,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AuthState()) {
    _checkExistingAuth();
  }

  Future<void> _checkExistingAuth() async {
    state = state.copyWith(status: AuthStatus.loading);
    
    final localStorageRepo = _ref.read(localStorageRepositoryProvider);
    final hasValidConfig = await localStorageRepo.hasValidConfig();
    
    hasValidConfig.fold(
      (failure) => state = state.copyWith(
        status: AuthStatus.unauthenticated,
        failure: failure,
      ),
      (hasValid) async {
        if (hasValid) {
          final configResult = await localStorageRepo.getUserConfig();
          configResult.fold(
            (failure) => state = state.copyWith(
              status: AuthStatus.unauthenticated,
              failure: failure,
            ),
            (config) {
              if (config != null) {
                _ref.read(userConfigProvider.notifier).state = config;
                state = state.copyWith(
                  status: AuthStatus.authenticated,
                  userConfig: config,
                );
              } else {
                state = state.copyWith(status: AuthStatus.unauthenticated);
              }
            },
          );
        } else {
          state = state.copyWith(status: AuthStatus.unauthenticated);
        }
      },
    );
  }

  Future<void> login(String username, String repository, String pat) async {
    state = state.copyWith(status: AuthStatus.loading, failure: null);
    
    final config = UserConfig(
      username: username,
      repository: repository,
      pat: pat,
    );
    
    // Temporarily set the user config so the use case can access it
    _ref.read(userConfigProvider.notifier).state = config;
    
    final loginUseCase = _ref.read(loginUseCaseProvider);
    final result = await loginUseCase(LoginParams(config: config));
    
    result.fold(
      (failure) {
        _ref.read(userConfigProvider.notifier).state = null;
        state = state.copyWith(
          status: AuthStatus.error,
          failure: failure,
        );
      },
      (success) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          userConfig: config,
        );
      },
    );
  }

  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading);
    
    final logoutUseCase = _ref.read(logoutUseCaseProvider);
    final result = await logoutUseCase(const NoParams());
    
    result.fold(
      (failure) => state = state.copyWith(
        status: AuthStatus.error,
        failure: failure,
      ),
      (_) {
        _ref.read(userConfigProvider.notifier).state = null;
        state = const AuthState(status: AuthStatus.unauthenticated);
      },
    );
  }

  void clearError() {
    state = state.copyWith(failure: null, status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);
