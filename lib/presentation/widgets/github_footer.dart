import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

class GitHubFooter extends StatefulWidget {
  const GitHubFooter({super.key});

  @override
  State<GitHubFooter> createState() => _GitHubFooterState();
}

class _GitHubFooterState extends State<GitHubFooter> {
  bool _isHovered = false;

  static const String _repoUrl = 'https://github.com/MonforteGG';

  Future<void> _openRepo() async {
    final uri = Uri.parse(_repoUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    final hoverColor = Theme.of(context).colorScheme.onSurface;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Made with ❤️ by ',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: textColor,
          ),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: _openRepo,
            child: Text(
              '@MonforteGG',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: _isHovered ? hoverColor : textColor,
                fontWeight: _isHovered ? FontWeight.w700 : FontWeight.w600,
                decoration: _isHovered ? TextDecoration.underline : TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
