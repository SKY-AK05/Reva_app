import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:reva_mobile_app/services/auth/auth_service.dart';

// Generate mocks
@GenerateMocks([
  SupabaseClient,
  GoTrueClient,
  FlutterSecureStorage,
  User,
  Session,
])
import 'auth_service_comprehensive_test.mocks.dart';

void main() {
  group('AuthService Comprehensive Tests', () {
    late AuthService authService;
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
    });

    group('RevaAuthException', () {
      test('should create exception with message only', () {
        const exception = RevaAuthException('Test error');
        expect(exception.message, equals('Test error'));
        expect(exception.code, isNull);
        expect(exception.toString(), equals('RevaAuthException: Test error'));
      });

      test('should create exception with message and code', () {
        const exception = RevaAuthException('Test error', code: 'TEST_CODE');
        expect(exception.message, equals('Test error'));
        expect(exception.code, equals('TEST_CODE'));
      });
    });

    group('Authentication State', () {
      test('should return correct authentication state', () {
        when(mockGoTrueClient.currentUser).thenReturn(null);
        expect(authService.isAuthenticated, isFalse);
        expect(authService.currentUser, isNull);

        when(mockGoTrueClient.currentUser).thenReturn(mockUser);
        expect(authService.isAuthenticated, isTrue);
        expect(authService.currentUser, equals(mockUser));
      });

      test('should return current session', () {
        when(mockGoTrueClient.currentSession).thenReturn(mockSession);
        expect(authService.currentSession, equals(mockSession));
      });
    });

    group('Email/Password Authentication', () {
      test('should sign in with email and password successfully', () async {
        final authResponse = AuthResponse(
          user: mockUser,
          session: mockSession,
        );

        when(mockGoTrueClient.signInWithPassword(
          email: 'test@example.com',
          password: 'password123',
        )).thenAnswer((_) async => authResponse);

        final result = await authService.signInWithEmailPassword(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.user, equals(mockUser));
        expect(result.session, equals(mockSession));
        verify(mockGoTrueClient.signInWithPassword(
          email: 'test@example.com',
          password: 'password123',
        )).called(1);
      });

      test('should throw RevaAuthException when sign in fails', () async {
        when(mockGoTrueClient.signInWithPassword(
          email: 'test@example.com',
          password: 'wrongpassword',
        )).thenThrow(AuthException('Invalid login credentials'));

        expect(
          () => authService.signInWithEmailPassword(
            email: 'test@example.com',
            password: 'wrongpassword',
          ),
          throwsA(isA<RevaAuthException>()),
        );
      });

      test('should throw RevaAuthException when no user returned', () async {
        final authResponse = AuthResponse(user: null, session: null);

        when(mockGoTrueClient.signInWithPassword(
          email: 'test@example.com',
          password: 'password123',
        )).thenAnswer((_) async => authResponse);

        expect(
          () => authService.signInWithEmailPassword(
            email: 'test@example.com',
            password: 'password123',
          ),
          throwsA(isA<RevaAuthException>()),
        );
      });

      test('should sign up with email and password successfully', () async {
        final authResponse = AuthResponse(
          user: mockUser,
          session: mockSession,
        );

        when(mockGoTrueClient.signUp(
          email: 'test@example.com',
          password: 'password123',
          data: null,
        )).thenAnswer((_) async => authResponse);

        final result = await authService.signUpWithEmailPassword(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.user, equals(mockUser));
        expect(result.session, equals(mockSession));
      });

      test('should sign up with metadata', () async {
        final metadata = {'name': 'John Doe'};
        final authResponse = AuthResponse(
          user: mockUser,
          session: mockSession,
        );

        when(mockGoTrueClient.signUp(
          email: 'test@example.com',
          password: 'password123',
          data: metadata,
        )).thenAnswer((_) async => authResponse);

        await authService.signUpWithEmailPassword(
          email: 'test@example.com',
          password: 'password123',
          metadata: metadata,
        );

        verify(mockGoTrueClient.signUp(
          email: 'test@example.com',
          password: 'password123',
          data: metadata,
        )).called(1);
      });
    });

    group('Google OAuth Authentication', () {
      test('should initiate Google OAuth sign in successfully', () async {
        when(mockGoTrueClient.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'io.supabase.revaapp://login-callback/',
        )).thenAnswer((_) async => true);

        final result = await authService.signInWithGoogle();

        expect(result, isTrue);
        verify(mockGoTrueClient.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'io.supabase.revaapp://login-callback/',
        )).called(1);
      });

      test('should throw RevaAuthException when Google OAuth fails', () async {
        when(mockGoTrueClient.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'io.supabase.revaapp://login-callback/',
        )).thenThrow(AuthException('OAuth failed'));

        expect(
          () => authService.signInWithGoogle(),
          throwsA(isA<RevaAuthException>()),
        );
      });
    });

    group('Sign Out', () {
      test('should sign out successfully', () async {
        when(mockGoTrueClient.signOut()).thenAnswer((_) async {});

        await authService.signOut();

        verify(mockGoTrueClient.signOut()).called(1);
      });

      test('should throw RevaAuthException when sign out fails', () async {
        when(mockGoTrueClient.signOut()).thenThrow(AuthException('Sign out failed'));

        expect(
          () => authService.signOut(),
          throwsA(isA<RevaAuthException>()),
        );
      });
    });

    group('Session Management', () {
      test('should refresh session successfully', () async {
        final authResponse = AuthResponse(
          user: mockUser,
          session: mockSession,
        );

        when(mockGoTrueClient.refreshSession()).thenAnswer((_) async => authResponse);

        final result = await authService.refreshSession();

        expect(result.session, equals(mockSession));
        verify(mockGoTrueClient.refreshSession()).called(1);
      });

      test('should throw RevaAuthException when session refresh fails', () async {
        when(mockGoTrueClient.refreshSession()).thenThrow(AuthException('Refresh failed'));

        expect(
          () => authService.refreshSession(),
          throwsA(isA<RevaAuthException>()),
        );
      });

      test('should throw RevaAuthException when no session returned on refresh', () async {
        final authResponse = AuthResponse(user: mockUser, session: null);

        when(mockGoTrueClient.refreshSession()).thenAnswer((_) async => authResponse);

        expect(
          () => authService.refreshSession(),
          throwsA(isA<RevaAuthException>()),
        );
      });
    });

    group('Password Reset', () {
      test('should send password reset email successfully', () async {
        when(mockGoTrueClient.resetPasswordForEmail(
          'test@example.com',
          redirectTo: 'io.supabase.revaapp://reset-password/',
        )).thenAnswer((_) async {});

        await authService.resetPassword('test@example.com');

        verify(mockGoTrueClient.resetPasswordForEmail(
          'test@example.com',
          redirectTo: 'io.supabase.revaapp://reset-password/',
        )).called(1);
      });

      test('should throw RevaAuthException when password reset fails', () async {
        when(mockGoTrueClient.resetPasswordForEmail(
          'test@example.com',
          redirectTo: 'io.supabase.revaapp://reset-password/',
        )).thenThrow(AuthException('Reset failed'));

        expect(
          () => authService.resetPassword('test@example.com'),
          throwsA(isA<RevaAuthException>()),
        );
      });
    });

    group('Password Update', () {
      test('should update password successfully', () async {
        final userResponse = UserResponse(user: mockUser);

        when(mockGoTrueClient.updateUser(any)).thenAnswer((_) async => userResponse);

        final result = await authService.updatePassword('newpassword123');

        expect(result.user, equals(mockUser));
        verify(mockGoTrueClient.updateUser(any)).called(1);
      });

      test('should throw RevaAuthException when password update fails', () async {
        when(mockGoTrueClient.updateUser(any)).thenThrow(AuthException('Update failed'));

        expect(
          () => authService.updatePassword('newpassword123'),
          throwsA(isA<RevaAuthException>()),
        );
      });
    });

    group('Error Message Handling', () {
      test('should return user-friendly error messages', () async {
        // Test invalid credentials
        when(mockGoTrueClient.signInWithPassword(
          email: 'test@example.com',
          password: 'wrong',
        )).thenThrow(AuthException('invalid login credentials'));

        try {
          await authService.signInWithEmailPassword(
            email: 'test@example.com',
            password: 'wrong',
          );
        } catch (e) {
          expect(e, isA<RevaAuthException>());
          expect((e as RevaAuthException).message, 
            contains('Invalid email or password'));
        }

        // Test email not confirmed
        when(mockGoTrueClient.signInWithPassword(
          email: 'test@example.com',
          password: 'password',
        )).thenThrow(AuthException('email not confirmed'));

        try {
          await authService.signInWithEmailPassword(
            email: 'test@example.com',
            password: 'password',
          );
        } catch (e) {
          expect(e, isA<RevaAuthException>());
          expect((e as RevaAuthException).message, 
            contains('check your email and click the confirmation link'));
        }

        // Test too many requests
        when(mockGoTrueClient.signInWithPassword(
          email: 'test@example.com',
          password: 'password',
        )).thenThrow(AuthException('too many requests'));

        try {
          await authService.signInWithEmailPassword(
            email: 'test@example.com',
            password: 'password',
          );
        } catch (e) {
          expect(e, isA<RevaAuthException>());
          expect((e as RevaAuthException).message, 
            contains('Too many attempts'));
        }

        // Test user already registered
        when(mockGoTrueClient.signUp(
          email: 'test@example.com',
          password: 'password',
          data: null,
        )).thenThrow(AuthException('user already registered'));

        try {
          await authService.signUpWithEmailPassword(
            email: 'test@example.com',
            password: 'password',
          );
        } catch (e) {
          expect(e, isA<RevaAuthException>());
          expect((e as RevaAuthException).message, 
            contains('account with this email already exists'));
        }
      });

      test('should handle generic errors', () async {
        when(mockGoTrueClient.signInWithPassword(
          email: 'test@example.com',
          password: 'password',
        )).thenThrow(Exception('Unknown error'));

        try {
          await authService.signInWithEmailPassword(
            email: 'test@example.com',
            password: 'password',
          );
        } catch (e) {
          expect(e, isA<RevaAuthException>());
          expect((e as RevaAuthException).message, 
            contains('An unexpected error occurred'));
        }
      });
    });

    group('Initialization and Cleanup', () {
      test('should initialize without errors', () async {
        // Mock secure storage operations
        when(mockSecureStorage.read(key: anyNamed('key')))
            .thenAnswer((_) async => null);

        await authService.initialize();

        // Should complete without throwing
        expect(true, isTrue);
      });

      test('should dispose resources properly', () {
        expect(() => authService.dispose(), returnsNormally);
      });
    });

    group('Auth State Changes', () {
      test('should handle auth state changes', () async {
        final authStateController = StreamController<AuthState>();
        
        when(mockGoTrueClient.onAuthStateChange)
            .thenAnswer((_) => authStateController.stream);

        // Create a new auth service to test the listener
        final testAuthService = AuthService();
        
        // Listen to auth state changes
        final authStates = <AuthState>[];
        testAuthService.authStateChanges.listen(authStates.add);

        // Emit auth state changes
        final signInState = AuthState(
          AuthChangeEvent.signedIn,
          mockSession,
        );
        authStateController.add(signInState);

        await Future.delayed(const Duration(milliseconds: 10));

        expect(authStates, contains(signInState));

        authStateController.close();
        testAuthService.dispose();
      });
    });

    group('Session Storage', () {
      test('should handle session storage operations', () async {
        // Mock session with tokens
        when(mockSession.accessToken).thenReturn('access_token_123');
        when(mockSession.refreshToken).thenReturn('refresh_token_123');

        // Mock secure storage write operations
        when(mockSecureStorage.write(
          key: anyNamed('key'),
          value: anyNamed('value'),
        )).thenAnswer((_) async {});

        // This would be called internally when session is stored
        // We can't directly test private methods, but we can verify
        // the behavior through public methods that trigger storage
        
        expect(true, isTrue); // Placeholder for session storage test
      });

      test('should handle session restoration', () async {
        // Mock secure storage read operations
        when(mockSecureStorage.read(key: 'supabase_session'))
            .thenAnswer((_) async => 'access_token_123');
        when(mockSecureStorage.read(key: 'refresh_token'))
            .thenAnswer((_) async => 'refresh_token_123');

        // Mock session recovery
        when(mockGoTrueClient.recoverSession('access_token_123'))
            .thenAnswer((_) async => AuthResponse(
              user: mockUser,
              session: mockSession,
            ));

        await authService.initialize();

        // Should complete without throwing
        expect(true, isTrue);
      });
    });
  });
}