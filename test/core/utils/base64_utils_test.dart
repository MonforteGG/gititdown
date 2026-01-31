import 'package:flutter_test/flutter_test.dart';
import 'package:gititdown/core/utils/base64_utils.dart';

void main() {
  group('Base64Utils', () {
    test('should encode string to base64', () {
      const input = 'Hello, World!';
      final encoded = Base64Utils.encode(input);
      expect(encoded, 'SGVsbG8sIFdvcmxkIQ==');
    });

    test('should decode base64 to string', () {
      const input = 'SGVsbG8sIFdvcmxkIQ==';
      final decoded = Base64Utils.decode(input);
      expect(decoded, 'Hello, World!');
    });

    test('should decode base64 with newlines removed', () {
      // GitHub API returns base64 with newlines
      const input = 'SGVs\nbG8s\nIFdv\ncmxk\nIQ==\n';
      final decoded = Base64Utils.decode(input);
      expect(decoded, 'Hello, World!');
    });

    test('should encode and decode correctly', () {
      const input = '# Markdown Header\n\nSome content here.';
      final encoded = Base64Utils.encode(input);
      final decoded = Base64Utils.decode(encoded);
      expect(decoded, input);
    });
  });
}
