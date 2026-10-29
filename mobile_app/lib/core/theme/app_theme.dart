import 'package:flutter/material.dart';

class AppTheme {
  // JJAASS Water Market Logo Brand Colors
  // Deep Navy from "JJAASS" wordmark & upper wave
  static const Color navyColor = Color(0xFF0F2B5C);
  // Rich Azure / Cornflower Blue from water droplet, lower wave & "WATER MARKET"
  static const Color primaryColor = Color(0xFF1D63B8);
  static const Color secondaryColor = Color(0xFF4788D7);
  static const Color accentColor = Color(0xFF0284C7);

  // High-contrast layout & surface colors (inspired by logo's crisp cool-light backdrop)
  static const Color lightBg = Color(0xFFF1F5F9); // Soft cool slate background for card contrast
  static const Color lightSurface = Colors.white;
  static const Color lightText = Color(0xFF0F2B5C); // Deep Navy for maximum readability
  static const Color bodyText = Color(0xFF1E293B); // Slate 800
  static const Color mutedText = Color(0xFF475569); // Slate 600 (readable muted text)
  static const Color borderColor = Color(0xFFCBD5E1); // Clear Slate 300 border

  // Dark theme fallbacks mapped to high-contrast light/navy palette to prevent white-on-white issues
  static const Color darkBg = Color(0xFFF1F5F9);
  static const Color darkSurface = Colors.white;
  static const Color darkText = Color(0xFF0F2B5C);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      highlightColor: const Color(0xFFE0F2FE),
      splashColor: const Color(0xFFBAE6FD),
      colorScheme: const ColorScheme.light(
        primary: navyColor,
        secondary: primaryColor,
        tertiary: secondaryColor,
        surface: lightSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: bodyText,
      ),
      scaffoldBackgroundColor: lightBg,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: navyColor, fontWeight: FontWeight.w900),
        headlineMedium: TextStyle(color: navyColor, fontWeight: FontWeight.w800),
        headlineSmall: TextStyle(color: navyColor, fontWeight: FontWeight.w800),
        titleLarge: TextStyle(color: navyColor, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(color: bodyText, fontWeight: FontWeight.w700),
        titleSmall: TextStyle(color: bodyText, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: bodyText, fontSize: 15, height: 1.4),
        bodyMedium: TextStyle(color: bodyText, fontSize: 14, height: 1.4),
        bodySmall: TextStyle(color: mutedText, fontSize: 12.5, height: 1.35),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: borderColor,
            width: 1.2,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: navyColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navyColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: navyColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
        labelStyle: const TextStyle(
          color: mutedText,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 14,
        ),
        prefixIconColor: primaryColor,
        suffixIconColor: mutedText,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;
}
