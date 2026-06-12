import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/utils/usecase.dart';
import '../entities/note.dart';
import '../repositories/github_repository.dart';

class GetNotes implements UseCase<List<Note>, GetNotesParams> {
  final IGitHubRepository repository;

  const GetNotes(this.repository);

  @override
  Future<Either<Failure, List<Note>>> call(GetNotesParams params) async {
    return await repository.getNotes(path: params.path);
  }
}

class GetNotesParams {
  final String path;

  const GetNotesParams({this.path = ''});
}
