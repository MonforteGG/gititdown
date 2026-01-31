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
    return await repository.getNote(params.path);
  }
}

class GetNoteParams {
  final String path;

  const GetNoteParams({required this.path});
}
