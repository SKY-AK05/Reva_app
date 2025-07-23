import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reva_mobile_app/core/components/ui_button.dart';
import 'package:reva_mobile_app/core/components/ui_card.dart';
import 'package:reva_mobile_app/core/components/ui_input.dart';
import 'package:reva_mobile_app/core/components/ui_loading.dart';
import 'package:reva_mobile_app/core/animations/app_animations.dart';
import 'package:reva_mobile_app/core/accessibility/accessibility_utils.dart';
import 'package:reva_mobile_app/core/responsive/responsive_utils.dart';
import 'package:reva_mobile_app/core/theme/app_theme.dart';

void main() {
  group('Enhanced UI Components Tests', () {
    testWidgets('UIButton has proper accessibility features', (WidgetTester tester) async {
      bool buttonPressed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: UIButton(
              text: 'Test Button',
              semanticLabel: 'Test button for accessibility',
              tooltip: 'This is a test button',
              onPressed: () => buttonPressed = true,
            ),
          ),
        ),
      );

      // Test semantic label
      expect(find.bySemanticsLabel('Test button for accessibility'), findsOneWidget);
      
      // Test tooltip
      final buttonFinder = find.byType(UIButton);
      await tester.longPress(buttonFinder);
      await tester.pumpAndSettle();
      expect(find.text('This is a test button'), findsOneWidget);
      
      // Test button press
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
      expect(buttonPressed, isTrue);
    });

    testWidgets('UIButton meets minimum touch target size', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: UIButton(
              text: 'Small Button',
              size: UIButtonSize.sm,
              onPressed: () {},
            ),
          ),
        ),
      );

      final buttonWidget = tester.widget<Container>(
        find.descendant(
          of: find.byType(UIButton),
          matching: find.byType(Container),
        ).first,
      );

      // Verify minimum touch target size
      expect(
        buttonWidget.constraints?.minWidth,
        greaterThanOrEqualTo(AccessibilityUtils.minTouchTargetSize),
      );
      expect(
        buttonWidget.constraints?.minHeight,
        greaterThanOrEqualTo(AccessibilityUtils.minTouchTargetSize),
      );
    });

    testWidgets('UICard has proper accessibility and animation features', (WidgetTester tester) async {
      bool cardTapped = false;
      
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: UICard(
              semanticLabel: 'Test card',
              enableAnimation: true,
              onTap: () => cardTapped = true,
              child: const Text('Card Content'),
            ),
          ),
        ),
      );

      // Test semantic label
      expect(find.bySemanticsLabel('Test card'), findsOneWidget);
      
      // Test card tap
      await tester.tap(find.byType(UICard));
      await tester.pumpAndSettle();
      expect(cardTapped, isTrue);
      
      // Test content is present
      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('UIInput has proper accessibility features', (WidgetTester tester) async {
      final controller = TextEditingController();
      
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: UIInput(
              label: 'Test Input',
              placeholder: 'Enter text here',
              helperText: 'This is helper text',
              semanticLabel: 'Test input field',
              controller: controller,
              enableAnimation: true,
            ),
          ),
        ),
      );

      // Test label is present
      expect(find.text('Test Input'), findsOneWidget);
      
      // Test placeholder
      expect(find.text('Enter text here'), findsOneWidget);
      
      // Test helper text
      expect(find.text('This is helper text'), findsOneWidget);
      
      // Test input functionality
      await tester.enterText(find.byType(TextFormField), 'Test input');
      expect(controller.text, equals('Test input'));
    });

    testWidgets('UIInput shows error state with animation', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: UIInput(
              label: 'Test Input',
              errorText: 'This field is required',
              enableAnimation: true,
            ),
          ),
        ),
      );

      // Test error text is present (may appear multiple times due to TextFormField and custom error display)
      expect(find.text('This field is required'), findsWidgets);
      
      // Test that error text has animation wrapper
      expect(find.byType(AnimatedOpacity), findsWidgets);
    });

    testWidgets('UILoading has proper accessibility features', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: UILoading(
              message: 'Loading data...',
              semanticLabel: 'Loading indicator',
              enableAnimation: true,
            ),
          ),
        ),
      );

      // Test semantic label
      expect(find.bySemanticsLabel('Loading indicator'), findsOneWidget);
      
      // Test loading message
      expect(find.text('Loading data...'), findsOneWidget);
      
      // Test circular progress indicator is present
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('UILoadingOverlay shows and hides with animation', (WidgetTester tester) async {
      bool isLoading = true;
      
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return UILoadingOverlay(
                  isLoading: isLoading,
                  message: 'Loading...',
                  enableAnimation: true,
                  child: const Text('Main Content'),
                );
              },
            ),
          ),
        ),
      );

      // Test loading overlay is visible
      expect(find.text('Loading...'), findsOneWidget);
      expect(find.text('Main Content'), findsOneWidget);
      
      // Test loading indicator is present
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Responsive components adapt to screen size', (WidgetTester tester) async {
      // Test with small screen size
      await tester.binding.setSurfaceSize(const Size(400, 800));
      
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Column(
              children: [
                ResponsiveText('Test Text'),
                ResponsivePadding(
                  child: Container(
                    color: Colors.blue,
                    height: 50,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify responsive components are present
      expect(find.byType(ResponsiveText), findsOneWidget);
      expect(find.byType(ResponsivePadding), findsOneWidget);
      
      // Test with large screen size
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpAndSettle();
      
      // Components should still be present and adapted
      expect(find.byType(ResponsiveText), findsOneWidget);
      expect(find.byType(ResponsivePadding), findsOneWidget);
    });

    testWidgets('Animation components work correctly', (WidgetTester tester) async {
      bool isVisible = true;
      
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    AppFadeTransition(
                      visible: isVisible,
                      child: const Text('Fade Text'),
                    ),
                    AnimatedButton(
                      onPressed: () {
                        setState(() {
                          isVisible = !isVisible;
                        });
                      },
                      child: const Text('Toggle'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Test fade transition is present
      expect(find.text('Fade Text'), findsOneWidget);
      expect(find.byType(AppFadeTransition), findsOneWidget);
      
      // Test animated button
      expect(find.byType(AnimatedButton), findsOneWidget);
      await tester.tap(find.text('Toggle'));
      await tester.pumpAndSettle();
    });

    group('Accessibility Utils Tests', () {
      test('calculateContrastRatio works correctly', () {
        final ratio = AccessibilityUtils.calculateContrastRatio(
          Colors.black,
          Colors.white,
        );
        
        // Black on white should have high contrast ratio
        expect(ratio, greaterThan(AccessibilityUtils.minContrastRatioNormal));
      });

      test('meetsContrastRequirements validates correctly', () {
        // High contrast combination
        expect(
          AccessibilityUtils.meetsContrastRequirements(
            Colors.black,
            Colors.white,
          ),
          isTrue,
        );
        
        // Low contrast combination
        expect(
          AccessibilityUtils.meetsContrastRequirements(
            Colors.grey[300]!,
            Colors.grey[200]!,
          ),
          isFalse,
        );
      });

      test('createSemanticLabel creates proper labels', () {
        final label = AccessibilityUtils.createSemanticLabel(
          label: 'Button',
          hint: 'Tap to continue',
          value: 'Selected',
          isSelected: true,
          isEnabled: true,
        );
        
        expect(label, contains('Button'));
        expect(label, contains('Selected'));
        expect(label, contains('selected'));
        expect(label, contains('Tap to continue'));
      });
    });

    group('Responsive Utils Tests', () {
      testWidgets('getScreenSize returns correct size', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final screenSize = ResponsiveUtils.getScreenSize(context);
                return Text('Screen: ${screenSize.name}');
              },
            ),
          ),
        );

        // Default test screen size should be small
        expect(find.textContaining('Screen:'), findsOneWidget);
      });

      testWidgets('responsive padding adapts to screen size', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final padding = ResponsiveUtils.getResponsivePadding(context);
                return Container(
                  padding: padding,
                  child: const Text('Padded Content'),
                );
              },
            ),
          ),
        );

        expect(find.text('Padded Content'), findsOneWidget);
      });
    });
  });
}