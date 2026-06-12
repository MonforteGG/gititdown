import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/utils/usecase.dart';
import '../repositories/github_repository.dart';

class DeleteFolder implements UseCase<void, DeleteFolderParams> {
  final IGitHubRepository repository;

  const DeleteFolder(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteFolderParams params) async {
    return await repository.deleteFolder(params.path);
  }
}

class DeleteFolderParams {
  final String path;

  const DeleteFolderParams({required this.path});
}
