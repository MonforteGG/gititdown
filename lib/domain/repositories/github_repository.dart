import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../entities/note.dart';
import '../entities/note_commit.dart';

abstract class IGitHubRepository {
  /// Get folders and markdown files for a repository path
  Future<Either<Failure, List<Note>>> getNotes({String path = ''});

  /// Get a single note with its content
  Future<Either<Failure, Note>> getNote(String path, {String? commitSha});

  /// Create or update a note
  Future<Either<Failure, Note>> saveNote(Note note);

  /// Create a folder in the current repository
  Future<Either<Failure, Note>> createFolder(String path);

  /// Delete an empty folder from the current repository
  Future<Either<Failure, void>> deleteFolder(String path);

  /// Delete a note
  Future<Either<Failure, void>> deleteNote(String path, String sha);

  /// Validate credentials by making a test API call
  Future<Either<Failure, bool>> validateCredentials();

  /// Get commit history for a note
  Future<Either<Failure, List<NoteCommit>>> getNoteHistory(String path);

  /// Get note content at a specific version (commit)
  Future<Either<Failure, Note>> getNoteAtVersion(String path, String commitSha);
}
