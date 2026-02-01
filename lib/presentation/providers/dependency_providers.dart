import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/datasources/github_remote_datasource.dart';
import '../../data/datasources/secure_storage_local_datasource.dart';
import '../../data/repositories/github_repository_impl.dart';
import '../../data/repositories/local_storage_repository_impl.dart';
import '../../domain/entities/user_config.dart';
import '../../domain/repositories/github_repository.dart';
import '../../domain/repositories/local_storage_repository.dart';
import '../../domain/usecases/delete_note.dart';
import '../../domain/usecases/get_note.dart';
import '../../domain/usecases/get_note_history.dart';
import '../../domain/usecases/get_notes.dart';
import '../../domain/usecases/login.dart';
import '../../domain/usecases/logout.dart';
import '../../domain/usecases/save_note.dart';

// ==================== EXTERNAL DEPENDENCIES ====================

final dioProvider = Provider<Dio>((ref) => Dio());

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

// ==================== USER CONFIG ====================

final userConfigProvider = StateProvider<UserConfig?>((ref) => null);

// ==================== DATA SOURCES ====================

final localStorageDataSourceProvider = Provider<ILocalStorageDataSource>(
  (ref) => SecureStorageLocalDataSource(
    storage: ref.watch(secureStorageProvider),
  ),
);

final githubRemoteDataSourceProvider = Provider<IGitHubRemoteDataSource>((ref) {
  final userConfig = ref.watch(userConfigProvider);
  if (userConfig == null) {
    throw Exception('User not authenticated');
  }
  
  return GitHubRemoteDataSource(
    dio: ref.watch(dioProvider),
    username: userConfig.username,
    repository: userConfig.repository,
    pat: userConfig.pat,
  );
});

// ==================== REPOSITORIES ====================

final localStorageRepositoryProvider = Provider<ILocalStorageRepository>(
  (ref) => LocalStorageRepositoryImpl(
    localDataSource: ref.watch(localStorageDataSourceProvider),
  ),
);

final githubRepositoryProvider = Provider<IGitHubRepository>((ref) {
  return GitHubRepositoryImpl(
    remoteDataSource: ref.watch(githubRemoteDataSourceProvider),
  );
});

// ==================== USE CASES ====================

final loginUseCaseProvider = Provider<Login>(
  (ref) => Login(
    githubRepository: ref.watch(githubRepositoryProvider),
    localStorageRepository: ref.watch(localStorageRepositoryProvider),
  ),
);

final logoutUseCaseProvider = Provider<Logout>(
  (ref) => Logout(
    ref.watch(localStorageRepositoryProvider),
  ),
);

final getNotesUseCaseProvider = Provider<GetNotes>(
  (ref) => GetNotes(
    ref.watch(githubRepositoryProvider),
  ),
);

final getNoteUseCaseProvider = Provider<GetNote>(
  (ref) => GetNote(
    ref.watch(githubRepositoryProvider),
  ),
);

final saveNoteUseCaseProvider = Provider<SaveNote>(
  (ref) => SaveNote(
    ref.watch(githubRepositoryProvider),
  ),
);

final deleteNoteUseCaseProvider = Provider<DeleteNote>(
  (ref) => DeleteNote(
    ref.watch(githubRepositoryProvider),
  ),
);

final getNoteHistoryUseCaseProvider = Provider<GetNoteHistory>(
  (ref) => GetNoteHistory(
    ref.watch(githubRepositoryProvider),
  ),
);
