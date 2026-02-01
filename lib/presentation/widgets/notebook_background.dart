import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// GridPainter - Draws a subtle grid pattern for the notebook background
class GridPainter extends CustomPainter {
  final Color color;
  final double spacing;
  final double strokeWidth;

  GridPainter({
    required this.color,
    this.spacing = 32.0,
    this.strokeWidth = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth;

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.spacing != spacing ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// NotebookPage - A container styled like a floating notebook page
class NotebookPage extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets margin;

  const NotebookPage({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.margin = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: margin,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE8E4DF),
            width: 1,
          ),
          boxShadow: [
            // Primary shadow - elevation
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            // Secondary shadow - depth
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 48,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// NotebookBackground - Combines grid background with notebook page container
class NotebookBackground extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets margin;
  final bool showNotebookPage;

  const NotebookBackground({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.margin = const EdgeInsets.fromLTRB(24, 16, 24, 24),
    this.showNotebookPage = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
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
        // Content (optionally wrapped in NotebookPage)
        if (showNotebookPage)
          SafeArea(
            child: NotebookPage(
              maxWidth: maxWidth,
              margin: margin,
              child: child,
            ),
          )
        else
          child,
      ],
    );
  }
}
