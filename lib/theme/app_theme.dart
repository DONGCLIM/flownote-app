import 'package:flutter/material.dart';

class AppColors {
  // Primary palette - Minimalist Scandinavian + Florist
  static const Color background = Color(0xFFFAF9F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F3EF);

  // Accent colors - Dusty Rose & Lavender
  static const Color primary = Color(0xFFB8756A); // Dusty Rose
  static const Color primaryLight = Color(0xFFD4948A);
  static const Color primaryDark = Color(0xFF8D5A51);

  static const Color secondary = Color(0xFF9B8DB4); // Soft Lavender
  static const Color secondaryLight = Color(0xFFB8ADCF);
  static const Color secondaryDark = Color(0xFF7A6B93);

  // Sage green accent (from Style 1 calendar)
  static const Color accent = Color(0xFF7A9E7E); // Sage Green
  static const Color accentLight = Color(0xFF9DB89F);
  static const Color accentDark = Color(0xFF5B7D5F);

  // Text colors
  static const Color textPrimary = Color(0xFF2C2825);
  static const Color textSecondary = Color(0xFF6B6560);
  static const Color textHint = Color(0xFFA8A4A0);

  // Border & divider
  static const Color border = Color(0xFFE8E4E0);
  static const Color divider = Color(0xFFF0EDE9);

  // Calendar specific
  static const Color calendarSelected = Color(0xFFB8756A);
  static const Color calendarToday = Color(0xFF9B8DB4);
  static const Color calendarMarker = Color(0xFF7A9E7E);

  // Status colors
  static const Color success = Color(0xFF7A9E7E);
  static const Color warning = Color(0xFFD4A843);
  static const Color error = Color(0xFFBF5858);

  // Scan limit indicator
  static const Color scanFree = Color(0xFF7A9E7E);
  static const Color scanLow = Color(0xFFD4A843);
  static const Color scanEmpty = Color(0xFFBF5858);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Georgia',
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        tertiary: AppColors.accent,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceVariant,
        outline: AppColors.border,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontFamily: 'Georgia',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        hintStyle: const TextStyle(
          color: AppColors.textHint,
          fontSize: 14,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        labelStyle: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
}
