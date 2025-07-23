import 'package:flutter_test/flutter_test.dart';
import 'package:reva_mobile_app/services/auth/auth_repository.dart';

void main() {
  group('AuthResult', () {
    test('should create success result', () {
      final result = AuthResult.success(message: 'Success');
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.message, equals('Success'));
      expect(result.error, isNull);
    });

    test('should create failure result', () {
      final result = AuthResult.failure(error: 'Error occurred');
      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.error, equals('Error occurred'));
      expect(result.message, isNull);
    });

    test('should create success result with user', () {
      final result = AuthResult.success(message: 'Success');
      expect(result.isSuccess, isTrue);
      expect(result.message, equals('Success'));
    });
  });
}