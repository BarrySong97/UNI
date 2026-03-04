import 'package:flutter/material.dart';

class ReaderPreferencesEntity {
  const ReaderPreferencesEntity({
    required this.bookId,
    this.fontSize = 19,
    this.pagePaddingLevel = 1,
    this.lineHeightLevel = 1,
    this.letterSpacing = 0,
    this.textColor = const Color(0xFF0E0E0E),
    this.backgroundColor = const Color(0xFFF2F2F2),
    this.brightness = 0,
    this.fontFamily = 'serif',
    this.firstLineIndent = true,
    this.pageTurnMode = 'horizontal',
  });

  final String bookId;
  final double fontSize;
  final int pagePaddingLevel;
  final int lineHeightLevel;
  final double letterSpacing;
  final Color textColor;
  final Color backgroundColor;
  final double brightness;
  final String fontFamily;
  final bool firstLineIndent;
  final String pageTurnMode;

  ReaderPreferencesEntity copyWith({
    String? bookId,
    double? fontSize,
    int? pagePaddingLevel,
    int? lineHeightLevel,
    double? letterSpacing,
    Color? textColor,
    Color? backgroundColor,
    double? brightness,
    String? fontFamily,
    bool? firstLineIndent,
    String? pageTurnMode,
  }) {
    return ReaderPreferencesEntity(
      bookId: bookId ?? this.bookId,
      fontSize: fontSize ?? this.fontSize,
      pagePaddingLevel: pagePaddingLevel ?? this.pagePaddingLevel,
      lineHeightLevel: lineHeightLevel ?? this.lineHeightLevel,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      brightness: brightness ?? this.brightness,
      fontFamily: fontFamily ?? this.fontFamily,
      firstLineIndent: firstLineIndent ?? this.firstLineIndent,
      pageTurnMode: pageTurnMode ?? this.pageTurnMode,
    );
  }

  static ReaderPreferencesEntity defaultsForBook(String bookId) {
    return ReaderPreferencesEntity(bookId: bookId);
  }
}
