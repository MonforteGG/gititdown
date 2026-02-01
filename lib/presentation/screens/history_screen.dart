import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/note.dart';
import '../../domain/entities/note_commit.dart';
import '../../presentation/providers/notes_provider.dart';
import '../widgets/github_footer.dart';
import '../widgets/notebook_background.dart';

const List<String> _fontFallback = ['Noto Sans'];

class HistoryScreen extends ConsumerStatefulWidget {
  final String notePath;
  final String noteName;

  const HistoryScreen({
    super.key,
    required this.notePath,
    required this.noteName,
  });

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(notesProvider.notifier).loadNoteHistory(widget.notePath);
    });
  }

  @override
  void dispose() {
    ref.read(notesProvider.notifier).clearHistoryState();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesState = ref.watch(notesProvider);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(
                color: AppTheme.inkBlack.withOpacity(0.035),
                spacing: 32,
              ),
            ),
          ),
          const Positioned(
            bottom: 16,
            right: 16,
            child: GitHubFooter(),
          ),
          SafeArea(
            child: NotebookPage(
              maxWidth: 800,
              margin: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  _buildAppBar(context),
                  Expanded(
                    child: notesState.historyStatus == HistoryStatus.loading
                        ? _buildLoadingState()
                        : notesState.historyStatus == HistoryStatus.error
                            ? _buildErrorState(notesState.failure)
                            : notesState.noteHistory.isEmpty
                                ? _buildEmptyState()
                                : notesState.versionNote != null
                                    ? _buildVersionView(notesState.versionNote!)
                                    : _buildCommitList(notesState.noteHistory),
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
    final notesState = ref.watch(notesProvider);
    final isViewingVersion = notesState.versionNote != null;

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
          if (isViewingVersion)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                ref.read(notesProvider.notifier).clearVersionView();
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              isViewingVersion
                  ? 'Version: ${_formatDate(notesState.versionNote!.lastModified)}'
                  : 'History: ${_stripExtension(widget.noteName)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isViewingVersion)
            Text(
              '${notesState.noteHistory.length} versions',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
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
            'Loading history...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.tertiary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Failure? failure) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load history',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            failure?.message ?? 'Unknown error',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.tertiary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              ref.read(notesProvider.notifier).loadNoteHistory(widget.notePath);
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.tertiary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No history available',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'This note has no previous versions',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.tertiary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommitList(List<NoteCommit> commits) {
    return ListView.separated(
      itemCount: commits.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        indent: 72,
        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
      ),
      itemBuilder: (context, index) {
        final commit = commits[index];
        final isLatest = index == 0;

        return _CommitTile(
          commit: commit,
          isLatest: isLatest,
          onTap: () async {
            await ref
                .read(notesProvider.notifier)
                .loadNoteVersion(widget.notePath, commit.sha);
          },
        );
      },
    );
  }

  Widget _buildVersionView(Note versionNote) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.md, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Read-only view of this version',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Markdown(
            data: versionNote.content.isEmpty
                ? '_This version has no content_'
                : versionNote.content,
            selectable: true,
            styleSheet: _buildMarkdownStyleSheet(context),
            padding: const EdgeInsets.all(AppTheme.md),
          ),
        ),
      ],
    );
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet(BuildContext context) {
    return MarkdownStyleSheet(
      h1: GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
        height: 1.3,
      ).copyWith(fontFamilyFallback: _fontFallback),
      h2: GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
        height: 1.3,
      ).copyWith(fontFamilyFallback: _fontFallback),
      h3: GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
        height: 1.3,
      ).copyWith(fontFamilyFallback: _fontFallback),
      p: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        color: Theme.of(context).colorScheme.onSurface,
        height: 1.7,
      ).copyWith(fontFamilyFallback: _fontFallback),
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
      listIndent: 24,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
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
    );
  }

  String _stripExtension(String name) {
    if (name.endsWith('.md')) {
      return name.substring(0, name.length - 3);
    }
    return name;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _CommitTile extends StatelessWidget {
  final NoteCommit commit;
  final bool isLatest;
  final VoidCallback onTap;

  const _CommitTile({
    required this.commit,
    required this.isLatest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isLatest
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isLatest
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                        : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Icon(
                  isLatest ? Icons.label_important_rounded : Icons.history_rounded,
                  size: 20,
                  color: isLatest
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      commit.message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: isLatest ? FontWeight.w600 : FontWeight.w500,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.person_rounded,
                          size: 12,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          commit.authorName,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(commit.date),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.tertiary.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
