import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/utils/usecase.dart';
import '../entities/note.dart';
import '../repositories/github_repository.dart';

class RenameFolder implements UseCase<Note, RenameFolderParams> {
  final IGitHubRepository repository;

  const RenameFolder(this.repository);

  @override
  Future<Either<Failure, Note>> call(RenameFolderParams params) async {
    return repository.renameFolder(params.folder, params.newPath);
  }
}

class RenameFolderParams {
  final Note folder;
  final String newPath;

  const RenameFolderParams({
    required this.folder,
    required this.newPath,
  });
}
