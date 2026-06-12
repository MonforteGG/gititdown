import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/error/failures.dart';
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

class NotesState {
  final NotesStatus status;
  final List<Note> notes;
  final Note? selectedNote;
  final Failure? failure;
  final String? errorMessage;
  final String currentPath;

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
      historyStatus: historyStatus ?? this.historyStatus,
      noteHistory: noteHistory ?? this.noteHistory,
      versionNote: versionNote,
    );
  }
}

class NotesNotifier extends StateNotifier<NotesState> {
  final Ref _ref;
  bool _isDisposed = false;

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
        );
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
        );
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
        );
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
        );
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
}

final notesProvider = StateNotifierProvider<NotesNotifier, NotesState>(
  (ref) => NotesNotifier(ref),
);
