import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../domain/entities/note.dart';
import '../providers/search_provider.dart';

const List<String> notesListFontFallback = ['Noto Sans'];

enum EntryAction { rename, toggleFavorite, delete }

class NoteCard extends StatefulWidget {
  final Note note;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;
  final VoidCallback? onToggleFavorite;
  final String Function(String) formatFileName;
  final String fileBadgeLabel;
  final SearchMatchMetadata? searchMetadata;
  final bool isFavorite;

  const NoteCard({
    super.key,
    required this.note,
    required this.index,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
    required this.onToggleFavorite,
    required this.formatFileName,
    required this.fileBadgeLabel,
    required this.searchMetadata,
    this.isFavorite = false,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard>
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
      duration: Duration(milliseconds: 300 + (widget.index * 50)),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDirectory = widget.note.isDirectory;
    final isAudio = widget.note.isAudio;
    final isPdf = widget.note.isPdf;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(_isHovered ? 2 : 0, 0, 0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: Ink(
                    padding: const EdgeInsets.all(AppTheme.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: _isHovered
                            ? colorScheme.primary.withValues(alpha: 0.25)
                            : colorScheme.outline.withValues(alpha: 0.15),
                      ),
                      boxShadow: _isHovered
                          ? [
                              BoxShadow(
                                color:
                                    colorScheme.shadow.withValues(alpha: 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(
                              alpha: isDirectory ? 0.12 : 0.08,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isDirectory
                                ? Icons.folder_open_rounded
                                : isAudio
                                    ? Icons.graphic_eq_rounded
                                    : isPdf
                                        ? Icons.picture_as_pdf_rounded
                                        : Icons.description_outlined,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (widget.isFavorite) ...[
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 16,
                                      color: Color(0xFFC99A1A),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(
                                    child: Text(
                                      isDirectory
                                          ? widget.note.name
                                          : widget
                                              .formatFileName(widget.note.name),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: isDirectory
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (!isDirectory)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surface,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: colorScheme.outline
                                              .withValues(alpha: 0.18),
                                        ),
                                      ),
                                      child: Text(
                                        widget.fileBadgeLabel,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.primary,
                                        ).copyWith(
                                          fontFamilyFallback:
                                              notesListFontFallback,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.note.path,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colorScheme.tertiary,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.searchMetadata?.snippet != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  widget.searchMetadata!.snippet!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.72),
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (widget.onRename != null ||
                            widget.onToggleFavorite != null ||
                            widget.onDelete != null) ...[
                          const SizedBox(width: 8),
                          PopupMenuButton<EntryAction>(
                            tooltip: 'Actions',
                            onSelected: (action) {
                              switch (action) {
                                case EntryAction.rename:
                                  widget.onRename?.call();
                                  break;
                                case EntryAction.toggleFavorite:
                                  widget.onToggleFavorite?.call();
                                  break;
                                case EntryAction.delete:
                                  widget.onDelete?.call();
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              if (widget.onRename != null)
                                const PopupMenuItem(
                                  value: EntryAction.rename,
                                  child: Text('Rename'),
                                ),
                              if (widget.onToggleFavorite != null)
                                PopupMenuItem(
                                  value: EntryAction.toggleFavorite,
                                  child: Text(
                                    widget.isFavorite
                                        ? 'Remove from favorites'
                                        : 'Add to favorites',
                                  ),
                                ),
                              if (widget.onDelete != null)
                                PopupMenuItem(
                                  value: EntryAction.delete,
                                  child: Text(
                                    widget.note.isDirectory
                                        ? 'Delete folder'
                                        : 'Delete',
                                  ),
                                ),
                            ],
                            icon: Icon(
                              Icons.more_horiz_rounded,
                              color: colorScheme.tertiary,
                            ),
                          ),
                        ],
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
                                ? colorScheme.primary
                                : colorScheme.tertiary,
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

class PathBar extends StatelessWidget {
  final String currentPath;
  final VoidCallback? onGoRoot;
  final VoidCallback? onGoUp;
  final bool showTreeToggle;
  final bool isTreeViewEnabled;
  final ValueChanged<bool>? onTreeViewChanged;

  const PathBar({
    super.key,
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
      padding:
          const EdgeInsets.fromLTRB(AppTheme.md, AppTheme.sm, AppTheme.md, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.25),
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
    final borderColor =
        colorScheme.outline.withValues(alpha: _isHovered ? 0.34 : 0.18);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.06),
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
                  Icon(
                    Icons.account_tree_rounded,
                    size: 16,
                    color: colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: colorScheme.onSurface,
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
                          ? colorScheme.primary.withValues(alpha: 0.16)
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      alignment: enabled
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: enabled
                              ? colorScheme.primary
                              : colorScheme.onSurface,
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

class TreeEntry {
  final Note note;
  final List<TreeEntry> children;

  const TreeEntry({
    required this.note,
    required this.children,
  });
}

class TreeNodeTile extends StatelessWidget {
  final TreeEntry entry;
  final int depth;
  final Set<String> expandedPaths;
  final ValueChanged<String> onToggleExpansion;
  final ValueChanged<Note> onOpen;
  final ValueChanged<Note>? onDelete;
  final ValueChanged<Note>? onRename;
  final ValueChanged<Note>? onToggleFavorite;
  final String Function(String) formatFileName;
  final String Function(Note) fileBadgeLabel;
  final bool isFavorite;
  final bool Function(String) isFavoritePath;

  const TreeNodeTile({
    super.key,
    required this.entry,
    required this.depth,
    required this.expandedPaths,
    required this.onToggleExpansion,
    required this.onOpen,
    required this.onDelete,
    required this.onRename,
    required this.onToggleFavorite,
    required this.formatFileName,
    required this.fileBadgeLabel,
    this.isFavorite = false,
    required this.isFavoritePath,
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
                              onPressed: () =>
                                  onToggleExpansion(entry.note.path),
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
                        color: colorScheme.primary.withValues(
                          alpha: isDirectory ? 0.12 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDirectory
                            ? Icons.folder_open_rounded
                            : entry.note.isAudio
                                ? Icons.graphic_eq_rounded
                                : entry.note.isPdf
                                    ? Icons.picture_as_pdf_rounded
                                    : Icons.description_outlined,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          if (isFavorite) ...[
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFC99A1A),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              isDirectory
                                  ? entry.note.name
                                  : formatFileName(entry.note.name),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: isDirectory
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isDirectory)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Text(
                          fileBadgeLabel(entry.note),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ).copyWith(fontFamilyFallback: notesListFontFallback),
                        ),
                      ),
                    if (onRename != null ||
                        onToggleFavorite != null ||
                        onDelete != null) ...[
                      const SizedBox(width: 6),
                      PopupMenuButton<EntryAction>(
                        tooltip: 'Actions',
                        onSelected: (action) {
                          switch (action) {
                            case EntryAction.rename:
                              onRename?.call(entry.note);
                              break;
                            case EntryAction.toggleFavorite:
                              onToggleFavorite?.call(entry.note);
                              break;
                            case EntryAction.delete:
                              onDelete?.call(entry.note);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          if (onRename != null)
                            const PopupMenuItem(
                              value: EntryAction.rename,
                              child: Text('Rename'),
                            ),
                          if (onToggleFavorite != null)
                            PopupMenuItem(
                              value: EntryAction.toggleFavorite,
                              child: Text(
                                isFavorite
                                    ? 'Remove from favorites'
                                    : 'Add to favorites',
                              ),
                            ),
                          if (onDelete != null)
                            PopupMenuItem(
                              value: EntryAction.delete,
                              child: Text(
                                isDirectory ? 'Delete folder' : 'Delete',
                              ),
                            ),
                        ],
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          size: 20,
                          color: colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isDirectory && isExpanded)
          for (final child in entry.children)
            TreeNodeTile(
              entry: child,
              depth: depth + 1,
              expandedPaths: expandedPaths,
              formatFileName: formatFileName,
              fileBadgeLabel: fileBadgeLabel,
              onToggleExpansion: onToggleExpansion,
              onOpen: onOpen,
              onDelete: onDelete,
              onRename: onRename,
              onToggleFavorite: onToggleFavorite,
              isFavorite: isFavoritePath(child.note.path),
              isFavoritePath: isFavoritePath,
            ),
      ],
    );
  }
}

class QuickAccessSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Note> entries;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapsed;
  final void Function(Note) onOpen;
  final void Function(Note) onRename;
  final void Function(Note) onDelete;
  final void Function(Note) onToggleFavorite;
  final bool Function(String) isFavorite;
  final String Function(String) formatFileName;

  const QuickAccessSection({
    super.key,
    required this.title,
    required this.icon,
    required this.entries,
    this.isCollapsed = false,
    this.onToggleCollapsed,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.isFavorite,
    required this.formatFileName,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty && onToggleCollapsed == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(AppTheme.md, AppTheme.md, AppTheme.md, 0),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    onTap: onToggleCollapsed,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(icon, size: 18, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${entries.length})',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.tertiary,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (onToggleCollapsed != null)
                  IconButton(
                    onPressed: onToggleCollapsed,
                    tooltip:
                        isCollapsed ? 'Expand favorites' : 'Collapse favorites',
                    icon: AnimatedRotation(
                      turns: isCollapsed ? 0 : 0.5,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: colorScheme.tertiary,
                      ),
                    ),
                  ),
              ],
            ),
            if (!isCollapsed) ...[
              const SizedBox(height: AppTheme.sm),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'No favorites yet',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.tertiary,
                        ),
                  ),
                )
              else
                for (var index = 0; index < entries.length; index++) ...[
                  _QuickAccessEntryTile(
                    note: entries[index],
                    onOpen: () => onOpen(entries[index]),
                    onRename: () => onRename(entries[index]),
                    onDelete: () => onDelete(entries[index]),
                    onToggleFavorite: () => onToggleFavorite(entries[index]),
                    isFavorite: isFavorite(entries[index].path),
                    formatFileName: formatFileName,
                  ),
                  if (index < entries.length - 1)
                    Divider(
                      height: 16,
                      color: colorScheme.outline.withValues(alpha: 0.14),
                    ),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickAccessEntryTile extends StatelessWidget {
  final Note note;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final bool isFavorite;
  final String Function(String) formatFileName;

  const _QuickAccessEntryTile({
    required this.note,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.isFavorite,
    required this.formatFileName,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              note.isDirectory
                  ? Icons.folder_open_rounded
                  : note.isAudio
                      ? Icons.graphic_eq_rounded
                      : note.isPdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.description_outlined,
              size: 18,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isFavorite) ...[
                        const Icon(Icons.star_rounded,
                            size: 14, color: Color(0xFFC99A1A)),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          note.isDirectory
                              ? note.name
                              : formatFileName(note.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    note.path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.tertiary,
                        ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<EntryAction>(
              onSelected: (action) {
                switch (action) {
                  case EntryAction.rename:
                    onRename();
                    break;
                  case EntryAction.toggleFavorite:
                    onToggleFavorite();
                    break;
                  case EntryAction.delete:
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: EntryAction.rename,
                  child: Text('Rename'),
                ),
                PopupMenuItem(
                  value: EntryAction.toggleFavorite,
                  child: Text(isFavorite
                      ? 'Remove from favorites'
                      : 'Add to favorites'),
                ),
                PopupMenuItem(
                  value: EntryAction.delete,
                  child: Text(note.isDirectory ? 'Delete folder' : 'Delete'),
                ),
              ],
              icon: Icon(Icons.more_horiz_rounded, color: colorScheme.tertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class LogoutDialog extends StatelessWidget {
  const LogoutDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
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

class DeleteNoteDialog extends StatelessWidget {
  final String noteName;

  const DeleteNoteDialog({
    super.key,
    required this.noteName,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
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

class CreateFolderDialog extends StatefulWidget {
  const CreateFolderDialog({super.key});

  @override
  State<CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<CreateFolderDialog> {
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
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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

class DeleteFolderDialog extends StatelessWidget {
  final String folderName;

  const DeleteFolderDialog({
    super.key,
    required this.folderName,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
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

class RenameEntryDialog extends StatefulWidget {
  final String title;
  final String initialValue;
  final bool isDirectory;

  const RenameEntryDialog({
    super.key,
    required this.title,
    required this.initialValue,
    required this.isDirectory,
  });

  @override
  State<RenameEntryDialog> createState() => _RenameEntryDialogState();
}

class _RenameEntryDialogState extends State<RenameEntryDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

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
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.drive_file_rename_outline_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.title)),
        ],
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.isDirectory ? 'Folder name' : 'File name',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Rename'),
        ),
      ],
    );
  }
}
