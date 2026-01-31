import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/utils/usecase.dart';
import '../repositories/github_repository.dart';

class DeleteNote implements UseCase<void, DeleteNoteParams> {
  final IGitHubRepository repository;

  const DeleteNote(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteNoteParams params) async {
    return await repository.deleteNote(params.path, params.sha);
  }
}

class DeleteNoteParams {
  final String path;
  final String sha;

  const DeleteNoteParams({
    required this.path,
    required this.sha,
  });
}
