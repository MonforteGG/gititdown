import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/utils/usecase.dart';
import '../entities/note.dart';
import '../repositories/github_repository.dart';

class RenameEntry implements UseCase<Note, RenameEntryParams> {
  final IGitHubRepository repository;

  const RenameEntry(this.repository);

  @override
  Future<Either<Failure, Note>> call(RenameEntryParams params) async {
    return repository.renameEntry(params.note, params.newPath);
  }
}

class RenameEntryParams {
  final Note note;
  final String newPath;

  const RenameEntryParams({
    required this.note,
    required this.newPath,
  });
}
