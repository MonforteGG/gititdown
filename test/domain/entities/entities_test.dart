import 'package:flutter_test/flutter_test.dart';
import 'package:gititdown/domain/entities/note.dart';
import 'package:gititdown/domain/entities/user_config.dart';

void main() {
  group('Note Entity', () {
    test('should create a Note with required fields', () {
      const note = Note(
        name: 'test.md',
        path: 'notes/test.md',
        sha: 'abc123',
      );

      expect(note.name, 'test.md');
      expect(note.path, 'notes/test.md');
      expect(note.sha, 'abc123');
      expect(note.content, '');
    });

    test('should create a Note with all fields', () {
      const note = Note(
        name: 'test.md',
        path: 'notes/test.md',
        sha: 'abc123',
        content: '# Hello',
      );

      expect(note.content, '# Hello');
    });

    test('should copy Note with new values', () {
      const note = Note(
        name: 'test.md',
        path: 'notes/test.md',
        sha: 'abc123',
        content: '# Hello',
      );

      final copied = note.copyWith(content: '# Updated');

      expect(copied.name, 'test.md');
      expect(copied.path, 'notes/test.md');
      expect(copied.sha, 'abc123');
      expect(copied.content, '# Updated');
    });

    test('should support value equality', () {
      const note1 = Note(
        name: 'test.md',
        path: 'notes/test.md',
        sha: 'abc123',
        content: '# Hello',
      );

      const note2 = Note(
        name: 'test.md',
        path: 'notes/test.md',
        sha: 'abc123',
        content: '# Hello',
      );

      expect(note1, note2);
    });
  });

  group('UserConfig Entity', () {
    test('should create UserConfig with all fields', () {
      const config = UserConfig(
        username: 'octocat',
        repository: 'my-notes',
        pat: 'ghp_xxxxxxxxxxxx',
      );

      expect(config.username, 'octocat');
      expect(config.repository, 'my-notes');
      expect(config.pat, 'ghp_xxxxxxxxxxxx');
    });

    test('should copy UserConfig with new values', () {
      const config = UserConfig(
        username: 'octocat',
        repository: 'my-notes',
        pat: 'ghp_old',
      );

      final copied = config.copyWith(pat: 'ghp_new');

      expect(copied.username, 'octocat');
      expect(copied.repository, 'my-notes');
      expect(copied.pat, 'ghp_new');
    });

    test('should support value equality', () {
      const config1 = UserConfig(
        username: 'octocat',
        repository: 'my-notes',
        pat: 'ghp_xxxxxxxxxxxx',
      );

      const config2 = UserConfig(
        username: 'octocat',
        repository: 'my-notes',
        pat: 'ghp_xxxxxxxxxxxx',
      );

      expect(config1, config2);
    });
  });
}
