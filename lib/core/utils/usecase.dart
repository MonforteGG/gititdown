import 'package:dartz/dartz.dart';
import '../error/failures.dart';

abstract class UseCase<Result, Params> {
  Future<Either<Failure, Result>> call(Params params);
}

class NoParams {
  const NoParams();
}
