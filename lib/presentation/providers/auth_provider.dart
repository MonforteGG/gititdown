import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/error/failures.dart';
import '../../core/utils/usecase.dart';
import '../../domain/entities/user_config.dart';
import '../../domain/usecases/login.dart';
import 'dependency_providers.dart';
import 'note_history_provider.dart';
import 'notes_provider.dart';
import 'search_provider.dart';

// Auth State
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final UserConfig? userConfig;
  final Failure? failure;
  final bool isCheckingStoredAuth;

  const AuthState({
    this.status = AuthStatus.initial,
    this.userConfig,
    this.failure,
    this.isCheckingStoredAuth = true,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserConfig? userConfig,
    Failure? failure,
    bool? isCheckingStoredAuth,
    bool clearFailure = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      userConfig: userConfig ?? this.userConfig,
      failure: clearFailure ? null : (failure ?? this.failure),
      isCheckingStoredAuth: isCheckingStoredAuth ?? this.isCheckingStoredAuth,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AuthState()) {
    _checkExistingAuth();
  }

  void _clearSessionState() {
    _ref.read(userConfigProvider.notifier).state = null;
    _ref.read(notesProvider.notifier).reset();
    _ref.read(vaultSearchProvider.notifier).reset();
    _ref.read(noteHistoryProvider.notifier).reset();
  }

  Future<void> _checkExistingAuth() async {
    state = state.copyWith(
      status: AuthStatus.loading,
      clearFailure: true,
      isCheckingStoredAuth: true,
    );
    
    final localStorageRepo = _ref.read(localStorageRepositoryProvider);
    final hasValidConfig = await localStorageRepo.hasValidConfig();
    
    hasValidConfig.fold(
      (failure) {
        _clearSessionState();
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          failure: failure,
          isCheckingStoredAuth: false,
        );
      },
      (hasValid) async {
        if (hasValid) {
          final configResult = await localStorageRepo.getUserConfig();
          configResult.fold(
            (failure) {
              _clearSessionState();
              state = state.copyWith(
                status: AuthStatus.unauthenticated,
                failure: failure,
                isCheckingStoredAuth: false,
              );
            },
            (config) {
              if (config != null) {
                _ref.read(userConfigProvider.notifier).state = config;
                state = state.copyWith(
                  status: AuthStatus.authenticated,
                  userConfig: config,
                  isCheckingStoredAuth: false,
                );
              } else {
                _clearSessionState();
                state = state.copyWith(
                  status: AuthStatus.unauthenticated,
                  isCheckingStoredAuth: false,
                );
              }
            },
          );
        } else {
          _clearSessionState();
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            isCheckingStoredAuth: false,
          );
        }
      },
    );
  }

  Future<void> login(String username, String repository, String pat) async {
    state = state.copyWith(
      status: AuthStatus.loading,
      clearFailure: true,
      isCheckingStoredAuth: false,
    );
    
    final config = UserConfig(
      username: username,
      repository: repository,
      pat: pat,
    );

    final loginUseCase = _ref.read(loginUseCaseProvider);
    final result = await loginUseCase(LoginParams(config: config));
    
    result.fold(
      (failure) {
        _clearSessionState();
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          failure: failure,
          isCheckingStoredAuth: false,
        );
      },
      (success) {
        _ref.read(userConfigProvider.notifier).state = config;
        state = state.copyWith(
          status: AuthStatus.authenticated,
          userConfig: config,
          isCheckingStoredAuth: false,
        );
      },
    );
  }

  Future<void> logout() async {
    state = state.copyWith(
      status: AuthStatus.loading,
      isCheckingStoredAuth: false,
    );
    
    final logoutUseCase = _ref.read(logoutUseCaseProvider);
    final result = await logoutUseCase(const NoParams());
    
    result.fold(
      (failure) => state = state.copyWith(
        status: AuthStatus.error,
        failure: failure,
        isCheckingStoredAuth: false,
      ),
      (_) {
        _clearSessionState();
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          isCheckingStoredAuth: false,
        );
      },
    );
  }

  void clearError() {
    state = state.copyWith(
      clearFailure: true,
      status: AuthStatus.unauthenticated,
      isCheckingStoredAuth: false,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);
