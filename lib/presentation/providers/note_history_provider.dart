import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/note.dart';
import '../../domain/entities/note_commit.dart';
import '../../domain/usecases/get_note.dart';
import '../../domain/usecases/get_note_history.dart';
import 'dependency_providers.dart';

enum HistoryStatus { initial, loading, loaded, error }

class NoteHistoryState {
  final HistoryStatus status;
  final List<NoteCommit> noteHistory;
  final Note? versionNote;
  final Failure? failure;

  const NoteHistoryState({
    this.status = HistoryStatus.initial,
    this.noteHistory = const [],
    this.versionNote,
    this.failure,
  });

  NoteHistoryState copyWith({
    HistoryStatus? status,
    List<NoteCommit>? noteHistory,
    Note? versionNote,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return NoteHistoryState(
      status: status ?? this.status,
      noteHistory: noteHistory ?? this.noteHistory,
      versionNote: versionNote,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

class NoteHistoryNotifier extends StateNotifier<NoteHistoryState> {
  final Ref _ref;
  bool _isDisposed = false;

  NoteHistoryNotifier(this._ref) : super(const NoteHistoryState());

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> loadNoteHistory(String path) async {
    if (_isDisposed) return;

    state = state.copyWith(
      status: HistoryStatus.loading,
      noteHistory: const [],
      versionNote: null,
      clearFailure: true,
    );

    final getNoteHistoryUseCase = _ref.read(getNoteHistoryUseCaseProvider);
    final result = await getNoteHistoryUseCase(GetNoteHistoryParams(path: path));

    result.fold(
      (failure) => state = state.copyWith(
        status: HistoryStatus.error,
        failure: failure,
      ),
      (history) => state = state.copyWith(
        status: HistoryStatus.loaded,
        noteHistory: history,
      ),
    );
  }

  Future<void> loadNoteVersion(String path, String commitSha) async {
    if (_isDisposed) return;

    final getNoteUseCase = _ref.read(getNoteUseCaseProvider);
    final result = await getNoteUseCase(GetNoteParams(path: path, commitSha: commitSha));

    result.fold(
      (failure) => state = state.copyWith(
        status: HistoryStatus.error,
        failure: failure,
      ),
      (note) => state = state.copyWith(
        status: HistoryStatus.loaded,
        versionNote: note,
      ),
    );
  }

  void clearHistoryState() {
    state = state.copyWith(
      status: HistoryStatus.initial,
      noteHistory: const [],
      versionNote: null,
    );
  }

  void clearVersionView() {
    state = state.copyWith(versionNote: null);
  }

  void reset() {
    state = const NoteHistoryState();
  }
}

final noteHistoryProvider =
    StateNotifierProvider<NoteHistoryNotifier, NoteHistoryState>(
  (ref) => NoteHistoryNotifier(ref),
);
