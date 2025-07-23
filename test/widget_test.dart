// This is a basic Flutter widget test for the Reva app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reva_mobile_app/main.dart';

void main() {
  testWidgets('Reva app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: RevaApp(),
      ),
    );

    // Verify that our app loads with the welcome message.
    expect(find.text('Welcome to Reva'), findsOneWidget);
    expect(find.text('AI-powered productivity assistant'), findsOneWidget);

    // Verify that the theme toggle button is present.
    expect(find.byIcon(Icons.dark_mode), findsOneWidget);
  });
}
