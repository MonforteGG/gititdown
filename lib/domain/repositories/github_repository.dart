import 'package:dartz/dartz.dart';
import 'dart:typed_data';
import '../../core/error/failures.dart';
import '../entities/note.dart';
import '../entities/note_commit.dart';

abstract class IGitHubRepository {
  /// Get folders and markdown files for a repository path
  Future<Either<Failure, List<Note>>> getNotes({String path = ''});

  /// Get all folders and markdown files in the repository
  Future<Either<Failure, List<Note>>> getVaultEntries();

  /// Get a single file metadata
  Future<Either<Failure, Note>> getFile(String path, {String? commitSha});

  /// Get raw bytes for a single file
  Future<Either<Failure, Uint8List>> getFileBytes(
    String path, {
    String? commitSha,
    void Function(int received, int total)? onReceiveProgress,
  });

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

  /// Rename or move a file entry
  Future<Either<Failure, Note>> renameEntry(Note note, String newPath);

  /// Rename or move a folder entry recursively
  Future<Either<Failure, Note>> renameFolder(Note folder, String newPath);

  /// Validate credentials by making a test API call
  Future<Either<Failure, bool>> validateCredentials();

  /// Get commit history for a note
  Future<Either<Failure, List<NoteCommit>>> getNoteHistory(String path);

  /// Get note content at a specific version (commit)
  Future<Either<Failure, Note>> getNoteAtVersion(String path, String commitSha);
}
