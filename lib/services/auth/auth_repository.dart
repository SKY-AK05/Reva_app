import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart' show AuthService, RevaAuthException;
import '../../utils/logger.dart';

/// Repository that provides a clean interface for authentication operations
class AuthRepository {
  final AuthService _authService;
  
  AuthRepository(this._authService);
  
  /// Stream of authentication state changes
  Stream<AuthState> get authStateChanges => _authService.authStateChanges;
  
  /// Current authenticated user
  User? get currentUser => _authService.currentUser;
  
  /// Whether user is currently authenticated
  bool get isAuthenticated => _authService.isAuthenticated;
  
  /// Initialize the repository
  Future<void> initialize() async {
    await _authService.initialize();
  }
  
  /// Sign in with email and password
  Future<AuthResult> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );
      
      return AuthResult.success(user: response.user);
    } on RevaAuthException catch (e) {
      Logger.error('Auth repository sign in failed: ${e.message}');
      return AuthResult.failure(error: e.message);
    } catch (e) {
      Logger.error('Unexpected auth repository error: $e');
      return AuthResult.failure(error: 'An unexpected error occurred');
    }
  }
  
  /// Sign up with email and password
  Future<AuthResult> signUpWithEmailPassword({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final metadata = fullName != null ? {'full_name': fullName} : null;
      
      final response = await _authService.signUpWithEmailPassword(
        email: email,
        password: password,
        metadata: metadata,
      );
      
      return AuthResult.success(user: response.user);
    } on RevaAuthException catch (e) {
      Logger.error('Auth repository sign up failed: ${e.message}');
      return AuthResult.failure(error: e.message);
    } catch (e) {
      Logger.error('Unexpected auth repository error: $e');
      return AuthResult.failure(error: 'An unexpected error occurred');
    }
  }
  
  /// Sign in with Google OAuth
  Future<AuthResult> signInWithGoogle() async {
    try {
      final success = await _authService.signInWithGoogle();
      
      if (success) {
        return AuthResult.success(message: 'Google sign-in initiated');
      } else {
        return AuthResult.failure(error: 'Failed to initiate Google sign-in');
      }
    } on RevaAuthException catch (e) {
      Logger.error('Auth repository Google sign in failed: ${e.message}');
      return AuthResult.failure(error: e.message);
    } catch (e) {
      Logger.error('Unexpected auth repository error: $e');
      return AuthResult.failure(error: 'An unexpected error occurred');
    }
  }
  
  /// Sign out the current user
  Future<AuthResult> signOut() async {
    try {
      await _authService.signOut();
      return AuthResult.success(message: 'Successfully signed out');
    } on RevaAuthException catch (e) {
      Logger.error('Auth repository sign out failed: ${e.message}');
      return AuthResult.failure(error: e.message);
    } catch (e) {
      Logger.error('Unexpected auth repository error: $e');
      return AuthResult.failure(error: 'An unexpected error occurred');
    }
  }
  
  /// Send password reset email
  Future<AuthResult> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
      return AuthResult.success(message: 'Password reset email sent');
    } on RevaAuthException catch (e) {
      Logger.error('Auth repository password reset failed: ${e.message}');
      return AuthResult.failure(error: e.message);
    } catch (e) {
      Logger.error('Unexpected auth repository error: $e');
      return AuthResult.failure(error: 'An unexpected error occurred');
    }
  }
  
  /// Update user password
  Future<AuthResult> updatePassword(String newPassword) async {
    try {
      final response = await _authService.updatePassword(newPassword);
      return AuthResult.success(user: response.user);
    } on RevaAuthException catch (e) {
      Logger.error('Auth repository password update failed: ${e.message}');
      return AuthResult.failure(error: e.message);
    } catch (e) {
      Logger.error('Unexpected auth repository error: $e');
      return AuthResult.failure(error: 'An unexpected error occurred');
    }
  }
  
  /// Refresh the current session
  Future<AuthResult> refreshSession() async {
    try {
      final response = await _authService.refreshSession();
      return AuthResult.success(user: response.user);
    } on RevaAuthException catch (e) {
      Logger.error('Auth repository session refresh failed: ${e.message}');
      return AuthResult.failure(error: e.message);
    } catch (e) {
      Logger.error('Unexpected auth repository error: $e');
      return AuthResult.failure(error: 'An unexpected error occurred');
    }
  }
}

/// Result wrapper for authentication operations
class AuthResult {
  final bool isSuccess;
  final String? error;
  final String? message;
  final User? user;
  
  const AuthResult._({
    required this.isSuccess,
    this.error,
    this.message,
    this.user,
  });
  
  factory AuthResult.success({String? message, User? user}) {
    return AuthResult._(
      isSuccess: true,
      message: message,
      user: user,
    );
  }
  
  factory AuthResult.failure({required String error}) {
    return AuthResult._(
      isSuccess: false,
      error: error,
    );
  }
  
  bool get isFailure => !isSuccess;
}