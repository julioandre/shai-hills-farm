import 'package:flutter/material.dart';

/// Field green, gold ring, barn red, and wordmark brown from the farm logo.
const farmSand = Color(0xFFF6F1E6);
const farmPaper = Color(0xFFFFFCF7);
const farmInk = Color(0xFF3E2914);
const farmLeaf = Color(0xFF007A33);
const farmGold = Color(0xFFCF8724);
const farmBarn = Color(0xFFCF2A2A);
const farmBrown = Color(0xFF8C4A07);
const farmSky = Color(0xFF00B4E6);
const farmLine = Color(0xFFE6D7C3);
const farmMist = Color(0xFFE5F3E8);

ThemeData farmTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: farmLeaf).copyWith(
    primary: farmLeaf,
    onPrimary: farmPaper,
    secondary: farmGold,
    onSecondary: farmInk,
    tertiary: farmSky,
    surface: farmPaper,
    error: farmBarn,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final textTheme = base.textTheme
      .apply(bodyColor: farmInk, displayColor: farmInk)
      .copyWith(
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontSize: 18,
          height: 1.35,
          color: farmInk,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: 16,
          height: 1.4,
          color: farmInk,
        ),
      );
  return base.copyWith(
    scaffoldBackgroundColor: farmSand,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: farmSand,
      foregroundColor: farmInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: farmPaper,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: farmLine),
      ),
    ),
    inputDecorationTheme: const InputDecorationThemeData(
      filled: true,
      fillColor: farmPaper,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: farmLine),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: farmPaper,
      indicatorColor: farmMist,
      height: 72,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: farmPaper,
      indicatorColor: farmMist,
      labelType: NavigationRailLabelType.all,
      minWidth: 88,
    ),
    chipTheme: base.chipTheme.copyWith(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    dividerTheme: const DividerThemeData(color: farmLine, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
  );
}
