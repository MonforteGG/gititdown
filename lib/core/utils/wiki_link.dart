class WikiLinkTarget {
  final String path;
  final Duration? startAt;

  const WikiLinkTarget({
    required this.path,
    this.startAt,
  });
}

class WikiLinks {
  static final RegExp pattern = RegExp(
    r'!?\[\[([^\]|]+)(?:\|([^\]]+))?\]\]',
  );

  static WikiLinkTarget parseTarget(String rawTarget) {
    final trimmed = rawTarget.trim();
    if (trimmed.isEmpty) {
      return const WikiLinkTarget(path: '');
    }

    final queryIndex = trimmed.indexOf('?');
    if (queryIndex != -1) {
      final path = trimmed.substring(0, queryIndex);
      final query = trimmed.substring(queryIndex + 1);
      return WikiLinkTarget(
        path: path,
        startAt: _parseTimestampQuery(query),
      );
    }

    final hashIndex = trimmed.lastIndexOf('#');
    if (hashIndex != -1) {
      final path = trimmed.substring(0, hashIndex);
      final fragment = trimmed.substring(hashIndex + 1);
      return WikiLinkTarget(
        path: path,
        startAt: _parseTimestampFragment(fragment),
      );
    }

    return WikiLinkTarget(path: trimmed);
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }

    return '$minutes:$seconds';
  }

  static String formatPreviewLabel(Duration duration) {
    if (duration.inHours <= 0) {
      return formatDuration(duration);
    }

    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final parts = <String>['${duration.inHours}h'];
    if (minutes > 0) parts.add('${minutes}m');
    if (seconds > 0) parts.add('${seconds}s');
    return parts.join(' ');
  }

  static String toPreviewMarkdown({
    required String rawTarget,
    String? alias,
  }) {
    final parsedTarget = parseTarget(rawTarget);
    final trimmedAlias = alias?.trim();
    final label = (trimmedAlias != null && trimmedAlias.isNotEmpty)
        ? trimmedAlias
        : parsedTarget.startAt != null
            ? formatPreviewLabel(parsedTarget.startAt!)
            : (parsedTarget.path.isNotEmpty ? parsedTarget.path : rawTarget);
    final safeLabel = label.replaceAll(']', r'\]');
    return '[$safeLabel](<${previewUri(rawTarget)}>)';
  }

  static Uri previewUri(String rawTarget) {
    return Uri(
      scheme: 'gititdown',
      host: 'note',
      queryParameters: {'target': rawTarget},
    );
  }

  static String? targetFromHref(String href) {
    var normalizedHref = href.trim();
    if (normalizedHref.startsWith('<') && normalizedHref.endsWith('>')) {
      normalizedHref = normalizedHref.substring(1, normalizedHref.length - 1);
    }

    final uri = Uri.tryParse(normalizedHref);
    if (uri == null || uri.scheme != 'gititdown' || uri.host != 'note') {
      return null;
    }

    final fromQuery = uri.queryParameters['target'];
    if (fromQuery != null && fromQuery.isNotEmpty) {
      return fromQuery;
    }

    var path = uri.path;
    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    var target = path.isEmpty ? '' : Uri.decodeComponent(path);
    if (uri.hasQuery) {
      target = target.isEmpty ? '?${uri.query}' : '$target?${uri.query}';
    }
    if (uri.hasFragment) {
      target = '$target#${uri.fragment}';
    }

    return target.isEmpty ? null : target;
  }

  static Duration? parseTimestampValue(String rawValue) {
    var value = rawValue.trim();
    if (value.isEmpty) return null;

    if (value.toLowerCase().startsWith('npt:')) {
      value = value.substring(4).trim();
    }

    final commaIndex = value.indexOf(',');
    if (commaIndex != -1) {
      value = value.substring(0, commaIndex).trim();
    }

    if (value.isEmpty) return null;

    final hmsDuration = _parseHmsToken(value);
    if (hmsDuration != null) return hmsDuration;

    final numericSeconds = double.tryParse(value);
    if (numericSeconds != null && numericSeconds >= 0) {
      return Duration(milliseconds: (numericSeconds * 1000).round());
    }

    return _parseColonTimestamp(value);
  }

  static Duration? _parseTimestampQuery(String query) {
    for (final part in query.split('&')) {
      final separatorIndex = part.indexOf('=');
      if (separatorIndex == -1) continue;

      final key = part.substring(0, separatorIndex).toLowerCase();
      final value = part.substring(separatorIndex + 1);
      if (key == 't' || key == 'time' || key == 'start') {
        return parseTimestampValue(value);
      }
    }
    return null;
  }

  static Duration? _parseTimestampFragment(String fragment) {
    final normalized = fragment.toLowerCase();
    if (normalized.startsWith('t=')) {
      return parseTimestampValue(fragment.substring(2));
    }
    return parseTimestampValue(fragment);
  }

  static Duration? _parseHmsToken(String value) {
    if (!RegExp(r'[hms]', caseSensitive: false).hasMatch(value)) {
      return null;
    }

    final match = RegExp(
      r'^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+(?:\.\d+)?)s)?$',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null || match.group(0) == null || match.group(0)!.isEmpty) {
      return null;
    }

    final hours = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
    final secondsRaw = match.group(3);
    final seconds = secondsRaw == null ? 0.0 : (double.tryParse(secondsRaw) ?? 0.0);

    if (hours == 0 && minutes == 0 && seconds == 0 && secondsRaw == null) {
      return null;
    }

    return Duration(hours: hours, minutes: minutes) +
        Duration(milliseconds: (seconds * 1000).round());
  }

  static Duration? _parseColonTimestamp(String value) {
    final parts = value.split(':');
    if (parts.length < 2 || parts.length > 3) return null;

    final numbers = <double>[];
    for (final part in parts) {
      final parsed = double.tryParse(part);
      if (parsed == null || parsed < 0) return null;
      numbers.add(parsed);
    }

    if (parts.length == 2) {
      final minutes = numbers[0].truncate();
      final seconds = numbers[1];
      if (seconds >= 60) return null;
      return Duration(minutes: minutes) +
          Duration(milliseconds: (seconds * 1000).round());
    }

    final hours = numbers[0].truncate();
    final minutes = numbers[1].truncate();
    final seconds = numbers[2];
    if (seconds >= 60) return null;

    return Duration(hours: hours, minutes: minutes) +
        Duration(milliseconds: (seconds * 1000).round());
  }
}
