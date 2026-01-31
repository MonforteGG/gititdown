import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/notes_list_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: GitItDownApp(),
    ),
  );
}

class GitItDownApp extends StatelessWidget {
  const GitItDownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitItDown',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Show appropriate screen based on auth status
    switch (authState.status) {
      case AuthStatus.initial:
        // Show splash/loading while checking auth
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      case AuthStatus.loading:
        // Show loading screen during authentication
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      case AuthStatus.authenticated:
        // User is authenticated, show notes list
        return const NotesListScreen();
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        // User is not authenticated or there was an error, show login
        return const LoginScreen();
    }
  }
}
