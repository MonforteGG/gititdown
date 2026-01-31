import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/utils/usecase.dart';
import '../entities/note.dart';
import '../repositories/github_repository.dart';

class SaveNote implements UseCase<Note, SaveNoteParams> {
  final IGitHubRepository repository;

  const SaveNote(this.repository);

  @override
  Future<Either<Failure, Note>> call(SaveNoteParams params) async {
    return await repository.saveNote(params.note);
  }
}

class SaveNoteParams {
  final Note note;

  const SaveNoteParams({required this.note});
}
