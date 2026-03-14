import 'dart:ui' show Color;

class ReaderPreferences {
  const ReaderPreferences({
    this.baseFontSizePx = 18.0,
    this.fontFamily,
    this.pageHorizontalPaddingPx = 24.0,
    this.pageVerticalPaddingPx = 40.0,
    this.lineHeightMultiplier = 1.6,
    this.paragraphSpacingMultiplier = 1.0,
    this.theme = ReaderTheme.light,
  });

  final double baseFontSizePx;
  final String? fontFamily;
  final double pageHorizontalPaddingPx;
  final double pageVerticalPaddingPx;
  final double lineHeightMultiplier;
  final double paragraphSpacingMultiplier;
  final ReaderTheme theme;

  /// Convert em units to logical pixels.
  double emToPx(double em) => em * baseFontSizePx;

  /// Use [clearFontFamily] = true to reset [fontFamily] to null (system default).
  ReaderPreferences copyWith({
    double? baseFontSizePx,
    String? fontFamily,
    bool clearFontFamily = false,
    double? pageHorizontalPaddingPx,
    double? pageVerticalPaddingPx,
    double? lineHeightMultiplier,
    double? paragraphSpacingMultiplier,
    ReaderTheme? theme,
  }) {
    return ReaderPreferences(
      baseFontSizePx: baseFontSizePx ?? this.baseFontSizePx,
      fontFamily: clearFontFamily ? null : (fontFamily ?? this.fontFamily),
      pageHorizontalPaddingPx:
          pageHorizontalPaddingPx ?? this.pageHorizontalPaddingPx,
      pageVerticalPaddingPx:
          pageVerticalPaddingPx ?? this.pageVerticalPaddingPx,
      lineHeightMultiplier: lineHeightMultiplier ?? this.lineHeightMultiplier,
      paragraphSpacingMultiplier:
          paragraphSpacingMultiplier ?? this.paragraphSpacingMultiplier,
      theme: theme ?? this.theme,
    );
  }

  /// Hash used for pagination cache invalidation.
  int get layoutHash => Object.hash(
    baseFontSizePx,
    fontFamily,
    pageHorizontalPaddingPx,
    pageVerticalPaddingPx,
    lineHeightMultiplier,
    paragraphSpacingMultiplier,
  );
}

enum ReaderTheme {
  light(
    backgroundColor: Color(0xFFFFFFFF),
    textColor: Color(0xFF1A1A1A),
    name: 'Light',
  ),
  sepia(
    backgroundColor: Color(0xFFF5EDDC),
    textColor: Color(0xFF3B2F1E),
    name: 'Sepia',
  ),
  dark(
    backgroundColor: Color(0xFF1A1A1A),
    textColor: Color(0xFFD4D4D4),
    name: 'Dark',
  );

  const ReaderTheme({
    required this.backgroundColor,
    required this.textColor,
    required this.name,
  });

  final Color backgroundColor;
  final Color textColor;
  final String name;
}
