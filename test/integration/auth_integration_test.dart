import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:reva_mobile_app/services/auth/auth_service.dart';
import 'package:reva_mobile_app/services/auth/session_manager.dart';

// Generate mocks
@GenerateMocks([
  SupabaseClient,
  GoTrueClient,
  FlutterSecureStorage,
  User,
  Session,
])
import 'auth_integration_test.mocks.dart';

void main() {
  group('Authentication Integration Tests', () {
    late AuthService authService;
    late SessionManager sessionManager;
    late MockSupabaseClient mockSupabaseClient;
    late MockGoTrueClient mockGoTrueClient;
    late MockFlutterSecureStorage mockSecureStorage;
    late MockUser mockUser;
    late MockSession mockSession;

    setUp(() {
      mockSupabaseClient = MockSupabaseClient();
      mockGoTrueClient = MockGoTrueClient();
      mockSecureStorage = MockFlutterSecureStorage();
      mockUser = MockUser();
      mockSession = MockSession();

      // Setup basic mocks
      when(mockSupabaseClient.auth).thenReturn(mockGoTrueClient);
      when(mockGoTrueClient.currentUser).thenReturn(null);
      when(mockGoTrueClient.currentSession).thenReturn(null);
      when(mockGoTrueClient.onAuthStateChange).thenAnswer(
        (_) => Stream<AuthState>.empty(),
      );

      authService = AuthService();
      sessionManager = SessionManager(authService);
    });

    group('Complete Authentication Flow', () {
      test('should complete full sign-in flow with session management', () async {
        // Setup successful sign-in response
        when(mockSession.accessToken).thenReturn('access_token_123');
        when(mockSession.refreshToken).thenReturn('refresh_token_123');
        when(mockSession.expiresAt).thenReturn(
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
        );
        when(mockSession.isExpired).thenReturn(false);

        final authResponse = AuthResponse(
          user: mockUser,
          session: mockSession,
        );

        when(mockGoTrueClient.signInWithPassword(
          email: 'test@example.com',
          password: 'password123',
        )).thenAnswer((_) async => authResponse);

        // Mock secure storage operations
        when(mockSecureStorage.write(
          key: anyNamed('key'),
          value: anyNamed('value'),
        )).thenAnswer((_) async {});

        // Perform sign-in
        final result = await authService.signInWithEmailPassword(
          email: 'test@example.com',
          password: 'password123',
        );

        // Verify sign-in was successful
        expect(result.user, equals(mockUser));
        expect(result.session, equals(mockSession));

        // Verify session was stored
        verify(mockSecureStorage.write(
          key: 'supabase_session',
          value: 'access_token_123',
        )).called(1);

        verify(mockSecureStorage.write(
          key: 'refresh_token',
          value: 'refresh_token_123',
        )).called(1);
      });

      test('should handle session expiration and refresh', () async {
        // Setup expired session
        when(mockSession.accessToken).thenReturn('expired_token');
        when(mockSession.refreshToken).thenReturn('refresh_token_123');
        when(mockSession.isExpired).thenReturn(true);

        // Setup refresh response
        final newSession = MockSession();
        when(newSession.accessToken).thenReturn('new_access_token');
        when(newSession.refreshToken).thenReturn('new_refresh_token');
        when(newSession.isExpired).thenReturn(false);

        final refreshResponse = AuthResponse(
          user: mockUser,
          session: newSession,
        );

        when(mockGoTrueClient.refreshSession()).thenAnswer((_) async => refreshResponse);

        // Mock secure storage operations
        when(mockSecureStorage.write(
          key: anyNamed('key'),
          value: anyNamed('value'),
        )).thenAnswer((_) async {});

        // Perform session refresh
        final result = await authService.refreshSession();

        // Verify refresh was successful
        expect(result.session, equals(newSession));

        // Verify new session was stored
        verify(mockSecureStorage.write(
          key: 'supabase_session',
          value: 'new_access_token',
        )).called(1);

        verify(mockSecureStorage.write(
          key: 'refresh_token',
          value: 'new_refresh_token',
        )).called(1);
      });

      test('should handle complete sign-out flow', () async {
        // Setup initial authenticated state
        when(mockGoTrueClient.currentUser).thenReturn(mockUser);
        when(mockGoTrueClient.currentSession).thenReturn(mockSession);

        // Mock sign-out operation
        when(mockGoTrueClient.signOut()).thenAnswer((_) async {});

        // Mock secure storage cleanup
        when(mockSecureStorage.delete(key: anyNamed('key')))
            .thenAnswer((_) async {});

        // Perform sign-out
        await authService.signOut();

        // Verify sign-out was called
        verify(mockGoTrueClient.signOut()).called(1);

        // Verify session data was cleared
        verify(mockSecureStorage.delete(key: 'supabase_session')).called(1);
        verify(mockSecureStorage.delete(key: 'refresh_token')).called(1);
      });
    });

    group('Session Management Integration', () {
      test('should restore session on app startup', () async {
        // Mock stored session data
        when(mockSecureStorage.read(key: 'supabase_session'))
            .thenAnswer((_) async => 'stored_access_token');
        when(mockSecureStorage.read(key: 'refresh_token'))
            .thenAnswer((_) async => 'stored_refresh_token');

        // Mock session recovery
        when(mockGoTrueClient.recoverSession('stored_access_token'))
            .thenAnswer((_) async => AuthResponse(
              user: mockUser,
              session: mockSession,
            ));

        when(mockSession.isExpired).thenReturn(false);

        // Initialize auth service (simulates app startup)
        await authService.initialize();

        // Verify session recovery was attempted
        verify(mockGoTrueClient.recoverSession('stored_access_token')).called(1);
      });

      test('should handle corrupted session data gracefully', () async {
        // Mock corrupted session data
        when(mockSecureStorage.read(key: 'supabase_session'))
            .thenAnswer((_) async => 'corrupted_token');
        when(mockSecureStorage.read(key: 'refresh_token'))
            .thenAnswer((_) async => 'corrupted_refresh');

        // Mock session recovery failure
        when(mockGoTrueClient.recoverSession('corrupted_token'))
            .thenThrow(AuthException('Invalid session'));

        // Mock cleanup operations
        when(mockSecureStorage.delete(key: anyNamed('key')))
            .thenAnswer((_) async {});

        // Initialize auth service
        await authService.initialize();

        // Verify cleanup was performed
        verify(mockSecureStorage.delete(key: 'supabase_session')).called(1);
        verify(mockSecureStorage.delete(key: 'refresh_token')).called(1);
      });

      test('should manage session lifecycle with automatic refresh', () async {
        // Setup session manager
        when(mockSession.accessToken).thenReturn('access_token');
        when(mockSession.refreshToken).thenReturn('refresh_token');
        when(mockSession.expiresAt).thenReturn(
          DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch ~/ 1000,
        );

        // Mock session refresh
        final newSession = MockSession();
        when(newSession.accessToken).thenReturn('new_access_token');
        when(newSession.refreshToken).thenReturn('new_refresh_token');
        when(newSession.expiresAt).thenReturn(
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
        );

        when(mockGoTrueClient.refreshSession()).thenAnswer((_) async => AuthResponse(
          user: mockUser,
          session: newSession,
        ));

        when(mockSecureStorage.write(
          key: anyNamed('key'),
          value: anyNamed('value'),
        )).thenAnswer((_) async {});

        // Test session refresh logic
        final shouldRefresh = await sessionManager.shouldRefreshSession(mockSession);
        expect(shouldRefresh, isTrue);

        // Perform refresh
        await sessionManager.refreshIfNeeded(mockSession);

        // Verify refresh was called
        verify(mockGoTrueClient.refreshSession()).called(1);
      });
    });

    group('Authentication Error Handling', () {
      test('should handle network errors during authentication', () async {
        // Mock network error
        when(mockGoTrueClient.signInWithPassword(
          email: 'test@example.com',
          password: 'password123',
        )).thenThrow(Exception('Network error'));

        // Attempt sign-in
        expect(
          () => authService.signInWithEmailPassword(
            email: 'test@example.com',
            password: 'password123',
          ),
          throwsA(isA<RevaAuthException>()),
        );
      });

      test('should handle invalid credentials gracefully', () async {
        // Mock invalid credentials error
        when(mockGoTrueClient.signInWithPassword(
          email: 'test@example.com',
          password: 'wrongpassword',
        )).thenThrow(AuthException('Invalid login credentials'));

        // Attempt sign-in
        try {
          await authService.signInWithEmailPassword(
            email: 'test@example.com',
            password: 'wrongpassword',
          );
          fail('Expected RevaAuthException');
        } catch (e) {
          expect(e, isA<RevaAuthException>());
          expect((e as RevaAuthException).message, contains('Invalid email or password'));
        }
      });

      test('should handle session refresh failures', () async {
        // Mock refresh failure
        when(mockGoTrueClient.refreshSession())
            .thenThrow(AuthException('Refresh token expired'));

        // Attempt refresh
        expect(
          () => authService.refreshSession(),
          throwsA(isA<RevaAuthException>()),
        );
      });
    });

    group('OAuth Integration', () {
      test('should handle Google OAuth flow', () async {
        // Mock OAuth initiation
        when(mockGoTrueClient.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'io.supabase.revaapp://login-callback/',
        )).thenAnswer((_) async => true);

        // Initiate OAuth
        final result = await authService.signInWithGoogle();

        expect(result, isTrue);
        verify(mockGoTrueClient.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'io.supabase.revaapp://login-callback/',
        )).called(1);
      });

      test('should handle OAuth callback processing', () async {
        // This would typically be handled by the platform-specific OAuth flow
        // For testing, we simulate the callback processing
        
        // Mock successful OAuth completion
        when(mockGoTrueClient.currentUser).thenReturn(mockUser);
        when(mockGoTrueClient.currentSession).thenReturn(mockSession);

        // Verify OAuth completion
        expect(authService.isAuthenticated, isTrue);
        expect(authService.currentUser, equals(mockUser));
      });
    });

    group('Password Management Integration', () {
      test('should handle password reset flow', () async {
        // Mock password reset
        when(mockGoTrueClient.resetPasswordForEmail(
          'test@example.com',
          redirectTo: 'io.supabase.revaapp://reset-password/',
        )).thenAnswer((_) async {});

        // Send password reset
        await authService.resetPassword('test@example.com');

        verify(mockGoTrueClient.resetPasswordForEmail(
          'test@example.com',
          redirectTo: 'io.supabase.revaapp://reset-password/',
        )).called(1);
      });

      test('should handle password update', () async {
        // Setup authenticated user
        when(mockGoTrueClient.currentUser).thenReturn(mockUser);

        // Mock password update
        when(mockGoTrueClient.updateUser(any))
            .thenAnswer((_) async => UserResponse(user: mockUser));

        // Update password
        final result = await authService.updatePassword('newpassword123');

        expect(result.user, equals(mockUser));
        verify(mockGoTrueClient.updateUser(any)).called(1);
      });
    });

    group('Authentication State Management', () {
      test('should handle auth state changes', () async {
        final authStateController = StreamController<AuthState>();
        
        when(mockGoTrueClient.onAuthStateChange)
            .thenAnswer((_) => authStateController.stream);

        // Create a new auth service to test the listener
        final testAuthService = AuthService();
        
        // Listen to auth state changes
        final authStates = <AuthState>[];
        testAuthService.authStateChanges.listen(authStates.add);

        // Emit sign-in state
        final signInState = AuthState(AuthChangeEvent.signedIn, mockSession);
        authStateController.add(signInState);

        // Emit sign-out state
        final signOutState = AuthState(AuthChangeEvent.signedOut, null);
        authStateController.add(signOutState);

        await Future.delayed(const Duration(milliseconds: 10));

        expect(authStates, hasLength(2));
        expect(authStates[0].event, equals(AuthChangeEvent.signedIn));
        expect(authStates[1].event, equals(AuthChangeEvent.signedOut));

        authStateController.close();
        testAuthService.dispose();
      });

      test('should handle token refresh state changes', () async {
        final authStateController = StreamController<AuthState>();
        
        when(mockGoTrueClient.onAuthStateChange)
            .thenAnswer((_) => authStateController.stream);

        // Mock secure storage for token refresh
        when(mockSecureStorage.write(
          key: anyNamed('key'),
          value: anyNamed('value'),
        )).thenAnswer((_) async {});

        when(mockSession.accessToken).thenReturn('new_access_token');
        when(mockSession.refreshToken).thenReturn('new_refresh_token');

        final testAuthService = AuthService();

        // Emit token refresh state
        final refreshState = AuthState(AuthChangeEvent.tokenRefreshed, mockSession);
        authStateController.add(refreshState);

        await Future.delayed(const Duration(milliseconds: 10));

        // Verify token storage was called
        verify(mockSecureStorage.write(
          key: 'supabase_session',
          value: 'new_access_token',
        )).called(1);

        authStateController.close();
        testAuthService.dispose();
      });
    });

    group('Concurrent Authentication Operations', () {
      test('should handle concurrent sign-in attempts', () async {
        // Mock successful sign-in
        final authResponse = AuthResponse(user: mockUser, session: mockSession);
        when(mockGoTrueClient.signInWithPassword(
          email: 'test@example.com',
          password: 'password123',
        )).thenAnswer((_) async => authResponse);

        when(mockSecureStorage.write(
          key: anyNamed('key'),
          value: anyNamed('value'),
        )).thenAnswer((_) async {});

        when(mockSession.accessToken).thenReturn('access_token');
        when(mockSession.refreshToken).thenReturn('refresh_token');

        // Perform concurrent sign-ins
        final futures = List.generate(3, (_) => authService.signInWithEmailPassword(
          email: 'test@example.com',
          password: 'password123',
        ));

        final results = await Future.wait(futures);

        // All should succeed
        for (final result in results) {
          expect(result.user, equals(mockUser));
          expect(result.session, equals(mockSession));
        }
      });

      test('should handle concurrent session refresh attempts', () async {
        // Mock successful refresh
        final refreshResponse = AuthResponse(user: mockUser, session: mockSession);
        when(mockGoTrueClient.refreshSession()).thenAnswer((_) async => refreshResponse);

        when(mockSecureStorage.write(
          key: anyNamed('key'),
          value: anyNamed('value'),
        )).thenAnswer((_) async {});

        when(mockSession.accessToken).thenReturn('new_access_token');
        when(mockSession.refreshToken).thenReturn('new_refresh_token');

        // Perform concurrent refreshes
        final futures = List.generate(3, (_) => authService.refreshSession());

        final results = await Future.wait(futures);

        // All should succeed
        for (final result in results) {
          expect(result.session, equals(mockSession));
        }
      });
    });
  });
}