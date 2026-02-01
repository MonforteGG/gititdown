import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/utils/base64_utils.dart';
import '../../domain/entities/note.dart';
import '../../domain/entities/note_commit.dart';
import '../../domain/repositories/github_repository.dart';
import '../datasources/github_remote_datasource.dart';

class GitHubRepositoryImpl implements IGitHubRepository {
  final IGitHubRemoteDataSource _remoteDataSource;

  GitHubRepositoryImpl({required IGitHubRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<Either<Failure, List<Note>>> getNotes() async {
    try {
      final files = await _remoteDataSource.getFiles('');
      final notes = files.map((file) => file.toEntity()).toList();
      // Sort alphabetically by name
      notes.sort((a, b) => a.name.compareTo(b.name));
      return Right(notes);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, Note>> getNote(String path, {String? commitSha}) async {
    try {
      final file = commitSha != null
          ? await _remoteDataSource.getFileAtCommit(path, commitSha)
          : await _remoteDataSource.getFile(path);

      // Decode content if present
      String decodedContent = '';
      if (file.content != null) {
        decodedContent = Base64Utils.decode(file.content!);
      }

      return Right(file.toEntity(decodedContent: decodedContent));
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, Note>> saveNote(Note note) async {
    try {
      final updatedFile = await _remoteDataSource.createOrUpdateFile(
        note.path,
        note.content,
        note.sha.isNotEmpty ? note.sha : null,
      );
      
      return Right(updatedFile.toEntity(decodedContent: note.content));
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteNote(String path, String sha) async {
    try {
      await _remoteDataSource.deleteFile(path, sha);
      return const Right(null);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> validateCredentials() async {
    try {
      final isValid = await _remoteDataSource.validateCredentials();
      return Right(isValid);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, List<NoteCommit>>> getNoteHistory(String path) async {
    try {
      final commits = await _remoteDataSource.getFileCommits(path);
      final noteCommits = commits.map((commit) => commit.toEntity()).toList();
      return Right(noteCommits);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, Note>> getNoteAtVersion(
    String path,
    String commitSha,
  ) async {
    try {
      final file = await _remoteDataSource.getFileAtCommit(path, commitSha);

      // Decode content if present
      String decodedContent = '';
      if (file.content != null) {
        decodedContent = Base64Utils.decode(file.content!);
      }

      return Right(file.toEntity(decodedContent: decodedContent));
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }
}