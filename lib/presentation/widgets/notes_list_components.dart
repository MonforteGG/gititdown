import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../domain/entities/note.dart';
import '../providers/search_provider.dart';

const List<String> notesListFontFallback = ['Noto Sans'];

class NoteCard extends StatefulWidget {
  final Note note;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final String Function(String) formatFileName;
  final String fileBadgeLabel;
  final SearchMatchMetadata? searchMetadata;

  const NoteCard({
    super.key,
    required this.note,
    required this.index,
    required this.onTap,
    required this.onDelete,
    required this.formatFileName,
    required this.fileBadgeLabel,
    required this.searchMetadata,
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
                                color: colorScheme.shadow.withValues(alpha: 0.08),
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
                              alpha:
                              isDirectory ? 0.12 : 0.08,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isDirectory
                                ? Icons.folder_open_rounded
                                : isAudio
                                    ? Icons.graphic_eq_rounded
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
                                  Expanded(
                                    child: Text(
                                      isDirectory
                                          ? widget.note.name
                                          : widget.formatFileName(widget.note.name),
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
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: colorScheme.outline.withValues(alpha: 0.18),
                                        ),
                                      ),
                                      child: Text(
                                        widget.fileBadgeLabel,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.primary,
                                        ).copyWith(
                                          fontFamilyFallback: notesListFontFallback,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.note.path,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.tertiary,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.searchMetadata?.snippet != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  widget.searchMetadata!.snippet!,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurface.withValues(alpha: 0.72),
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (widget.onDelete != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: widget.onDelete,
                            tooltip: 'Delete',
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: colorScheme.error,
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
      padding: const EdgeInsets.fromLTRB(AppTheme.md, AppTheme.sm, AppTheme.md, 0),
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
  final String Function(String) formatFileName;
  final String Function(Note) fileBadgeLabel;

  const TreeNodeTile({
    super.key,
    required this.entry,
    required this.depth,
    required this.expandedPaths,
    required this.onToggleExpansion,
    required this.onOpen,
    required this.onDelete,
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
                    if (onDelete != null) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () => onDelete!.call(entry.note),
                        tooltip: isDirectory ? 'Delete folder' : 'Delete note',
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: colorScheme.error,
                        ),
                        visualDensity: VisualDensity.compact,
                        splashRadius: 18,
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
            ),
      ],
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
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
