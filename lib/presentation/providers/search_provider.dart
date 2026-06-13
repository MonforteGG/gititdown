import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/error/failures.dart';
import '../../core/utils/usecase.dart';
import '../../domain/entities/note.dart';
import '../../domain/usecases/get_note.dart';
import 'dependency_providers.dart';

enum SearchStatus { initial, loading, loaded, error }

class SearchMatchMetadata {
  final int contentMatchCount;
  final String? snippet;
  final bool matchedByNameOrPath;

  const SearchMatchMetadata({
    required this.contentMatchCount,
    required this.snippet,
    required this.matchedByNameOrPath,
  });
}

class VaultSearchState {
  final SearchStatus status;
  final String query;
  final List<Note> vaultEntries;
  final List<Note> searchResults;
  final Map<String, String> noteContentCache;
  final Map<String, String> noteContentShaCache;
  final Map<String, SearchMatchMetadata> searchMatchMetadata;
  final Failure? failure;

  const VaultSearchState({
    this.status = SearchStatus.initial,
    this.query = '',
    this.vaultEntries = const [],
    this.searchResults = const [],
    this.noteContentCache = const {},
    this.noteContentShaCache = const {},
    this.searchMatchMetadata = const {},
    this.failure,
  });

  VaultSearchState copyWith({
    SearchStatus? status,
    String? query,
    List<Note>? vaultEntries,
    List<Note>? searchResults,
    Map<String, String>? noteContentCache,
    Map<String, String>? noteContentShaCache,
    Map<String, SearchMatchMetadata>? searchMatchMetadata,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return VaultSearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      vaultEntries: vaultEntries ?? this.vaultEntries,
      searchResults: searchResults ?? this.searchResults,
      noteContentCache: noteContentCache ?? this.noteContentCache,
      noteContentShaCache: noteContentShaCache ?? this.noteContentShaCache,
      searchMatchMetadata: searchMatchMetadata ?? this.searchMatchMetadata,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

class VaultSearchNotifier extends StateNotifier<VaultSearchState> {
  final Ref _ref;
  bool _isDisposed = false;
  bool _isIndexingSearchContent = false;

  VaultSearchNotifier(this._ref) : super(const VaultSearchState());

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> loadVaultEntries({bool force = false}) async {
    if (!force && state.status == SearchStatus.loaded && state.vaultEntries.isNotEmpty) {
      _applySearchQuery(state.query);
      return;
    }

    state = state.copyWith(status: SearchStatus.loading, clearFailure: true);

    final getVaultEntriesUseCase = _ref.read(getVaultEntriesUseCaseProvider);
    final result = await getVaultEntriesUseCase(const NoParams());

    result.fold(
      (failure) => state = state.copyWith(
        status: SearchStatus.error,
        failure: failure,
      ),
      (entries) {
        final retainedContentCache = <String, String>{};
        final retainedShaCache = <String, String>{};

        for (final entry in entries.where((entry) => entry.isMarkdown)) {
          final cachedSha = state.noteContentShaCache[entry.path];
          final cachedContent = state.noteContentCache[entry.path];
          if (cachedSha == entry.sha && cachedContent != null) {
            retainedContentCache[entry.path] = cachedContent;
            retainedShaCache[entry.path] = cachedSha!;
          }
        }

        state = state.copyWith(
          status: SearchStatus.loaded,
          vaultEntries: entries,
          noteContentCache: retainedContentCache,
          noteContentShaCache: retainedShaCache,
        );
        _applySearchQuery(state.query);
      },
    );
  }

  void updateQuery(String query) {
    state = state.copyWith(query: query);
    _applySearchQuery(query);
  }

  void clearSearch() {
    state = state.copyWith(
      query: '',
      searchResults: const [],
      searchMatchMetadata: const {},
    );
  }

  Future<void> loadSearchContentIndex() async {
    if (_isIndexingSearchContent) return;

    final missingEntries = state.vaultEntries
        .where((entry) => entry.isMarkdown)
        .where((entry) => state.noteContentShaCache[entry.path] != entry.sha)
        .toList();

    if (missingEntries.isEmpty) {
      state = state.copyWith(status: SearchStatus.loaded);
      _applySearchQuery(state.query);
      return;
    }

    _isIndexingSearchContent = true;
    state = state.copyWith(status: SearchStatus.loading);

    final contentCache = Map<String, String>.from(state.noteContentCache);
    final shaCache = Map<String, String>.from(state.noteContentShaCache);
    final getNoteUseCase = _ref.read(getNoteUseCaseProvider);

    try {
      const batchSize = 4;

      for (var i = 0; i < missingEntries.length; i += batchSize) {
        if (_isDisposed) return;

        final batch = missingEntries.skip(i).take(batchSize).toList();
        final batchResults = await Future.wait(
          batch.map((entry) async {
            final result = await getNoteUseCase(GetNoteParams(path: entry.path));
            return (entry: entry, result: result);
          }),
        );

        for (final batchResult in batchResults) {
          batchResult.result.fold(
            (_) {},
            (note) {
              contentCache[batchResult.entry.path] = note.content;
              shaCache[batchResult.entry.path] = batchResult.entry.sha;
            },
          );
        }
      }

      state = state.copyWith(
        status: SearchStatus.loaded,
        noteContentCache: contentCache,
        noteContentShaCache: shaCache,
      );
      _applySearchQuery(state.query);
    } finally {
      _isIndexingSearchContent = false;
    }
  }

  void upsertVaultEntry(Note entry, {String? content}) {
    final updatedEntries = List<Note>.from(state.vaultEntries);
    final existingIndex = updatedEntries.indexWhere((note) => note.path == entry.path);

    if (existingIndex >= 0) {
      updatedEntries[existingIndex] = entry;
    } else {
      updatedEntries.add(entry);
    }

    updatedEntries.sort((a, b) {
      if (a.type != b.type) {
        return a.isDirectory ? -1 : 1;
      }
      return a.path.toLowerCase().compareTo(b.path.toLowerCase());
    });

    final updatedContentCache = Map<String, String>.from(state.noteContentCache);
    final updatedShaCache = Map<String, String>.from(state.noteContentShaCache);

    if (entry.isMarkdown) {
      if (content != null) {
        updatedContentCache[entry.path] = content;
        updatedShaCache[entry.path] = entry.sha;
      } else if (updatedShaCache[entry.path] != entry.sha) {
        updatedContentCache.remove(entry.path);
        updatedShaCache.remove(entry.path);
      }
    } else {
      updatedContentCache.remove(entry.path);
      updatedShaCache.remove(entry.path);
    }

    state = state.copyWith(
      vaultEntries: updatedEntries,
      noteContentCache: updatedContentCache,
      noteContentShaCache: updatedShaCache,
    );
    _applySearchQuery(state.query);
  }

  void removeVaultEntry(String path, {bool recursive = false}) {
    final updatedContentCache = Map<String, String>.from(state.noteContentCache);
    final updatedShaCache = Map<String, String>.from(state.noteContentShaCache);

    bool shouldRemove(String candidatePath) =>
        candidatePath == path || (recursive && candidatePath.startsWith('$path/'));

    updatedContentCache.removeWhere((key, _) => shouldRemove(key));
    updatedShaCache.removeWhere((key, _) => shouldRemove(key));

    state = state.copyWith(
      vaultEntries: state.vaultEntries.where((entry) => !shouldRemove(entry.path)).toList(),
      noteContentCache: updatedContentCache,
      noteContentShaCache: updatedShaCache,
    );
    _applySearchQuery(state.query);
  }

  Note? findNoteByWikiLink(String rawTarget, {String currentPath = ''}) {
    final target = rawTarget.trim();
    if (target.isEmpty) return null;

    final hasExplicitExtension = target.contains('.') && !target.endsWith('.');
    final normalizedTarget = hasExplicitExtension ? target : '$target.md';
    final normalizedLower = normalizedTarget.toLowerCase();
    final rawTargetLower = target.toLowerCase();

    Note? exactRawPathMatch;
    try {
      exactRawPathMatch = state.vaultEntries.firstWhere(
        (entry) => entry.isFile && entry.path.toLowerCase() == rawTargetLower,
      );
    } catch (_) {
      exactRawPathMatch = null;
    }
    if (exactRawPathMatch != null) return exactRawPathMatch;

    Note? exactPathMatch;
    try {
      exactPathMatch = state.vaultEntries.firstWhere(
        (entry) => entry.isFile && entry.path.toLowerCase() == normalizedLower,
      );
    } catch (_) {
      exactPathMatch = null;
    }
    if (exactPathMatch != null) return exactPathMatch;

    final fileName = (hasExplicitExtension ? target : normalizedTarget)
        .split('/')
        .last
        .toLowerCase();
    final candidates = state.vaultEntries.where((entry) {
      if (!entry.isFile) return false;
      final entryPath = entry.path.toLowerCase();
      return entryPath == rawTargetLower ||
          entryPath == normalizedLower ||
          entryPath.endsWith('/$fileName');
    }).toList();

    if (candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.first;

    return candidates.firstWhere(
      (entry) => entry.parentPath == currentPath,
      orElse: () => candidates.first,
    );
  }

  void reset() {
    state = const VaultSearchState();
  }

  void _applySearchQuery(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      state = state.copyWith(
        searchResults: const [],
        searchMatchMetadata: const {},
      );
      return;
    }

    final results = <Note>[];
    final metadata = <String, SearchMatchMetadata>{};

    for (final entry in state.vaultEntries) {
      final name = entry.name.toLowerCase();
      final path = entry.path.toLowerCase();
      final content = state.noteContentCache[entry.path]?.toLowerCase() ?? '';
      final matchedByNameOrPath =
          name.contains(normalizedQuery) || path.contains(normalizedQuery);
      final contentMatchCount = entry.isFile ? _countOccurrences(content, normalizedQuery) : 0;

      if (!matchedByNameOrPath && contentMatchCount == 0) {
        continue;
      }

      results.add(entry);
      metadata[entry.path] = SearchMatchMetadata(
        contentMatchCount: contentMatchCount,
        snippet: contentMatchCount > 0
            ? _buildSnippet(state.noteContentCache[entry.path] ?? '', normalizedQuery)
            : null,
        matchedByNameOrPath: matchedByNameOrPath,
      );
    }

    state = state.copyWith(
      searchResults: results,
      searchMatchMetadata: metadata,
    );
  }

  int _countOccurrences(String text, String query) {
    if (text.isEmpty || query.isEmpty) return 0;

    var count = 0;
    var start = 0;
    while (true) {
      final index = text.indexOf(query, start);
      if (index == -1) break;
      count++;
      start = index + query.length;
    }
    return count;
  }

  String? _buildSnippet(String content, String normalizedQuery) {
    if (content.isEmpty || normalizedQuery.isEmpty) return null;

    final lowerContent = content.toLowerCase();
    final matchIndex = lowerContent.indexOf(normalizedQuery);
    if (matchIndex == -1) return null;

    const snippetRadius = 36;
    final start = (matchIndex - snippetRadius).clamp(0, content.length);
    final end = (matchIndex + normalizedQuery.length + snippetRadius).clamp(0, content.length);
    final prefix = start > 0 ? '...' : '';
    final suffix = end < content.length ? '...' : '';
    final snippet = content.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim();

    return '$prefix$snippet$suffix';
  }
}

final vaultSearchProvider =
    StateNotifierProvider<VaultSearchNotifier, VaultSearchState>(
  (ref) => VaultSearchNotifier(ref),
);
