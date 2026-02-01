import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../domain/entities/note.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/notes_provider.dart';
import '../widgets/notebook_background.dart';
import 'editor_screen.dart';

class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen>
    with TickerProviderStateMixin {
  late AnimationController _fabController;
  late Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fabScale = CurvedAnimation(
      parent: _fabController,
      curve: Curves.elasticOut,
    );

    Future.microtask(() {
      ref.read(notesProvider.notifier).loadNotes();
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      _fabController.forward();
    });
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
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

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _LogoutDialog(),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  void _createNewNote() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const EditorScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _openNote(Note note) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            EditorScreen(note: note),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.02, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteNoteDialog(noteName: _formatFileName(note.name)),
    );

    if (confirmed == true) {
      final success = await ref
          .read(notesProvider.notifier)
          .deleteNote(note.path, note.sha);

      if (!success && mounted) {
        final error = ref.read(notesProvider).failure?.message ?? 'Failed to delete note';
        _showErrorSnackbar(error);
      }
    }
  }

  String _formatFileName(String name) {
    if (name.endsWith('.md')) {
      return name.substring(0, name.length - 3);
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final notesState = ref.watch(notesProvider);
    final notes = notesState.notes;

    ref.listen(notesProvider, (previous, next) {
      if (next.status == NotesStatus.error && next.failure != null) {
        _showErrorSnackbar(next.failure!.message);
      }
    });

    final isLoading = notesState.status == NotesStatus.loading ||
        notesState.status == NotesStatus.deleting;

    return Scaffold(
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
          // Notebook page with content
          SafeArea(
            child: NotebookPage(
              maxWidth: 720,
              margin: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: CustomScrollView(
                slivers: [
                  // Custom App Bar
                  _buildAppBar(context),
                  // Content
                  SliverToBoxAdapter(
                    child: isLoading && notes.isEmpty
                        ? _buildLoadingState()
                        : notes.isEmpty
                            ? _buildEmptyState(context)
                            : null,
                  ),
                  if (!isLoading || notes.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.md,
                        AppTheme.sm,
                        AppTheme.md,
                        100, // Space for FAB
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final note = notes[index];
                            return _NoteCard(
                              note: note,
                              index: index,
                              onTap: () => _openNote(note),
                              onDelete: () => _deleteNote(note),
                              formatFileName: _formatFileName,
                            );
                          },
                          childCount: notes.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScale,
        child: FloatingActionButton.extended(
          onPressed: _createNewNote,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Note'),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: AppTheme.md, bottom: 16),
        title: Row(
          children: [
            // Logo
            Image.asset(
              'lib/assets/logo.png',
              width: 40,
              height: 40,
            ),
            const SizedBox(width: 10),
            Text(
              'Notes',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.fadeTitle,
        ],
      ),
      actions: [
        // Refresh button
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
          onPressed: () => ref.read(notesProvider.notifier).loadNotes(),
        ),
        // Logout with custom styling
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Disconnect',
            onPressed: _handleLogout,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading notes...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Decorative empty state illustration
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 40,
                    color: Theme.of(context).colorScheme.tertiary.withOpacity(0.5),
                  ),
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No notes yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Start writing your first note',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _createNewNote,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create Note'),
            ),
          ],
        ),
      ),
    );
  }
}

// Animated Note Card
class _NoteCard extends StatefulWidget {
  final Note note;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String Function(String) formatFileName;

  const _NoteCard({
    required this.note,
    required this.index,
    required this.onTap,
    required this.onDelete,
    required this.formatFileName,
  });

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Staggered animation based on index
    Future.delayed(Duration(milliseconds: 50 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.sm),
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: _isHovered
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                      : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: _isHovered ? AppTheme.subtleShadow : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.md),
                    child: Row(
                      children: [
                        // Document Icon with accent
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 22,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              // Markdown indicator
                              Positioned(
                                bottom: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Text(
                                    'md',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 7,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Note Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.formatFileName(widget.note.name),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.note.lastModified != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 12,
                                      color: Theme.of(context).colorScheme.tertiary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDate(widget.note.lastModified!),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Delete Button
                        AnimatedOpacity(
                          opacity: _isHovered ? 1.0 : 0.6,
                          duration: const Duration(milliseconds: 200),
                          child: IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                            tooltip: 'Delete',
                            onPressed: widget.onDelete,
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .error
                                  .withOpacity(0.0),
                            ),
                          ),
                        ),
                        // Chevron
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          transform: Matrix4.translationValues(
                            _isHovered ? 4 : 0,
                            0,
                            0,
                          ),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: _isHovered
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Logout Dialog
class _LogoutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.logout_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(width: 12),
          const Text('Disconnect'),
        ],
      ),
      content: const Text(
        'Are you sure you want to disconnect from GitHub? Your notes will remain in your repository.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Disconnect'),
        ),
      ],
    );
  }
}

// Delete Note Dialog
class _DeleteNoteDialog extends StatelessWidget {
  final String noteName;

  const _DeleteNoteDialog({required this.noteName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(width: 12),
          const Text('Delete Note'),
        ],
      ),
      content: RichText(
        text: TextSpan(
          style: Theme.of(context).dialogTheme.contentTextStyle,
          children: [
            const TextSpan(text: 'Are you sure you want to delete '),
            TextSpan(
              text: '"$noteName"',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const TextSpan(text: '? This action cannot be undone.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
