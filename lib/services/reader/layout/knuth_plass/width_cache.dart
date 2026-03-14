import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Caches measured space-character widths per [TextStyle].
///
/// Uses a structural key (fontSize + fontWeight + fontStyle + fontFamily)
/// instead of [TextStyle.hashCode] for consistent cache hits across
/// equivalent style instances.
///
/// Create one instance per chapter pagination call and discard afterwards,
/// since font parameters may change between paginations.
class WidthCache {
  final Map<String, double> _spaceWidths = {};

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

  /// Build a canonical string key from the style properties that affect
  /// character width measurement.
  static String _styleKey(TextStyle style) {
    return '${style.fontSize}|${style.fontWeight?.value}|${style.fontStyle?.name}|${style.fontFamily}';
  }
}
