import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../core/error/failures.dart';
import '../../core/utils/wiki_link.dart';
import '../../domain/entities/note.dart';
import '../../presentation/providers/notes_provider.dart';
import '../../presentation/providers/search_provider.dart';
import 'audio_player_screen.dart';
import 'history_screen.dart';
import 'pdf_viewer_screen.dart';
import '../widgets/editor_components.dart';
import '../widgets/github_footer.dart';
import '../widgets/notebook_background.dart';

// Font fallback for characters not covered by primary fonts
const List<String> _fontFallback = ['Noto Sans'];

enum EditorMode { view, edit }

class EditorScreen extends ConsumerStatefulWidget {
  final Note? note;

  const EditorScreen({super.key, this.note});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with TickerProviderStateMixin {
  static final RegExp _wikiLinkPattern = WikiLinks.pattern;

  late TextEditingController _contentController;
  late TextEditingController _nameController;
  late EditorMode _mode;
  bool _hasChanges = false;
  bool _isLoadingContent = false;
  Note? _loadedNote;
  String? _activeWikiQuery;
  List<Note> _wikiSuggestions = const [];
  int _selectedWikiSuggestionIndex = 0;
  late FocusNode _editorFocusNode;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _editorFocusNode = FocusNode();
    _contentController =
        TextEditingController(text: widget.note?.content ?? '');
    _nameController = TextEditingController(
      text: widget.note != null ? _stripExtension(widget.note!.name) : '',
    );
    _mode = widget.note == null ? EditorMode.edit : EditorMode.view;
    _loadedNote = widget.note;

    _contentController.addListener(_onContentChanged);
    _nameController.addListener(_onContentChanged);

    // Animation setup
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    // Load content if opening an existing note without content
    if (widget.note != null && widget.note!.content.isEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _loadNoteContent();
      });
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      ref.read(vaultSearchProvider.notifier).loadVaultEntries();
    });
  }

  Future<void> _loadNoteContent() async {
    setState(() {
      _isLoadingContent = true;
    });

    await ref.read(notesProvider.notifier).loadNote(widget.note!.path);

    final notesState = ref.read(notesProvider);
    if (notesState.selectedNote != null) {
      _loadedNote = notesState.selectedNote;
      _contentController.text = notesState.selectedNote!.content;
      setState(() {
        _hasChanges = false;
      });
    }

    setState(() {
      _isLoadingContent = false;
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _editorFocusNode.dispose();
    _contentController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    setState(() {
      _hasChanges = true;
    });
    _updateWikiSuggestions();
  }

  String _stripExtension(String name) {
    if (name.endsWith('.md')) {
      return name.substring(0, name.length - 3);
    }
    return name;
  }

  String _addExtension(String name) {
    if (!name.endsWith('.md')) {
      return '$name.md';
    }
    return name;
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.error_outline,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppTheme.md),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppTheme.md),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => const UnsavedChangesDialog(),
    );

    if (result == 'save') {
      await _saveNote();
      return true;
    } else if (result == 'discard') {
      return true;
    }
    return false;
  }

  Future<void> _handleBlockedPop() async {
    if (await _onWillPop() && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveNote() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showErrorSnackbar('Please enter a note name');
      return;
    }

    final content = _contentController.text;
    final fullName = _addExtension(name);
    final currentNote = _loadedNote ?? widget.note;
    final currentPath = ref.read(notesProvider).currentPath;
    final path = currentNote?.path ??
        (currentPath.isEmpty ? fullName : '$currentPath/$fullName');

    final note = Note(
      name: fullName,
      path: path,
      sha: currentNote?.sha ?? '',
      content: content,
      lastModified: DateTime.now(),
    );

    final success = await ref.read(notesProvider.notifier).saveNote(note);

    if (success) {
      if (!mounted) return;
      _showSuccessSnackbar('Note saved');
      setState(() {
        _hasChanges = false;
        _loadedNote = ref.read(notesProvider).selectedNote;
      });
      if (widget.note == null) {
        Navigator.of(context).pop();
      }
    } else {
      final notesState = ref.read(notesProvider);
      if (notesState.errorMessage != null) {
        _showErrorSnackbar(notesState.errorMessage!);
      } else {
        _showErrorSnackbar(
            notesState.failure?.message ?? 'Failed to save note');
      }
    }
  }

  void _toggleMode(EditorMode mode) {
    setState(() {
      _mode = mode;
    });
  }

  TextSelection _safeSelection() {
    final selection = _contentController.selection;
    if (selection.isValid) {
      return selection;
    }

    final textLength = _contentController.text.length;
    return TextSelection.collapsed(offset: textLength);
  }

  void _updateEditorValue({
    required String text,
    required TextSelection selection,
  }) {
    _contentController.value = TextEditingValue(
      text: text,
      selection: selection,
    );
    _editorFocusNode.requestFocus();
    _updateWikiSuggestions();
  }

  void _wrapSelection({
    required String prefix,
    required String suffix,
    required String placeholder,
  }) {
    final selection = _safeSelection();
    final text = _contentController.text;
    final start = selection.start;
    final end = selection.end;
    final selectedText =
        start == end ? placeholder : text.substring(start, end);
    final replacement = '$prefix$selectedText$suffix';
    final updatedText = text.replaceRange(start, end, replacement);

    _updateEditorValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  void _prefixSelectedLines(String prefix, {String placeholder = 'Item'}) {
    final selection = _safeSelection();
    final text = _contentController.text;
    final start = selection.start;
    final end = selection.end;

    if (start == end) {
      final replacement = '$prefix$placeholder';
      final updatedText = text.replaceRange(start, end, replacement);
      _updateEditorValue(
        text: updatedText,
        selection: TextSelection.collapsed(offset: start + replacement.length),
      );
      return;
    }

    final blockStart = text.lastIndexOf('\n', start - 1);
    final normalizedStart = blockStart == -1 ? 0 : blockStart + 1;
    final blockEndIndex = text.indexOf('\n', end);
    final normalizedEnd = blockEndIndex == -1 ? text.length : blockEndIndex;
    final selectedBlock = text.substring(normalizedStart, normalizedEnd);
    final replacement = selectedBlock
        .split('\n')
        .map((line) => line.isEmpty ? prefix.trimRight() : '$prefix$line')
        .join('\n');

    final updatedText = text.substring(0, normalizedStart) +
        replacement +
        text.substring(normalizedEnd);

    _updateEditorValue(
      text: updatedText,
      selection: TextSelection(
        baseOffset: normalizedStart,
        extentOffset: normalizedStart + replacement.length,
      ),
    );
  }

  void _insertMarkdownLink() {
    final selection = _safeSelection();
    final text = _contentController.text;
    final start = selection.start;
    final end = selection.end;
    final selectedText =
        start == end ? 'link text' : text.substring(start, end);
    final replacement = '[$selectedText](https://)';
    final updatedText = text.replaceRange(start, end, replacement);
    final urlStart = start + selectedText.length + 3;

    _updateEditorValue(
      text: updatedText,
      selection:
          TextSelection(baseOffset: urlStart, extentOffset: urlStart + 8),
    );
  }

  void _insertWikiLink() {
    _wrapSelection(prefix: '[[', suffix: ']]', placeholder: 'note');
  }

  void _insertCodeBlock() {
    final selection = _safeSelection();
    final text = _contentController.text;
    final start = selection.start;
    final end = selection.end;
    final selectedText =
        start == end ? '\ncode\n' : '\n${text.substring(start, end)}\n';
    final replacement = '```$selectedText```';
    final updatedText = text.replaceRange(start, end, replacement);

    _updateEditorValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  void _updateWikiSuggestions() {
    final selection = _contentController.selection;
    if (!selection.isValid) {
      if (_activeWikiQuery != null || _wikiSuggestions.isNotEmpty) {
        setState(() {
          _activeWikiQuery = null;
          _wikiSuggestions = const [];
          _selectedWikiSuggestionIndex = 0;
        });
      }
      return;
    }

    final cursorIndex = selection.baseOffset;
    if (cursorIndex < 0) return;

    final text = _contentController.text;
    final textBeforeCursor = text.substring(0, cursorIndex);
    final openIndex = textBeforeCursor.lastIndexOf('[[');
    if (openIndex == -1) {
      if (_activeWikiQuery != null || _wikiSuggestions.isNotEmpty) {
        setState(() {
          _activeWikiQuery = null;
          _wikiSuggestions = const [];
          _selectedWikiSuggestionIndex = 0;
        });
      }
      return;
    }

    final afterOpen = textBeforeCursor.substring(openIndex + 2);
    if (afterOpen.contains(']]') ||
        afterOpen.contains('\n') ||
        afterOpen.contains('|')) {
      if (_activeWikiQuery != null || _wikiSuggestions.isNotEmpty) {
        setState(() {
          _activeWikiQuery = null;
          _wikiSuggestions = const [];
          _selectedWikiSuggestionIndex = 0;
        });
      }
      return;
    }

    final query = afterOpen.trim();
    final vaultEntries = ref.read(vaultSearchProvider).vaultEntries;
    final fileEntries = vaultEntries.where((entry) => entry.isFile).toList();
    final normalizedQuery = query.toLowerCase();

    final suggestions = fileEntries
        .where((entry) {
          if (normalizedQuery.isEmpty) return true;
          final displayPath = entry.path.toLowerCase();
          final displayName = _stripExtension(entry.name).toLowerCase();
          return displayName.contains(normalizedQuery) ||
              displayPath.contains(normalizedQuery);
        })
        .take(8)
        .toList();

    setState(() {
      _activeWikiQuery = query;
      _wikiSuggestions = suggestions;
      _selectedWikiSuggestionIndex = suggestions.isEmpty
          ? 0
          : _selectedWikiSuggestionIndex.clamp(0, suggestions.length - 1);
    });
  }

  void _applyWikiSuggestion(Note note) {
    final selection = _contentController.selection;
    if (!selection.isValid) return;

    final cursorIndex = selection.baseOffset;
    final text = _contentController.text;
    final textBeforeCursor = text.substring(0, cursorIndex);
    final openIndex = textBeforeCursor.lastIndexOf('[[');
    if (openIndex == -1) return;

    final displayTarget = note.path.endsWith('.md')
        ? note.path.substring(0, note.path.length - 3)
        : note.path;
    final replacement = '[[$displayTarget]]';
    final updatedText = text.substring(0, openIndex) +
        replacement +
        text.substring(cursorIndex);
    final newCursorOffset = openIndex + replacement.length;

    _contentController.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: newCursorOffset),
    );

    setState(() {
      _wikiSuggestions = const [];
      _activeWikiQuery = null;
      _selectedWikiSuggestionIndex = 0;
    });
  }

  KeyEventResult _handleEditorKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (_wikiSuggestions.isEmpty) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedWikiSuggestionIndex =
            (_selectedWikiSuggestionIndex + 1) % _wikiSuggestions.length;
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedWikiSuggestionIndex =
            (_selectedWikiSuggestionIndex - 1 + _wikiSuggestions.length) %
                _wikiSuggestions.length;
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      _applyWikiSuggestion(_wikiSuggestions[_selectedWikiSuggestionIndex]);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() {
        _wikiSuggestions = const [];
        _activeWikiQuery = null;
        _selectedWikiSuggestionIndex = 0;
      });
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  String _normalizeMarkdownForPreview(String content) {
    final normalizedFrontmatter = _normalizeFrontmatterForPreview(content);

    return normalizedFrontmatter.replaceAllMapped(_wikiLinkPattern, (match) {
      final target = match.group(1)?.trim() ?? '';
      return WikiLinks.toPreviewMarkdown(rawTarget: target);
    });
  }

  String _normalizeFrontmatterForPreview(String content) {
    final lines = content.split('\n');
    if (lines.length < 3 || lines.first.trim() != '---') {
      return content;
    }

    var closingIndex = -1;
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        closingIndex = i;
        break;
      }
    }

    if (closingIndex == -1) {
      return content;
    }

    final frontmatterLines = lines.sublist(1, closingIndex);
    final bodyLines = lines.sublist(closingIndex + 1);
    final tableLines = <String>[
      '|  |  |',
      '| --- | --- |',
    ];

    for (var i = 0; i < frontmatterLines.length; i++) {
      final line = frontmatterLines[i].trimRight();
      if (line.trim().isEmpty) {
        continue;
      }

      final keyMatch = RegExp(r'^([A-Za-z0-9_-]+):\s*(.*)$').firstMatch(line);
      if (keyMatch == null) {
        continue;
      }

      final key = keyMatch.group(1) ?? '';
      final rawValue = keyMatch.group(2)?.trim() ?? '';

      if (rawValue.isEmpty) {
        final items = <String>[];
        var j = i + 1;
        while (j < frontmatterLines.length) {
          final candidate = frontmatterLines[j].trim();
          if (!candidate.startsWith('- ')) {
            break;
          }
          items.add(candidate.substring(2).trim());
          j++;
        }

        if (items.isNotEmpty) {
          tableLines.add(
            '| **${_escapeTableCell(key)}** | ${_escapeTableCell(items.join(', '))} |',
          );
          i = j - 1;
          continue;
        }
      }

      tableLines.add(
        '| **${_escapeTableCell(key)}** | ${_escapeTableCell(rawValue)} |',
      );
    }

    if (tableLines.length == 2) {
      return content;
    }

    final remainingBody = bodyLines.join('\n').trimLeft();
    if (remainingBody.isEmpty) {
      return '${tableLines.join('\n')}\n';
    }

    return '${tableLines.join('\n')}\n\n$remainingBody';
  }

  String _escapeTableCell(String value) {
    return value.replaceAll('|', r'\|');
  }

  Future<void> _handlePreviewLinkTap(
      String text, String? href, String title) async {
    if (href == null) return;

    final rawTarget = WikiLinks.targetFromHref(href);
    if (rawTarget == null) return;

    final parsedTarget = WikiLinks.parseTarget(rawTarget);
    final notifier = ref.read(vaultSearchProvider.notifier);
    final searchState = ref.read(vaultSearchProvider);

    if (searchState.vaultEntries.isEmpty) {
      await notifier.loadVaultEntries();
    }

    final targetNote = notifier.findNoteByWikiLink(
      parsedTarget.path,
      currentPath: ref.read(notesProvider).currentPath,
    );

    if (targetNote == null) {
      if (!mounted) return;
      _showErrorSnackbar('Linked note not found: $rawTarget');
      return;
    }

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => targetNote.isAudio
            ? AudioPlayerScreen(
                note: targetNote,
                initialPosition: parsedTarget.startAt,
                autoplay: parsedTarget.startAt != null,
              )
            : targetNote.isPdf
                ? PdfViewerScreen(note: targetNote)
                : EditorScreen(note: targetNote),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesState = ref.watch(notesProvider);
    final isSaving = notesState.status == NotesStatus.saving;

    ref.listen(notesProvider, (previous, next) {
      if (next.status == NotesStatus.error && next.failure != null) {
        if (next.failure is ConflictFailure) {
          _showErrorSnackbar('Note was modified externally. Please reload.');
        }
      }
    });

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_hasChanges) return;
        _handleBlockedPop();
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Grid background
            Positioned.fill(
              child: CustomPaint(
                painter: GridPainter(
                  color: AppTheme.inkBlack.withValues(alpha: 0.035),
                  spacing: 32,
                ),
              ),
            ),
            // GitHub Footer
            const Positioned(
              bottom: 16,
              right: 16,
              child: GitHubFooter(),
            ),
            // Notebook page
            SafeArea(
              child: NotebookPage(
                maxWidth: 800,
                margin: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      // Custom App Bar
                      _buildAppBar(context, isSaving),
                      // Content
                      Expanded(
                        child: _isLoadingContent
                            ? _buildLoadingState()
                            : Column(
                                children: [
                                  if (_mode == EditorMode.edit)
                                    _buildMarkdownToolbar(isSaving),
                                  // Name Field
                                  if (widget.note == null &&
                                      _mode == EditorMode.edit)
                                    _buildNameField(context, isSaving),
                                  // Editor/Preview
                                  Expanded(
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      child: _mode == EditorMode.view
                                          ? _buildPreviewMode()
                                          : _buildEditMode(isSaving),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isSaving) {
    return Container(
      padding: const EdgeInsets.only(
        top: 8,
        left: 8,
        right: 8,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Back Button
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              if (await _onWillPop() && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          const SizedBox(width: 4),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.note != null
                      ? _stripExtension(widget.note!.name)
                      : 'New Note',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_hasChanges)
                  Text(
                    'Unsaved changes',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 11,
                        ),
                  ),
                if (widget.note == null &&
                    ref.watch(notesProvider).currentPath.isNotEmpty)
                  Text(
                    ref.watch(notesProvider).currentPath,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.tertiary,
                          fontSize: 11,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // History Button
          if (widget.note != null)
            IconButton(
              icon: const Icon(Icons.history_rounded),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => HistoryScreen(
                      notePath: widget.note!.path,
                      noteName: widget.note!.name,
                    ),
                  ),
                );
              },
              tooltip: 'View history',
            ),
          const SizedBox(width: 8),
          // Mode Toggle
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ModeButton(
                  icon: Icons.visibility_rounded,
                  label: 'View',
                  isSelected: _mode == EditorMode.view,
                  onTap: () => _toggleMode(EditorMode.view),
                ),
                ModeButton(
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                  isSelected: _mode == EditorMode.edit,
                  onTap: () => _toggleMode(EditorMode.edit),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Save Button
          IconButton(
            icon: isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  )
                : Icon(
                    _hasChanges ? Icons.save_outlined : Icons.check_rounded,
                    color: _mode == EditorMode.edit && _hasChanges
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context)
                            .colorScheme
                            .tertiary
                            .withValues(alpha: 0.5),
                  ),
            onPressed: _mode == EditorMode.edit && _hasChanges && !isSaving
                ? _saveNote
                : null,
            tooltip: _hasChanges ? 'Save changes' : 'Saved',
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading note...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.tertiary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField(BuildContext context, bool isSaving) {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(AppTheme.md, AppTheme.md, AppTheme.md, 0),
      child: TextField(
        controller: _nameController,
        enabled: !isSaving,
        style: GoogleFonts.playfairDisplay(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ).copyWith(fontFamilyFallback: _fontFallback),
        decoration: InputDecoration(
          hintText: 'Note title',
          hintStyle: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color:
                Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.5),
          ).copyWith(fontFamilyFallback: _fontFallback),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          filled: false,
        ),
      ),
    );
  }

  Widget _buildPreviewMode() {
    final previewData = _normalizeMarkdownForPreview(
        _contentController.text.isEmpty
            ? '_Start writing to see preview..._'
            : _contentController.text);

    return Markdown(
      key: const ValueKey('preview'),
      data: previewData,
      selectable: true,
      onTapLink: _handlePreviewLinkTap,
      styleSheet: MarkdownStyleSheet(
        // Headings with Playfair Display
        h1: GoogleFonts.playfairDisplay(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
          height: 1.3,
        ).copyWith(fontFamilyFallback: _fontFallback),
        h2: GoogleFonts.playfairDisplay(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
          height: 1.3,
        ).copyWith(fontFamilyFallback: _fontFallback),
        h3: GoogleFonts.playfairDisplay(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
          height: 1.3,
        ).copyWith(fontFamilyFallback: _fontFallback),
        h4: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ).copyWith(fontFamilyFallback: _fontFallback),
        h5: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ).copyWith(fontFamilyFallback: _fontFallback),
        h6: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.tertiary,
          letterSpacing: 0.5,
        ).copyWith(fontFamilyFallback: _fontFallback),
        // Body text
        p: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          color: Theme.of(context).colorScheme.onSurface,
          height: 1.7,
        ).copyWith(fontFamilyFallback: _fontFallback),
        // Links
        a: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
        ).copyWith(fontFamilyFallback: _fontFallback),
        // Code
        code: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          color: Theme.of(context).colorScheme.primary,
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        ).copyWith(fontFamilyFallback: _fontFallback),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFFF8F6F4),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        codeblockPadding: const EdgeInsets.all(AppTheme.md),
        // Blockquote
        blockquote: GoogleFonts.playfairDisplay(
          fontSize: 18,
          fontStyle: FontStyle.italic,
          color: Theme.of(context).colorScheme.tertiary,
          height: 1.6,
        ).copyWith(fontFamilyFallback: _fontFallback),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 3,
            ),
          ),
        ),
        blockquotePadding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
        // Lists
        listBullet: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          color: Theme.of(context).colorScheme.primary,
        ).copyWith(fontFamilyFallback: _fontFallback),
        listIndent: 24,
        // Horizontal rule
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
        ),
        // Table
        tableHead: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ).copyWith(fontFamilyFallback: _fontFallback),
        tableBody: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface,
        ).copyWith(fontFamilyFallback: _fontFallback),
        tableBorder: TableBorder.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
        tableHeadAlign: TextAlign.left,
        tableCellsPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        // Emphasis
        em: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontStyle: FontStyle.italic,
          color: Theme.of(context).colorScheme.onSurface,
        ).copyWith(fontFamilyFallback: _fontFallback),
        strong: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ).copyWith(fontFamilyFallback: _fontFallback),
        // Spacing
        h1Padding: const EdgeInsets.only(top: 24, bottom: 12),
        h2Padding: const EdgeInsets.only(top: 20, bottom: 10),
        h3Padding: const EdgeInsets.only(top: 16, bottom: 8),
        pPadding: const EdgeInsets.only(bottom: 12),
        blockSpacing: 16,
      ),
      padding: const EdgeInsets.all(AppTheme.md),
    );
  }

  Widget _buildEditMode(bool isSaving) {
    return Stack(
      key: const ValueKey('edit'),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.md),
          child: Focus(
            focusNode: _editorFocusNode,
            onKeyEvent: _handleEditorKeyEvent,
            child: TextField(
              controller: _contentController,
              enabled: !isSaving,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                height: 1.7,
                color: Theme.of(context).colorScheme.onSurface,
              ).copyWith(fontFamilyFallback: _fontFallback),
              decoration: InputDecoration(
                hintText:
                    'Start writing in Markdown...\n\n# Heading\n**bold** and *italic*\n- List item\n[[link a note]]\n[[audio.mp3#12:34|meeting moment]]',
                hintStyle: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  height: 1.7,
                  color: Theme.of(context)
                      .colorScheme
                      .tertiary
                      .withValues(alpha: 0.4),
                ).copyWith(fontFamilyFallback: _fontFallback),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: AppTheme.md),
                filled: false,
              ),
              cursorColor: Theme.of(context).colorScheme.primary,
              cursorWidth: 2,
            ),
          ),
        ),
        if (_activeWikiQuery != null && _wikiSuggestions.isNotEmpty)
          Positioned(
            left: AppTheme.md,
            right: AppTheme.md,
            bottom: AppTheme.md,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 240),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.25),
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _wikiSuggestions.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.15),
                  ),
                  itemBuilder: (context, index) {
                    final suggestion = _wikiSuggestions[index];
                    final displayTarget = suggestion.path.endsWith('.md')
                        ? suggestion.path
                            .substring(0, suggestion.path.length - 3)
                        : suggestion.path;

                    return ListTile(
                      dense: true,
                      selected: index == _selectedWikiSuggestionIndex,
                      leading: Icon(
                        Icons.link_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        _stripExtension(suggestion.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        displayTarget,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _applyWikiSuggestion(suggestion),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMarkdownToolbar(bool isSaving) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin:
          const EdgeInsets.fromLTRB(AppTheme.md, AppTheme.sm, AppTheme.md, 0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.16)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            MarkdownToolbarButton(
              label: 'H1',
              icon: Icons.title_rounded,
              enabled: !isSaving,
              onTap: () => _prefixSelectedLines('# ', placeholder: 'Heading'),
            ),
            MarkdownToolbarButton(
              label: 'H2',
              icon: Icons.format_size_rounded,
              enabled: !isSaving,
              onTap: () => _prefixSelectedLines('## ', placeholder: 'Section'),
            ),
            MarkdownToolbarButton(
              label: 'Bold',
              icon: Icons.format_bold_rounded,
              enabled: !isSaving,
              onTap: () => _wrapSelection(
                prefix: '**',
                suffix: '**',
                placeholder: 'bold text',
              ),
            ),
            MarkdownToolbarButton(
              label: 'Italic',
              icon: Icons.format_italic_rounded,
              enabled: !isSaving,
              onTap: () => _wrapSelection(
                prefix: '*',
                suffix: '*',
                placeholder: 'italic text',
              ),
            ),
            MarkdownToolbarButton(
              label: 'List',
              icon: Icons.format_list_bulleted_rounded,
              enabled: !isSaving,
              onTap: () => _prefixSelectedLines('- ', placeholder: 'List item'),
            ),
            MarkdownToolbarButton(
              label: 'Task',
              icon: Icons.check_box_outlined,
              enabled: !isSaving,
              onTap: () => _prefixSelectedLines('- [ ] ', placeholder: 'Task'),
            ),
            MarkdownToolbarButton(
              label: 'Quote',
              icon: Icons.format_quote_rounded,
              enabled: !isSaving,
              onTap: () => _prefixSelectedLines('> ', placeholder: 'Quote'),
            ),
            MarkdownToolbarButton(
              label: 'Code',
              icon: Icons.code_rounded,
              enabled: !isSaving,
              onTap: _insertCodeBlock,
            ),
            MarkdownToolbarButton(
              label: 'Link',
              icon: Icons.link_rounded,
              enabled: !isSaving,
              onTap: _insertMarkdownLink,
            ),
            MarkdownToolbarButton(
              label: 'Wiki',
              icon: Icons.auto_awesome_rounded,
              enabled: !isSaving,
              onTap: _insertWikiLink,
            ),
          ],
        ),
      ),
    );
  }
}
