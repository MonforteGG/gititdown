import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/utils/usecase.dart';
import '../entities/note.dart';
import '../repositories/github_repository.dart';

class GetVaultEntries implements UseCase<List<Note>, NoParams> {
  final IGitHubRepository repository;

  const GetVaultEntries(this.repository);

  @override
  Future<Either<Failure, List<Note>>> call(NoParams params) async {
    return await repository.getVaultEntries();
  }
}
