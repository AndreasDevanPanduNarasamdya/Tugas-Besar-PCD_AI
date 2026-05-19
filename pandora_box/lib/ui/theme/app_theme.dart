import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Colors - exact from mockup
  static const Color darkBackground = Color(0xFF0D0D0D);
  static const Color cardBackground = Color(0xFF1A1A1A);
  static const Color cardBorder = Color(0xFF2A2A2A);
  static const Color primaryRed = Color(0xFFE50914);
  static const Color textWhite = Colors.white;
  static const Color textGrey = Color(0xFFAAAAAA);
  static const Color textDarkGrey = Color(0xFF666666);
  static const Color accentGreen = Color(0xFF00FF41);
  static const Color accentMagenta = Color(0xFFFF00FF);
  static const Color bottomNavBg = Color(0xFF111111);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: primaryRed,
      colorScheme: const ColorScheme.dark(
        primary: primaryRed,
        surface: cardBackground,
        background: darkBackground,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: primaryRed),
        titleTextStyle: TextStyle(
          color: textWhite,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: textWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textWhite,
          side: const BorderSide(color: cardBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            color: textWhite, fontWeight: FontWeight.bold, fontSize: 28),
        headlineMedium: TextStyle(
            color: textWhite, fontWeight: FontWeight.bold, fontSize: 22),
        titleLarge: TextStyle(
            color: textWhite, fontWeight: FontWeight.bold, fontSize: 18),
        titleMedium: TextStyle(
            color: textWhite, fontWeight: FontWeight.w600, fontSize: 15),
        bodyLarge: TextStyle(color: textWhite, fontSize: 14),
        bodyMedium: TextStyle(color: textGrey, fontSize: 12),
        labelSmall: TextStyle(color: textDarkGrey, fontSize: 10),
      ),
    );
  }
}
