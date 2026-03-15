import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Caches measured character and word widths per [TextStyle].
///
/// Uses a structural key (fontSize + fontWeight + fontStyle + fontFamily)
/// instead of [TextStyle.hashCode] for consistent cache hits across
/// equivalent style instances.
///
/// Create one instance per chapter pagination call and discard afterwards,
/// since font parameters may change between paginations.
class WidthCache {
  final Map<String, double> _spaceWidths = {};
  final Map<String, double> _wordWidths = {};

  /// Return the width of a single space character rendered in [style].
  double spaceWidth(TextStyle style) {
    final key = _styleKey(style);
    return _spaceWidths.putIfAbsent(key, () {
      final painter = TextPainter(
        text: TextSpan(text: ' ', style: style),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    });
  }

  /// Return the width of [word] rendered in [style].
  ///
  /// Caches the result so repeated words (e.g. "the", "and") across
  /// paragraphs in the same chapter are measured only once.
  double wordWidth(String word, TextStyle style) {
    final key = '${_styleKey(style)}|$word';
    return _wordWidths.putIfAbsent(key, () {
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    });
  }

  /// Build a canonical string key from the style properties that affect
  /// character width measurement.
  static String _styleKey(TextStyle style) {
    return '${style.fontSize}|${style.fontWeight?.value}|${style.fontStyle?.name}|${style.fontFamily}';
  }
}
