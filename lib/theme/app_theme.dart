import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF111111),
          onSurface: Color(0xFFFFFFFF),
          primary: Color(0xFFFF5252),
          onPrimary: Color(0xFFFFFFFF),
        ),
      );
}
