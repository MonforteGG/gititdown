import '../../domain/entities/note_commit.dart';

class NoteCommitModel {
  final String sha;
  final String message;
  final DateTime date;
  final String authorName;

  NoteCommitModel({
    required this.sha,
    required this.message,
    required this.date,
    required this.authorName,
  });

  factory NoteCommitModel.fromJson(Map<String, dynamic> json) {
    final commit = json['commit'] as Map<String, dynamic>;
    final author = commit['author'] as Map<String, dynamic>;

    return NoteCommitModel(
      sha: json['sha'] as String,
      message: commit['message'] as String,
      date: DateTime.parse(author['date'] as String),
      authorName: author['name'] as String,
    );
  }

  NoteCommit toEntity() {
    return NoteCommit(
      sha: sha,
      message: message,
      date: date,
      authorName: authorName,
    );
  }
}
