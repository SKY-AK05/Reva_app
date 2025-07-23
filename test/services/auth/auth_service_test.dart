import 'package:flutter_test/flutter_test.dart';
import 'package:reva_mobile_app/services/auth/auth_service.dart';

void main() {
  group('RevaAuthException', () {
    test('should create exception with message', () {
      const exception = RevaAuthException('Test error');
      expect(exception.message, equals('Test error'));
      expect(exception.code, isNull);
    });

    test('should create exception with message and code', () {
      const exception = RevaAuthException('Test error', code: 'TEST_CODE');
      expect(exception.message, equals('Test error'));
      expect(exception.code, equals('TEST_CODE'));
    });

    test('should have proper toString implementation', () {
      const exception = RevaAuthException('Test error');
      expect(exception.toString(), equals('RevaAuthException: Test error'));
    });
  });
}