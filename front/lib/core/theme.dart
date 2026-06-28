import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF6366F1); // Indigo
  static const Color secondaryColor = Color(0xFFEC4899); // Pink
  static const Color backgroundColor = Color(0xFF0F172A); // Dark Slate
  static const Color surfaceColor = Color(0xFF1E293B); // Slate Blue
  static const Color textPrimaryColor = Color(0xFFF8FAFC); // White/Slate 50
  static const Color textSecondaryColor = Color(0xFF94A3B8); // Slate 400
  static const Color accentColor = Color(0xFFF43F5E); // Rose

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: accentColor,
      ),
      cardTheme: CardTheme(
        color: surfaceColor.withOpacity(0.85),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: backgroundColor,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: primaryColor.withOpacity(0.2)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: primaryColor.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textSecondaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimaryColor),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimaryColor, letterSpacing: 0.15),
        bodyLarge: TextStyle(fontSize: 16, color: textPrimaryColor, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, color: textSecondaryColor, height: 1.43),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimaryColor),
      ),
    );
  }
}
