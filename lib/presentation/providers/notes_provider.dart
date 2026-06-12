import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/error/failures.dart';
import '../../core/utils/usecase.dart';
import '../../domain/entities/note.dart';
import '../../domain/entities/note_commit.dart';
import '../../domain/usecases/create_folder.dart';
import '../../domain/usecases/delete_folder.dart';
import '../../domain/usecases/delete_note.dart';
import '../../domain/usecases/get_note.dart';
import '../../domain/usecases/get_note_history.dart';
import '../../domain/usecases/get_notes.dart';
import '../../domain/usecases/save_note.dart';
import 'dependency_providers.dart';

// Notes State
enum NotesStatus { initial, loading, loaded, saving, deleting, error }

enum HistoryStatus { initial, loading, loaded, error }
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

class NotesState {
  final NotesStatus status;
  final List<Note> notes;
  final Note? selectedNote;
  final Failure? failure;
  final String? errorMessage;
  final String currentPath;
  final SearchStatus searchStatus;
  final String searchQuery;
  final List<Note> vaultEntries;
  final List<Note> searchResults;
  final Map<String, String> noteContentCache;
  final Map<String, SearchMatchMetadata> searchMatchMetadata;

  final HistoryStatus historyStatus;
  final List<NoteCommit> noteHistory;
  final Note? versionNote;

  const NotesState({
    this.status = NotesStatus.initial,
    this.notes = const [],
    this.selectedNote,
    this.failure,
    this.errorMessage,
    this.currentPath = '',
    this.searchStatus = SearchStatus.initial,
    this.searchQuery = '',
    this.vaultEntries = const [],
    this.searchResults = const [],
    this.noteContentCache = const {},
    this.searchMatchMetadata = const {},
    this.historyStatus = HistoryStatus.initial,
    this.noteHistory = const [],
    this.versionNote,
  });

  NotesState copyWith({
    NotesStatus? status,
    List<Note>? notes,
    Note? selectedNote,
    Failure? failure,
    String? errorMessage,
    String? currentPath,
    SearchStatus? searchStatus,
    String? searchQuery,
    List<Note>? vaultEntries,
    List<Note>? searchResults,
    Map<String, String>? noteContentCache,
    Map<String, SearchMatchMetadata>? searchMatchMetadata,
    bool clearSelectedNote = false,
    HistoryStatus? historyStatus,
    List<NoteCommit>? noteHistory,
    Note? versionNote,
  }) {
    return NotesState(
      status: status ?? this.status,
      notes: notes ?? this.notes,
      selectedNote: clearSelectedNote ? null : (selectedNote ?? this.selectedNote),
      failure: failure ?? this.failure,
      errorMessage: errorMessage ?? this.errorMessage,
      currentPath: currentPath ?? this.currentPath,
      searchStatus: searchStatus ?? this.searchStatus,
      searchQuery: searchQuery ?? this.searchQuery,
      vaultEntries: vaultEntries ?? this.vaultEntries,
      searchResults: searchResults ?? this.searchResults,
      noteContentCache: noteContentCache ?? this.noteContentCache,
      searchMatchMetadata: searchMatchMetadata ?? this.searchMatchMetadata,
      historyStatus: historyStatus ?? this.historyStatus,
      noteHistory: noteHistory ?? this.noteHistory,
      versionNote: versionNote,
    );
  }
}

class NotesNotifier extends StateNotifier<NotesState> {
  final Ref _ref;
  bool _isDisposed = false;
  bool _isIndexingSearchContent = false;

  NotesNotifier(this._ref) : super(const NotesState());

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> loadNotes([String? path]) async {
    state = state.copyWith(status: NotesStatus.loading, failure: null);

    final targetPath = path ?? state.currentPath;
    final getNotesUseCase = _ref.read(getNotesUseCaseProvider);
    final result = await getNotesUseCase(GetNotesParams(path: targetPath));

    result.fold(
      (failure) => state = state.copyWith(
        status: NotesStatus.error,
        failure: failure,
      ),
      (notes) => state = state.copyWith(
        status: NotesStatus.loaded,
        notes: notes,
        currentPath: targetPath,
      ),
    );
  }

