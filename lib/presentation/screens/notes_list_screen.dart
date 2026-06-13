import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../domain/entities/note.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/notes_provider.dart';
import 'audio_player_screen.dart';
import '../widgets/github_footer.dart';
import '../widgets/notebook_background.dart';
import 'editor_screen.dart';

// Font fallback for characters not covered by primary fonts
const List<String> _fontFallback = ['Noto Sans'];

class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen>
    with TickerProviderStateMixin {
  late AnimationController _fabController;
  final TextEditingController _searchController = TextEditingController();
  bool _showTreeView = false;
  final Set<String> _expandedTreePaths = <String>{};

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
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
    _searchController.dispose();
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

  Future<void> _refreshNotes() async {
    final notifier = ref.read(notesProvider.notifier);
    final notesState = ref.read(notesProvider);

    await notifier.loadNotes();

    if (_showTreeView ||
        notesState.searchStatus != SearchStatus.initial ||
        notesState.searchQuery.trim().isNotEmpty) {
      await notifier.loadVaultEntries(force: true);
    }
  }

  Future<void> _toggleTreeView(bool enabled) async {
    if (enabled) {
      final notifier = ref.read(notesProvider.notifier);
      final state = ref.read(notesProvider);
      if (state.vaultEntries.isEmpty) {
        await notifier.loadVaultEntries();
      }
    }

    if (!mounted) return;
    setState(() {
      _showTreeView = enabled;
    });
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

  Future<void> _createFolder() async {
    final folderName = await showDialog<String>(
      context: context,
      builder: (context) => const _CreateFolderDialog(),
    );

    if (folderName == null || folderName.trim().isEmpty) {
      return;
    }

    if (folderName.contains('/') || folderName.contains('\\')) {
      _showErrorSnackbar('Folder name cannot contain slashes');
      return;
    }

    final success =
        await ref.read(notesProvider.notifier).createFolder(folderName.trim());

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Folder created'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final error =
          ref.read(notesProvider).failure?.message ?? 'Failed to create folder';
      _showErrorSnackbar(error);
    }
  }

  void _openNote(Note note) {
    if (note.isDirectory) {
      if (ref.read(notesProvider).searchQuery.trim().isNotEmpty) {
        _searchController.clear();
        ref.read(notesProvider.notifier).clearSearch();
      }
      ref.read(notesProvider.notifier).openDirectory(note);
      return;
    }

    if (note.isAudio) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AudioPlayerScreen(note: note),
        ),
      );
      return;
    }

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
    if (note.isDirectory) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _DeleteFolderDialog(folderName: note.name),
      );

      if (confirmed == true) {
        final success =
            await ref.read(notesProvider.notifier).deleteFolder(note.path);

        if (!success && mounted) {
          final error = ref.read(notesProvider).failure?.message ??
              'Failed to delete folder';
          _showErrorSnackbar(error);
        }
      }
      return;
    }

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

  String _fileBadgeLabel(Note note) {
    if (note.isAudio) return 'mp3';
    if (note.isMarkdown) return 'md';
    return 'file';
  }

  @override
  Widget build(BuildContext context) {
    final notesState = ref.watch(notesProvider);
    final isSearching = notesState.searchQuery.trim().isNotEmpty;
    final notes = isSearching ? notesState.searchResults : notesState.notes;
    final currentPath = notesState.currentPath;
    final searchMetadata = notesState.searchMatchMetadata;
    final isTreeMode = !isSearching && currentPath.isEmpty && _showTreeView;

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
          // GitHub Footer
          const Positioned(
            bottom: 16,
            right: 16,
            child: GitHubFooter(),
          ),
          // Notebook page with content
          SafeArea(
            child: NotebookPage(
              maxWidth: 720,
              margin: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Stack(
                children: [
                  CustomScrollView(
                    slivers: [
                      _buildAppBar(context),
                      SliverToBoxAdapter(
                        child: _buildSearchBar(notesState),
                      ),
                      SliverToBoxAdapter(
                        child: _PathBar(
                          currentPath: currentPath,
                          onGoRoot: currentPath.isEmpty
                              ? null
                              : () => ref.read(notesProvider.notifier).navigateToRoot(),
                          onGoUp: currentPath.isEmpty
                              ? null
                              : () => ref.read(notesProvider.notifier).navigateUp(),
                          showTreeToggle: currentPath.isEmpty && !isSearching,
                          isTreeViewEnabled: isTreeMode,
                          onTreeViewChanged: _toggleTreeView,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: isLoading && (isTreeMode ? notesState.vaultEntries.isEmpty : notes.isEmpty)
                            ? _buildLoadingState()
                            : !isTreeMode && notes.isEmpty
                                ? _buildEmptyState(context, currentPath, isSearching)
                                : null,
                      ),
                      if (isTreeMode)
                        SliverToBoxAdapter(
                          child: _buildTreeView(notesState),
                        )
                      else if (!isLoading || notes.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            AppTheme.md,
                            AppTheme.sm,
                            AppTheme.md,
                            AppTheme.xxl,
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
                                  fileBadgeLabel: _fileBadgeLabel(note),
                                  searchMetadata:
                                      isSearching ? searchMetadata[note.path] : null,
                                );
                              },
                              childCount: notes.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
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
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(width: 10),
            Text(
              'Notes',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ).copyWith(fontFamilyFallback: _fontFallback),
            ),
          ],
        ),
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.fadeTitle,
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.create_new_folder_rounded),
          tooltip: 'New Folder',
          onPressed: _createFolder,
        ),
        IconButton(
          icon: Icon(Icons.add_rounded, color: AppTheme.brandOrange),
          tooltip: 'New Note',
          onPressed: _createNewNote,
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
          onPressed: _refreshNotes,
        ),
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

  Widget _buildSearchBar(NotesState notesState) {
    final isSearching = notesState.searchQuery.trim().isNotEmpty;
    final isSearchLoading = notesState.searchStatus == SearchStatus.loading;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.md, AppTheme.sm, AppTheme.md, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (value) async {
          final notifier = ref.read(notesProvider.notifier);
          notifier.updateSearchQuery(value);

          if (value.trim().isNotEmpty && notesState.vaultEntries.isEmpty) {
            await notifier.loadVaultEntries();
          }

          if (value.trim().isNotEmpty) {
            await notifier.loadSearchContentIndex();
          }
        },
        decoration: InputDecoration(
          hintText: 'Search across the vault',
          prefixIcon: isSearchLoading
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                )
              : const Icon(Icons.search_rounded),
          suffixIcon: isSearching
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(notesProvider.notifier).clearSearch();
                  },
                )
              : null,
        ),
      ),
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

  Widget _buildEmptyState(
    BuildContext context,
    String currentPath,
    bool isSearching,
  ) {
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
              isSearching
                  ? 'No matches found'
                  : currentPath.isEmpty
                      ? 'No notes yet'
                      : 'This folder is empty',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Try another note name or path'
                  : currentPath.isEmpty
                      ? 'Start writing your first note'
                      : 'Create a markdown note inside this folder',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
            ),
            const SizedBox(height: 24),
            if (!isSearching)
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

  Widget _buildTreeView(NotesState notesState) {
    final entries = notesState.vaultEntries;
    if (entries.isEmpty) {
      return _buildEmptyState(context, '', false);
    }

    final tree = _buildTreeEntries(entries);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.md, AppTheme.sm, AppTheme.md, AppTheme.xxl),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.28),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.22),
          ),
        ),
        child: Column(
          children: [
            for (final entry in tree)
              _TreeNodeTile(
                entry: entry,
                depth: 0,
                expandedPaths: _expandedTreePaths,
                formatFileName: _formatFileName,
                fileBadgeLabel: _fileBadgeLabel,
                onToggleExpansion: (path) {
                  setState(() {
                    if (!_expandedTreePaths.add(path)) {
                      _expandedTreePaths.remove(path);
                    }
                  });
                },
                onOpen: _openNote,
              ),
          ],
        ),
      ),
    );
  }

  List<_TreeEntry> _buildTreeEntries(List<Note> entries) {
    final childrenByParent = <String, List<Note>>{};
    for (final entry in entries) {
      childrenByParent.putIfAbsent(entry.parentPath, () => <Note>[]).add(entry);
    }

    List<_TreeEntry> buildLevel(String parentPath) {
      final siblings = [...(childrenByParent[parentPath] ?? const <Note>[])];
      siblings.sort((a, b) {
        if (a.isDirectory != b.isDirectory) {
          return a.isDirectory ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return siblings
          .map(
            (entry) => _TreeEntry(
              note: entry,
              children: entry.isDirectory ? buildLevel(entry.path) : const <_TreeEntry>[],
            ),
          )
          .toList();
    }

    return buildLevel('');
  }
}

// Animated Note Card
class _NoteCard extends StatefulWidget {
  final Note note;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final String Function(String) formatFileName;
  final String fileBadgeLabel;
  final SearchMatchMetadata? searchMetadata;

  const _NoteCard({
    required this.note,
    required this.index,
    required this.onTap,
    required this.onDelete,
    required this.formatFileName,
    required this.fileBadgeLabel,
    required this.searchMetadata,
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
    final isDirectory = widget.note.isDirectory;

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
                                isDirectory
                                    ? Icons.folder_open_rounded
                                    : widget.note.isAudio
                                        ? Icons.graphic_eq_rounded
                                        : Icons.description_outlined,
                                size: 22,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              if (!isDirectory)
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
                                      widget.fileBadgeLabel,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 7,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).colorScheme.onPrimary,
                                      ).copyWith(fontFamilyFallback: _fontFallback),
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
                                isDirectory
                                    ? widget.note.name
                                    : widget.formatFileName(widget.note.name),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isDirectory) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.note.path,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ] else if (widget.searchMetadata != null &&
                                  (widget.searchMetadata!.contentMatchCount > 0 ||
                                      widget.searchMetadata!.matchedByNameOrPath)) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.note.path,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (widget.searchMetadata!.contentMatchCount > 0) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.searchMetadata!.snippet ?? '',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.tertiary,
                                          fontStyle: FontStyle.italic,
                                        ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.searchMetadata!.contentMatchCount == 1
                                        ? '1 content match'
                                        : '${widget.searchMetadata!.contentMatchCount} content matches',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Matched by name or path',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ] else if (widget.note.lastModified != null) ...[
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
                        if (widget.onDelete != null)
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

class _PathBar extends StatelessWidget {
  final String currentPath;
  final VoidCallback? onGoRoot;
  final VoidCallback? onGoUp;
  final bool showTreeToggle;
  final bool isTreeViewEnabled;
  final ValueChanged<bool>? onTreeViewChanged;

  const _PathBar({
    required this.currentPath,
    required this.onGoRoot,
    required this.onGoUp,
    this.showTreeToggle = false,
    this.isTreeViewEnabled = false,
    this.onTreeViewChanged,
  });

  @override
  Widget build(BuildContext context) {
    final label = currentPath.isEmpty ? 'Vault root' : currentPath;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.md, AppTheme.sm, AppTheme.md, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.45),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.device_hub_rounded,
              size: 18,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showTreeToggle) ...[
              const SizedBox(width: 8),
              _TreeToggleChip(
                isEnabled: isTreeViewEnabled,
                onChanged: onTreeViewChanged,
              ),
            ],
            if (onGoRoot != null)
              TextButton.icon(
                onPressed: onGoRoot,
                icon: const Icon(Icons.home_rounded, size: 16),
                label: const Text('Root'),
              ),
            if (onGoUp != null)
              TextButton.icon(
                onPressed: onGoUp,
                icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                label: const Text('Up'),
              ),
          ],
        ),
      ),
    );
  }
}

