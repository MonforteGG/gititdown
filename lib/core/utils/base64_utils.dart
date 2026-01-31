import 'dart:convert';
import 'dart:typed_data';

class Base64Utils {
  /// Decodes a Base64 string, removing newlines first (GitHub requirement)
  static String decode(String base64String) {
    // Remove newlines as per GitHub API requirement
    final cleanBase64 = base64String.replaceAll('\n', '');
    final bytes = base64Decode(cleanBase64);
    return utf8.decode(bytes);
  }

  /// Encodes a string to Base64
  static String encode(String content) {
    final bytes = utf8.encode(content);
    return base64Encode(bytes);
  }

  /// Encodes bytes to Base64
  static String encodeBytes(Uint8List bytes) {
    return base64Encode(bytes);
  }
}