  Future<void> loadVaultEntries({bool force = false}) async {
    if (!force &&
        state.searchStatus == SearchStatus.loaded &&
        state.vaultEntries.isNotEmpty) {
      _applySearchQuery(state.searchQuery);
      return;
    }

    state = state.copyWith(searchStatus: SearchStatus.loading, failure: null);

    final getVaultEntriesUseCase = _ref.read(getVaultEntriesUseCaseProvider);
    final result = await getVaultEntriesUseCase(const NoParams());

    result.fold(
      (failure) => state = state.copyWith(
        searchStatus: SearchStatus.error,
        failure: failure,
      ),
      (entries) {
        state = state.copyWith(
          searchStatus: SearchStatus.loaded,
          vaultEntries: entries,
          noteContentCache: force ? const {} : state.noteContentCache,
        );
        _applySearchQuery(state.searchQuery);
      },
    );
  }

  Note? findNoteByWikiLink(String rawTarget) {
    final target = rawTarget.trim();
    if (target.isEmpty) return null;

    final hasExplicitExtension =
        target.contains('.') && !target.endsWith('.');
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
      (entry) => entry.parentPath == state.currentPath,
      orElse: () => candidates.first,
    );
  }

  Future<void> loadNote(String path) async {
    if (_isDisposed) return;
    state = state.copyWith(status: NotesStatus.loading, failure: null);
    
    final getNoteUseCase = _ref.read(getNoteUseCaseProvider);
    final result = await getNoteUseCase(GetNoteParams(path: path));
    
    result.fold(
      (failure) => state = state.copyWith(
        status: NotesStatus.error,
        failure: failure,
      ),
      (note) => state = state.copyWith(
        status: NotesStatus.loaded,
        selectedNote: note,
      ),
    );
  }

  Future<bool> saveNote(Note note) async {
    if (_isDisposed) return false;
    state = state.copyWith(status: NotesStatus.saving, failure: null);
    
    final saveNoteUseCase = _ref.read(saveNoteUseCaseProvider);
    final result = await saveNoteUseCase(SaveNoteParams(note: note));
    
    return result.fold(
      (failure) {
        state = state.copyWith(
          status: NotesStatus.error,
          failure: failure,
        );
        return false;
      },
      (savedNote) {
        // Update the notes list with the saved note
        final updatedNotes = List<Note>.from(state.notes);
        final existingIndex = updatedNotes.indexWhere((n) => n.path == savedNote.path);
        
        if (existingIndex >= 0) {
          updatedNotes[existingIndex] = savedNote;
        } else {
          updatedNotes.add(savedNote);
          updatedNotes.sort((a, b) {
            if (a.type != b.type) {
              return a.isDirectory ? -1 : 1;
            }
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        }
        
        state = state.copyWith(
          status: NotesStatus.loaded,
          notes: updatedNotes,
          selectedNote: savedNote,
          vaultEntries: _upsertVaultEntry(savedNote),
          noteContentCache: {
            ...state.noteContentCache,
            savedNote.path: savedNote.content,
          },
        );
        _applySearchQuery(state.searchQuery);
        return true;
      },
    );
  }

  Future<bool> deleteNote(String path, String sha) async {
    if (_isDisposed) return false;
    state = state.copyWith(status: NotesStatus.deleting, failure: null);
    
    final deleteNoteUseCase = _ref.read(deleteNoteUseCaseProvider);
    final result = await deleteNoteUseCase(DeleteNoteParams(path: path, sha: sha));
    
    return result.fold(
      (failure) {
        state = state.copyWith(
          status: NotesStatus.error,
          failure: failure,
        );
        return false;
      },
      (_) {
        // Remove the note from the list
        final updatedNotes = state.notes.where((n) => n.path != path).toList();
        
        state = state.copyWith(
          status: NotesStatus.loaded,
          notes: updatedNotes,
          selectedNote: state.selectedNote?.path == path ? null : state.selectedNote,
          vaultEntries: state.vaultEntries.where((n) => n.path != path).toList(),
          noteContentCache: Map<String, String>.from(state.noteContentCache)
            ..remove(path),
        );
        _applySearchQuery(state.searchQuery);
        return true;
      },
    );
  }

  Future<bool> deleteFolder(String path) async {
    if (_isDisposed) return false;
    state = state.copyWith(status: NotesStatus.deleting, failure: null);

    final deleteFolderUseCase = _ref.read(deleteFolderUseCaseProvider);
    final result =
        await deleteFolderUseCase(DeleteFolderParams(path: path));

    return result.fold(
      (failure) {
        state = state.copyWith(
          status: NotesStatus.error,
          failure: failure,
        );
        return false;
      },
      (_) {
        final updatedNotes = state.notes.where((n) => n.path != path).toList();

        state = state.copyWith(
          status: NotesStatus.loaded,
          notes: updatedNotes,
          vaultEntries: state.vaultEntries.where((n) => n.path != path).toList(),
          noteContentCache: Map<String, String>.from(state.noteContentCache)
            ..removeWhere((key, _) => key == path || key.startsWith('$path/')),
        );
        _applySearchQuery(state.searchQuery);
        return true;
      },
    );
  }

  Future<bool> createFolder(String name) async {
    if (_isDisposed) return false;

    state = state.copyWith(status: NotesStatus.saving, failure: null);

    final normalizedName = name.trim().replaceAll('\\', '/');
    final folderPath = state.currentPath.isEmpty
        ? normalizedName
        : '${state.currentPath}/$normalizedName';

    final createFolderUseCase = _ref.read(createFolderUseCaseProvider);
    final result =
        await createFolderUseCase(CreateFolderParams(path: folderPath));

    return result.fold(
      (failure) {
        state = state.copyWith(
          status: NotesStatus.error,
          failure: failure,
        );
        return false;
      },
      (folder) {
        final updatedNotes = List<Note>.from(state.notes)..add(folder);
        updatedNotes.sort((a, b) {
          if (a.type != b.type) {
            return a.isDirectory ? -1 : 1;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

        state = state.copyWith(
          status: NotesStatus.loaded,
          notes: updatedNotes,
          vaultEntries: _upsertVaultEntry(folder),
        );
        _applySearchQuery(state.searchQuery);
        return true;
      },
    );
  }

  void selectNote(Note note) {
    state = state.copyWith(selectedNote: note);
  }

  void clearSelectedNote() {
    state = state.copyWith(clearSelectedNote: true);
  }

  void clearError() {
    state = state.copyWith(failure: null, errorMessage: null, status: NotesStatus.loaded);
  }

  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _applySearchQuery(query);
  }

  void clearSearch() {
    state = state.copyWith(
      searchQuery: '',
      searchResults: const [],
      searchMatchMetadata: const {},
    );
  }

  Future<void> loadSearchContentIndex() async {
    if (_isIndexingSearchContent) return;

    final fileEntries = state.vaultEntries.where((entry) => entry.isFile).toList();
    final missingEntries = fileEntries
        .where((entry) => entry.isMarkdown && !state.noteContentCache.containsKey(entry.path))
        .toList();

    if (missingEntries.isEmpty) {
      state = state.copyWith(searchStatus: SearchStatus.loaded);
      _applySearchQuery(state.searchQuery);
      return;
    }

    _isIndexingSearchContent = true;
    state = state.copyWith(searchStatus: SearchStatus.loading);

    final cache = Map<String, String>.from(state.noteContentCache);
    final getNoteUseCase = _ref.read(getNoteUseCaseProvider);

    try {
      for (final entry in missingEntries) {
        if (_isDisposed) return;

        final result = await getNoteUseCase(GetNoteParams(path: entry.path));
        result.fold(
          (_) {},
          (note) => cache[entry.path] = note.content,
        );
      }

      state = state.copyWith(
        searchStatus: SearchStatus.loaded,
        noteContentCache: cache,
      );
      _applySearchQuery(state.searchQuery);
    } finally {
      _isIndexingSearchContent = false;
    }
  }

  Future<void> openDirectory(Note directory) async {
    if (!directory.isDirectory) return;
    await loadNotes(directory.path);
  }

  Future<void> navigateToRoot() async {
    await loadNotes('');
  }

  Future<void> navigateUp() async {
    if (state.currentPath.isEmpty) return;

    final segments = state.currentPath.split('/')..removeLast();
    await loadNotes(segments.join('/'));
  }

  void handleConflict(String path) async {
    // Reload the note to get the latest version
    await loadNote(path);
    state = state.copyWith(
      errorMessage: 'This note was modified externally. Please review and save again.',
    );
  }

  Future<void> loadNoteHistory(String path) async {
    if (_isDisposed) return;
    state = state.copyWith(
      historyStatus: HistoryStatus.loading,
      noteHistory: [],
      versionNote: null,
      failure: null,
    );

    final getNoteHistoryUseCase = _ref.read(getNoteHistoryUseCaseProvider);
    final result = await getNoteHistoryUseCase(GetNoteHistoryParams(path: path));

    result.fold(
      (failure) => state = state.copyWith(
        historyStatus: HistoryStatus.error,
        failure: failure,
      ),
      (history) => state = state.copyWith(
        historyStatus: HistoryStatus.loaded,
        noteHistory: history,
      ),
    );
  }

  Future<void> loadNoteVersion(String path, String commitSha) async {
    if (_isDisposed) return;
    state = state.copyWith(status: NotesStatus.loading, failure: null);

    final getNoteUseCase = _ref.read(getNoteUseCaseProvider);
    final result = await getNoteUseCase(GetNoteParams(path: path, commitSha: commitSha));

    result.fold(
      (failure) => state = state.copyWith(
        status: NotesStatus.error,
        failure: failure,
      ),
      (note) => state = state.copyWith(
        status: NotesStatus.loaded,
        versionNote: note,
      ),
    );
  }

  void clearHistoryState() {
    state = state.copyWith(
      historyStatus: HistoryStatus.initial,
      noteHistory: [],
      versionNote: null,
    );
  }

  void clearVersionView() {
    state = state.copyWith(
      versionNote: null,
    );
  }

  List<Note> _upsertVaultEntry(Note entry) {
    final updatedEntries = List<Note>.from(state.vaultEntries);
    final existingIndex = updatedEntries.indexWhere((n) => n.path == entry.path);

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

    return updatedEntries;
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
      final content =
          state.noteContentCache[entry.path]?.toLowerCase() ?? '';
      final matchedByNameOrPath =
          name.contains(normalizedQuery) || path.contains(normalizedQuery);
      final contentMatchCount =
          entry.isFile ? _countOccurrences(content, normalizedQuery) : 0;

      if (!matchedByNameOrPath && contentMatchCount == 0) {
        continue;
      }

      results.add(entry);
      metadata[entry.path] = SearchMatchMetadata(
        contentMatchCount: contentMatchCount,
        snippet: contentMatchCount > 0
            ? _buildSnippet(
                state.noteContentCache[entry.path] ?? '',
                normalizedQuery,
              )
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

    final snippetRadius = 36;
    final start = (matchIndex - snippetRadius).clamp(0, content.length);
    final end =
        (matchIndex + normalizedQuery.length + snippetRadius).clamp(0, content.length);
    final prefix = start > 0 ? '...' : '';
    final suffix = end < content.length ? '...' : '';
    final snippet = content.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim();

    return '$prefix$snippet$suffix';
  }
}

final notesProvider = StateNotifierProvider<NotesNotifier, NotesState>(
  (ref) => NotesNotifier(ref),
);
