import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/utils/usecase.dart';
import '../entities/note_commit.dart';
import '../repositories/github_repository.dart';

class GetNoteHistory implements UseCase<List<NoteCommit>, GetNoteHistoryParams> {
  final IGitHubRepository repository;

  const GetNoteHistory(this.repository);

  @override
  Future<Either<Failure, List<NoteCommit>>> call(GetNoteHistoryParams params) async {
    return await repository.getNoteHistory(params.path);
  }
}

class GetNoteHistoryParams {
  final String path;

  const GetNoteHistoryParams({required this.path});
}
