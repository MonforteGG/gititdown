import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/utils/usecase.dart';
import '../repositories/local_storage_repository.dart';

class Logout implements UseCase<void, NoParams> {
  final ILocalStorageRepository repository;

  const Logout(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    return await repository.clearAll();
  }
}
