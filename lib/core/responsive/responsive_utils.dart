import 'package:flutter/material.dart';

/// Screen size breakpoints
enum ScreenSize {
  small,   // < 600dp
  medium,  // 600dp - 840dp
  large,   // > 840dp
}

/// Device orientation helper
enum DeviceOrientation {
  portrait,
  landscape,
}

/// Responsive utilities for creating adaptive layouts
class ResponsiveUtils {
  /// Breakpoint values
  static const double smallBreakpoint = 600;
  static const double mediumBreakpoint = 840;

  /// Get current screen size category
  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < smallBreakpoint) {
      return ScreenSize.small;
    } else if (width < mediumBreakpoint) {
      return ScreenSize.medium;
    } else {
      return ScreenSize.large;
    }
  }

  /// Get current device orientation
  static DeviceOrientation getOrientation(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    return orientation == Orientation.portrait 
      ? DeviceOrientation.portrait 
      : DeviceOrientation.landscape;
  }

  /// Check if device is in portrait mode
  static bool isPortrait(BuildContext context) {
    return getOrientation(context) == DeviceOrientation.portrait;
  }

  /// Check if device is in landscape mode
  static bool isLandscape(BuildContext context) {
    return getOrientation(context) == DeviceOrientation.landscape;
  }

  /// Check if screen is small (phone)
  static bool isSmallScreen(BuildContext context) {
    return getScreenSize(context) == ScreenSize.small;
  }

  /// Check if screen is medium (tablet portrait)
  static bool isMediumScreen(BuildContext context) {
    return getScreenSize(context) == ScreenSize.medium;
  }

  /// Check if screen is large (tablet landscape, desktop)
  static bool isLargeScreen(BuildContext context) {
    return getScreenSize(context) == ScreenSize.large;
  }

  /// Get responsive padding based on screen size
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final screenSize = getScreenSize(context);
    
    switch (screenSize) {
      case ScreenSize.small:
        return const EdgeInsets.all(16);
      case ScreenSize.medium:
        return const EdgeInsets.all(24);
      case ScreenSize.large:
        return const EdgeInsets.all(32);
    }
  }

  /// Get responsive margin based on screen size
  static EdgeInsets getResponsiveMargin(BuildContext context) {
    final screenSize = getScreenSize(context);
    
    switch (screenSize) {
      case ScreenSize.small:
        return const EdgeInsets.all(8);
      case ScreenSize.medium:
        return const EdgeInsets.all(12);
      case ScreenSize.large:
        return const EdgeInsets.all(16);
    }
  }

  /// Get responsive font size multiplier
  static double getFontSizeMultiplier(BuildContext context) {
    final screenSize = getScreenSize(context);
    
    switch (screenSize) {
      case ScreenSize.small:
        return 1.0;
      case ScreenSize.medium:
        return 1.1;
      case ScreenSize.large:
        return 1.2;
    }
  }

  /// Get responsive grid column count
  static int getGridColumns(BuildContext context, {int? maxColumns}) {
    final width = MediaQuery.of(context).size.width;
    final columns = (width / 200).floor().clamp(1, maxColumns ?? 4);
    return columns;
  }

  /// Get responsive list item height
  static double getListItemHeight(BuildContext context) {
    final screenSize = getScreenSize(context);
    
    switch (screenSize) {
      case ScreenSize.small:
        return 72;
      case ScreenSize.medium:
        return 80;
      case ScreenSize.large:
        return 88;
    }
  }

  /// Get safe area padding
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// Get status bar height
  static double getStatusBarHeight(BuildContext context) {
    return MediaQuery.of(context).padding.top;
  }

  /// Get bottom safe area height (for home indicator on iOS)
  static double getBottomSafeAreaHeight(BuildContext context) {
    return MediaQuery.of(context).padding.bottom;
  }

  /// Check if device has a notch or dynamic island
  static bool hasNotch(BuildContext context) {
    return MediaQuery.of(context).padding.top > 24;
  }

  /// Get keyboard height
  static double getKeyboardHeight(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom;
  }

  /// Check if keyboard is visible
  static bool isKeyboardVisible(BuildContext context) {
    return getKeyboardHeight(context) > 0;
  }
}

/// Responsive widget that builds different layouts based on screen size
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenSize screenSize) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = ResponsiveUtils.getScreenSize(context);
    return builder(context, screenSize);
  }
}

/// Responsive widget with separate builders for different screen sizes
class ResponsiveLayout extends StatelessWidget {
  final Widget Function(BuildContext context)? small;
  final Widget Function(BuildContext context)? medium;
  final Widget Function(BuildContext context)? large;
  final Widget Function(BuildContext context) fallback;

