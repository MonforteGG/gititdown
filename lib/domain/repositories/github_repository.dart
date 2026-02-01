import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../entities/note.dart';
import '../entities/note_commit.dart';

abstract class IGitHubRepository {
  /// Get all markdown files from the repository
  Future<Either<Failure, List<Note>>> getNotes();

  /// Get a single note with its content
  Future<Either<Failure, Note>> getNote(String path, {String? commitSha});

  /// Create or update a note
  Future<Either<Failure, Note>> saveNote(Note note);

  /// Delete a note
  Future<Either<Failure, void>> deleteNote(String path, String sha);

  /// Validate credentials by making a test API call
  Future<Either<Failure, bool>> validateCredentials();

  /// Get commit history for a note
  Future<Either<Failure, List<NoteCommit>>> getNoteHistory(String path);

  /// Get note content at a specific version (commit)
  Future<Either<Failure, Note>> getNoteAtVersion(String path, String commitSha);
}
