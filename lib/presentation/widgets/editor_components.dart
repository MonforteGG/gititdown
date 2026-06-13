import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';

const List<String> editorFontFallback = ['Noto Sans'];

class MarkdownToolbarButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const MarkdownToolbarButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: enabled
                ? colorScheme.primary.withValues(alpha: 0.08)
                : colorScheme.outline.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: enabled
                  ? colorScheme.primary.withValues(alpha: 0.18)
                  : colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: enabled ? colorScheme.primary : colorScheme.tertiary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: enabled ? colorScheme.primary : colorScheme.tertiary,
                ).copyWith(fontFamilyFallback: editorFontFallback),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const ModeButton({
    super.key,
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
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
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
                  : Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.6),
              ).copyWith(fontFamilyFallback: editorFontFallback),
            ),
          ],
        ),
      ),
    );
  }
}

class UnsavedChangesDialog extends StatelessWidget {
  const UnsavedChangesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
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