  const ResponsiveLayout({
    super.key,
    this.small,
    this.medium,
    this.large,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = ResponsiveUtils.getScreenSize(context);
    
    switch (screenSize) {
      case ScreenSize.small:
        return (small ?? fallback)(context);
      case ScreenSize.medium:
        return (medium ?? fallback)(context);
      case ScreenSize.large:
        return (large ?? fallback)(context);
    }
  }
}

/// Responsive padding widget
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsets? small;
  final EdgeInsets? medium;
  final EdgeInsets? large;

  const ResponsivePadding({
    super.key,
    required this.child,
    this.small,
    this.medium,
    this.large,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = ResponsiveUtils.getScreenSize(context);
    
    EdgeInsets padding;
    switch (screenSize) {
      case ScreenSize.small:
        padding = small ?? ResponsiveUtils.getResponsivePadding(context);
        break;
      case ScreenSize.medium:
        padding = medium ?? ResponsiveUtils.getResponsivePadding(context);
        break;
      case ScreenSize.large:
        padding = large ?? ResponsiveUtils.getResponsivePadding(context);
        break;
    }
    
    return Padding(
      padding: padding,
      child: child,
    );
  }
}

/// Responsive text widget that scales font size based on screen size
class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool scaleWithScreen;

  const ResponsiveText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.scaleWithScreen = true,
  });

  @override
  Widget build(BuildContext context) {
    TextStyle effectiveStyle = style ?? Theme.of(context).textTheme.bodyMedium!;
    
    if (scaleWithScreen) {
      final multiplier = ResponsiveUtils.getFontSizeMultiplier(context);
      effectiveStyle = effectiveStyle.copyWith(
        fontSize: (effectiveStyle.fontSize ?? 14) * multiplier,
      );
    }
    
    return Text(
      text,
      style: effectiveStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Responsive grid view that adjusts column count based on screen size
class ResponsiveGridView extends StatelessWidget {
  final List<Widget> children;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final EdgeInsets? padding;
  final int? maxColumns;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const ResponsiveGridView({
    super.key,
    required this.children,
    this.childAspectRatio = 1.0,
    this.crossAxisSpacing = 8.0,
    this.mainAxisSpacing = 8.0,
    this.padding,
    this.maxColumns,
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveUtils.getGridColumns(context, maxColumns: maxColumns);
    
    return GridView.count(
      crossAxisCount: columns,
      childAspectRatio: childAspectRatio,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
      padding: padding,
      physics: physics,
      shrinkWrap: shrinkWrap,
      children: children,
    );
  }
}

/// Extension for responsive utilities on BuildContext
extension ResponsiveExtensions on BuildContext {
  /// Get screen size
  ScreenSize get screenSize => ResponsiveUtils.getScreenSize(this);
  
  /// Get device orientation
  DeviceOrientation get deviceOrientation => ResponsiveUtils.getOrientation(this);
  
  /// Check if portrait
  bool get isPortrait => ResponsiveUtils.isPortrait(this);
  
  /// Check if landscape
  bool get isLandscape => ResponsiveUtils.isLandscape(this);
  
  /// Check if small screen
  bool get isSmallScreen => ResponsiveUtils.isSmallScreen(this);
  
  /// Check if medium screen
  bool get isMediumScreen => ResponsiveUtils.isMediumScreen(this);
  
  /// Check if large screen
  bool get isLargeScreen => ResponsiveUtils.isLargeScreen(this);
  
  /// Get responsive padding
  EdgeInsets get responsivePadding => ResponsiveUtils.getResponsivePadding(this);
  
  /// Get responsive margin
  EdgeInsets get responsiveMargin => ResponsiveUtils.getResponsiveMargin(this);
  
  /// Get font size multiplier
  double get fontSizeMultiplier => ResponsiveUtils.getFontSizeMultiplier(this);
  
  /// Get safe area padding
  EdgeInsets get safeAreaPadding => ResponsiveUtils.getSafeAreaPadding(this);
  
  /// Get status bar height
  double get statusBarHeight => ResponsiveUtils.getStatusBarHeight(this);
  
  /// Get bottom safe area height
  double get bottomSafeAreaHeight => ResponsiveUtils.getBottomSafeAreaHeight(this);
  
  /// Check if has notch
  bool get hasNotch => ResponsiveUtils.hasNotch(this);
  
  /// Get keyboard height
  double get keyboardHeight => ResponsiveUtils.getKeyboardHeight(this);
  
  /// Check if keyboard is visible
  bool get isKeyboardVisible => ResponsiveUtils.isKeyboardVisible(this);
}