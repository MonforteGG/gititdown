import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../entities/user_config.dart';

abstract class ILocalStorageRepository {
  /// Save user configuration
  Future<Either<Failure, void>> saveUserConfig(UserConfig config);
  
  /// Get stored user configuration
  Future<Either<Failure, UserConfig?>> getUserConfig();
  
  /// Clear all stored data
  Future<Either<Failure, void>> clearAll();
  
  /// Check if user is logged in
  Future<Either<Failure, bool>> hasValidConfig();
}
