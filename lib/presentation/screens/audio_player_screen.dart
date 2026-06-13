import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../domain/entities/note.dart';
import '../../domain/usecases/get_file.dart';
import '../../domain/usecases/get_file_bytes.dart';
import '../../domain/usecases/get_note.dart';
import '../providers/dependency_providers.dart';

const List<String> _fontFallback = ['Noto Sans'];

class AudioReference {
  final String label;
  final Duration position;
  final String sourcePath;
  final String sectionTitle;

  const AudioReference({
    required this.label,
    required this.position,
    required this.sourcePath,
    required this.sectionTitle,
  });
}

class AudioPlayerScreen extends ConsumerStatefulWidget {
  final Note note;
  final Duration? initialPosition;
  final bool autoplay;

  const AudioPlayerScreen({
    super.key,
    required this.note,
    this.initialPosition,
    this.autoplay = false,
  });

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen> {
  static final RegExp _wikiLinkPattern = RegExp(
    r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]',
  );
  static final RegExp _timeStampPattern = RegExp(
    r'^(?:(\d+):)?([0-5]?\d):([0-5]?\d)$',
  );
  final AudioPlayer _player = AudioPlayer();
  static const List<double> _playbackSpeeds = [1.0, 1.5, 2.0];
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  Note? _resolvedNote;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerState _playerState = PlayerState.stopped;
  double _playbackRate = 1.0;
  bool _isLoading = true;
  String? _errorMessage;
  bool _initialPlaybackHandled = false;
  List<AudioReference> _references = const [];
  String? _referenceSourcePath;

