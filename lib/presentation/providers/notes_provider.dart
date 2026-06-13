import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/note.dart';
import '../../domain/usecases/create_folder.dart';
import '../../domain/usecases/delete_folder.dart';
import '../../domain/usecases/delete_note.dart';
import '../../domain/usecases/get_note.dart';
import '../../domain/usecases/get_notes.dart';
import '../../domain/usecases/rename_entry.dart';
import '../../domain/usecases/rename_folder.dart';
import '../../domain/usecases/save_note.dart';
import 'dependency_providers.dart';
import 'library_preferences_provider.dart';
import 'search_provider.dart';

enum NotesStatus { initial, loading, loaded, saving, deleting, error }

class NotesState {
  final NotesStatus status;
  final List<Note> notes;
  final Note? selectedNote;
  final Failure? failure;
  final String? errorMessage;
  final String currentPath;

  const NotesState({
    this.status = NotesStatus.initial,
    this.notes = const [],
    this.selectedNote,
    this.failure,
    this.errorMessage,
    this.currentPath = '',
  });

  NotesState copyWith({
    NotesStatus? status,
    List<Note>? notes,
    Note? selectedNote,
    Failure? failure,
    String? errorMessage,
    String? currentPath,
    bool clearSelectedNote = false,
    bool clearFailure = false,
    bool clearErrorMessage = false,
  }) {
    return NotesState(
      status: status ?? this.status,
      notes: notes ?? this.notes,
      selectedNote: clearSelectedNote ? null : (selectedNote ?? this.selectedNote),
      failure: clearFailure ? null : (failure ?? this.failure),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      currentPath: currentPath ?? this.currentPath,
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
    state = state.copyWith(status: NotesStatus.loading, clearFailure: true);

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
    state = state.copyWith(status: NotesStatus.loading, clearFailure: true);

    final getNoteUseCase = _ref.read(getNoteUseCaseProvider);
    final result = await getNoteUseCase(GetNoteParams(path: path));

    result.fold(
      (failure) => state = state.copyWith(
        status: NotesStatus.error,
        failure: failure,
      ),
      (note) {
        state = state.copyWith(
          status: NotesStatus.loaded,
          selectedNote: note,
        );
        _ref.read(vaultSearchProvider.notifier).upsertVaultEntry(
              note,
              content: note.content,
            );
      },
    );
  }

  Future<bool> saveNote(Note note) async {
    if (_isDisposed) return false;
    state = state.copyWith(status: NotesStatus.saving, clearFailure: true);

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
        _ref.read(vaultSearchProvider.notifier).upsertVaultEntry(
              savedNote,
              content: savedNote.content,
            );
        return true;
      },
    );
  }

  Future<bool> deleteNote(String path, String sha) async {
    if (_isDisposed) return false;
    state = state.copyWith(status: NotesStatus.deleting, clearFailure: true);

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
        state = state.copyWith(
          status: NotesStatus.loaded,
          notes: state.notes.where((note) => note.path != path).toList(),
          selectedNote: state.selectedNote?.path == path ? null : state.selectedNote,
        );
        _ref.read(vaultSearchProvider.notifier).removeVaultEntry(path);
        _ref.read(libraryPreferencesProvider.notifier).removePath(path);
        return true;
      },
    );
  }

  Future<bool> deleteFolder(String path) async {
    if (_isDisposed) return false;
    state = state.copyWith(status: NotesStatus.deleting, clearFailure: true);

    final deleteFolderUseCase = _ref.read(deleteFolderUseCaseProvider);
    final result = await deleteFolderUseCase(DeleteFolderParams(path: path));

    return result.fold(
      (failure) {
        state = state.copyWith(
          status: NotesStatus.error,
          failure: failure,
        );
        return false;
      },
      (_) {
        state = state.copyWith(
          status: NotesStatus.loaded,
          notes: state.notes.where((note) => note.path != path).toList(),
        );
        _ref.read(vaultSearchProvider.notifier).removeVaultEntry(path, recursive: true);
        _ref.read(libraryPreferencesProvider.notifier).removePath(path, recursive: true);
        return true;
      },
    );
  }

  Future<bool> renameEntry(Note note, String newName) async {
    if (_isDisposed) return false;

    final normalizedName = newName.trim();
    if (normalizedName.isEmpty) {
      state = state.copyWith(
        status: NotesStatus.error,
        failure: const ValidationFailure(message: 'Name cannot be empty'),
      );
      return false;
    }

    final newPath = note.parentPath.isEmpty ? normalizedName : '${note.parentPath}/$normalizedName';
    if (newPath == note.path) {
      return true;
    }

    state = state.copyWith(status: NotesStatus.saving, clearFailure: true);

    final result = note.isDirectory
        ? await _ref.read(renameFolderUseCaseProvider)(
              RenameFolderParams(folder: note, newPath: newPath),
            )
        : await _ref.read(renameEntryUseCaseProvider)(
              RenameEntryParams(note: note, newPath: newPath),
            );

    return result.fold(
      (failure) {
        state = state.copyWith(
          status: NotesStatus.error,
          failure: failure,
        );
        return false;
      },
      (renamedEntry) async {
        final updatedCurrentPath = _remapPath(state.currentPath, note.path, renamedEntry.path);
        final updatedSelectedNote = _remapSelectedNote(state.selectedNote, note, renamedEntry);
        final updatedVisibleNotes = _remapVisibleNotes(
          state.notes,
          note,
          renamedEntry,
          recursive: note.isDirectory,
        );

        state = state.copyWith(
          status: NotesStatus.loaded,
          notes: updatedVisibleNotes,
          currentPath: updatedCurrentPath,
          selectedNote: updatedSelectedNote,
        );

        await _ref
            .read(libraryPreferencesProvider.notifier)
            .replacePath(note.path, renamedEntry.path, recursive: note.isDirectory);
        _ref.read(vaultSearchProvider.notifier).renameVaultEntry(
              note.path,
              renamedEntry,
              recursive: note.isDirectory,
            );
        loadNotes(updatedCurrentPath);
        _ref.read(vaultSearchProvider.notifier).loadVaultEntries(force: true);
        return true;
      },
    );
  }

  Future<bool> createFolder(String name) async {
    if (_isDisposed) return false;

    state = state.copyWith(status: NotesStatus.saving, clearFailure: true);

    final normalizedName = name.trim().replaceAll('\\', '/');
    final folderPath =
        state.currentPath.isEmpty ? normalizedName : '${state.currentPath}/$normalizedName';

    final createFolderUseCase = _ref.read(createFolderUseCaseProvider);
    final result = await createFolderUseCase(CreateFolderParams(path: folderPath));

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
        _ref.read(vaultSearchProvider.notifier).upsertVaultEntry(folder);
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
    state = state.copyWith(
      failure: null,
      clearFailure: true,
      clearErrorMessage: true,
      status: NotesStatus.loaded,
    );
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
    await loadNote(path);
    state = state.copyWith(
      errorMessage: 'This note was modified externally. Please review and save again.',
    );
  }

  void reset() {
    state = const NotesState();
  }

  String _remapPath(String currentPath, String oldPath, String newPath) {
    if (currentPath == oldPath) {
      return newPath;
    }
    if (currentPath.startsWith('$oldPath/')) {
      return currentPath.replaceFirst('$oldPath/', '$newPath/');
    }
    return currentPath;
  }

  Note? _remapSelectedNote(Note? selectedNote, Note original, Note renamedEntry) {
    if (selectedNote == null) return null;
    if (selectedNote.path == original.path) {
      return renamedEntry;
    }
    if (original.isDirectory && selectedNote.path.startsWith('${original.path}/')) {
      return null;
    }
    return selectedNote;
  }

  List<Note> _remapVisibleNotes(
    List<Note> visibleNotes,
    Note original,
    Note renamedEntry, {
    required bool recursive,
  }) {
    return visibleNotes.map((entry) {
      if (entry.path == original.path) {
        return renamedEntry;
      }
      if (recursive && entry.path.startsWith('${original.path}/')) {
        final newPath = entry.path.replaceFirst('${original.path}/', '${renamedEntry.path}/');
        final newName = newPath.split('/').last;
        return entry.copyWith(
          path: newPath,
          name: newName,
        );
      }
      return entry;
    }).toList();
  }
}

final notesProvider = StateNotifierProvider<NotesNotifier, NotesState>(
  (ref) => NotesNotifier(ref),
);
