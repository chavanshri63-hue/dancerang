import 'package:flutter/material.dart';

class AppTheme {
  // Brand palette
  static const Color red = Color(0xFFE53935);
  static const Color bg = Color(0xFF101114);
  static const Color card = Color(0xFF1B1D22);
  static const Color cardLight = Color(0xFF272A31);
  static const Color cardBg = Color(0xFF1B1D22);
  static const Color stroke = Color(0xFF2B2E35); // thin divider/border color

  // -------- LIGHT --------
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: red, brightness: Brightness.light),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: red,
          unselectedItemColor: Colors.black54,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
        ),
      );

  // -------- DARK --------
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: red, brightness: Brightness.dark),
        scaffoldBackgroundColor: bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: card,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: bg,
          selectedItemColor: red,
          unselectedItemColor: Colors.white70,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
        ),
      );

  // --- Aliases so both names work everywhere ---
  static ThemeData get lightTheme => light;
  static ThemeData get darkTheme  => dark;
}