import 'package:equatable/equatable.dart';

class UserConfig extends Equatable {
  final String username;
  final String repository;
  final String pat;

  const UserConfig({
    required this.username,
    required this.repository,
    required this.pat,
  });

  UserConfig copyWith({
    String? username,
    String? repository,
    String? pat,
  }) {
    return UserConfig(
      username: username ?? this.username,
      repository: repository ?? this.repository,
      pat: pat ?? this.pat,
    );
  }

  @override
  List<Object?> get props => [username, repository, pat];
}