class _TreeToggleChip extends StatefulWidget {
  final bool isEnabled;
  final ValueChanged<bool>? onChanged;

  const _TreeToggleChip({
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  State<_TreeToggleChip> createState() => _TreeToggleChipState();
}

class _TreeToggleChipState extends State<_TreeToggleChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = widget.isEnabled;
    final canInteract = widget.onChanged != null;
    final backgroundColor = colorScheme.surface;
    final borderColor = colorScheme.outline.withOpacity(_isHovered ? 0.34 : 0.18);
    final foregroundColor = colorScheme.onSurface;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canInteract ? () => widget.onChanged!.call(!enabled) : null,
            borderRadius: BorderRadius.circular(999),
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.account_tree_rounded,
                      size: 16,
                      color: foregroundColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: foregroundColor,
                        ),
                    child: const Text('Tree'),
                  ),
                  const SizedBox(width: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: 34,
                    height: 20,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: enabled
                          ? colorScheme.primary.withOpacity(0.16)
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      alignment:
                          enabled ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: enabled ? colorScheme.primary : colorScheme.onSurface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TreeEntry {
  final Note note;
  final List<_TreeEntry> children;

  const _TreeEntry({
    required this.note,
    required this.children,
  });
}

class _TreeNodeTile extends StatelessWidget {
  final _TreeEntry entry;
  final int depth;
  final Set<String> expandedPaths;
  final ValueChanged<String> onToggleExpansion;
  final ValueChanged<Note> onOpen;
  final String Function(String) formatFileName;
  final String Function(Note) fileBadgeLabel;

  const _TreeNodeTile({
    required this.entry,
    required this.depth,
    required this.expandedPaths,
    required this.onToggleExpansion,
    required this.onOpen,
    required this.formatFileName,
    required this.fileBadgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDirectory = entry.note.isDirectory;
    final isExpanded = expandedPaths.contains(entry.note.path);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 18.0, bottom: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              onTap: () => onOpen(entry.note),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: isDirectory
                          ? IconButton(
                              onPressed: () => onToggleExpansion(entry.note.path),
                              icon: AnimatedRotation(
                                turns: isExpanded ? 0.25 : 0,
                                duration: const Duration(milliseconds: 180),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: colorScheme.tertiary,
                                ),
                              ),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              splashRadius: 16,
                            )
                          : Icon(
                              Icons.subdirectory_arrow_right_rounded,
                              size: 16,
                              color: colorScheme.outline,
                            ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(isDirectory ? 0.12 : 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDirectory
                            ? Icons.folder_open_rounded
                            : entry.note.isAudio
                                ? Icons.graphic_eq_rounded
                                : Icons.description_outlined,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isDirectory ? entry.note.name : formatFileName(entry.note.name),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: isDirectory ? FontWeight.w700 : FontWeight.w500,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isDirectory)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.18),
                          ),
                        ),
                        child: Text(
                          fileBadgeLabel(entry.note),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ).copyWith(fontFamilyFallback: _fontFallback),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isDirectory && isExpanded)
          for (final child in entry.children)
            _TreeNodeTile(
              entry: child,
              depth: depth + 1,
              expandedPaths: expandedPaths,
              formatFileName: formatFileName,
              fileBadgeLabel: fileBadgeLabel,
              onToggleExpansion: onToggleExpansion,
              onOpen: onOpen,
            ),
      ],
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

class _CreateFolderDialog extends StatefulWidget {
  const _CreateFolderDialog();

  @override
  State<_CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<_CreateFolderDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.create_new_folder_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          const Text('New Folder'),
        ],
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Folder name',
          hintText: 'Projects',
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _DeleteFolderDialog extends StatelessWidget {
  final String folderName;

  const _DeleteFolderDialog({required this.folderName});

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
              Icons.folder_delete_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(width: 12),
          const Text('Delete Folder'),
        ],
      ),
      content: RichText(
        text: TextSpan(
          style: Theme.of(context).dialogTheme.contentTextStyle,
          children: [
            const TextSpan(text: 'Delete '),
            TextSpan(
              text: '"$folderName"',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const TextSpan(
              text:
                  '? Only empty folders can be deleted. This action cannot be undone.',
            ),
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
