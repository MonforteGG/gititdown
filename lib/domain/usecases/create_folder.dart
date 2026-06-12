import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/utils/usecase.dart';
import '../entities/note.dart';
import '../repositories/github_repository.dart';

class CreateFolder implements UseCase<Note, CreateFolderParams> {
  final IGitHubRepository repository;

  const CreateFolder(this.repository);

  @override
  Future<Either<Failure, Note>> call(CreateFolderParams params) async {
    return await repository.createFolder(params.path);
  }
}

class CreateFolderParams {
  final String path;

  const CreateFolderParams({required this.path});
}
