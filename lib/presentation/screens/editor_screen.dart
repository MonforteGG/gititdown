import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/note.dart';
import '../../presentation/providers/notes_provider.dart';
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
  late TextEditingController _contentController;
  late TextEditingController _nameController;
  late EditorMode _mode;
  bool _hasChanges = false;
  bool _isLoadingContent = false;
  Note? _loadedNote;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.note?.content ?? '');
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
    _contentController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    setState(() {
      _hasChanges = true;
    });
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
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.error_outline, color: Colors.white, size: 18),
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
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
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
      builder: (context) => _UnsavedChangesDialog(),
    );

    if (result == 'save') {
      await _saveNote();
      return true;
    } else if (result == 'discard') {
      return true;
    }
    return false;
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
    final path = currentNote?.path ?? fullName;

    final note = Note(
      name: fullName,
      path: path,
      sha: currentNote?.sha ?? '',
      content: content,
      lastModified: DateTime.now(),
    );

    final success = await ref.read(notesProvider.notifier).saveNote(note);

    if (success) {
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
        _showErrorSnackbar(notesState.failure?.message ?? 'Failed to save note');
      }
    }
  }

  void _toggleMode(EditorMode mode) {
    setState(() {
      _mode = mode;
    });
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

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Stack(
          children: [
            // Grid background
            Positioned.fill(
              child: CustomPaint(
                painter: GridPainter(
                  color: AppTheme.inkBlack.withOpacity(0.035),
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
                                   // Name Field
                                   if (widget.note == null && _mode == EditorMode.edit)
                                    _buildNameField(context, isSaving),
                                  // Editor/Preview
                                  Expanded(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
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
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Back Button
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              if (await _onWillPop()) {
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
              ],
            ),
          ),
          // Mode Toggle
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ModeButton(
                  icon: Icons.visibility_rounded,
                  label: 'View',
                  isSelected: _mode == EditorMode.view,
                  onTap: () => _toggleMode(EditorMode.view),
                ),
                _ModeButton(
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
          if (_mode == EditorMode.edit)
            _SaveButton(
              isSaving: isSaving,
              hasChanges: _hasChanges,
              onSave: _saveNote,
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
      padding: const EdgeInsets.fromLTRB(AppTheme.md, AppTheme.md, AppTheme.md, 0),
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
            color: Theme.of(context).colorScheme.tertiary.withOpacity(0.5),
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
    return Markdown(
      key: const ValueKey('preview'),
      data: _contentController.text.isEmpty
          ? '_Start writing to see preview..._'
          : _contentController.text,
      selectable: true,
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
          decorationColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
        ).copyWith(fontFamilyFallback: _fontFallback),
        // Code
        code: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        ).copyWith(fontFamilyFallback: _fontFallback),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFFF8F6F4),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
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
              color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
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
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
        tableHeadAlign: TextAlign.left,
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    return Container(
      key: const ValueKey('edit'),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.md),
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
          hintText: 'Start writing in Markdown...\n\n# Heading\n**bold** and *italic*\n- List item',
          hintStyle: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            height: 1.7,
            color: Theme.of(context).colorScheme.tertiary.withOpacity(0.4),
          ).copyWith(fontFamilyFallback: _fontFallback),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: AppTheme.md),
          filled: false,
        ),
        cursorColor: Theme.of(context).colorScheme.primary,
        cursorWidth: 2,
      ),
    );
  }
}

// Mode Toggle Button
class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm - 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.tertiary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.tertiary,
              ).copyWith(fontFamilyFallback: _fontFallback),
            ),
          ],
        ),
      ),
    );
  }
}

// Save Button with animation
class _SaveButton extends StatelessWidget {
  final bool isSaving;
  final bool hasChanges;
  final VoidCallback onSave;

  const _SaveButton({
    required this.isSaving,
    required this.hasChanges,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: FilledButton.icon(
        onPressed: isSaving ? null : onSave,
        icon: isSaving
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : Icon(
                hasChanges ? Icons.save_rounded : Icons.check_rounded,
                size: 18,
              ),
        label: Text(isSaving ? 'Saving' : 'Save'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          backgroundColor: hasChanges
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.primary.withOpacity(0.7),
        ),
      ),
    );
  }
}

// Unsaved Changes Dialog
class _UnsavedChangesDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.edit_note_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 12),
          const Text('Unsaved Changes'),
        ],
      ),
      content: const Text(
        'You have unsaved changes. What would you like to do?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop('discard'),
          child: Text(
            'Discard',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Keep Editing'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop('save'),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
