import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../domain/entities/note.dart';
import '../../presentation/providers/notes_provider.dart';

enum EditorMode { view, edit }

class EditorScreen extends ConsumerStatefulWidget {
  final Note? note;

  const EditorScreen({super.key, this.note});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late TextEditingController _contentController;
  late TextEditingController _nameController;
  late EditorMode _mode;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _nameController = TextEditingController(
      text: widget.note != null ? _stripExtension(widget.note!.name) : '',
    );
    _mode = widget.note == null ? EditorMode.edit : EditorMode.view;

    _contentController.addListener(_onContentChanged);
    _nameController.addListener(_onContentChanged);
  }

  @override
  void dispose() {
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
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Do you want to save them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop(false);
              await _saveNote();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _saveNote() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showErrorSnackbar('Please enter a note name');
      return;
    }

    final content = _contentController.text;
    final fullName = _addExtension(name);
    final path = widget.note?.path ?? fullName;

    final note = Note(
      name: fullName,
      path: path,
      sha: widget.note?.sha ?? '',
      content: content,
      lastModified: DateTime.now(),
    );

    final success = await ref.read(notesProvider.notifier).saveNote(note);

    if (success) {
      _showSuccessSnackbar('Note saved successfully');
      setState(() {
        _hasChanges = false;
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
          _showErrorSnackbar('This note was modified externally. Please reload and try again.');
        }
      }
    });

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _onWillPop()) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: widget.note != null
              ? Text(_stripExtension(widget.note!.name))
              : const Text('New Note'),
          actions: [
            // Mode Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SegmentedButton<EditorMode>(
                segments: const [
                  ButtonSegment(
                    value: EditorMode.view,
                    label: Text('View'),
                    icon: Icon(Icons.visibility),
                  ),
                  ButtonSegment(
                    value: EditorMode.edit,
                    label: Text('Edit'),
                    icon: Icon(Icons.edit),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  _toggleMode(selection.first);
                },
              ),
            ),
            // Save Button
            if (_mode == EditorMode.edit)
              IconButton(
                icon: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                tooltip: 'Save',
                onPressed: isSaving ? null : _saveNote,
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // Name Field (only for new notes or in edit mode)
            if (widget.note == null || _mode == EditorMode.edit)
              Padding(
                padding: const EdgeInsets.all(AppTheme.mediumPadding),
                child: TextField(
                  controller: _nameController,
                  enabled: !isSaving,
                  decoration: InputDecoration(
                    labelText: 'Note Name',
                    hintText: 'Enter note name',
                    suffixText: '.md',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),

            // Content Area
            Expanded(
              child: _mode == EditorMode.view
                  ? _buildPreviewMode()
                  : _buildEditMode(isSaving),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewMode() {
    return Markdown(
      data: _contentController.text,
      styleSheet: MarkdownStyleSheet(
        h1: Theme.of(context).textTheme.displayMedium,
        h2: Theme.of(context).textTheme.titleLarge,
        h3: Theme.of(context).textTheme.titleMedium,
        p: Theme.of(context).textTheme.bodyLarge,
        code: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          backgroundColor: Theme.of(context).colorScheme.surface,
        ),
        codeblockDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        blockquote: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontStyle: FontStyle.italic,
            ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.secondary,
              width: 4,
            ),
          ),
        ),
        listBullet: Theme.of(context).textTheme.bodyLarge,
      ),
      padding: const EdgeInsets.all(AppTheme.mediumPadding),
    );
  }

  Widget _buildEditMode(bool isSaving) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.mediumPadding),
      child: TextField(
        controller: _contentController,
        enabled: !isSaving,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: InputDecoration(
          hintText: 'Start writing in Markdown...',
          border: InputBorder.none,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          contentPadding: const EdgeInsets.all(AppTheme.mediumPadding),
        ),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }
}
