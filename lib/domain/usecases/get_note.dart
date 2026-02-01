import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/utils/usecase.dart';
import '../entities/note.dart';
import '../repositories/github_repository.dart';

class GetNote implements UseCase<Note, GetNoteParams> {
  final IGitHubRepository repository;

  const GetNote(this.repository);

  @override
  Future<Either<Failure, Note>> call(GetNoteParams params) async {
    return await repository.getNote(params.path, commitSha: params.commitSha);
  }
}

class GetNoteParams {
  final String path;
  final String? commitSha;

  const GetNoteParams({required this.path, this.commitSha});
}
