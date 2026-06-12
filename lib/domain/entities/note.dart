import 'package:equatable/equatable.dart';

enum NoteType { file, directory }

class Note extends Equatable {
  final String name;
  final String path;
  final String sha;
  final String content;
  final DateTime? lastModified;
  final NoteType type;
  final String? downloadUrl;

  const Note({
    required this.name,
    required this.path,
    required this.sha,
    this.content = '',
    this.lastModified,
    this.type = NoteType.file,
    this.downloadUrl,
  });

  Note copyWith({
    String? name,
    String? path,
    String? sha,
    String? content,
    DateTime? lastModified,
    NoteType? type,
    String? downloadUrl,
  }) {
    return Note(
      name: name ?? this.name,
      path: path ?? this.path,
      sha: sha ?? this.sha,
      content: content ?? this.content,
      lastModified: lastModified ?? this.lastModified,
      type: type ?? this.type,
      downloadUrl: downloadUrl ?? this.downloadUrl,
    );
  }

  bool get isDirectory => type == NoteType.directory;

  bool get isFile => type == NoteType.file;

  bool get isMarkdown => isFile && name.toLowerCase().endsWith('.md');

  bool get isAudio => isFile && name.toLowerCase().endsWith('.mp3');

  String get parentPath {
    final lastSlashIndex = path.lastIndexOf('/');
    if (lastSlashIndex == -1) {
      return '';
    }
    return path.substring(0, lastSlashIndex);
  }

  @override
  List<Object?> get props => [name, path, sha, content, lastModified, type, downloadUrl];
}
