import 'package:dio/dio.dart';
import '../../config/constants.dart';
import '../../core/error/failures.dart';
import '../../core/utils/base64_utils.dart';
import '../models/github_file_model.dart';
import '../models/note_commit_model.dart';

abstract class IGitHubRemoteDataSource {
  Future<List<GitHubFileModel>> getFiles(String path);
  Future<GitHubFileModel> getFile(String path);
  Future<GitHubFileModel> createOrUpdateFile(String path, String content, String? sha);
  Future<void> deleteFile(String path, String sha);
  Future<bool> validateCredentials();
  Future<List<NoteCommitModel>> getFileCommits(String path);
  Future<GitHubFileModel> getFileAtCommit(String path, String commitSha);
}

class GitHubRemoteDataSource implements IGitHubRemoteDataSource {
  final Dio _dio;
  final String _username;
  final String _repository;
  final String _pat;

  GitHubRemoteDataSource({
    required Dio dio,
    required String username,
    required String repository,
    required String pat,
  })  : _dio = dio,
        _username = username,
        _repository = repository,
        _pat = pat {
    _dio.options.baseUrl = AppConstants.githubApiBaseUrl;
    _dio.options.headers = {
      ...AppConstants.defaultHeaders,
      'Authorization': 'token $_pat',
    };
  }

  String get _repoPath => '/repos/$_username/$_repository';

  @override
  Future<List<GitHubFileModel>> getFiles(String path) async {
    try {
      final response = await _dio.get(
        '$_repoPath/contents/$path',
      );

      if (response.data is List) {
        final files = (response.data as List)
            .map((json) => GitHubFileModel.fromJson(json as Map<String, dynamic>))
            .where((file) => file.type == 'file' && file.name.endsWith(AppConstants.markdownExtension))
            .toList();
        return files;
      }
      
      return [];
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<GitHubFileModel> getFile(String path) async {
    try {
      final response = await _dio.get(
        '$_repoPath/contents/$path',
      );

      final file = GitHubFileModel.fromJson(response.data as Map<String, dynamic>);
      
      // Decode content if present
      if (file.content != null) {
        final decodedContent = Base64Utils.decode(file.content!);
        return GitHubFileModel(
          name: file.name,
          path: file.path,
          sha: file.sha,
          content: file.content,
          type: file.type,
          size: file.size,
          downloadUrl: file.downloadUrl,
        );
      }
      
      return file;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<GitHubFileModel> createOrUpdateFile(
    String path,
    String content,
    String? sha,
  ) async {
    try {
      final encodedContent = Base64Utils.encode(content);
      
      final body = {
        'message': sha == null 
            ? AppConstants.defaultCreateMessage 
            : AppConstants.defaultCommitMessage,
        'content': encodedContent,
        if (sha != null) 'sha': sha,
      };

      final response = await _dio.put(
        '$_repoPath/contents/$path',
        data: body,
      );

      final contentData = response.data['content'] as Map<String, dynamic>;
      return GitHubFileModel.fromJson(contentData);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> deleteFile(String path, String sha) async {
    try {
      final body = {
        'message': AppConstants.defaultDeleteMessage,
        'sha': sha,
      };

      await _dio.delete(
        '$_repoPath/contents/$path',
        data: body,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<bool> validateCredentials() async {
    try {
      final response = await _dio.head(_repoPath);
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<List<NoteCommitModel>> getFileCommits(String path) async {
    try {
      final response = await _dio.get(
        '$_repoPath/commits',
        queryParameters: {'path': path},
      );

      if (response.data is List) {
        final commits = (response.data as List)
            .map((json) => NoteCommitModel.fromJson(json as Map<String, dynamic>))
            .toList();
        return commits;
      }

      return [];
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<GitHubFileModel> getFileAtCommit(String path, String commitSha) async {
    try {
      final response = await _dio.get(
        '$_repoPath/contents/$path',
        queryParameters: {'ref': commitSha},
      );

      final file = GitHubFileModel.fromJson(response.data as Map<String, dynamic>);
      return file;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Failure _handleDioError(DioException e) {
    final statusCode = e.response?.statusCode;
    final message = e.response?.data?['message'] ?? e.message ?? 'Unknown error';

    switch (statusCode) {
      case 401:
        return AuthenticationFailure(message: 'Invalid or expired token', statusCode: statusCode);
      case 404:
        return NotFoundFailure(message: 'Repository not found', statusCode: statusCode);
      case 409:
        return ConflictFailure(message: 'File was modified externally', statusCode: statusCode);
      case 422:
        return ValidationFailure(message: message, statusCode: statusCode);
      default:
        if (e.type == DioExceptionType.connectionError || 
            e.type == DioExceptionType.connectionTimeout) {
          return NetworkFailure(message: 'Network error: $message', statusCode: statusCode);
        }
        return ServerFailure(message: 'Server error: $message', statusCode: statusCode);
    }
  }
}
