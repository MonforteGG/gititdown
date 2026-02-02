import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../core/error/failures.dart';
import '../../presentation/providers/auth_provider.dart';
import '../widgets/github_footer.dart';
import 'package:url_launcher/url_launcher.dart';

// Font fallback for characters not covered by primary fonts
const List<String> _fontFallback = ['Noto Sans'];

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _repositoryController = TextEditingController();
  final _patController = TextEditingController();
  bool _obscureToken = true;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _usernameController.dispose();
    _repositoryController.dispose();
    _patController.dispose();
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

  Future<void> _launchGitHubTokenPage() async {
    final uri = Uri.parse('https://github.com/settings/tokens/new');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      await ref.read(authProvider.notifier).login(
            _usernameController.text.trim(),
            _repositoryController.text.trim(),
            _patController.text.trim(),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      if (next.status == AuthStatus.error && next.failure != null) {
        String message = next.failure!.message;
        if (next.failure is AuthenticationFailure) {
          message = 'Invalid token. Please check your Personal Access Token.';
        } else if (next.failure?.statusCode == 404) {
          message = 'Repository not found. Check your username and repository.';
        }
        _showErrorSnackbar(message);
      }
    });

    final isLoading = authState.status == AuthStatus.loading;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: Stack(
        children: [
          // Decorative Background Elements
          Positioned(
            top: -100,
            right: -100,
            child: _DecorativeCircle(
              size: 300,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.03),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: _DecorativeCircle(
              size: 400,
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.05),
            ),
          ),
          // Subtle grid pattern
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _GridPainter(
                  color: AppTheme.inkBlack.withOpacity(0.035),
                ),
              ),
            ),
          ),
          // Windows Download Badge (desktop only)
          if (!isMobile)
            const Positioned(
              bottom: 16,
              left: 16,
              child: _WindowsDownloadBadge(),
            ),
          // GitHub Footer (desktop only)
          if (!isMobile)
            const Positioned(
              bottom: 16,
              right: 16,
              child: GitHubFooter(),
            ),
          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.lg),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildLogoSection(context),
                            const SizedBox(height: 48),
                            _buildFormSection(context, isLoading),
                            const SizedBox(height: 32),
                            _buildConnectButton(context, isLoading),
                            const SizedBox(height: 24),
                            _buildSecurityNote(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection(BuildContext context) {
    return Column(
      children: [
        // Logo
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Image.asset(
            'lib/assets/logo.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(height: 24),
        // App Name - Editorial Typography with two-tone style
        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  letterSpacing: -1.5,
                  fontWeight: FontWeight.w700,
                ),
            children: const [
              TextSpan(
                text: 'Git',
                style: TextStyle(
                  color: Color(0xFFE96A2B), // Orange
                ),
              ),
              TextSpan(
                text: 'It',
                style: TextStyle(
                  color: Color(0xFF4A4A4A), // Dark gray (same as "Down")
                  fontWeight: FontWeight.w400,
                ),
              ),
              TextSpan(
                text: 'Down',
                style: TextStyle(
                  color: Color(0xFF4A4A4A), // Dark gray
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Tagline with decorative elements
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 1,
              color: Theme.of(context).colorScheme.outline,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Your notes, versioned and everywhere',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.tertiary,
                  letterSpacing: 0.5,
                ).copyWith(fontFamilyFallback: _fontFallback),
              ),
            ),
            Container(
              width: 24,
              height: 1,
              color: Theme.of(context).colorScheme.outline,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormSection(BuildContext context, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
        ),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Label
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'CONNECT TO GITHUB',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Username Field
          _AnimatedTextField(
            controller: _usernameController,
            enabled: !isLoading,
            label: 'Username',
            hint: 'octocat',
            prefixIcon: Icons.person_outline_rounded,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter your GitHub username';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
            delay: 0,
          ),
          const SizedBox(height: 16),

          // Repository Field
          _AnimatedTextField(
            controller: _repositoryController,
            enabled: !isLoading,
            label: 'Repository',
            hint: 'my-notes',
            prefixIcon: Icons.folder_outlined,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter your repository name';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
            delay: 100,
          ),
          const SizedBox(height: 16),

          // Token Field
          _AnimatedTextField(
            controller: _patController,
            enabled: !isLoading,
            label: 'Personal Access Token',
            hint: 'ghp_xxxx...',
            prefixIcon: Icons.key_rounded,
            obscureText: _obscureToken,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureToken ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureToken = !_obscureToken),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter your Personal Access Token';
              }
              return null;
            },
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleLogin(),
            delay: 200,
          ),
          const SizedBox(height: 12),

          // Create Token Link
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: isLoading ? null : _launchGitHubTokenPage,
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: const Text('Create token'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                textStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ).copyWith(fontFamilyFallback: _fontFallback),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectButton(BuildContext context, bool isLoading) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Connecting...',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ).copyWith(fontFamilyFallback: _fontFallback),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Connect',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ).copyWith(fontFamilyFallback: _fontFallback),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSecurityNote(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 14,
          color: Theme.of(context).colorScheme.tertiary,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Stored securely on your device, never shared',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// Animated Text Field with staggered entrance
class _AnimatedTextField extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final int delay;

  const _AnimatedTextField({
    required this.controller,
    required this.enabled,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.delay = 0,
  });

  @override
  State<_AnimatedTextField> createState() => _AnimatedTextFieldState();
}

class _AnimatedTextFieldState extends State<_AnimatedTextField>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    Future.delayed(Duration(milliseconds: 300 + widget.delay), () {
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: widget.obscureText,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: Icon(widget.prefixIcon, size: 20),
            suffixIcon: widget.suffixIcon,
          ),
          validator: widget.validator,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
        ),
      ),
    );
  }
}

class _WindowsDownloadBadge extends StatelessWidget {
  const _WindowsDownloadBadge();

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => launchUrl(
          Uri.parse('https://github.com/MonforteGG/gititdown/releases'),
          mode: LaunchMode.externalApplication,
        ),
        child: Image.asset(
          'lib/assets/windows-button.png',
          height: 40,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

// Decorative Circle Widget
class _DecorativeCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _DecorativeCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

// Subtle Grid Pattern Painter
class _GridPainter extends CustomPainter {
  final Color color;

  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const spacing = 40.0;

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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
