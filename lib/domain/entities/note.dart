import 'package:equatable/equatable.dart';

class Note extends Equatable {
  final String name;
  final String path;
  final String sha;
  final String content;
  final DateTime? lastModified;

  const Note({
    required this.name,
    required this.path,
    required this.sha,
    this.content = '',
    this.lastModified,
  });

  Note copyWith({
    String? name,
    String? path,
    String? sha,
    String? content,
    DateTime? lastModified,
  }) {
    return Note(
      name: name ?? this.name,
      path: path ?? this.path,
      sha: sha ?? this.sha,
      content: content ?? this.content,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  @override
  List<Object?> get props => [name, path, sha, content, lastModified];
}
