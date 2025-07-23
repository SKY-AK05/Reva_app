import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/providers.dart';
import 'login_screen.dart';
import 'auth_loading_screen.dart';

class AuthWrapper extends ConsumerWidget {
  final Widget authenticatedChild;
  
  const AuthWrapper({
    super.key,
    required this.authenticatedChild,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    
    return authState.when(
      data: (state) {
        // Check if user is authenticated
        if (state.session?.user != null) {
          return authenticatedChild;
        } else {
          return const LoginScreen();
        }
      },
      loading: () => const AuthLoadingScreen(
        message: 'Checking authentication...',
      ),
      error: (error, stackTrace) {
        // On error, show login screen
        return const LoginScreen();
      },
    );
  }
}