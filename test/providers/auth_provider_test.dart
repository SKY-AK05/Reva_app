import 'package:flutter_test/flutter_test.dart';
import 'package:reva_mobile_app/providers/auth_provider.dart';

void main() {
  group('AuthenticationState', () {
    test('should create initial state', () {
      const state = AuthenticationState.initial();
      expect(state, isA<AuthenticationStateInitial>());
    });

    test('should create loading state', () {
      const state = AuthenticationState.loading();
      expect(state, isA<AuthenticationStateLoading>());
    });

    test('should create unauthenticated state', () {
      const state = AuthenticationState.unauthenticated();
      expect(state, isA<AuthenticationStateUnauthenticated>());
    });

    test('should create email verification required state', () {
      const state = AuthenticationState.emailVerificationRequired();
      expect(state, isA<AuthenticationStateEmailVerificationRequired>());
    });

    test('should create error state', () {
      const state = AuthenticationState.error('Test error');
      expect(state, isA<AuthenticationStateError>());
      expect((state as AuthenticationStateError).message, equals('Test error'));
    });
  });
}