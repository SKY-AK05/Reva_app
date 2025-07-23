import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../animations/app_animations.dart';
import '../accessibility/accessibility_utils.dart';
import '../responsive/responsive_utils.dart';
import 'ui_icon.dart';

/// Loading indicator sizes
enum UILoadingSize {
  sm,
  md,
  lg,
  xl,
}

/// A reusable loading indicator component with animations and accessibility
class UILoading extends StatelessWidget {
  final UILoadingSize size;
  final Color? color;
  final String? message;
  final String? semanticLabel;
  final bool enableAnimation;

  const UILoading({
    super.key,
    this.size = UILoadingSize.md,
    this.color,
    this.message,
    this.semanticLabel,
    this.enableAnimation = true,
  });

  const UILoading.sm({
    super.key,
    this.color,
    this.message,
    this.semanticLabel,
    this.enableAnimation = true,
  }) : size = UILoadingSize.sm;

  const UILoading.md({
    super.key,
    this.color,
    this.message,
    this.semanticLabel,
    this.enableAnimation = true,
  }) : size = UILoadingSize.md;

  const UILoading.lg({
    super.key,
    this.color,
    this.message,
    this.semanticLabel,
    this.enableAnimation = true,
  }) : size = UILoadingSize.lg;

  const UILoading.xl({
    super.key,
    this.color,
    this.message,
    this.semanticLabel,
    this.enableAnimation = true,
  }) : size = UILoadingSize.xl;

  @override
  Widget build(BuildContext context) {
    final indicatorColor = color ?? AppTheme.getColor(context, 'primary');
    final indicatorSize = _getSize(context);
    final effectiveSemanticLabel = semanticLabel ?? message ?? 'Loading';

    Widget indicator = SizedBox(
      width: indicatorSize,
      height: indicatorSize,
      child: CircularProgressIndicator(
        strokeWidth: _getStrokeWidth(),
        valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
      ),
    );

    // Add fade-in animation if enabled
    if (enableAnimation) {
      indicator = AppFadeTransition(
        visible: true,
        duration: AppAnimations.normal,
        child: indicator,
      );
    }

    Widget loadingWidget;
    if (message != null) {
      loadingWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          SizedBox(height: AppTheme.spacing3),
          if (enableAnimation)
            AppFadeTransition(
              visible: true,
              duration: AppAnimations.normal,
              child: ResponsiveText(
                message!,
                style: AppTheme.getTextStyle(context, 'body').copyWith(
                  color: AppTheme.getColor(context, 'mutedForeground'),
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ResponsiveText(
              message!,
              style: AppTheme.getTextStyle(context, 'body').copyWith(
                color: AppTheme.getColor(context, 'mutedForeground'),
              ),
              textAlign: TextAlign.center,
            ),
        ],
      );
    } else {
      loadingWidget = indicator;
    }

    // Add semantic information for screen readers
    return Semantics(
      label: effectiveSemanticLabel,
      liveRegion: true,
      child: loadingWidget,
    );
  }

  double _getSize(BuildContext context) {
    final baseSize = switch (size) {
      UILoadingSize.sm => 16.0,
      UILoadingSize.md => 24.0,
      UILoadingSize.lg => 32.0,
      UILoadingSize.xl => 48.0,
    };
    
    // Scale based on screen size for better responsive design
    final multiplier = ResponsiveUtils.getFontSizeMultiplier(context);
    return baseSize * multiplier;
  }



  double _getStrokeWidth() {
    switch (size) {
      case UILoadingSize.sm:
        return 2;
      case UILoadingSize.md:
        return 2.5;
      case UILoadingSize.lg:
        return 3;
      case UILoadingSize.xl:
        return 4;
    }
  }
}

/// A full-screen loading overlay with animations and accessibility
class UILoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final Color? backgroundColor;
  final bool enableAnimation;
  final String? semanticLabel;

  const UILoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.backgroundColor,
    this.enableAnimation = true,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          AppFadeTransition(
            visible: isLoading,
            duration: enableAnimation ? AppAnimations.normal : Duration.zero,
            child: Container(
              color: backgroundColor ?? 
                AppTheme.getColor(context, 'background').withValues(alpha: 0.8),
              child: Center(
                child: UILoading.lg(
                  message: message,
                  semanticLabel: semanticLabel,
                  enableAnimation: enableAnimation,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A skeleton loading component for list items
class UISkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final String borderRadius;

  const UISkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 'md',
  });

  const UISkeleton.text({
    super.key,
    this.width,
  }) : height = 16, borderRadius = 'sm';

  const UISkeleton.avatar({
    super.key,
    double? size,
  }) : width = size ?? 40, height = size ?? 40, borderRadius = '3xl';

  const UISkeleton.card({
    super.key,
    this.width,
    this.height,
  }) : borderRadius = 'lg';

  @override
  State<UISkeleton> createState() => _UISkeletonState();
}

class _UISkeletonState extends State<UISkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height ?? 16,
          decoration: BoxDecoration(
            color: AppTheme.getColor(context, 'muted').withOpacity(_animation.value),
            borderRadius: AppTheme.getBorderRadius(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// A skeleton loading component for list items
class UISkeletonList extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  const UISkeletonList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}

/// Pre-built skeleton for common list item patterns
class UISkeletonListItem extends StatelessWidget {
  final bool showAvatar;
  final bool showSubtitle;
  final bool showTrailing;

  const UISkeletonListItem({
    super.key,
    this.showAvatar = false,
    this.showSubtitle = true,
    this.showTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppTheme.getPadding('md'),
      child: Row(
        children: [
          if (showAvatar) ...[
            const UISkeleton.avatar(),
            SizedBox(width: AppTheme.spacing3),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UISkeleton.text(width: MediaQuery.of(context).size.width * 0.6),
                if (showSubtitle) ...[
                  SizedBox(height: AppTheme.spacing1),
                  UISkeleton.text(width: MediaQuery.of(context).size.width * 0.4),
                ],
              ],
            ),
          ),
          if (showTrailing) ...[
            SizedBox(width: AppTheme.spacing3),
            const UISkeleton(width: 24, height: 24),
          ],
        ],
      ),
    );
  }
}