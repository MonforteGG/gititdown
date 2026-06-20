import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../../core/utils/usecase.dart';
import '../repositories/github_repository.dart';

class GetFileBytes implements UseCase<Uint8List, GetFileBytesParams> {
  final IGitHubRepository repository;

  const GetFileBytes(this.repository);

  @override
  Future<Either<Failure, Uint8List>> call(GetFileBytesParams params) async {
    return repository.getFileBytes(
      params.path,
      commitSha: params.commitSha,
      onReceiveProgress: params.onReceiveProgress,
    );
  }
}

class GetFileBytesParams {
  final String path;
  final String? commitSha;
  final void Function(int received, int total)? onReceiveProgress;

  const GetFileBytesParams({
    required this.path,
    this.commitSha,
    this.onReceiveProgress,
  });
}
