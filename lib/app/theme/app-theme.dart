import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A7EA4)),
      useMaterial3: true,
    );
  }
}
