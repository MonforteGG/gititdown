import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/constants.dart';
import '../../domain/entities/user_config.dart';

abstract class ILocalStorageDataSource {
  Future<void> saveUserConfig(UserConfig config);
  Future<UserConfig?> getUserConfig();
  Future<void> clearAll();
  Future<bool> hasValidConfig();
}

class SecureStorageLocalDataSource implements ILocalStorageDataSource {
  final FlutterSecureStorage _storage;

  SecureStorageLocalDataSource({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> saveUserConfig(UserConfig config) async {
    await _storage.write(key: AppConstants.storageKeyUsername, value: config.username);
    await _storage.write(key: AppConstants.storageKeyRepo, value: config.repository);
    await _storage.write(key: AppConstants.storageKeyPat, value: config.pat);
  }

  @override
  Future<UserConfig?> getUserConfig() async {
    final username = await _storage.read(key: AppConstants.storageKeyUsername);
    final repository = await _storage.read(key: AppConstants.storageKeyRepo);
    final pat = await _storage.read(key: AppConstants.storageKeyPat);

    if (username == null || repository == null || pat == null) {
      return null;
    }

    return UserConfig(
      username: username,
      repository: repository,
      pat: pat,
    );
  }

  @override
  Future<void> clearAll() async {
    await _storage.delete(key: AppConstants.storageKeyUsername);
    await _storage.delete(key: AppConstants.storageKeyRepo);
    await _storage.delete(key: AppConstants.storageKeyPat);
  }

  @override
  Future<bool> hasValidConfig() async {
    final config = await getUserConfig();
    return config != null && 
           config.username.isNotEmpty && 
           config.repository.isNotEmpty && 
           config.pat.isNotEmpty;
  }
}
