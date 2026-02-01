import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';

class GitHubStarsButton extends StatefulWidget {
  const GitHubStarsButton({super.key});

  @override
  State<GitHubStarsButton> createState() => _GitHubStarsButtonState();
}

class _GitHubStarsButtonState extends State<GitHubStarsButton> {
  int _starCount = 0;
  bool _loading = true;
  bool _isHovered = false;

  static const String _starsUrl = 'https://api.github.com/repos/MonforteGG/gititdown';
  static const String _stargazersUrl = 'https://github.com/MonforteGG/gititdown/stargazers';

  @override
  void initState() {
    super.initState();
    _fetchStarCount();
  }

  Future<void> _fetchStarCount() async {
    try {
      final dio = Dio();
      final response = await dio.get(_starsUrl);
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _starCount = response.data['stargazers_count'] ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openStargazers() async {
    final uri = Uri.parse(_stargazersUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _openStargazers,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFF2F363D) : const Color(0xFF24292F),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isHovered ? const Color(0xFF444D56) : Colors.transparent,
              width: 1,
            ),
          ),
          child: _loading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_border,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Star',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isHovered ? const Color(0xFF24292F) : Colors.white.withValues(alpha: 0.2),
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Text(
                        '$_starCount',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
