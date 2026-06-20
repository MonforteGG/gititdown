import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../config/theme.dart';
import '../../domain/entities/note.dart';
import '../../domain/usecases/get_file_bytes.dart';
import '../providers/dependency_providers.dart';
import '../widgets/github_footer.dart';
import '../widgets/notebook_background.dart';

const List<String> _fontFallback = ['Noto Sans'];

class PdfViewerScreen extends ConsumerStatefulWidget {
  final Note note;

  const PdfViewerScreen({
    super.key,
    required this.note,
  });

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  Uint8List? _pdfBytes;
  bool _isLoading = true;
  String? _errorMessage;
  double? _downloadProgress;
  int? _downloadedBytes;
  int? _totalBytes;
  bool _isViewerReady = false;
  int? _currentPage;
  int? _pageCount;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _downloadProgress = null;
      _downloadedBytes = null;
      _totalBytes = null;
      _isViewerReady = false;
      _currentPage = null;
      _pageCount = null;
    });

    final result = await ref.read(getFileBytesUseCaseProvider)(
      GetFileBytesParams(
        path: widget.note.path,
        onReceiveProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _downloadedBytes = received >= 0 ? received : null;
            _totalBytes = total > 0 ? total : null;
            _downloadProgress =
                total > 0 ? (received / total).clamp(0.0, 1.0) : null;
          });
        },
      ),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _errorMessage = failure.message;
          _isLoading = false;
        });
      },
      (bytes) {
        setState(() {
          _pdfBytes = bytes;
          _isLoading = false;
        });
      },
    );
  }

  String _formatByteCount(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;

    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    final decimals = unitIndex == 0 ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} ${units[unitIndex]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = widget.note;
    final folderPath =
        note.parentPath.isEmpty ? 'Repository root' : note.parentPath;

    return Scaffold(
      backgroundColor: AppTheme.paperCream,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(
                color: AppTheme.inkBlack.withValues(alpha: 0.035),
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
              maxWidth: 1120,
              margin: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
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
                          color:
                              theme.colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                note.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                folderPath,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.tertiary,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.zoom_out_rounded),
                          tooltip: 'Zoom out',
                          onPressed: _isViewerReady
                              ? () => _pdfViewerController.zoomDown()
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.zoom_in_rounded),
                          tooltip: 'Zoom in',
                          onPressed: _isViewerReady
                              ? () => _pdfViewerController.zoomUp()
                              : null,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.xl,
                        AppTheme.lg,
                        AppTheme.xl,
                        AppTheme.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppTheme.lg),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.82),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusLg),
                              border: Border.all(
                                color: theme.colorScheme.outline
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF1EC),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.picture_as_pdf_rounded,
                                    color: AppTheme.brandOrange,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Vault PDF',
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.warmGray,
                                        ).copyWith(
                                          fontFamilyFallback: _fontFallback,
                                        ),
                                      ),
                                      const SizedBox(height: AppTheme.xs),
                                      Text(
                                        note.name,
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppTheme.lg),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusLg,
                                ),
                                border: Border.all(
                                  color: theme.colorScheme.outline
                                      .withValues(alpha: 0.22),
                                ),
                                boxShadow: AppTheme.subtleShadow,
                              ),
                              child: _isLoading
                                  ? _PdfLoadingState(
                                      progress: _downloadProgress,
                                      downloadedBytes: _downloadedBytes,
                                      totalBytes: _totalBytes,
                                      formatByteCount: _formatByteCount,
                                    )
                                  : _errorMessage != null
                                      ? _PdfErrorState(
                                          message: _errorMessage!,
                                          onRetry: _loadPdf,
                                        )
                                      : _pdfBytes == null || _pdfBytes!.isEmpty
                                          ? _PdfErrorState(
                                              message: 'The PDF file is empty.',
                                              onRetry: _loadPdf,
                                            )
                                          : PdfViewer.data(
                                              _pdfBytes!,
                                              sourceName: note.name,
                                              controller: _pdfViewerController,
                                              params: PdfViewerParams(
                                                margin: 0,
                                                maxScale: 8,
                                                calculateInitialZoom:
                                                    (_, __, fitZoom, ___) =>
                                                        fitZoom,
                                                onPageChanged: (pageNumber) {
                                                  if (!mounted) return;
                                                  setState(() {
                                                    _currentPage = pageNumber;
                                                  });
                                                },
                                                viewerOverlayBuilder:
                                                    (context, size, _) => [
                                                  _PdfVerticalScrollThumb(
                                                    controller:
                                                        _pdfViewerController,
                                                    rightInset: 20,
                                                    verticalInset: 18,
                                                    thumbSize: const Size(
                                                      22,
                                                      72,
                                                    ),
                                                  ),
                                                  if (_currentPage != null &&
                                                      _pageCount != null)
                                                    Positioned(
                                                      right: 48,
                                                      bottom: 14,
                                                      child: IgnorePointer(
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 12,
                                                            vertical: 8,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: AppTheme
                                                                .inkBlack
                                                                .withValues(
                                                              alpha: 0.82,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                              999,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            '$_currentPage/$_pageCount',
                                                            style: Theme.of(
                                                              context,
                                                            )
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                                onViewerReady:
                                                    (document, controller) {
                                                  if (!mounted) return;
                                                  if (!identical(
                                                    controller,
                                                    _pdfViewerController,
                                                  )) {
                                                    return;
                                                  }
                                                  final firstPage =
                                                      document.pages.isEmpty
                                                          ? null
                                                          : document.pages.first
                                                              .pageNumber;
                                                  if (firstPage != null) {
                                                    controller.goTo(
                                                      controller
                                                          .calcMatrixFitWidthForPage(
                                                        pageNumber: firstPage,
                                                      ),
                                                      duration: Duration.zero,
                                                    );
                                                  }
                                                  setState(() {
                                                    _isViewerReady = true;
                                                    _pageCount =
                                                        document.pages.length;
                                                    _currentPage ??=
                                                        firstPage ?? 1;
                                                  });
                                                },
                                              ),
                                            ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfVerticalScrollThumb extends StatefulWidget {
  final PdfViewerController controller;
  final double rightInset;
  final double verticalInset;
  final Size thumbSize;

  const _PdfVerticalScrollThumb({
    required this.controller,
    required this.rightInset,
    required this.verticalInset,
    required this.thumbSize,
  });

  @override
  State<_PdfVerticalScrollThumb> createState() =>
      _PdfVerticalScrollThumbState();
}

class _PdfVerticalScrollThumbState extends State<_PdfVerticalScrollThumb> {
  double _panStartOffset = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (!widget.controller.isReady) {
          return const SizedBox.shrink();
        }

        final view = widget.controller.visibleRect;
        final all = widget.controller.documentSize;
        final boundaryMargin = widget.controller.params.boundaryMargin;
        final effectiveDocHeight =
            boundaryMargin == null || boundaryMargin.vertical.isInfinite
                ? all.height
                : all.height + boundaryMargin.vertical;

        if (effectiveDocHeight <= view.height) {
          return const SizedBox.shrink();
        }

        final scrollRange = effectiveDocHeight - view.height;
        final minScrollY =
            boundaryMargin == null || boundaryMargin.vertical.isInfinite
                ? 0.0
                : -boundaryMargin.top;
        final y = (-widget.controller.value.y - minScrollY) / scrollRange;
        final trackHeight = (view.height * widget.controller.currentZoom) -
            (widget.verticalInset * 2);

        if (trackHeight <= widget.thumbSize.height) {
          return const SizedBox.shrink();
        }

        final travel = trackHeight - widget.thumbSize.height;
        final top = widget.verticalInset + (y.clamp(0.0, 1.0) * travel);

        return Positioned(
          right: widget.rightInset,
          top: top,
          width: widget.thumbSize.width,
          height: widget.thumbSize.height,
          child: GestureDetector(
            onPanStart: (details) {
              _panStartOffset = top - details.localPosition.dy;
            },
            onPanUpdate: (details) {
              final nextTop = (_panStartOffset + details.localPosition.dy)
                  .clamp(widget.verticalInset, widget.verticalInset + travel);
              final nextRatio =
                  ((nextTop - widget.verticalInset) / travel).clamp(0.0, 1.0);
              final matrix = widget.controller.value.clone();
              matrix.y = -(nextRatio * scrollRange + minScrollY);
              widget.controller.value = matrix;
            },
            child: Container(
              width: widget.thumbSize.width,
              height: widget.thumbSize.height,
              decoration: BoxDecoration(
                color: AppTheme.inkBlack.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.inkBlack.withValues(alpha: 0.16),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.drag_indicator_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PdfLoadingState extends StatelessWidget {
  final double? progress;
  final int? downloadedBytes;
  final int? totalBytes;
  final String Function(int bytes) formatByteCount;

  const _PdfLoadingState({
    required this.progress,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.formatByteCount,
  });

  @override
  Widget build(BuildContext context) {
    final determinateProgress = progress;
    final downloadedLabel =
        downloadedBytes != null ? formatByteCount(downloadedBytes!) : null;
    final totalLabel = totalBytes != null ? formatByteCount(totalBytes!) : null;
    final percentageLabel = determinateProgress != null
        ? '${(determinateProgress * 100).round()}%'
        : null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Loading PDF',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.inkBlack,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppTheme.md),
              Text(
                determinateProgress != null
                    ? 'Downloading PDF from GitHub'
                    : 'Preparing authenticated download',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.warmGray,
                    ),
              ),
              const SizedBox(height: AppTheme.lg),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: determinateProgress,
                  backgroundColor: const Color(0xFFE7DED2),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.brandOrange,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    downloadedLabel != null
                        ? totalLabel != null
                            ? '$downloadedLabel / $totalLabel'
                            : downloadedLabel
                        : 'Starting...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.warmGray,
                        ),
                  ),
                  if (percentageLabel != null)
                    Text(
                      percentageLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.inkBlack,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _PdfErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1EC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.picture_as_pdf_outlined,
                color: AppTheme.brandOrange,
                size: 32,
              ),
            ),
            const SizedBox(height: AppTheme.md),
            Text(
              'Could not open this PDF',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.sm),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.warmGray,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
