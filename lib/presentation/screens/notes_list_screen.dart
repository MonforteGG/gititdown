import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../domain/entities/note.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/library_preferences_provider.dart';
import '../../presentation/providers/notes_provider.dart';
import '../../presentation/providers/search_provider.dart';
import 'audio_player_screen.dart';
import '../widgets/github_footer.dart';
import '../widgets/notebook_background.dart';
import '../widgets/notes_list_components.dart';
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
  Timer? _searchDebounce;
  bool _showTreeView = false;
  bool _showFavoritesSection = false;
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
      ref.read(vaultSearchProvider.notifier).loadVaultEntries();
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      _fabController.forward();
    });
  }

  @override
  void dispose() {
    _fabController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
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
                color: Colors.white.withValues(alpha: 0.2),
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
      builder: (context) => const LogoutDialog(),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  Future<void> _refreshNotes() async {
    final notifier = ref.read(notesProvider.notifier);
    final searchState = ref.read(vaultSearchProvider);

    await notifier.loadNotes();

    if (_showTreeView ||
        searchState.status != SearchStatus.initial ||
        searchState.query.trim().isNotEmpty) {
      await ref.read(vaultSearchProvider.notifier).loadVaultEntries(force: true);
    }
  }

  Future<void> _toggleTreeView(bool enabled) async {
    if (enabled) {
      final searchNotifier = ref.read(vaultSearchProvider.notifier);
      final searchState = ref.read(vaultSearchProvider);
      if (searchState.vaultEntries.isEmpty) {
        await searchNotifier.loadVaultEntries();
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
      builder: (context) => const CreateFolderDialog(),
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
      if (ref.read(vaultSearchProvider).query.trim().isNotEmpty) {
        _searchController.clear();
        ref.read(vaultSearchProvider.notifier).clearSearch();
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
        builder: (context) => DeleteFolderDialog(folderName: note.name),
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
      builder: (context) => DeleteNoteDialog(noteName: _formatFileName(note.name)),
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

  Future<void> _renameEntry(Note note) async {
    final initialValue = note.isDirectory ? note.name : _formatFileName(note.name);
    final renamedValue = await showDialog<String>(
      context: context,
      builder: (context) => RenameEntryDialog(
        title: note.isDirectory ? 'Rename Folder' : 'Rename Entry',
        initialValue: initialValue,
        isDirectory: note.isDirectory,
      ),
    );

    if (renamedValue == null || renamedValue.trim().isEmpty) {
      return;
    }

    if (renamedValue.contains('/') || renamedValue.contains('\\')) {
      _showErrorSnackbar('Name cannot contain slashes');
      return;
    }

    final normalizedValue = renamedValue.trim();
    final targetName = note.isDirectory || note.isAudio
        ? normalizedValue
        : '$normalizedValue.md';

    final success = await ref.read(notesProvider.notifier).renameEntry(note, targetName);
    if (!success && mounted) {
      final error = ref.read(notesProvider).failure?.message ?? 'Failed to rename entry';
      _showErrorSnackbar(error);
    }
  }

  Future<void> _toggleFavorite(Note note) async {
    final isNowFavorite =
        await ref.read(libraryPreferencesProvider.notifier).toggleFavorite(note.path);
    if (!mounted) return;
    setState(() {
      if (isNowFavorite) {
        _showFavoritesSection = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isNowFavorite ? 'Added to favorites' : 'Removed from favorites',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1200),
      ),
    );
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
    final searchState = ref.watch(vaultSearchProvider);
    final libraryPrefs = ref.watch(libraryPreferencesProvider);
    final isSearching = searchState.query.trim().isNotEmpty;
    final notes = isSearching ? searchState.searchResults : notesState.notes;
    final currentPath = notesState.currentPath;
    final searchMetadata = searchState.searchMatchMetadata;
    final isTreeMode = !isSearching && currentPath.isEmpty && _showTreeView;
    final noteByPath = {for (final entry in searchState.vaultEntries) entry.path: entry};
    final favoriteEntries = libraryPrefs.favorites
        .map((path) => noteByPath[path])
        .whereType<Note>()
        .toList();

    ref.listen(notesProvider, (previous, next) {
      if (next.status == NotesStatus.error && next.failure != null) {
        _showErrorSnackbar(next.failure!.message);
      }
    });
    ref.listen(vaultSearchProvider, (previous, next) {
      if (next.status == SearchStatus.error && next.failure != null) {
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
                        child: _buildSearchBar(searchState),
                      ),
                      SliverToBoxAdapter(
                        child: PathBar(
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
                      if (!isSearching &&
                          currentPath.isEmpty &&
                          libraryPrefs.isLoaded)
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              QuickAccessSection(
                                title: 'Favorites',
                                icon: Icons.star_rounded,
                                entries: favoriteEntries,
                                isCollapsed: !_showFavoritesSection,
                                onToggleCollapsed: () {
                                  setState(() {
                                    _showFavoritesSection = !_showFavoritesSection;
                                  });
                                },
                                onOpen: _openNote,
                                onRename: _renameEntry,
                                onDelete: _deleteNote,
                                onToggleFavorite: _toggleFavorite,
                                isFavorite: ref.read(libraryPreferencesProvider.notifier).isFavorite,
                                formatFileName: _formatFileName,
                              ),
                            ],
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: isLoading &&
                                (isTreeMode ? searchState.vaultEntries.isEmpty : notes.isEmpty)
                            ? _buildLoadingState()
                            : !isTreeMode && notes.isEmpty
                                ? _buildEmptyState(context, currentPath, isSearching)
                                : null,
                      ),
                      if (isTreeMode)
                        SliverToBoxAdapter(
                          child: _buildTreeView(searchState),
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
                                return NoteCard(
                                  note: note,
                                  index: index,
                                  onTap: () => _openNote(note),
                                  onDelete: () => _deleteNote(note),
                                  onRename: () => _renameEntry(note),
                                  onToggleFavorite: () => _toggleFavorite(note),
                                  formatFileName: _formatFileName,
                                  fileBadgeLabel: _fileBadgeLabel(note),
                                  searchMetadata:
                                      isSearching ? searchMetadata[note.path] : null,
                                  isFavorite: libraryPrefs.favorites.contains(note.path),
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
          icon: const Icon(Icons.add_rounded, color: AppTheme.brandOrange),
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

  Widget _buildSearchBar(VaultSearchState searchState) {
    final isSearching = searchState.query.trim().isNotEmpty;
    final isSearchLoading = searchState.status == SearchStatus.loading;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.md, AppTheme.sm, AppTheme.md, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          final notifier = ref.read(vaultSearchProvider.notifier);
          notifier.updateQuery(value);
          _searchDebounce?.cancel();

          if (value.trim().isEmpty) {
            return;
          }

          _searchDebounce = Timer(const Duration(milliseconds: 250), () async {
            final currentSearchState = ref.read(vaultSearchProvider);
            if (currentSearchState.vaultEntries.isEmpty) {
              await notifier.loadVaultEntries();
            }
            await notifier.loadSearchContentIndex();
          });
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
                    _searchDebounce?.cancel();
                    ref.read(vaultSearchProvider.notifier).clearSearch();
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
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
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
                    color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.5),
                  ),
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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

  Widget _buildTreeView(VaultSearchState searchState) {
    final entries = searchState.vaultEntries;
    final libraryPrefs = ref.watch(libraryPreferencesProvider);
    if (entries.isEmpty) {
      return _buildEmptyState(context, '', false);
    }

    final tree = _buildTreeEntries(entries);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.md, AppTheme.sm, AppTheme.md, AppTheme.xxl),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.22),
          ),
        ),
        child: Column(
          children: [
            for (final entry in tree)
              TreeNodeTile(
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
                onDelete: _deleteNote,
                onRename: _renameEntry,
                onToggleFavorite: _toggleFavorite,
                isFavorite: libraryPrefs.favorites.contains(entry.note.path),
                isFavoritePath: (path) => libraryPrefs.favorites.contains(path),
              ),
          ],
        ),
      ),
    );
  }

  List<TreeEntry> _buildTreeEntries(List<Note> entries) {
    final childrenByParent = <String, List<Note>>{};
    for (final entry in entries) {
      childrenByParent.putIfAbsent(entry.parentPath, () => <Note>[]).add(entry);
    }

    List<TreeEntry> buildLevel(String parentPath) {
      final siblings = [...(childrenByParent[parentPath] ?? const <Note>[])];
      siblings.sort((a, b) {
        if (a.isDirectory != b.isDirectory) {
          return a.isDirectory ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return siblings
          .map(
            (entry) => TreeEntry(
              note: entry,
              children: entry.isDirectory ? buildLevel(entry.path) : const <TreeEntry>[],
            ),
          )
          .toList();
    }

    return buildLevel('');
  }
}
