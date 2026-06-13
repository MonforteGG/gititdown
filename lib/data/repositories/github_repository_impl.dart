import 'package:dartz/dartz.dart';
import 'dart:typed_data';
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
  Future<Either<Failure, List<Note>>> getNotes({String path = ''}) async {
    try {
      final files = await _remoteDataSource.getFiles(path);
      final notes = files.map((file) => file.toEntity()).toList()
        ..sort((a, b) {
          if (a.type != b.type) {
            return a.isDirectory ? -1 : 1;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      return Right(notes);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Note>>> getVaultEntries() async {
    try {
      final files = await _remoteDataSource.getVaultEntries();
      final notes = files.map((file) => file.toEntity()).toList()
        ..sort((a, b) {
          if (a.type != b.type) {
            return a.isDirectory ? -1 : 1;
          }
          return a.path.toLowerCase().compareTo(b.path.toLowerCase());
        });
      return Right(notes);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, Note>> getFile(String path, {String? commitSha}) async {
    try {
      final file = commitSha != null
          ? await _remoteDataSource.getFileAtCommit(path, commitSha)
          : await _remoteDataSource.getFile(path);

      return Right(file.toEntity());
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, Uint8List>> getFileBytes(
    String path, {
    String? commitSha,
  }) async {
    try {
      final bytes = await _remoteDataSource.getFileBytes(
        path,
        commitSha: commitSha,
      );

      return Right(bytes);
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

      String decodedContent = '';
      if (file.content != null && file.name.toLowerCase().endsWith('.md')) {
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
  Future<Either<Failure, Note>> createFolder(String path) async {
    try {
      await _remoteDataSource.createFolder(path);

      final segments = path.split('/');
      final folderName = segments.isNotEmpty ? segments.last : path;

      return Right(
        Note(
          name: folderName,
          path: path,
          sha: '',
          type: NoteType.directory,
        ),
      );
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteFolder(String path) async {
    try {
      await _remoteDataSource.deleteFolder(path);
      return const Right(null);
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
  Future<Either<Failure, Note>> renameEntry(Note note, String newPath) async {
    try {
      final sourceFile = await _remoteDataSource.getFile(note.path);
      final bytes = await _remoteDataSource.getFileBytes(note.path);
      final createdFile = await _remoteDataSource.createOrUpdateFileBytes(
        newPath,
        bytes,
        null,
      );
      await _remoteDataSource.deleteFile(note.path, sourceFile.sha);

      final decodedContent = note.isMarkdown ? Base64Utils.decode(Base64Utils.encodeBytes(bytes)) : '';
      return Right(createdFile.toEntity(decodedContent: decodedContent));
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, Note>> renameFolder(Note folder, String newPath) async {
    try {
      final vaultEntries = await _remoteDataSource.getVaultEntries();
      final descendantEntries = vaultEntries
          .map((file) => file.toEntity())
          .where(
            (entry) => entry.path == folder.path || entry.path.startsWith('${folder.path}/'),
          )
          .toList();

      final descendantDirectories = descendantEntries
          .where((entry) => entry.isDirectory)
          .toList()
        ..sort((a, b) => a.path.length.compareTo(b.path.length));

      final descendantFiles = descendantEntries
          .where((entry) => entry.isFile)
          .toList()
        ..sort((a, b) => a.path.length.compareTo(b.path.length));

      if (descendantEntries.length == 1 && descendantDirectories.length == 1) {
        await _remoteDataSource.createFolder(newPath);
        await _remoteDataSource.deleteFolder(folder.path);
      } else {
        for (final directory in descendantDirectories) {
          final targetPath = directory.path == folder.path
              ? newPath
              : directory.path.replaceFirst('${folder.path}/', '$newPath/');
          await _remoteDataSource.createFolder(targetPath);
        }

        for (final file in descendantFiles) {
          final targetPath = file.path == folder.path
              ? newPath
              : file.path.replaceFirst('${folder.path}/', '$newPath/');
          final bytes = await _remoteDataSource.getFileBytes(file.path);
          await _remoteDataSource.createOrUpdateFileBytes(targetPath, bytes, null);
          await _remoteDataSource.deleteFile(file.path, file.sha);
        }

        for (final directory in descendantDirectories.reversed) {
          await _remoteDataSource.deleteFolder(directory.path);
        }
      }

      final folderName = newPath.split('/').last;
      return Right(
        Note(
          name: folderName,
          path: newPath,
          sha: '',
          type: NoteType.directory,
        ),
      );
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
