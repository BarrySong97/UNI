import 'dart:ui' show Color;

import '../../../entities/annotation-entity.dart';
import '../../../shared/constants/reader-constants.dart';

class ReaderPreferences {
  const ReaderPreferences({
    this.baseFontSizePx = 18.0,
    this.fontFamily,
    this.pageHorizontalPaddingPx = 24.0,
    this.pageVerticalPaddingPx = 40.0,
    this.lineHeightMultiplier = 1.6,
    this.paragraphSpacingMultiplier = 1.0,
    this.theme = ReaderTheme.light,
    this.defaultMarkColor = ReaderConstants.defaultHighlightColor,
    this.defaultMarkStyle = AnnotationStyle.highlight,
  });

  final double baseFontSizePx;
  final String? fontFamily;
  final double pageHorizontalPaddingPx;
  final double pageVerticalPaddingPx;
  final double lineHeightMultiplier;
  final double paragraphSpacingMultiplier;
  final ReaderTheme theme;
  final String defaultMarkColor;
  final AnnotationStyle defaultMarkStyle;

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
    String? defaultMarkColor,
    AnnotationStyle? defaultMarkStyle,
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
      defaultMarkColor: defaultMarkColor ?? this.defaultMarkColor,
      defaultMarkStyle: defaultMarkStyle ?? this.defaultMarkStyle,
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

  Map<String, dynamic> toJson() => {
    'baseFontSizePx': baseFontSizePx,
    'fontFamily': fontFamily,
    'pageHorizontalPaddingPx': pageHorizontalPaddingPx,
    'pageVerticalPaddingPx': pageVerticalPaddingPx,
    'lineHeightMultiplier': lineHeightMultiplier,
    'paragraphSpacingMultiplier': paragraphSpacingMultiplier,
    'theme': theme.name,
    'defaultMarkColor': defaultMarkColor,
    'defaultMarkStyle': defaultMarkStyle.name,
  };

  factory ReaderPreferences.fromJson(Map<String, dynamic> json) {
    return ReaderPreferences(
      baseFontSizePx: (json['baseFontSizePx'] as num?)?.toDouble() ?? 18.0,
      fontFamily: json['fontFamily'] as String?,
      pageHorizontalPaddingPx:
          (json['pageHorizontalPaddingPx'] as num?)?.toDouble() ?? 24.0,
      pageVerticalPaddingPx:
          (json['pageVerticalPaddingPx'] as num?)?.toDouble() ?? 40.0,
      lineHeightMultiplier:
          (json['lineHeightMultiplier'] as num?)?.toDouble() ?? 1.6,
      paragraphSpacingMultiplier:
          (json['paragraphSpacingMultiplier'] as num?)?.toDouble() ?? 1.0,
      defaultMarkColor:
          json['defaultMarkColor'] as String? ??
          ReaderConstants.defaultHighlightColor,
      defaultMarkStyle: _annotationStyleFromName(
        json['defaultMarkStyle'] as String?,
      ),
      theme: ReaderTheme.values.firstWhere(
        (t) => t.name == json['theme'],
        orElse: () => ReaderTheme.light,
      ),
    );
  }
}

AnnotationStyle _annotationStyleFromName(String? raw) {
  return switch (raw) {
    'underline' => AnnotationStyle.underline,
    'highlight' => AnnotationStyle.highlight,
    _ => AnnotationStyle.highlight,
  };
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
  mint(
    backgroundColor: Color(0xFFE8F5E9),
    textColor: Color(0xFF2E3D30),
    name: 'Mint',
  ),
  rose(
    backgroundColor: Color(0xFFFCE4EC),
    textColor: Color(0xFF3D2B30),
    name: 'Rose',
  ),
  paper(
    backgroundColor: Color(0xFFF5F0E8),
    textColor: Color(0xFF33302B),
    name: 'Paper',
  ),
  dusk(
    backgroundColor: Color(0xFF2C3E50),
    textColor: Color(0xFFD5DDE5),
    name: 'Dusk',
    isDark: true,
  ),
  dark(
    backgroundColor: Color(0xFF1A1A1A),
    textColor: Color(0xFFD4D4D4),
    name: 'Dark',
    isDark: true,
  ),
  night(
    backgroundColor: Color(0xFF000000),
    textColor: Color(0xFFB0B0B0),
    name: 'Night',
    isDark: true,
  );

  const ReaderTheme({
    required this.backgroundColor,
    required this.textColor,
    required this.name,
    this.isDark = false,
  });

  final Color backgroundColor;
  final Color textColor;
  final String name;
  final bool isDark;
}
