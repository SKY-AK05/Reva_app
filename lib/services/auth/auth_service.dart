import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../utils/logger.dart';

/// Exception thrown when authentication operations fail
class RevaAuthException implements Exception {
  final String message;
  final String? code;
  
  const RevaAuthException(this.message, {this.code});
  
  @override
  String toString() => 'RevaAuthException: $message';
}

/// Service responsible for handling all authentication operations
class AuthService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  
  static const String _sessionKey = 'supabase_session';
  static const String _refreshTokenKey = 'refresh_token';
  
  final SupabaseClient _supabase = SupabaseConfig.client;
  final StreamController<AuthState> _authStateController = StreamController<AuthState>.broadcast();
  
  /// Stream of authentication state changes
  Stream<AuthState> get authStateChanges => _authStateController.stream;
  
  /// Current authenticated user
  User? get currentUser => _supabase.auth.currentUser;
  
  /// Current session
  Session? get currentSession => _supabase.auth.currentSession;
  
  /// Whether user is currently authenticated
  bool get isAuthenticated => currentUser != null;

  AuthService() {
    _initializeAuthListener();
  }

  /// Initialize authentication state listener
  void _initializeAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      
      Logger.info('Auth state changed: $event');
      
      switch (event) {
        case AuthChangeEvent.signedIn:
          if (session != null) {
            _storeSession(session);
          }
          break;
        case AuthChangeEvent.signedOut:
          _clearStoredSession();
          break;
        case AuthChangeEvent.tokenRefreshed:
          if (session != null) {
            _storeSession(session);
          }
          break;
        default:
          break;
      }
      
      _authStateController.add(data);
    });
  }

  /// Initialize the service and attempt to restore previous session
  Future<void> initialize() async {
    try {
      await _restoreSession();
    } catch (e) {
      Logger.error('Failed to restore session: $e');
      // Clear potentially corrupted session data
      await _clearStoredSession();
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      Logger.info('Attempting email/password sign in for: $email');
      
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user == null) {
        throw const RevaAuthException('Sign in failed: No user returned');
      }
      
      Logger.info('Email/password sign in successful');
      return response;
    } on RevaAuthException {
      rethrow;
    } catch (e) {
      Logger.error('Email/password sign in failed: $e');
      throw RevaAuthException(_getErrorMessage(e));
    }
  }

  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      Logger.info('Attempting email/password sign up for: $email');
      
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );
      
      Logger.info('Email/password sign up successful');
      return response;
    } catch (e) {
      Logger.error('Email/password sign up failed: $e');
      throw RevaAuthException(_getErrorMessage(e));
    }
  }

  /// Sign in with Google OAuth
  Future<bool> signInWithGoogle() async {
    try {
      Logger.info('Attempting Google OAuth sign in');
      
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.revaapp://login-callback/',
      );
      
      Logger.info('Google OAuth sign in initiated');
      return response;
    } catch (e) {
      Logger.error('Google OAuth sign in failed: $e');
      throw RevaAuthException(_getErrorMessage(e));
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      Logger.info('Attempting sign out');
      
      await _supabase.auth.signOut();
      await _clearStoredSession();
      
      Logger.info('Sign out successful');
    } catch (e) {
      Logger.error('Sign out failed: $e');
      throw RevaAuthException(_getErrorMessage(e));
    }
  }

  /// Refresh the current session
  Future<AuthResponse> refreshSession() async {
    try {
      Logger.info('Attempting session refresh');
      
      final response = await _supabase.auth.refreshSession();
      
      if (response.session == null) {
        throw const RevaAuthException('Session refresh failed: No session returned');
      }
      
      Logger.info('Session refresh successful');
      return response;
    } catch (e) {
      Logger.error('Session refresh failed: $e');
      throw RevaAuthException(_getErrorMessage(e));
    }
  }

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    try {
      Logger.info('Sending password reset email to: $email');
      
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.revaapp://reset-password/',
      );
      
      Logger.info('Password reset email sent');
    } catch (e) {
      Logger.error('Password reset failed: $e');
      throw RevaAuthException(_getErrorMessage(e));
    }
  }

  /// Update user password
  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      Logger.info('Attempting password update');
      
      final response = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      
      Logger.info('Password update successful');
      return response;
    } catch (e) {
      Logger.error('Password update failed: $e');
      throw RevaAuthException(_getErrorMessage(e));
    }
  }

  /// Store session securely
  Future<void> _storeSession(Session session) async {
    try {
      // Store the access token and refresh token separately
      await _storage.write(
        key: _sessionKey,
        value: session.accessToken,
      );
      await _storage.write(
        key: _refreshTokenKey,
        value: session.refreshToken ?? '',
      );
      Logger.info('Session stored securely');
    } catch (e) {
      Logger.error('Failed to store session: $e');
    }
  }

  /// Restore session from secure storage
  Future<void> _restoreSession() async {
    try {
      final accessToken = await _storage.read(key: _sessionKey);
      final refreshToken = await _storage.read(key: _refreshTokenKey);
      
      if (accessToken != null && refreshToken != null) {
        Logger.info('Attempting to restore session');
        
        // Try to restore the session using stored tokens
        await _supabase.auth.recoverSession(accessToken);
        
        // Verify session is still valid
        if (currentSession?.isExpired == true) {
          Logger.info('Stored session expired, attempting refresh');
          await refreshSession();
        }
        
        Logger.info('Session restored successfully');
      }
    } catch (e) {
      Logger.error('Failed to restore session: $e');
      throw e;
    }
  }

  /// Clear stored session data
  Future<void> _clearStoredSession() async {
    try {
      await _storage.delete(key: _sessionKey);
      await _storage.delete(key: _refreshTokenKey);
      Logger.info('Stored session cleared');
    } catch (e) {
      Logger.error('Failed to clear stored session: $e');
    }
  }

  /// Get user-friendly error message
  String _getErrorMessage(dynamic error) {
    if (error is RevaAuthException) {
      return error.message;
    }
    
    if (error is AuthException) {
      return error.message;
    }
    
    if (error is PostgrestException) {
      return error.message;
    }
    
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('invalid login credentials')) {
      return 'Invalid email or password. Please check your credentials and try again.';
    }
    
    if (errorString.contains('email not confirmed')) {
      return 'Please check your email and click the confirmation link before signing in.';
    }
    
    if (errorString.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment before trying again.';
    }
    
    if (errorString.contains('network')) {
      return 'Network error. Please check your internet connection and try again.';
    }
    
    if (errorString.contains('user already registered')) {
      return 'An account with this email already exists. Please sign in instead.';
    }
    
    return 'An unexpected error occurred. Please try again.';
  }

  /// Dispose of resources
  void dispose() {
    _authStateController.close();
  }
}