import 'package:flutter/material.dart';

import '../../entities/highlight-entity.dart';

/// Legacy span builder kept for API compatibility.
/// Readium now handles highlight rendering via decorations.
class HighlightedTextSpanBuilder {
  List<InlineSpan> build({
    required String text,
    required List<HighlightEntity> highlights,
    required TextStyle? baseStyle,
  }) {
    return <InlineSpan>[TextSpan(text: text, style: baseStyle)];
  }
}
