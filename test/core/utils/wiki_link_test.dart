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

    test('parses 63:31 as 63 minutes, not as an hour timestamp', () {
      final parsed = WikiLinks.parseTarget(
        '2026-07-06 - Reunion Revision propuesta DeCA - Proyecto DeCA.mp3#63:31',
      );
      expect(
        parsed.path,
        '2026-07-06 - Reunion Revision propuesta DeCA - Proyecto DeCA.mp3',
      );
      expect(parsed.startAt, const Duration(minutes: 63, seconds: 31));
      expect(parsed.startAt, isNot(const Duration(hours: 6, minutes: 3, seconds: 31)));
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
    test('round-trips 63:31 through the encoded preview href', () {
      const target = 'audio.mp3#63:31';
      final href = 'gititdown://note/${Uri.encodeComponent(target)}';
      final restored = WikiLinks.targetFromHref(href);

      expect(restored, target);
      expect(
        WikiLinks.parseTarget(restored!).startAt,
        const Duration(minutes: 63, seconds: 31),
      );
    });

    test('recovers a decoded 63:31 hash timestamp', () {
      final restored = WikiLinks.targetFromHref(
        'gititdown://note/audio.mp3#63:31',
      );

      expect(restored, 'audio.mp3#63:31');
      expect(
        WikiLinks.parseTarget(restored!).startAt,
        const Duration(minutes: 63, seconds: 31),
      );
    });

    test('round-trips a spaced filename with a 63:31 timestamp', () {
      const content =
          '[[2026-07-06 - Reunion Revision propuesta DeCA - Proyecto DeCA.mp3#63:31|A día de hoy no se sube a ninguno]]';
      final match = WikiLinks.pattern.firstMatch(content);
      expect(match, isNotNull);
      expect(
        match!.group(1),
        '2026-07-06 - Reunion Revision propuesta DeCA - Proyecto DeCA.mp3#63:31',
      );
      expect(match.group(2), 'A día de hoy no se sube a ninguno');

      final markdown = WikiLinks.toPreviewMarkdown(rawTarget: match.group(1)!);
      expect(markdown, contains('[01:03:31]'));
      expect(
        markdown,
        isNot(contains('[A día de hoy no se sube a ninguno]')),
      );

      final href = RegExp(
        r'\((gititdown://note/[^)]+)\)',
      ).firstMatch(markdown)?.group(1);
      final restored = WikiLinks.targetFromHref(href!);
      expect(restored, match.group(1));
      expect(
        WikiLinks.parseTarget(restored!).startAt,
        const Duration(minutes: 63, seconds: 31),
      );
    });

    test('preview markdown href round-trips hour timestamps', () {
      final markdown = WikiLinks.toPreviewMarkdown(
        rawTarget: 'meetings/long.mp3#01:23:45',
      );
      final href = RegExp(
        r'\((gititdown://note/[^)]+)\)',
      ).firstMatch(markdown)?.group(1);

      expect(href, isNotNull);
      expect(markdown, isNot(contains('#01:23:45')));
      expect(markdown, contains('[01:23:45]'));
      expect(
        WikiLinks.parseTarget(WikiLinks.targetFromHref(href!)!).startAt,
        const Duration(hours: 1, minutes: 23, seconds: 45),
      );
    });
  });
}
