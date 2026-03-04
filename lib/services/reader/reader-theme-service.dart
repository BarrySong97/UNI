import 'package:flutter/material.dart';

import '../../entities/reader-preferences-entity.dart';

class ReaderThemeService {
  TextStyle buildPaginationTextStyle(ReaderPreferencesEntity preferences) {
    return TextStyle(
      fontSize: preferences.fontSize,
      height: lineHeight(preferences.lineHeightLevel),
      letterSpacing: preferences.letterSpacing,
      color: preferences.textColor,
      fontFamily: fontFamily(preferences.fontFamily),
    );
  }

  TextStyle buildRenderTextStyle({
    required ReaderPreferencesEntity preferences,
    required TextStyle fallback,
  }) {
    return fallback.copyWith(
      fontSize: preferences.fontSize,
      color: preferences.textColor,
      height: lineHeight(preferences.lineHeightLevel),
      letterSpacing: preferences.letterSpacing,
      fontFamily: fontFamily(preferences.fontFamily),
    );
  }

  double horizontalPadding(int level) {
    return switch (level) {
      0 => 12,
      2 => 30,
      _ => 20,
    };
  }

  double lineHeight(int level) {
    return switch (level) {
      0 => 1.45,
      2 => 1.95,
      _ => 1.7,
    };
  }

  String? fontFamily(String value) {
    return switch (value) {
      'sans' => null,
      _ => 'serif',
    };
  }
}
