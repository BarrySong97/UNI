import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/reader-preferences-entity.dart';
import 'package:uni/services/reader/reader-theme-service.dart';

void main() {
  test('buildPaginationTextStyle maps preferences consistently', () {
    final service = ReaderThemeService();
    const prefs = ReaderPreferencesEntity(
      bookId: 'book-1',
      fontSize: 22,
      lineHeightLevel: 2,
      letterSpacing: 0.35,
      textColor: Color(0xFF112233),
      fontFamily: 'sans',
    );

    final style = service.buildPaginationTextStyle(prefs);

    expect(style.fontSize, 22);
    expect(style.height, 1.95);
    expect(style.letterSpacing, 0.35);
    expect(style.color?.toARGB32(), const Color(0xFF112233).toARGB32());
    expect(style.fontFamily, isNull);
  });

  test('horizontalPadding maps level values', () {
    final service = ReaderThemeService();

    expect(service.horizontalPadding(0), 12);
    expect(service.horizontalPadding(1), 20);
    expect(service.horizontalPadding(2), 30);
  });
}
