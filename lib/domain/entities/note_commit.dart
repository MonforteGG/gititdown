import 'package:equatable/equatable.dart';

class NoteCommit extends Equatable {
  final String sha;
  final String message;
  final DateTime date;
  final String authorName;

  const NoteCommit({
    required this.sha,
    required this.message,
    required this.date,
    required this.authorName,
  });

  @override
  List<Object?> get props => [sha, message, date, authorName];
}
