import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';

/// Accessibility utilities and helpers
class AccessibilityUtils {
  /// Minimum touch target size (44x44 dp) as per accessibility guidelines
  static const double minTouchTargetSize = 44.0;

  /// Minimum contrast ratios
  static const double minContrastRatioNormal = 4.5;
  static const double minContrastRatioLarge = 3.0;

  /// Check if a widget meets minimum touch target size requirements
  static bool meetsTouchTargetSize(Size size) {
    return size.width >= minTouchTargetSize && size.height >= minTouchTargetSize;
  }

  /// Calculate contrast ratio between two colors
  static double calculateContrastRatio(Color color1, Color color2) {
    final luminance1 = _calculateLuminance(color1);
    final luminance2 = _calculateLuminance(color2);
    
    final lighter = luminance1 > luminance2 ? luminance1 : luminance2;
    final darker = luminance1 > luminance2 ? luminance2 : luminance1;
    
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Calculate relative luminance of a color
  static double _calculateLuminance(Color color) {
    final r = _linearizeColorComponent(color.red / 255.0);
    final g = _linearizeColorComponent(color.green / 255.0);
    final b = _linearizeColorComponent(color.blue / 255.0);
    
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  static double _linearizeColorComponent(double component) {
    if (component <= 0.03928) {
      return component / 12.92;
    } else {
      return math.pow((component + 0.055) / 1.055, 2.4).toDouble();
    }
  }

  /// Check if color combination meets WCAG contrast requirements
  static bool meetsContrastRequirements(
    Color foreground,
    Color background, {
    bool isLargeText = false,
  }) {
    final ratio = calculateContrastRatio(foreground, background);
    final minRatio = isLargeText ? minContrastRatioLarge : minContrastRatioNormal;
    return ratio >= minRatio;
  }

  /// Provide haptic feedback for accessibility
  static void provideFeedback(HapticFeedbackType type) {
    switch (type) {
      case HapticFeedbackType.lightImpact:
        HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.mediumImpact:
        HapticFeedback.mediumImpact();
        break;
      case HapticFeedbackType.heavyImpact:
        HapticFeedback.heavyImpact();
        break;
      case HapticFeedbackType.selectionClick:
        HapticFeedback.selectionClick();
        break;
      case HapticFeedbackType.vibrate:
        HapticFeedback.vibrate();
        break;
    }
  }

  /// Announce text to screen readers
  static void announceToScreenReader(
    BuildContext context,
    String message, {
    TextDirection? textDirection,
  }) {
    final direction = textDirection ?? Directionality.of(context);
    SemanticsService.announce(message, direction);
  }

  /// Create semantic label for screen readers
  static String createSemanticLabel({
    required String label,
    String? hint,
    String? value,
    bool? isSelected,
    bool? isEnabled,
  }) {
    final buffer = StringBuffer(label);
    
    if (value != null && value.isNotEmpty) {
      buffer.write(', $value');
    }
    
    if (isSelected == true) {
      buffer.write(', selected');
    }
    
    if (isEnabled == false) {
      buffer.write(', disabled');
    }
    
    if (hint != null && hint.isNotEmpty) {
      buffer.write(', $hint');
    }
    
    return buffer.toString();
  }
}

/// Enum for haptic feedback types
enum HapticFeedbackType {
  lightImpact,
  mediumImpact,
  heavyImpact,
  selectionClick,
  vibrate,
}

/// Accessible button wrapper that ensures proper touch targets and semantics
class AccessibleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final String? tooltip;
  final bool excludeSemantics;
  final HapticFeedbackType? hapticFeedback;

  const AccessibleButton({
    super.key,
    required this.child,
    this.onPressed,
    this.semanticLabel,
    this.tooltip,
    this.excludeSemantics = false,
    this.hapticFeedback,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = InkWell(
      onTap: onPressed != null ? _handleTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(
          minWidth: AccessibilityUtils.minTouchTargetSize,
          minHeight: AccessibilityUtils.minTouchTargetSize,
        ),
        child: Center(child: child),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    if (!excludeSemantics) {
      button = Semantics(
        label: semanticLabel,
        button: true,
        enabled: onPressed != null,
        child: button,
      );
    }

    return button;
  }

  void _handleTap() {
    if (hapticFeedback != null) {
      AccessibilityUtils.provideFeedback(hapticFeedback!);
    }
    onPressed?.call();
  }
}

/// Accessible text widget with proper contrast checking
class AccessibleText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color? backgroundColor;
  final String? semanticLabel;
  final bool excludeSemantics;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const AccessibleText(
    this.text, {
    super.key,
    this.style,
    this.backgroundColor,
    this.semanticLabel,
    this.excludeSemantics = false,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStyle = style ?? theme.textTheme.bodyMedium!;
    final textColor = effectiveStyle.color ?? theme.colorScheme.onSurface;
    final bgColor = backgroundColor ?? theme.colorScheme.surface;

    // Check contrast ratio in debug mode
    assert(() {
      final contrastRatio = AccessibilityUtils.calculateContrastRatio(
        textColor,
        bgColor,
      );
      final isLargeText = (effectiveStyle.fontSize ?? 14) >= 18;
      final meetsRequirements = AccessibilityUtils.meetsContrastRequirements(
        textColor,
        bgColor,
        isLargeText: isLargeText,
      );
      
      if (!meetsRequirements) {
        debugPrint(
          'Warning: Text contrast ratio ($contrastRatio) does not meet '
          'accessibility requirements for ${isLargeText ? 'large' : 'normal'} text',
        );
      }
      return true;
    }());

    Widget textWidget = Text(
      text,
      style: effectiveStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );

    if (!excludeSemantics && semanticLabel != null) {
      textWidget = Semantics(
        label: semanticLabel,
        child: ExcludeSemantics(child: textWidget),
      );
    }

    return textWidget;
  }
}

/// Accessible form field with proper labeling and error handling
class AccessibleFormField extends StatelessWidget {
  final Widget child;
  final String? label;
  final String? hint;
  final String? error;
  final bool isRequired;

  const AccessibleFormField({
    super.key,
    required this.child,
    this.label,
    this.hint,
    this.error,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final semanticLabel = AccessibilityUtils.createSemanticLabel(
      label: label ?? '',
      hint: hint,
      value: error,
      isEnabled: true,
    );

    return Semantics(
      label: semanticLabel,
      textField: true,
      child: child,
    );
  }
}

/// Screen reader announcements helper
class ScreenReaderAnnouncements {
  static void announcePageChange(BuildContext context, String pageName) {
    AccessibilityUtils.announceToScreenReader(
      context,
      'Navigated to $pageName',
    );
  }

  static void announceAction(BuildContext context, String action) {
    AccessibilityUtils.announceToScreenReader(
      context,
      action,
    );
  }

  static void announceError(BuildContext context, String error) {
    AccessibilityUtils.announceToScreenReader(
      context,
      'Error: $error',
    );
  }

  static void announceSuccess(BuildContext context, String message) {
    AccessibilityUtils.announceToScreenReader(
      context,
      'Success: $message',
    );
  }

  static void announceLoading(BuildContext context, {String? message}) {
    AccessibilityUtils.announceToScreenReader(
      context,
      message ?? 'Loading',
    );
  }

  static void announceLoadingComplete(BuildContext context, {String? message}) {
    AccessibilityUtils.announceToScreenReader(
      context,
      message ?? 'Loading complete',
    );
  }
}

/// Extension for adding accessibility helpers to widgets
extension AccessibilityExtensions on Widget {
  /// Add semantic label to any widget
  Widget withSemanticLabel(String label) {
    return Semantics(
      label: label,
      child: this,
    );
  }

  /// Add tooltip to any widget
  Widget withTooltip(String message) {
    return Tooltip(
      message: message,
      child: this,
    );
  }

  /// Ensure minimum touch target size
  Widget withMinTouchTarget() {
    return Container(
      constraints: const BoxConstraints(
        minWidth: AccessibilityUtils.minTouchTargetSize,
        minHeight: AccessibilityUtils.minTouchTargetSize,
      ),
      child: this,
    );
  }

  /// Add haptic feedback to tappable widgets
  Widget withHapticFeedback(HapticFeedbackType type) {
    return GestureDetector(
      onTap: () => AccessibilityUtils.provideFeedback(type),
      child: this,
    );
  }
}