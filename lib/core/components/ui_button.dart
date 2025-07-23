import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../animations/app_animations.dart';
import '../accessibility/accessibility_utils.dart';
import '../responsive/responsive_utils.dart';

/// Button variants matching ShadCN UI design
enum UIButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
  destructive,
}

/// Button sizes
enum UIButtonSize {
  sm,
  md,
  lg,
}

/// A reusable button component matching ShadCN UI design with animations and accessibility
class UIButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final UIButtonVariant variant;
  final UIButtonSize size;
  final Widget? icon;
  final bool isLoading;
  final bool fullWidth;
  final String? semanticLabel;
  final String? tooltip;
  final HapticFeedbackType? hapticFeedback;
  final bool enableAnimation;

  const UIButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = UIButtonVariant.primary,
    this.size = UIButtonSize.md,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
    this.hapticFeedback = HapticFeedbackType.lightImpact,
    this.enableAnimation = true,
  });

  const UIButton.primary({
    super.key,
    required this.text,
    this.onPressed,
    this.size = UIButtonSize.md,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
    this.hapticFeedback = HapticFeedbackType.lightImpact,
    this.enableAnimation = true,
  }) : variant = UIButtonVariant.primary;

  const UIButton.secondary({
    super.key,
    required this.text,
    this.onPressed,
    this.size = UIButtonSize.md,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
    this.hapticFeedback = HapticFeedbackType.lightImpact,
    this.enableAnimation = true,
  }) : variant = UIButtonVariant.secondary;

  const UIButton.outline({
    super.key,
    required this.text,
    this.onPressed,
    this.size = UIButtonSize.md,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
    this.hapticFeedback = HapticFeedbackType.lightImpact,
    this.enableAnimation = true,
  }) : variant = UIButtonVariant.outline;

  const UIButton.ghost({
    super.key,
    required this.text,
    this.onPressed,
    this.size = UIButtonSize.md,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
    this.hapticFeedback = HapticFeedbackType.lightImpact,
    this.enableAnimation = true,
  }) : variant = UIButtonVariant.ghost;

  const UIButton.destructive({
    super.key,
    required this.text,
    this.onPressed,
    this.size = UIButtonSize.md,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
    this.hapticFeedback = HapticFeedbackType.lightImpact,
    this.enableAnimation = true,
  }) : variant = UIButtonVariant.destructive;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = _getButtonStyle(context);
    final buttonChild = _buildButtonChild(context);
    final effectiveSemanticLabel = semanticLabel ?? text;

    Widget button = ElevatedButton(
      onPressed: isLoading ? null : _handlePress,
      style: buttonStyle,
      child: buttonChild,
    );

    // Add animation wrapper if enabled
    if (enableAnimation && onPressed != null) {
      button = AnimatedButton(
        onPressed: _handlePress,
        duration: AppAnimations.fast,
        child: button,
      );
    }

    // Add ripple effect for better interaction feedback
    button = RippleAnimation(
      onTap: isLoading ? null : _handlePress,
      borderRadius: AppTheme.getBorderRadius('md'),
      child: button,
    );

    // Ensure minimum touch target size for accessibility
    button = Container(
      constraints: BoxConstraints(
        minWidth: AccessibilityUtils.minTouchTargetSize,
        minHeight: AccessibilityUtils.minTouchTargetSize,
      ),
      child: button,
    );

    // Add responsive sizing
    if (ResponsiveUtils.isLargeScreen(context)) {
      button = Transform.scale(
        scale: 1.1,
        child: button,
      );
    }

    if (fullWidth) {
      button = SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    // Add tooltip if provided
    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    // Add semantic information for screen readers
    return Semantics(
      label: effectiveSemanticLabel,
      button: true,
      enabled: onPressed != null && !isLoading,
      child: button,
    );
  }

  void _handlePress() {
    if (isLoading) return;
    
    // Provide haptic feedback
    if (hapticFeedback != null) {
      AccessibilityUtils.provideFeedback(hapticFeedback!);
    }
    
    onPressed?.call();
  }

  Widget _buildButtonChild(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        height: _getIconSize(),
        width: _getIconSize(),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            _getLoadingColor(),
          ),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _getIconSize(),
            width: _getIconSize(),
            child: icon,
          ),
          SizedBox(width: AppTheme.spacing2),
          Text(text),
        ],
      );
    }

    return Text(text);
  }

  ButtonStyle _getButtonStyle(BuildContext context) {
    final colors = _getColors(context);
    final padding = _getPadding();
    final textStyle = _getTextStyle(context);

    return ElevatedButton.styleFrom(
      backgroundColor: colors['background'],
      foregroundColor: colors['foreground'],
      elevation: variant == UIButtonVariant.ghost ? 0 : null,
      shadowColor: variant == UIButtonVariant.ghost ? Colors.transparent : null,
      side: _getBorder(context),
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.getBorderRadius('md'),
      ),
      padding: padding,
      minimumSize: Size(0, _getMinHeight()),
      textStyle: textStyle,
    );
  }

  Map<String, Color> _getColors(BuildContext context) {
    switch (variant) {
      case UIButtonVariant.primary:
        return {
          'background': AppTheme.getColor(context, 'primary'),
          'foreground': AppTheme.getColor(context, 'primaryForeground'),
        };
      case UIButtonVariant.secondary:
        return {
          'background': AppTheme.getColor(context, 'secondary'),
          'foreground': AppTheme.getColor(context, 'secondaryForeground'),
        };
      case UIButtonVariant.outline:
        return {
          'background': AppTheme.getColor(context, 'background'),
          'foreground': AppTheme.getColor(context, 'foreground'),
        };
      case UIButtonVariant.ghost:
        return {
          'background': Colors.transparent,
          'foreground': AppTheme.getColor(context, 'foreground'),
        };
      case UIButtonVariant.destructive:
        return {
          'background': AppTheme.getColor(context, 'destructive'),
          'foreground': AppTheme.getColor(context, 'destructiveForeground'),
        };
    }
  }

  BorderSide? _getBorder(BuildContext context) {
    if (variant == UIButtonVariant.outline) {
      return BorderSide(
        color: AppTheme.getColor(context, 'border'),
        width: 1,
      );
    }
    return null;
  }

  EdgeInsetsGeometry _getPadding() {
    switch (size) {
      case UIButtonSize.sm:
        return EdgeInsets.symmetric(
          horizontal: AppTheme.spacing3,
          vertical: AppTheme.spacing1,
        );
      case UIButtonSize.md:
        return EdgeInsets.symmetric(
          horizontal: AppTheme.spacing4,
          vertical: AppTheme.spacing2,
        );
      case UIButtonSize.lg:
        return EdgeInsets.symmetric(
          horizontal: AppTheme.spacing6,
          vertical: AppTheme.spacing3,
        );
    }
  }

  double _getMinHeight() {
    switch (size) {
      case UIButtonSize.sm:
        return 32;
      case UIButtonSize.md:
        return 40;
      case UIButtonSize.lg:
        return 48;
    }
  }

  double _getIconSize() {
    switch (size) {
      case UIButtonSize.sm:
        return 14;
      case UIButtonSize.md:
        return 16;
      case UIButtonSize.lg:
        return 18;
    }
  }

  TextStyle _getTextStyle(BuildContext context) {
    final baseStyle = AppTheme.getTextStyle(context, 'label');
    
    switch (size) {
      case UIButtonSize.sm:
        return baseStyle.copyWith(fontSize: 12);
      case UIButtonSize.md:
        return baseStyle.copyWith(fontSize: 14);
      case UIButtonSize.lg:
        return baseStyle.copyWith(fontSize: 16);
    }
  }

  Color _getLoadingColor() {
    switch (variant) {
      case UIButtonVariant.primary:
      case UIButtonVariant.destructive:
        return Colors.white;
      case UIButtonVariant.secondary:
      case UIButtonVariant.outline:
      case UIButtonVariant.ghost:
        return Colors.grey;
    }
  }
}