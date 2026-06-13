import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/utils/usecase.dart';
import '../entities/user_config.dart';
import '../repositories/github_repository.dart';
import '../repositories/local_storage_repository.dart';

typedef GitHubRepositoryResolver = IGitHubRepository Function(UserConfig config);

class Login implements UseCase<bool, LoginParams> {
  final GitHubRepositoryResolver githubRepositoryResolver;
  final ILocalStorageRepository localStorageRepository;

  const Login({
    required this.githubRepositoryResolver,
    required this.localStorageRepository,
  });

  @override
  Future<Either<Failure, bool>> call(LoginParams params) async {
    final githubRepository = githubRepositoryResolver(params.config);

    // First validate credentials with GitHub
    final validationResult = await githubRepository.validateCredentials();
    
    if (validationResult.isLeft()) {
      return validationResult;
    }
    
    // If valid, save user config
    final saveResult = await localStorageRepository.saveUserConfig(params.config);
    
    if (saveResult.isLeft()) {
      return Left(saveResult.fold(
        (failure) => failure,
        (_) => throw Exception('Unexpected right value'),
      ));
    }
    
    return const Right(true);
  }
}

class LoginParams {
  final UserConfig config;

  const LoginParams({required this.config});
}
