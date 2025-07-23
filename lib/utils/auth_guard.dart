import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/auth_exports.dart';

/// A widget that protects routes by checking authentication status
class AuthGuard extends ConsumerWidget {
  final Widget child;
  final Widget? fallback;
  
  const AuthGuard({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    
    return switch (authState) {
      AuthenticationStateLoading() || AuthenticationStateInitial() => 
        const AuthLoadingScreen(message: 'Checking authentication...'),
      AuthenticationStateAuthenticated() => child,
      AuthenticationStateEmailVerificationRequired() => 
        const AuthLoadingScreen(message: 'Please verify your email...'),
      _ => fallback ?? const LoginScreen(),
    };
  }
}

/// A mixin that provides authentication guard functionality to routes
mixin AuthGuardMixin {
  /// Check if user is authenticated and navigate to login if not
  static bool checkAuthentication(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.read(isAuthenticatedStateProvider);
    
    if (!isAuthenticated) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
      return false;
    }
    
    return true;
  }
  
  /// Navigate to login screen and clear navigation stack
  static void navigateToLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }
  
  /// Navigate to authenticated home screen
  static void navigateToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthenticatedHome()),
      (route) => false,
    );
  }
}

/// Placeholder for the authenticated home screen
class AuthenticatedHome extends ConsumerWidget {
  const AuthenticatedHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserStateProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reva'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authNotifier = ref.read(authNotifierProvider.notifier);
              await authNotifier.signOut();
            },
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.psychology_outlined,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            const Text(
              'Welcome to Reva!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (user?.email != null) ...[
              Text(
                'Hello, ${user!.email}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
            ],
            const Text(
              'You are successfully authenticated.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}