import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/constants.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/note.dart';
import '../../domain/entities/user_config.dart';
import '../../domain/usecases/get_file.dart';
import '../../domain/usecases/get_file_bytes.dart';
import '../../domain/usecases/save_note.dart';
import 'dependency_providers.dart';

class LibraryPreferencesState {
  final bool isLoaded;
  final Set<String> favorites;
  final List<String> recent;
  final String prefsSha;

  const LibraryPreferencesState({
    this.isLoaded = false,
    this.favorites = const {},
    this.recent = const [],
    this.prefsSha = '',
  });

  LibraryPreferencesState copyWith({
    bool? isLoaded,
    Set<String>? favorites,
    List<String>? recent,
    String? prefsSha,
  }) {
    return LibraryPreferencesState(
      isLoaded: isLoaded ?? this.isLoaded,
      favorites: favorites ?? this.favorites,
      recent: recent ?? this.recent,
      prefsSha: prefsSha ?? this.prefsSha,
    );
  }
}

class LibraryPreferencesNotifier extends StateNotifier<LibraryPreferencesState> {
  final Ref _ref;
  Future<void>? _loadFuture;

  LibraryPreferencesNotifier(this._ref) : super(const LibraryPreferencesState()) {
    _load();
  }

  Future<void> _load() async {
    if (_loadFuture != null) {
      return _loadFuture!;
    }

    _loadFuture = _performLoad();
    try {
      await _loadFuture;
    } finally {
      _loadFuture = null;
    }
  }

  Future<void> _performLoad() async {
    final config = _ref.read(userConfigProvider);
    if (config == null) {
      state = const LibraryPreferencesState(isLoaded: true);
      return;
    }

    final getFileResult = await _ref.read(getFileUseCaseProvider)(
      const GetFileParams(path: AppConstants.appPreferencesPath),
    );

    await getFileResult.fold(
      (failure) async {
        if (failure is NotFoundFailure) {
          state = const LibraryPreferencesState(isLoaded: true);
          return;
        }
        state = const LibraryPreferencesState(isLoaded: true);
      },
      (file) async {
        final bytesResult = await _ref.read(getFileBytesUseCaseProvider)(
          const GetFileBytesParams(path: AppConstants.appPreferencesPath),
        );

        bytesResult.fold(
          (_) {
            state = LibraryPreferencesState(
              isLoaded: true,
              prefsSha: file.sha,
            );
          },
          (bytes) {
            final decoded = utf8.decode(bytes, allowMalformed: true);
            final parsed = jsonDecode(decoded) as Map<String, dynamic>;
            final favorites = ((parsed['favorites'] as List<dynamic>?) ?? const [])
                .cast<String>()
                .toSet();
            final recent = ((parsed['recent'] as List<dynamic>?) ?? const [])
                .cast<String>();

            state = LibraryPreferencesState(
              isLoaded: true,
              favorites: favorites,
              recent: recent,
              prefsSha: file.sha,
            );
          },
        );
      },
    );
  }

  Future<void> handleUserConfigChanged(UserConfig? next) async {
    if (next == null) {
      state = const LibraryPreferencesState(isLoaded: true);
      return;
    }
    await _load();
  }

  bool isFavorite(String path) => state.favorites.contains(path);

  Future<bool> toggleFavorite(String path) async {
    if (!state.isLoaded) {
      await _load();
    }
    final updatedFavorites = Set<String>.from(state.favorites);
    final isNowFavorite = updatedFavorites.add(path);
    if (!isNowFavorite) {
      updatedFavorites.remove(path);
    }
    state = state.copyWith(favorites: updatedFavorites);
    await _persist();
    return isNowFavorite;
  }

  Future<void> recordRecent(String path) async {
    if (!state.isLoaded) {
      await _load();
    }
    final updatedRecent = List<String>.from(state.recent)
      ..remove(path)
      ..insert(0, path);
    if (updatedRecent.length > 20) {
      updatedRecent.removeRange(20, updatedRecent.length);
    }
    state = state.copyWith(recent: updatedRecent);
    await _persist();
  }

  Future<void> removePath(String path, {bool recursive = false}) async {
    bool matches(String candidate) =>
        candidate == path || (recursive && candidate.startsWith('$path/'));

    state = state.copyWith(
      favorites: state.favorites.where((candidate) => !matches(candidate)).toSet(),
      recent: state.recent.where((candidate) => !matches(candidate)).toList(),
    );
    await _persist();
  }

  Future<void> replacePath(String oldPath, String newPath, {bool recursive = false}) async {
    String remap(String candidate) {
      if (candidate == oldPath) return newPath;
      if (recursive && candidate.startsWith('$oldPath/')) {
        return candidate.replaceFirst('$oldPath/', '$newPath/');
      }
      return candidate;
    }

    state = state.copyWith(
      favorites: state.favorites.map(remap).toSet(),
      recent: state.recent.map(remap).toList(),
    );
    await _persist();
  }

  void reset() {
    state = const LibraryPreferencesState();
  }

  Future<void> _persist() async {
    final config = _ref.read(userConfigProvider);
    if (config == null) return;

    final payload = jsonEncode({
      'favorites': state.favorites.toList()..sort(),
      'recent': state.recent,
    });

    final saveResult = await _ref.read(saveNoteUseCaseProvider)(
      SaveNoteParams(
        note: Note(
          name: '.gititdown.json',
          path: AppConstants.appPreferencesPath,
          sha: state.prefsSha,
          content: payload,
        ),
      ),
    );

    saveResult.fold(
      (_) {},
      (savedFile) {
        state = state.copyWith(prefsSha: savedFile.sha);
      },
    );
  }
}

final libraryPreferencesProvider =
    StateNotifierProvider<LibraryPreferencesNotifier, LibraryPreferencesState>((ref) {
  final notifier = LibraryPreferencesNotifier(ref);
  ref.listen<UserConfig?>(userConfigProvider, (_, next) {
    notifier.handleUserConfigChanged(next);
  });
  return notifier;
});
