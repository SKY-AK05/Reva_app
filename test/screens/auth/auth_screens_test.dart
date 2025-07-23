import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reva_mobile_app/screens/auth/auth_exports.dart';

void main() {
  group('Auth Screens', () {
    testWidgets('LoginScreen should build without error', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      
      expect(find.text('Welcome to Reva'), findsOneWidget);
      expect(find.text('Sign In'), findsAtLeastNWidgets(1));
      expect(find.byType(TextFormField), findsNWidgets(2)); // Email and password fields
    });

    testWidgets('SignUpScreen should build without error', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SignUpScreen(),
          ),
        ),
      );
      
      expect(find.text('Join Reva'), findsOneWidget);
      expect(find.text('Create Account'), findsAtLeastNWidgets(1));
      expect(find.byType(TextFormField), findsNWidgets(4)); // Name, email, password, confirm password fields
    });

    testWidgets('AuthLoadingScreen should build without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AuthLoadingScreen(message: 'Test loading'),
        ),
      );
      
      expect(find.text('Test loading'), findsOneWidget);
      expect(find.text('Please wait...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}