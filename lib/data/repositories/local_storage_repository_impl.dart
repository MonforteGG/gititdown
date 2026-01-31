import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/user_config.dart';
import '../../domain/repositories/local_storage_repository.dart';
import '../datasources/secure_storage_local_datasource.dart';

class LocalStorageRepositoryImpl implements ILocalStorageRepository {
  final ILocalStorageDataSource _localDataSource;

  LocalStorageRepositoryImpl({required ILocalStorageDataSource localDataSource})
      : _localDataSource = localDataSource;

  @override
  Future<Either<Failure, void>> saveUserConfig(UserConfig config) async {
    try {
      await _localDataSource.saveUserConfig(config);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to save config: $e'));
    }
  }

  @override
  Future<Either<Failure, UserConfig?>> getUserConfig() async {
    try {
      final config = await _localDataSource.getUserConfig();
      return Right(config);
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to get config: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> clearAll() async {
    try {
      await _localDataSource.clearAll();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to clear storage: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> hasValidConfig() async {
    try {
      final hasValid = await _localDataSource.hasValidConfig();
      return Right(hasValid);
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to check config: $e'));
    }
  }
}