  @override
  void initState() {
    super.initState();
    _positionSubscription = _player.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
    _durationSubscription = _player.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration);
    });
    _playerStateSubscription = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playerState = state);
    });
    _loadAudio();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadAudio() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final note = widget.note.downloadUrl != null
        ? widget.note
        : await _fetchFreshFileInfo();

    if (note == null || note.downloadUrl == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not resolve the audio file URL.';
      });
      return;
    }

    try {
      if (kIsWeb) {
        await _loadWebAudio(note);
      } else {
        await _player.setSourceUrl(note.downloadUrl!);
      }

      await _loadSiblingReferences(note);
      await _applyInitialPlaybackOptions();

      if (!mounted) return;
      setState(() {
        _resolvedNote = note;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load audio: $error';
      });
    }
  }

  Future<void> _loadWebAudio(Note note) async {
    final getFileBytesUseCase = ref.read(getFileBytesUseCaseProvider);
    final result = await getFileBytesUseCase(
      GetFileBytesParams(path: note.path),
    );

    final bytes = result.fold<Uint8List?>((_) => null, (value) => value);
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Could not fetch authenticated audio bytes from GitHub.');
    }

    await _player.setSource(
      BytesSource(
        bytes,
        mimeType: 'audio/mpeg',
      ),
    );
  }

  Future<Note?> _fetchFreshFileInfo() async {
    final getFileUseCase = ref.read(getFileUseCaseProvider);
    final result = await getFileUseCase(GetFileParams(path: widget.note.path));
    return result.fold((_) => null, (note) => note);
  }

  Future<void> _loadSiblingReferences(Note note) async {
    final siblingNotePath = _buildSiblingNotePath(note.path);
    if (siblingNotePath == null) {
      if (!mounted) return;
      setState(() {
        _references = const [];
        _referenceSourcePath = null;
      });
      return;
    }

    final getNoteUseCase = ref.read(getNoteUseCaseProvider);
    final result = await getNoteUseCase(GetNoteParams(path: siblingNotePath));
    final siblingNote = result.fold<Note?>((_) => null, (value) => value);
    if (siblingNote == null) {
      if (!mounted) return;
      setState(() {
        _references = const [];
        _referenceSourcePath = null;
      });
      return;
    }

    final references = _extractReferences(
      content: siblingNote.content,
      audioNote: note,
      sourcePath: siblingNote.path,
    );

    if (!mounted) return;
    setState(() {
      _references = references;
      _referenceSourcePath = siblingNote.path;
    });
  }

  String? _buildSiblingNotePath(String audioPath) {
    final lastDotIndex = audioPath.lastIndexOf('.');
    if (lastDotIndex == -1) return null;
    return '${audioPath.substring(0, lastDotIndex)}.md';
  }

  List<AudioReference> _extractReferences({
    required String content,
    required Note audioNote,
    required String sourcePath,
  }) {
    final references = <AudioReference>[];
    final seenKeys = <String>{};
    final headings = _extractHeadings(content);

    for (final match in _wikiLinkPattern.allMatches(content)) {
      final rawTarget = match.group(1)?.trim() ?? '';
      final alias = match.group(2)?.trim();
      final parsedTarget = _parseWikiLinkTarget(rawTarget);
      final timestamp = parsedTarget.startAt;

      if (timestamp == null || !_matchesAudioTarget(parsedTarget.path, audioNote)) {
        continue;
      }

      final label = _buildReferenceLabel(
        content: content,
        match: match,
        alias: alias,
        fallbackLabel: rawTarget,
      );
      final dedupeKey =
          '${timestamp.inMilliseconds}|${label.trim().toLowerCase()}';
      if (!seenKeys.add(dedupeKey)) {
        continue;
      }

      references.add(
        AudioReference(
          label: label,
          position: timestamp,
          sourcePath: sourcePath,
          sectionTitle: _findHeadingForOffset(
            headings: headings,
            offset: match.start,
          ),
        ),
      );
    }

    references.sort((a, b) => a.position.compareTo(b.position));
    return references;
  }

  List<({int offset, String title})> _extractHeadings(String content) {
    final headings = <({int offset, String title})>[];
    final headingPattern = RegExp(r'^(#{1,6})\s+(.+)$', multiLine: true);

    for (final match in headingPattern.allMatches(content)) {
      final title = (match.group(2) ?? '').trim();
      if (title.isEmpty) continue;
      headings.add((offset: match.start, title: title));
    }

    return headings;
  }

  String _findHeadingForOffset({
    required List<({int offset, String title})> headings,
    required int offset,
  }) {
    String activeHeading = 'General';

    for (final heading in headings) {
      if (heading.offset > offset) {
        break;
      }
      activeHeading = heading.title;
    }

    return activeHeading;
  }

  String _buildReferenceLabel({
    required String content,
    required RegExpMatch match,
    required String? alias,
    required String fallbackLabel,
  }) {
    if (alias != null && alias.trim().isNotEmpty) {
      return alias.trim();
    }

    final lineStart = content.lastIndexOf('\n', match.start - 1);
    final rawPrefix = content.substring(lineStart + 1, match.start).trimRight();
    final cleanedPrefix = rawPrefix
        .replaceFirst(RegExp(r'^\s*[-*]\s*'), '')
        .replaceFirst(RegExp(r'^\s*\d+\.\s*'), '')
        .replaceFirst(RegExp(r'[:\-–]+\s*$'), '')
        .trim();

    return cleanedPrefix.isEmpty ? fallbackLabel : cleanedPrefix;
  }

  bool _matchesAudioTarget(String rawPath, Note audioNote) {
    final normalizedTarget = rawPath.trim().toLowerCase();
    if (normalizedTarget.isEmpty) return false;

    final audioPath = audioNote.path.toLowerCase();
    final audioName = audioNote.name.toLowerCase();
    final audioBaseName = _stripExtension(audioNote.name).toLowerCase();

    return normalizedTarget == audioPath ||
        normalizedTarget == audioName ||
        normalizedTarget.endsWith('/$audioName') ||
        normalizedTarget == audioBaseName;
  }

  ({String path, Duration? startAt}) _parseWikiLinkTarget(String rawTarget) {
    final trimmed = rawTarget.trim();
    if (trimmed.isEmpty) {
      return (path: trimmed, startAt: null);
    }

    final queryIndex = trimmed.indexOf('?');
    if (queryIndex != -1) {
      final path = trimmed.substring(0, queryIndex);
      final query = trimmed.substring(queryIndex + 1);
      return (path: path, startAt: _parseTimestampQuery(query));
    }

    final hashIndex = trimmed.lastIndexOf('#');
    if (hashIndex != -1) {
      final path = trimmed.substring(0, hashIndex);
      final fragment = trimmed.substring(hashIndex + 1);
      return (path: path, startAt: _parseTimestampFragment(fragment));
    }

    return (path: trimmed, startAt: null);
  }

  Duration? _parseTimestampQuery(String query) {
    for (final part in query.split('&')) {
      final separatorIndex = part.indexOf('=');
      if (separatorIndex == -1) continue;

      final key = part.substring(0, separatorIndex).toLowerCase();
      final value = part.substring(separatorIndex + 1);
      if (key == 't' || key == 'time' || key == 'start') {
        return _parseTimestampValue(value);
      }
    }
    return null;
  }

  Duration? _parseTimestampFragment(String fragment) {
    final normalized = fragment.toLowerCase();
    if (normalized.startsWith('t=')) {
      return _parseTimestampValue(fragment.substring(2));
    }
    return _parseTimestampValue(fragment);
  }

  Duration? _parseTimestampValue(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) return null;

    final asSeconds = int.tryParse(value);
    if (asSeconds != null) {
      return Duration(seconds: asSeconds);
    }

    final match = _timeStampPattern.firstMatch(value);
    if (match == null) return null;

    final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;

    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }

  String _stripExtension(String name) {
    final lastDotIndex = name.lastIndexOf('.');
    if (lastDotIndex == -1) return name;
    return name.substring(0, lastDotIndex);
  }

  Future<void> _applyInitialPlaybackOptions() async {
    if (_initialPlaybackHandled) return;
    _initialPlaybackHandled = true;

    if (widget.initialPosition != null) {
      await _player.seek(widget.initialPosition!);
    }

    if (widget.autoplay) {
      await _player.resume();
    }
  }

  Future<void> _togglePlayback() async {
    if (_resolvedNote?.downloadUrl == null) return;

    if (_playerState == PlayerState.playing) {
      await _player.pause();
      return;
    }

    await _player.resume();
  }

  Future<void> _seek(double value) async {
    await _player.seek(Duration(milliseconds: value.round()));
  }

  Future<void> _seekBy(Duration offset) async {
    final target = _position + offset;
    final maxPosition = _duration.inMilliseconds > 0 ? _duration : Duration.zero;
    final clamped = target < Duration.zero
        ? Duration.zero
        : target > maxPosition
            ? maxPosition
            : target;
    await _player.seek(clamped);
  }

  Future<void> _setPlaybackRate(double rate) async {
    await _player.setPlaybackRate(rate);
    if (!mounted) return;
    setState(() => _playbackRate = rate);
  }

  Future<void> _jumpToReference(AudioReference reference) async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
    }
    await _player.seek(reference.position);
    await _player.resume();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }

    return '$minutes:$seconds';
  }

  int get _activeReferenceIndex {
    if (_references.isEmpty) return -1;

    for (var i = 0; i < _references.length; i++) {
      final current = _references[i];
      final next = i + 1 < _references.length ? _references[i + 1] : null;
      final isActive = _position >= current.position &&
          (next == null || _position < next.position);

      if (isActive) {
        return i;
      }
    }

    return _position < _references.first.position ? -1 : _references.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final note = _resolvedNote ?? widget.note;
    final progressMax =
        _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0;
    final progressValue = _position.inMilliseconds
        .clamp(0, _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 1)
        .toDouble();
    final theme = Theme.of(context);
    final folderPath = note.parentPath.isEmpty ? 'Repository root' : note.parentPath;
    final activeReference = _activeReferenceIndex >= 0
        ? _references[_activeReferenceIndex]
        : null;
    final groupedReferences = <String, List<(int, AudioReference)>>{};
    for (var i = 0; i < _references.length; i++) {
      final reference = _references[i];
      groupedReferences.putIfAbsent(reference.sectionTitle, () => []).add(
            (i, reference),
          );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          note.name,
          style: GoogleFonts.plusJakartaSans().copyWith(
            fontFamilyFallback: _fontFallback,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.paperCream,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF7F0E5),
                    const Color(0xFFF5F4EF),
                    const Color(0xFFE8F0EE),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            left: -40,
            child: _AmbientBlob(
              size: 220,
              colors: const [Color(0x33E96A2B), Color(0x00E96A2B)],
            ),
          ),
          Positioned(
            right: -70,
            bottom: 80,
            child: _AmbientBlob(
              size: 260,
              colors: const [Color(0x33C9A959), Color(0x00C9A959)],
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.lg),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 96),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _errorMessage != null
                        ? _ErrorState(
                            message: _errorMessage!,
                            onRetry: _loadAudio,
                          )
                        : Container(
                            padding: const EdgeInsets.all(AppTheme.xl),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.76),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusLg + 8),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.9),
                              ),
                              boxShadow: AppTheme.elevatedShadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppTheme.lg),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusLg,
                                    ),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFEFD7B7),
                                        Color(0xFFE1E7DF),
                                        Color(0xFFD7E8E7),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isCompact = constraints.maxWidth < 640;
                                      return Flex(
                                        direction: isCompact
                                            ? Axis.vertical
                                            : Axis.horizontal,
                                        crossAxisAlignment: isCompact
                                            ? CrossAxisAlignment.start
                                            : CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 120,
                                            height: 120,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.72),
                                              borderRadius: BorderRadius.circular(30),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppTheme.inkBlack
                                                      .withOpacity(0.08),
                                                  blurRadius: 24,
                                                  offset: const Offset(0, 10),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.graphic_eq_rounded,
                                              size: 56,
                                              color: AppTheme.brandOrange,
                                            ),
                                          ),
                                          SizedBox(
                                            width: isCompact ? 0 : AppTheme.xl,
                                            height: isCompact ? AppTheme.lg : 0,
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Vault Audio',
                                                  style: GoogleFonts.playfairDisplay(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppTheme.warmGray,
                                                  ).copyWith(
                                                    fontFamilyFallback:
                                                        _fontFallback,
                                                  ),
                                                ),
                                                const SizedBox(height: AppTheme.sm),
                                                Text(
                                                  note.name,
                                                  style: theme.textTheme.headlineLarge,
                                                ),
                                                const SizedBox(height: AppTheme.sm),
                                                Text(
                                                  folderPath,
                                                  style: theme.textTheme.bodyMedium
                                                      ?.copyWith(
                                                    color: AppTheme.warmGray,
                                                  ),
                                                ),
                                                const SizedBox(height: AppTheme.md),
                                                Wrap(
                                                  spacing: AppTheme.sm,
                                                  runSpacing: AppTheme.sm,
                                                  children: [
                                                    _MetaChip(
                                                      icon:
                                                          Icons.audio_file_rounded,
                                                      label: 'MP3 file',
                                                    ),
                                                    _MetaChip(
                                                      icon: Icons.schedule_rounded,
                                                      label:
                                                          _formatDuration(_duration),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: AppTheme.xl),
                                Text(
                                  'Playback',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.inkBlack,
                                  ).copyWith(fontFamilyFallback: _fontFallback),
                                ),
                                const SizedBox(height: AppTheme.sm),
                                Text(
                                  note.path,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.warmGray,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.lg),
                                Container(
                                  padding: const EdgeInsets.all(AppTheme.lg),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F5F0),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusLg,
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFFE8E1D7),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      if (activeReference != null)
                                        Container(
                                          width: double.infinity,
                                          margin: const EdgeInsets.only(
                                            bottom: AppTheme.lg,
                                          ),
                                          padding: const EdgeInsets.all(
                                            AppTheme.md,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFFBF4),
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.radiusMd,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFE7D9C7),
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFF2DFC8),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    999,
                                                  ),
                                                ),
                                                child: Text(
                                                  _formatDuration(
                                                    activeReference.position,
                                                  ),
                                                  style: theme
                                                      .textTheme.labelLarge
                                                      ?.copyWith(
                                                    color: AppTheme.inkBlack,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(
                                                width: AppTheme.md,
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Now Discussing',
                                                      style: theme
                                                          .textTheme.labelSmall
                                                          ?.copyWith(
                                                        color:
                                                            AppTheme.mutedGray,
                                                        letterSpacing: 1.1,
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: AppTheme.xs,
                                                    ),
                                                    Text(
                                                      activeReference.label,
                                                      style: theme
                                                          .textTheme.bodyMedium
                                                          ?.copyWith(
                                                        color: AppTheme.inkBlack,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 6,
                                          activeTrackColor: AppTheme.brandOrange,
                                          inactiveTrackColor:
                                              const Color(0xFFE3DDD4),
                                          thumbColor: AppTheme.brandOrange,
                                          overlayColor: const Color(0x33E96A2B),
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                            enabledThumbRadius: 8,
                                          ),
                                        ),
                                        child: Slider(
                                          value: progressValue,
                                          min: 0,
                                          max: progressMax,
                                          onChanged: _seek,
                                        ),
                                      ),
                                      if (_references.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        _SoundCloudReferenceTrack(
                                          duration: _duration,
                                          references: _references,
                                          activeIndex: _activeReferenceIndex,
                                          onTap: _jumpToReference,
                                        ),
                                      ],
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          _TimeStamp(
                                            label: 'Position',
                                            value: _formatDuration(_position),
                                          ),
                                          _TimeStamp(
                                            label: 'Remaining',
                                            value: _formatDuration(
                                              (_duration - _position).isNegative
                                                  ? Duration.zero
                                                  : _duration - _position,
                                            ),
                                          ),
                                          _TimeStamp(
                                            label: 'Total',
                                            value: _formatDuration(_duration),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppTheme.lg),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: AppTheme.sm,
                                        runSpacing: AppTheme.sm,
                                        children: _playbackSpeeds
                                            .map(
                                              (speed) => ChoiceChip(
                                                label: Text('${speed}x'),
                                                selected: _playbackRate == speed,
                                                onSelected: (_) =>
                                                    _setPlaybackRate(speed),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                      const SizedBox(height: AppTheme.xl),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          _RoundControlButton(
                                            onPressed: () =>
                                                _seekBy(const Duration(seconds: -10)),
                                            icon: Icons.replay_10_rounded,
                                            label: '-10s',
                                            backgroundColor:
                                                const Color(0xFFF2DFC8),
                                            foregroundColor: AppTheme.inkBlack,
                                          ),
                                          const SizedBox(width: AppTheme.md),
                                          _RoundControlButton(
                                            onPressed: _togglePlayback,
                                            icon:
                                                _playerState == PlayerState.playing
                                                    ? Icons.pause_rounded
                                                    : Icons.play_arrow_rounded,
                                            label: _playerState ==
                                                    PlayerState.playing
                                                ? 'Pause'
                                                : 'Play',
                                            backgroundColor:
                                                AppTheme.brandOrange,
                                            foregroundColor: Colors.white,
                                            size: 78,
                                            iconSize: 34,
                                          ),
                                          const SizedBox(width: AppTheme.md),
                                          _RoundControlButton(
                                            onPressed: () =>
                                                _seekBy(const Duration(seconds: 10)),
                                            icon: Icons.forward_10_rounded,
                                            label: '+10s',
                                            backgroundColor:
                                                const Color(0xFFDCE8DF),
                                            foregroundColor: AppTheme.inkBlack,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (_references.isNotEmpty) ...[
                                  const SizedBox(height: AppTheme.xl),
                                  Container(
                                    padding: const EdgeInsets.all(AppTheme.lg),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.72),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusLg,
                                      ),
                                      border: Border.all(
                                        color: const Color(0xFFE7DED2),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'Referenced Moments',
                                          style: GoogleFonts.playfairDisplay(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.inkBlack,
                                          ).copyWith(
                                            fontFamilyFallback: _fontFallback,
                                          ),
                                        ),
                                        if (_referenceSourcePath != null) ...[
                                          const SizedBox(height: AppTheme.xs),
                                          Text(
                                            _referenceSourcePath!,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: AppTheme.warmGray,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: AppTheme.md),
                                        ...groupedReferences.entries.expand(
                                          (entry) sync* {
                                            yield Padding(
                                              padding: const EdgeInsets.only(
                                                top: AppTheme.sm,
                                                bottom: AppTheme.sm,
                                              ),
                                              child: Text(
                                                entry.key,
                                                style: theme
                                                    .textTheme.titleMedium
                                                    ?.copyWith(
                                                  color: AppTheme.inkBlack,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            );

                                            for (final item in entry.value) {
                                              final index = item.$1;
                                              final reference = item.$2;
                                              final isActive =
                                                  index == _activeReferenceIndex;

                                              yield Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: AppTheme.sm,
                                                ),
                                                child: _ReferenceCard(
                                                  reference: reference,
                                                  isActive: isActive,
                                                  isPlaying: isActive &&
                                                      _playerState ==
                                                          PlayerState.playing,
                                                  onTap: () async {
                                                    if (isActive &&
                                                        _playerState ==
                                                            PlayerState.playing) {
                                                      await _player.pause();
                                                      return;
                                                    }
                                                    await _jumpToReference(
                                                      reference,
                                                    );
                                                  },
                                                  formatDuration:
                                                      _formatDuration,
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundCloudReferenceTrack extends StatelessWidget {
  final Duration duration;
  final List<AudioReference> references;
  final int activeIndex;
  final ValueChanged<AudioReference> onTap;

  const _SoundCloudReferenceTrack({
    required this.duration,
    required this.references,
    required this.activeIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalMilliseconds = duration.inMilliseconds;
    if (totalMilliseconds <= 0) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 24,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const markerWidth = 18.0;
          const minimumGap = 12.0;
          final leftPositions = <double>[];

          for (final reference in references) {
            final fraction =
                reference.position.inMilliseconds / totalMilliseconds;
            final desiredLeft = (constraints.maxWidth * fraction)
                .clamp(0.0, constraints.maxWidth - markerWidth);
            final adjustedLeft = leftPositions.isEmpty
                ? desiredLeft
                : desiredLeft < leftPositions.last + minimumGap
                    ? (leftPositions.last + minimumGap)
                        .clamp(0.0, constraints.maxWidth - markerWidth)
                    : desiredLeft;
            leftPositions.add(adjustedLeft);
          }

          return Stack(
            children: List.generate(references.length, (index) {
              final reference = references[index];
              final left = leftPositions[index];
              final isActive = index == activeIndex;

              return Positioned(
                left: left,
                child: Tooltip(
                  message: reference.label,
                  waitDuration: const Duration(milliseconds: 180),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => onTap(reference),
                      child: Container(
                        width: markerWidth,
                        height: 24,
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: isActive ? 7 : 6,
                          height: isActive ? 18 : 16,
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppTheme.brandOrange
                                : AppTheme.inkGold,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  final AudioReference reference;
  final bool isActive;
  final bool isPlaying;
  final Future<void> Function() onTap;
  final String Function(Duration) formatDuration;

  const _ReferenceCard({
    required this.reference,
    required this.isActive,
    required this.isPlaying,
    required this.onTap,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? const Color(0xFFFFF6EA) : const Color(0xFFFFFCF7),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isActive
                  ? const Color(0xFFE2C49E)
                  : const Color(0xFFE7DED2),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFECCB9E)
                      : const Color(0xFFF2DFC8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  formatDuration(reference.position),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.inkBlack,
                      ),
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Text(
                  reference.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.inkBlack,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: AppTheme.sm),
              Icon(
                isPlaying
                    ? Icons.pause_circle_outline_rounded
                    : Icons.play_circle_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmbientBlob extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _AmbientBlob({
    required this.size,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.95)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppTheme.warmGray,
          ),
          const SizedBox(width: AppTheme.sm),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.inkBlack,
                ),
          ),
        ],
      ),
    );
  }
}

class _TimeStamp extends StatelessWidget {
  final String label;
  final String value;

  const _TimeStamp({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.mutedGray,
                letterSpacing: 1.1,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.inkBlack,
          ).copyWith(fontFamilyFallback: _fontFallback),
        ),
      ],
    );
  }
}

class _RoundControlButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final double size;
  final double iconSize;

  const _RoundControlButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.size = 56,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: backgroundColor,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                size: iconSize,
                color: foregroundColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.sm),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.warmGray,
              ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: AppTheme.md),
        Text(
          message,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.md),
        FilledButton(
          onPressed: onRetry,
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
