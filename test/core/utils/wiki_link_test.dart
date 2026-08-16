import 'package:flutter_test/flutter_test.dart';
import 'package:gititdown/core/utils/wiki_link.dart';

void main() {
  group('WikiLinks.parseTarget', () {
    test('keeps a plain audio path', () {
      final parsed = WikiLinks.parseTarget('meetings/standup.mp3');
      expect(parsed.path, 'meetings/standup.mp3');
      expect(parsed.startAt, isNull);
    });

    test('parses MM:SS fragment timestamps', () {
      final parsed = WikiLinks.parseTarget('audio.mp3#03:44');
      expect(parsed.path, 'audio.mp3');
      expect(parsed.startAt, const Duration(minutes: 3, seconds: 44));
    });

    test('parses hour-long HH:MM:SS fragment timestamps', () {
      final parsed = WikiLinks.parseTarget('audio.mp3#01:23:45');
      expect(parsed.path, 'audio.mp3');
      expect(parsed.startAt, const Duration(hours: 1, minutes: 23, seconds: 45));
    });

    test('parses unpadded hour timestamps', () {
      final parsed = WikiLinks.parseTarget('audio.mp3#1:00:00');
      expect(parsed.path, 'audio.mp3');
      expect(parsed.startAt, const Duration(hours: 1));
    });

    test('parses t= hour timestamps', () {
      final parsed = WikiLinks.parseTarget('audio.mp3#t=1:02:03');
      expect(parsed.path, 'audio.mp3');
      expect(parsed.startAt, const Duration(hours: 1, minutes: 2, seconds: 3));
    });

    test('parses query timestamps in seconds', () {
      final parsed = WikiLinks.parseTarget('audio.mp3?t=754');
      expect(parsed.path, 'audio.mp3');
      expect(parsed.startAt, const Duration(seconds: 754));
    });

    test('parses query timestamps past one hour', () {
      final parsed = WikiLinks.parseTarget('audio.mp3?t=3723');
      expect(parsed.path, 'audio.mp3');
      expect(parsed.startAt, const Duration(hours: 1, minutes: 2, seconds: 3));
    });

    test('parses minutes overflow as more than one hour', () {
      final parsed = WikiLinks.parseTarget('audio.mp3#75:00');
      expect(parsed.path, 'audio.mp3');
      expect(parsed.startAt, const Duration(hours: 1, minutes: 15));
    });

    test('parses 1h2m3s tokens', () {
      final parsed = WikiLinks.parseTarget('audio.mp3#t=1h2m3s');
      expect(parsed.startAt, const Duration(hours: 1, minutes: 2, seconds: 3));
    });

    test('uses the start of a media fragment range', () {
      final parsed = WikiLinks.parseTarget('audio.mp3#t=1:00:00,1:05:00');
      expect(parsed.startAt, const Duration(hours: 1));
    });
  });

  group('WikiLinks preview hrefs', () {
    test('round-trips hour timestamps through the preview URI', () {
      const target = 'meetings/long.mp3#01:23:45';
      final href = WikiLinks.previewUri(target).toString();
      final restored = WikiLinks.targetFromHref(href);

      expect(restored, target);
      expect(
        WikiLinks.parseTarget(restored!).startAt,
        const Duration(hours: 1, minutes: 23, seconds: 45),
      );
    });

    test('recovers a decoded hash timestamp from the old preview format', () {
      final restored = WikiLinks.targetFromHref(
        'gititdown://note/audio.mp3#01:23:45',
      );

      expect(restored, 'audio.mp3#01:23:45');
      expect(
        WikiLinks.parseTarget(restored!).startAt,
        const Duration(hours: 1, minutes: 23, seconds: 45),
      );
    });

    test('keeps aliases in the preview label', () {
      final markdown = WikiLinks.toPreviewMarkdown(
        rawTarget: 'audio.mp3#01:23:45',
        alias: 'decision',
      );

      expect(markdown, contains('[decision]'));
      expect(markdown, contains('target=audio.mp3'));
    });

    test('preview markdown href round-trips hour timestamps', () {
      final markdown = WikiLinks.toPreviewMarkdown(
        rawTarget: 'meetings/long.mp3#01:23:45',
      );
      final href = RegExp(r'\(<([^>]+)>\)').firstMatch(markdown)?.group(1);

      expect(href, isNotNull);
      expect(markdown, isNot(contains('#01:23:45')));
      expect(markdown, contains('<gititdown://note?'));
      expect(markdown, contains('[1h 23m 45s]'));
      expect(
        WikiLinks.parseTarget(WikiLinks.targetFromHref(href!)!).startAt,
        const Duration(hours: 1, minutes: 23, seconds: 45),
      );
    });
  });
}
