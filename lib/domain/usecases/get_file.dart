import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/utils/usecase.dart';
import '../entities/note.dart';
import '../repositories/github_repository.dart';

class GetFile implements UseCase<Note, GetFileParams> {
  final IGitHubRepository repository;

  const GetFile(this.repository);

  @override
  Future<Either<Failure, Note>> call(GetFileParams params) async {
    return await repository.getFile(params.path, commitSha: params.commitSha);
  }
}

class GetFileParams {
  final String path;
  final String? commitSha;

  const GetFileParams({required this.path, this.commitSha});
}
