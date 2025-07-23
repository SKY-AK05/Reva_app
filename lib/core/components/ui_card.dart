import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../animations/app_animations.dart';
import '../accessibility/accessibility_utils.dart';
import '../responsive/responsive_utils.dart';

/// A reusable card component matching ShadCN UI design with animations and accessibility
class UICard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final String shadowLevel;
  final String borderRadius;
  final Color? backgroundColor;
  final Border? border;
  final String? semanticLabel;
  final bool enableAnimation;
  final bool enableHoverEffect;
  final HapticFeedbackType? hapticFeedback;

  const UICard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.shadowLevel = 'sm',
    this.borderRadius = 'lg',
    this.backgroundColor,
    this.border,
    this.semanticLabel,
    this.enableAnimation = true,
    this.enableHoverEffect = true,
    this.hapticFeedback = HapticFeedbackType.lightImpact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = backgroundColor ?? theme.cardTheme.color;
    final responsivePadding = ResponsiveUtils.getResponsivePadding(context);

    Widget cardWidget = Container(
      margin: margin ?? ResponsiveUtils.getResponsiveMargin(context),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: AppTheme.getBorderRadius(borderRadius),
        boxShadow: AppTheme.getShadow(shadowLevel),
        border: border ?? Border.all(
          color: AppTheme.getColor(context, 'border'),
          width: 1,
        ),
      ),
      child: Padding(
        padding: padding ?? responsivePadding,
        child: child,
      ),
    );

    // Add hover effect for better interaction feedback
    if (onTap != null && enableHoverEffect) {
      cardWidget = AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.defaultCurve,
        margin: margin ?? ResponsiveUtils.getResponsiveMargin(context),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: AppTheme.getBorderRadius(borderRadius),
          boxShadow: AppTheme.getShadow(shadowLevel),
          border: border ?? Border.all(
            color: AppTheme.getColor(context, 'border'),
            width: 1,
          ),
        ),
        child: Padding(
          padding: padding ?? responsivePadding,
          child: child,
        ),
      );
    }

    // Add animation wrapper if enabled
    if (enableAnimation && onTap != null) {
      cardWidget = AnimatedButton(
        onPressed: _handleTap,
        duration: AppAnimations.fast,
        child: cardWidget,
      );
    }

    // Add ripple effect for tappable cards
    if (onTap != null) {
      cardWidget = RippleAnimation(
        onTap: _handleTap,
        borderRadius: AppTheme.getBorderRadius(borderRadius),
        child: cardWidget,
      );
    }

    // Ensure minimum touch target size for tappable cards
    if (onTap != null) {
      cardWidget = Container(
        constraints: const BoxConstraints(
          minHeight: AccessibilityUtils.minTouchTargetSize,
        ),
        child: cardWidget,
      );
    }

    // Add semantic information for screen readers
    if (semanticLabel != null || onTap != null) {
      cardWidget = Semantics(
        label: semanticLabel,
        button: onTap != null,
        enabled: onTap != null,
        child: cardWidget,
      );
    }

    return cardWidget;
  }

  void _handleTap() {
    // Provide haptic feedback
    if (hapticFeedback != null) {
      AccessibilityUtils.provideFeedback(hapticFeedback!);
    }
    
    onTap?.call();
  }
}

/// A specialized card for list items
class UIListCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool showBorder;

  const UIListCard({
    super.key,
    required this.child,
    this.onTap,
    this.isSelected = false,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return UICard(
      onTap: onTap,
      padding: AppTheme.getPadding('md'),
      margin: EdgeInsets.only(bottom: AppTheme.spacing2),
      shadowLevel: isSelected ? 'md' : 'sm',
      backgroundColor: isSelected 
        ? AppTheme.getColor(context, 'accent')
        : null,
      border: showBorder ? null : Border.all(color: Colors.transparent),
      child: child,
    );
  }
}