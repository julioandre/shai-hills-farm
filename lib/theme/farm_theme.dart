import 'package:flutter/material.dart';

const farmSand = Color(0xFFF4EFE6);
const farmPaper = Color(0xFFFFFBF5);
const farmInk = Color(0xFF1C2B24);
const farmLeaf = Color(0xFF1F4D3A);
const farmLine = Color(0xFFE4D9C8);

ThemeData farmTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: farmLeaf).copyWith(
    primary: farmLeaf,
    onPrimary: farmPaper,
    secondary: const Color(0xFF8C4A32),
    onSecondary: farmPaper,
    surface: farmPaper,
    error: const Color(0xFF8E2F2F),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: farmSand,
    textTheme: base.textTheme.apply(bodyColor: farmInk, displayColor: farmInk),
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
      indicatorColor: const Color(0xFFD5E6DB),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    dividerTheme: const DividerThemeData(color: farmLine, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );
}
