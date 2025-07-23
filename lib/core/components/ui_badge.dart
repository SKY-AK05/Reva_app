import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Badge variants
enum UIBadgeVariant {
  primary,
  secondary,
  success,
  warning,
  destructive,
  outline,
}

/// Badge sizes
enum UIBadgeSize {
  sm,
  md,
  lg,
}

/// A reusable badge component matching ShadCN UI design
class UIBadge extends StatelessWidget {
  final String text;
  final UIBadgeVariant variant;
  final UIBadgeSize size;
  final Widget? icon;

  const UIBadge({
    super.key,
    required this.text,
    this.variant = UIBadgeVariant.primary,
    this.size = UIBadgeSize.md,
    this.icon,
  });

  const UIBadge.primary({
    super.key,
    required this.text,
    this.size = UIBadgeSize.md,
    this.icon,
  }) : variant = UIBadgeVariant.primary;

  const UIBadge.secondary({
    super.key,
    required this.text,
    this.size = UIBadgeSize.md,
    this.icon,
  }) : variant = UIBadgeVariant.secondary;

  const UIBadge.success({
    super.key,
    required this.text,
    this.size = UIBadgeSize.md,
    this.icon,
  }) : variant = UIBadgeVariant.success;

  const UIBadge.warning({
    super.key,
    required this.text,
    this.size = UIBadgeSize.md,
    this.icon,
  }) : variant = UIBadgeVariant.warning;

  const UIBadge.destructive({
    super.key,
    required this.text,
    this.size = UIBadgeSize.md,
    this.icon,
  }) : variant = UIBadgeVariant.destructive;

  const UIBadge.outline({
    super.key,
    required this.text,
    this.size = UIBadgeSize.md,
    this.icon,
  }) : variant = UIBadgeVariant.outline;

  @override
  Widget build(BuildContext context) {
    final colors = _getColors(context);
    final padding = _getPadding();
    final textStyle = _getTextStyle(context);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors['background'],
        borderRadius: AppTheme.getBorderRadius('sm'),
        border: variant == UIBadgeVariant.outline 
          ? Border.all(
              color: AppTheme.getColor(context, 'border'),
              width: 1,
            )
          : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            SizedBox(
              height: _getIconSize(),
              width: _getIconSize(),
              child: icon,
            ),
            SizedBox(width: AppTheme.spacing1),
          ],
          Text(
            text,
            style: textStyle.copyWith(
              color: colors['foreground'],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, Color> _getColors(BuildContext context) {
    switch (variant) {
      case UIBadgeVariant.primary:
        return {
          'background': AppTheme.getColor(context, 'primary'),
          'foreground': AppTheme.getColor(context, 'primaryForeground'),
        };
      case UIBadgeVariant.secondary:
        return {
          'background': AppTheme.getColor(context, 'secondary'),
          'foreground': AppTheme.getColor(context, 'secondaryForeground'),
        };
      case UIBadgeVariant.success:
        return {
          'background': AppTheme.successColor,
          'foreground': Colors.white,
        };
      case UIBadgeVariant.warning:
        return {
          'background': AppTheme.warningColor,
          'foreground': Colors.white,
        };
      case UIBadgeVariant.destructive:
        return {
          'background': AppTheme.getColor(context, 'destructive'),
          'foreground': AppTheme.getColor(context, 'destructiveForeground'),
        };
      case UIBadgeVariant.outline:
        return {
          'background': AppTheme.getColor(context, 'background'),
          'foreground': AppTheme.getColor(context, 'foreground'),
        };
    }
  }

  EdgeInsetsGeometry _getPadding() {
    switch (size) {
      case UIBadgeSize.sm:
        return EdgeInsets.symmetric(
          horizontal: AppTheme.spacing2,
          vertical: AppTheme.spacing1 / 2,
        );
      case UIBadgeSize.md:
        return EdgeInsets.symmetric(
          horizontal: AppTheme.spacing2,
          vertical: AppTheme.spacing1,
        );
      case UIBadgeSize.lg:
        return EdgeInsets.symmetric(
          horizontal: AppTheme.spacing3,
          vertical: AppTheme.spacing1,
        );
    }
  }

  TextStyle _getTextStyle(BuildContext context) {
    final baseStyle = AppTheme.getTextStyle(context, 'labelSmall');
    
    switch (size) {
      case UIBadgeSize.sm:
        return baseStyle.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        );
      case UIBadgeSize.md:
        return baseStyle.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
      case UIBadgeSize.lg:
        return baseStyle.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );
    }
  }

  double _getIconSize() {
    switch (size) {
      case UIBadgeSize.sm:
        return 10;
      case UIBadgeSize.md:
        return 12;
      case UIBadgeSize.lg:
        return 14;
    }
  }
}

/// A notification badge for showing counts
class UINotificationBadge extends StatelessWidget {
  final int count;
  final Widget child;
  final Color? backgroundColor;
  final Color? textColor;
  final bool showZero;

  const UINotificationBadge({
    super.key,
    required this.count,
    required this.child,
    this.backgroundColor,
    this.textColor,
    this.showZero = false,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0 && !showZero) {
      return child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: count > 99 ? AppTheme.spacing1 : AppTheme.spacing1 / 2,
              vertical: AppTheme.spacing1 / 2,
            ),
            decoration: BoxDecoration(
              color: backgroundColor ?? AppTheme.getColor(context, 'destructive'),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.getColor(context, 'background'),
                width: 1,
              ),
            ),
            constraints: const BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
            child: Text(
              count > 99 ? '99+' : count.toString(),
              style: AppTheme.getTextStyle(context, 'labelSmall').copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: textColor ?? Colors.white,
                height: 1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}