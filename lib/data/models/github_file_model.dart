import '../../domain/entities/note.dart';

class GitHubFileModel {
  final String name;
  final String path;
  final String sha;
  final String? content;
  final String type;
  final int? size;
  final String? downloadUrl;

  GitHubFileModel({
    required this.name,
    required this.path,
    required this.sha,
    this.content,
    required this.type,
    this.size,
    this.downloadUrl,
  });

  factory GitHubFileModel.fromJson(Map<String, dynamic> json) {
    return GitHubFileModel(
      name: json['name'] as String,
      path: json['path'] as String,
      sha: json['sha'] as String,
      content: json['content'] as String?,
      type: json['type'] as String,
      size: json['size'] as int?,
      downloadUrl: json['download_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'sha': sha,
      'content': content,
      'type': type,
      'size': size,
      'download_url': downloadUrl,
    };
  }

  Note toEntity({String decodedContent = ''}) {
    return Note(
      name: name,
      path: path,
      sha: sha,
      content: decodedContent,
    );
  }
}
