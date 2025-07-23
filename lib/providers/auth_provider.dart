import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth/auth_exports.dart';
import '../utils/logger.dart';
import 'providers.dart';

/// Authentication state notifier that manages authentication operations
class AuthNotifier extends StateNotifier<AuthenticationState> {
  final AuthRepository _authRepository;
  final SessionManager _sessionManager;
  
  AuthNotifier(this._authRepository, this._sessionManager) 
      : super(const AuthenticationState.initial()) {
    _initialize();
  }

  /// Initialize authentication state
  Future<void> _initialize() async {
    try {
      await _authRepository.initialize();
      
      // Listen to auth state changes
      _authRepository.authStateChanges.listen((authState) {
        _handleAuthStateChange(authState);
      });
      
      // Check current authentication status
      if (_authRepository.isAuthenticated) {
        state = AuthenticationState.authenticated(_authRepository.currentUser!);
      } else {
        state = const AuthenticationState.unauthenticated();
      }
    } catch (e) {
      Logger.error('Failed to initialize auth: $e');
      state = AuthenticationState.error(e.toString());
    }
  }

  /// Handle authentication state changes
  void _handleAuthStateChange(AuthState authState) {
    switch (authState.event) {
      case AuthChangeEvent.signedIn:
        if (authState.session?.user != null) {
          state = AuthenticationState.authenticated(authState.session!.user!);
        }
        break;
      case AuthChangeEvent.signedOut:
        state = const AuthenticationState.unauthenticated();
        break;
      case AuthChangeEvent.tokenRefreshed:
        if (authState.session?.user != null) {
          state = AuthenticationState.authenticated(authState.session!.user!);
        }
        break;
      default:
        break;
    }
  }

  /// Sign in with email and password
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    state = const AuthenticationState.loading();
    
    try {
      final result = await _authRepository.signInWithEmailPassword(
        email: email,
        password: password,
      );
      
      if (result.isFailure) {
        state = AuthenticationState.error(result.error!);
      }
      // Success state will be handled by auth state change listener
    } catch (e) {
      Logger.error('Sign in error: $e');
      state = AuthenticationState.error('An unexpected error occurred');
    }
  }

  /// Sign up with email and password
  Future<void> signUpWithEmailPassword({
    required String email,
    required String password,
    String? fullName,
  }) async {
    state = const AuthenticationState.loading();
    
    try {
      final result = await _authRepository.signUpWithEmailPassword(
        email: email,
        password: password,
        fullName: fullName,
      );
      
      if (result.isFailure) {
        state = AuthenticationState.error(result.error!);
      } else {
        // For sign up, we might need email verification
        state = const AuthenticationState.emailVerificationRequired();
      }
    } catch (e) {
      Logger.error('Sign up error: $e');
      state = AuthenticationState.error('An unexpected error occurred');
    }
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    state = const AuthenticationState.loading();
    
    try {
      final result = await _authRepository.signInWithGoogle();
      
      if (result.isFailure) {
        state = AuthenticationState.error(result.error!);
      }
      // Success state will be handled by auth state change listener
    } catch (e) {
      Logger.error('Google sign in error: $e');
      state = AuthenticationState.error('An unexpected error occurred');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _authRepository.signOut();
      // State will be updated by auth state change listener
    } catch (e) {
      Logger.error('Sign out error: $e');
      state = AuthenticationState.error('Failed to sign out');
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      final result = await _authRepository.resetPassword(email);
      
      if (result.isFailure) {
        state = AuthenticationState.error(result.error!);
      } else {
        // Don't change the main state for password reset
        Logger.info('Password reset email sent');
      }
    } catch (e) {
      Logger.error('Password reset error: $e');
      state = AuthenticationState.error('Failed to send password reset email');
    }
  }

  /// Clear error state
  void clearError() {
    if (state is AuthenticationStateError) {
      if (_authRepository.isAuthenticated) {
        state = AuthenticationState.authenticated(_authRepository.currentUser!);
      } else {
        state = const AuthenticationState.unauthenticated();
      }
    }
  }

  @override
  void dispose() {
    _sessionManager.dispose();
    super.dispose();
  }
}

/// Authentication state sealed class
sealed class AuthenticationState {
  const AuthenticationState();

  const factory AuthenticationState.initial() = AuthenticationStateInitial;
  const factory AuthenticationState.loading() = AuthenticationStateLoading;
  const factory AuthenticationState.authenticated(User user) = AuthenticationStateAuthenticated;
  const factory AuthenticationState.unauthenticated() = AuthenticationStateUnauthenticated;
  const factory AuthenticationState.emailVerificationRequired() = AuthenticationStateEmailVerificationRequired;
  const factory AuthenticationState.error(String message) = AuthenticationStateError;
}

class AuthenticationStateInitial extends AuthenticationState {
  const AuthenticationStateInitial();
}

class AuthenticationStateLoading extends AuthenticationState {
  const AuthenticationStateLoading();
}

class AuthenticationStateAuthenticated extends AuthenticationState {
  final User user;
  const AuthenticationStateAuthenticated(this.user);
}

class AuthenticationStateUnauthenticated extends AuthenticationState {
  const AuthenticationStateUnauthenticated();
}

class AuthenticationStateEmailVerificationRequired extends AuthenticationState {
  const AuthenticationStateEmailVerificationRequired();
}

class AuthenticationStateError extends AuthenticationState {
  final String message;
  const AuthenticationStateError(this.message);
}

/// Provider for the authentication notifier
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthenticationState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final sessionManager = ref.watch(sessionManagerProvider);
  return AuthNotifier(authRepository, sessionManager);
});

/// Convenience providers for specific authentication states
final isAuthenticatedStateProvider = Provider<bool>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState is AuthenticationStateAuthenticated;
});

final currentUserStateProvider = Provider<User?>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return switch (authState) {
    AuthenticationStateAuthenticated(user: final user) => user,
    _ => null,
  };
});

final authLoadingStateProvider = Provider<bool>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState is AuthenticationStateLoading;
});

final authErrorProvider = Provider<String?>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return switch (authState) {
    AuthenticationStateError(message: final message) => message,
    _ => null,
  };
});