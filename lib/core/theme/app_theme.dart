import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ShadCN UI Design Tokens - Light Theme
  static const Color _lightBackground = Color(0xFFFFFFFF);
  static const Color _lightForeground = Color(0xFF0F172A);
  static const Color _lightCard = Color(0xFFFFFFFF);
  static const Color _lightCardForeground = Color(0xFF0F172A);
  static const Color _lightPopover = Color(0xFFFFFFFF);
  static const Color _lightPopoverForeground = Color(0xFF0F172A);
  static const Color _lightPrimary = Color(0xFF0F172A);
  static const Color _lightPrimaryForeground = Color(0xFFF8FAFC);
  static const Color _lightSecondary = Color(0xFFF1F5F9);
  static const Color _lightSecondaryForeground = Color(0xFF0F172A);
  static const Color _lightMuted = Color(0xFFF1F5F9);
  static const Color _lightMutedForeground = Color(0xFF64748B);
  static const Color _lightAccent = Color(0xFFF1F5F9);
  static const Color _lightAccentForeground = Color(0xFF0F172A);
  static const Color _lightDestructive = Color(0xFFEF4444);
  static const Color _lightDestructiveForeground = Color(0xFFF8FAFC);
  static const Color _lightBorder = Color(0xFFE2E8F0);
  static const Color _lightInput = Color(0xFFE2E8F0);
  static const Color _lightRing = Color(0xFF0F172A);

  // ShadCN UI Design Tokens - Dark Theme
  static const Color _darkBackground = Color(0xFF000000); // true black
  static const Color _darkForeground = Color(0xFFF8FAFC);
  static const Color _darkCard = Color(0xFF181818); // slightly lighter for cards
  static const Color _darkCardForeground = Color(0xFFF8FAFC);
  static const Color _darkPopover = Color(0xFF181818);
  static const Color _darkPopoverForeground = Color(0xFFF8FAFC);
  static const Color _darkPrimary = Color(0xFFF8FAFC);
  static const Color _darkPrimaryForeground = Color(0xFF000000);
  static const Color _darkSecondary = Color(0xFF222222);
  static const Color _darkSecondaryForeground = Color(0xFFF8FAFC);
  static const Color _darkMuted = Color(0xFF23272F);
  static const Color _darkMutedForeground = Color(0xFF94A3B8);
  static const Color _darkAccent = Color(0xFF23272F);
  static const Color _darkAccentForeground = Color(0xFFF8FAFC);
  static const Color _darkDestructive = Color(0xFF7F1D1D);
  static const Color _darkDestructiveForeground = Color(0xFFF8FAFC);
  static const Color _darkBorder = Color(0xFF23272F);
  static const Color _darkInput = Color(0xFF181818);
  static const Color _darkRing = Color(0xFF94A3B8);
  static const Color _darkSurfaceVariant = Color(0xFF181818);
  static const Color _darkOnSurfaceVariant = Color(0xFFB0B8C1);

  // Semantic colors
  static const Color successColor = Color(0xFF10B981); // emerald-500
  static const Color warningColor = Color(0xFFF59E0B); // amber-500
  static const Color infoColor = Color(0xFF3B82F6); // blue-500

  // Radius values matching ShadCN UI
  static const double radiusXs = 2.0;
  static const double radiusSm = 4.0;
  static const double radiusMd = 6.0;
  static const double radiusLg = 8.0;
  static const double radiusXl = 12.0;
  static const double radius2xl = 16.0;
  static const double radius3xl = 24.0;

  // Spacing values
  static const double spacing1 = 4.0;
  static const double spacing2 = 8.0;
  static const double spacing3 = 12.0;
  static const double spacing4 = 16.0;
  static const double spacing5 = 20.0;
  static const double spacing6 = 24.0;
  static const double spacing8 = 32.0;
  static const double spacing10 = 40.0;
  static const double spacing12 = 48.0;
  static const double spacing16 = 64.0;
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _lightBackground,
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: _lightPrimary,
        onPrimary: _lightPrimaryForeground,
        secondary: _lightSecondary,
        onSecondary: _lightSecondaryForeground,
        tertiary: _lightAccent,
        onTertiary: _lightAccentForeground,
        surface: _lightCard,
        onSurface: _lightCardForeground,
        background: _lightBackground,
        onBackground: _lightForeground,
        error: _lightDestructive,
        onError: _lightDestructiveForeground,
        outline: _lightBorder,
        shadow: Colors.black12,
      ),
      
      // Inter font family throughout the app
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: _lightForeground,
          height: 1.2,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: _lightForeground,
          height: 1.2,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: _lightForeground,
          height: 1.3,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _lightForeground,
          height: 1.3,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _lightForeground,
          height: 1.4,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _lightForeground,
          height: 1.4,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: _lightForeground,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: _lightForeground,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: _lightMutedForeground,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _lightForeground,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _lightForeground,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _lightMutedForeground,
        ),
      ),

      // Button themes with ShadCN UI styling
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lightPrimary,
          foregroundColor: _lightPrimaryForeground,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: spacing4,
            vertical: spacing2,
          ),
          minimumSize: const Size(0, 40),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _lightForeground,
          backgroundColor: _lightBackground,
          side: const BorderSide(color: _lightBorder),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: spacing4,
            vertical: spacing2,
          ),
          minimumSize: const Size(0, 40),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _lightPrimary,
          backgroundColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: spacing4,
            vertical: spacing2,
          ),
          minimumSize: const Size(0, 40),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: _lightInput),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: _lightInput),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: _lightRing, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: _lightDestructive),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: _lightDestructive, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacing3,
          vertical: spacing2,
        ),
        hintStyle: GoogleFonts.inter(
          color: _lightMutedForeground,
          fontSize: 14,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: _lightCard,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: _lightBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: _lightBackground,
        foregroundColor: _lightForeground,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _lightForeground,
        ),
        iconTheme: const IconThemeData(
          color: _lightForeground,
          size: 24,
        ),
      ),

      // Bottom navigation theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _lightBackground,
        selectedItemColor: _lightPrimary,
        unselectedItemColor: _lightMutedForeground,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Divider theme
      dividerTheme: const DividerThemeData(
        color: _lightBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBackground,
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: _darkPrimary,
        onPrimary: _darkPrimaryForeground,
        secondary: _darkSecondary,
        onSecondary: _darkSecondaryForeground,
        tertiary: _darkAccent,
        onTertiary: _darkAccentForeground,
        surface: _darkCard,
        onSurface: _darkCardForeground,
        background: _darkBackground,
        onBackground: _darkForeground,
        error: _darkDestructive,
        onError: _darkDestructiveForeground,
        outline: _darkBorder,
        shadow: Colors.black26,
        surfaceVariant: _darkSurfaceVariant,
        onSurfaceVariant: _darkOnSurfaceVariant,
      ),
      
      // Inter font family throughout the app
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: _darkForeground,
          height: 1.2,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: _darkForeground,
          height: 1.2,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: _darkForeground,
          height: 1.3,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _darkForeground,
          height: 1.3,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _darkForeground,
          height: 1.4,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _darkForeground,
          height: 1.4,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: _darkForeground,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: _darkForeground,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: _darkMutedForeground,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _darkForeground,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _darkForeground,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _darkMutedForeground,
        ),
      ),

      // Button themes with ShadCN UI styling
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkPrimary,
          foregroundColor: _darkPrimaryForeground,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: spacing4,
            vertical: spacing2,
          ),
          minimumSize: const Size(0, 40),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkForeground,
          backgroundColor: _darkBackground,
          side: const BorderSide(color: _darkBorder),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: spacing4,
            vertical: spacing2,
          ),
          minimumSize: const Size(0, 40),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _darkPrimary,
          backgroundColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: spacing4,
            vertical: spacing2,
          ),
          minimumSize: const Size(0, 40),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius3xl),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius3xl),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius3xl),
          borderSide: const BorderSide(color: _darkRing, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius3xl),
          borderSide: const BorderSide(color: _darkDestructive),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius3xl),
          borderSide: const BorderSide(color: _darkDestructive, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacing4,
          vertical: spacing3,
        ),
        hintStyle: GoogleFonts.inter(
          color: _darkMutedForeground,
          fontSize: 14,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: _darkCard,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: _darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: _darkBackground,
        foregroundColor: _darkForeground,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withOpacity(0.2),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _darkForeground,
        ),
        iconTheme: const IconThemeData(
          color: _darkForeground,
          size: 24,
        ),
      ),

      // Bottom navigation theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _darkBackground,
        selectedItemColor: _darkPrimary,
        unselectedItemColor: _darkMutedForeground,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Divider theme
      dividerTheme: const DividerThemeData(
        color: _darkBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // Helper methods for accessing design tokens
  static Color getColor(BuildContext context, String colorName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    switch (colorName) {
      case 'background':
        return isDark ? _darkBackground : _lightBackground;
      case 'foreground':
        return isDark ? _darkForeground : _lightForeground;
      case 'card':
        return isDark ? _darkCard : _lightCard;
      case 'cardForeground':
        return isDark ? _darkCardForeground : _lightCardForeground;
      case 'primary':
        return isDark ? _darkPrimary : _lightPrimary;
      case 'primaryForeground':
        return isDark ? _darkPrimaryForeground : _lightPrimaryForeground;
      case 'secondary':
        return isDark ? _darkSecondary : _lightSecondary;
      case 'secondaryForeground':
        return isDark ? _darkSecondaryForeground : _lightSecondaryForeground;
      case 'muted':
        return isDark ? _darkMuted : _lightMuted;
      case 'mutedForeground':
        return isDark ? _darkMutedForeground : _lightMutedForeground;
      case 'accent':
        return isDark ? _darkAccent : _lightAccent;
      case 'accentForeground':
        return isDark ? _darkAccentForeground : _lightAccentForeground;
      case 'destructive':
        return isDark ? _darkDestructive : _lightDestructive;
      case 'destructiveForeground':
        return isDark ? _darkDestructiveForeground : _lightDestructiveForeground;
      case 'border':
        return isDark ? _darkBorder : _lightBorder;
      case 'input':
        return isDark ? _darkInput : _lightInput;
      case 'ring':
        return isDark ? _darkRing : _lightRing;
      case 'success':
        return successColor;
      case 'warning':
        return warningColor;
      case 'info':
        return infoColor;
      default:
        return isDark ? _darkForeground : _lightForeground;
    }
  }

  // Typography helpers
  static TextStyle getTextStyle(BuildContext context, String styleName) {
    final textTheme = Theme.of(context).textTheme;
    
    switch (styleName) {
      case 'h1':
        return textTheme.displayLarge!;
      case 'h2':
        return textTheme.displayMedium!;
      case 'h3':
        return textTheme.displaySmall!;
      case 'h4':
        return textTheme.headlineLarge!;
      case 'h5':
        return textTheme.headlineMedium!;
      case 'h6':
        return textTheme.headlineSmall!;
      case 'body':
        return textTheme.bodyMedium!;
      case 'bodyLarge':
        return textTheme.bodyLarge!;
      case 'bodySmall':
        return textTheme.bodySmall!;
      case 'label':
        return textTheme.labelMedium!;
      case 'labelLarge':
        return textTheme.labelLarge!;
      case 'labelSmall':
        return textTheme.labelSmall!;
      default:
        return textTheme.bodyMedium!;
    }
  }

  // Shadow helpers for consistent elevation
  static List<BoxShadow> getShadow(String level) {
    switch (level) {
      case 'sm':
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ];
      case 'md':
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ];
      case 'lg':
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ];
      case 'xl':
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ];
      default:
        return [];
    }
  }

  // Border radius helpers
  static BorderRadius getBorderRadius(String size) {
    switch (size) {
      case 'xs':
        return BorderRadius.circular(radiusXs);
      case 'sm':
        return BorderRadius.circular(radiusSm);
      case 'md':
        return BorderRadius.circular(radiusMd);
      case 'lg':
        return BorderRadius.circular(radiusLg);
      case 'xl':
        return BorderRadius.circular(radiusXl);
      case '2xl':
        return BorderRadius.circular(radius2xl);
      case '3xl':
        return BorderRadius.circular(radius3xl);
      default:
        return BorderRadius.circular(radiusMd);
    }
  }

  // Spacing helpers
  static double getSpacing(int multiplier) {
    return spacing1 * multiplier;
  }

  static EdgeInsets getPadding(String size) {
    switch (size) {
      case 'xs':
        return EdgeInsets.all(spacing1);
      case 'sm':
        return EdgeInsets.all(spacing2);
      case 'md':
        return EdgeInsets.all(spacing3);
      case 'lg':
        return EdgeInsets.all(spacing4);
      case 'xl':
        return EdgeInsets.all(spacing6);
      case '2xl':
        return EdgeInsets.all(spacing8);
      default:
        return EdgeInsets.all(spacing4);
    }
  }

  static EdgeInsets getMargin(String size) {
    switch (size) {
      case 'xs':
        return EdgeInsets.all(spacing1);
      case 'sm':
        return EdgeInsets.all(spacing2);
      case 'md':
        return EdgeInsets.all(spacing3);
      case 'lg':
        return EdgeInsets.all(spacing4);
      case 'xl':
        return EdgeInsets.all(spacing6);
      case '2xl':
        return EdgeInsets.all(spacing8);
      default:
        return EdgeInsets.all(spacing4);
    }
  }
}