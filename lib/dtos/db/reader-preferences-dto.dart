import 'package:flutter/material.dart';

import '../../entities/reader-preferences-entity.dart';

class ReaderPreferencesDto {
  const ReaderPreferencesDto({
    required this.bookId,
    required this.fontSize,
    required this.pagePaddingLevel,
    required this.lineHeightLevel,
    required this.letterSpacing,
    required this.textColorValue,
    required this.backgroundColorValue,
    required this.brightness,
    required this.fontFamily,
    required this.firstLineIndent,
    required this.pageTurnMode,
  });

  final String bookId;
  final double fontSize;
  final int pagePaddingLevel;
  final int lineHeightLevel;
  final double letterSpacing;
  final int textColorValue;
  final int backgroundColorValue;
  final double brightness;
  final String fontFamily;
  final int firstLineIndent;
  final String pageTurnMode;

  ReaderPreferencesEntity toEntity() {
    return ReaderPreferencesEntity(
      bookId: bookId,
      fontSize: fontSize,
      pagePaddingLevel: pagePaddingLevel,
      lineHeightLevel: lineHeightLevel,
      letterSpacing: letterSpacing,
      textColor: Color(textColorValue),
      backgroundColor: Color(backgroundColorValue),
      brightness: brightness,
      fontFamily: fontFamily,
      firstLineIndent: firstLineIndent == 1,
      pageTurnMode: pageTurnMode,
    );
  }

  factory ReaderPreferencesDto.fromEntity(ReaderPreferencesEntity entity) {
    return ReaderPreferencesDto(
      bookId: entity.bookId,
      fontSize: entity.fontSize,
      pagePaddingLevel: entity.pagePaddingLevel,
      lineHeightLevel: entity.lineHeightLevel,
      letterSpacing: entity.letterSpacing,
      textColorValue: entity.textColor.toARGB32(),
      backgroundColorValue: entity.backgroundColor.toARGB32(),
      brightness: entity.brightness,
      fontFamily: entity.fontFamily,
      firstLineIndent: entity.firstLineIndent ? 1 : 0,
      pageTurnMode: entity.pageTurnMode,
    );
  }
}
