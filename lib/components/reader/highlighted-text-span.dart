import 'package:flutter/material.dart';

import '../../entities/highlight-entity.dart';
import '../../services/highlight/highlight-resolver-service.dart';

class HighlightedTextSpanBuilder {
  HighlightedTextSpanBuilder({HighlightResolverService? resolverService})
      : _resolverService = resolverService ?? HighlightResolverService();

  final HighlightResolverService _resolverService;

  List<InlineSpan> build({
    required String text,
    required List<HighlightEntity> highlights,
    required TextStyle? baseStyle,
  }) {
    if (text.isEmpty || highlights.isEmpty) {
      return <InlineSpan>[TextSpan(text: text, style: baseStyle)];
    }

    final sorted = _resolverService.sortForRender(highlights);
    final buffer = <InlineSpan>[];
    var pointer = 0;

    for (final highlight in sorted) {
      final resolved = _resolverService.relocateByContext(chapterText: text, highlight: highlight);
      final start = resolved.start.clamp(0, text.length);
      final end = resolved.end.clamp(start, text.length);

      if (start > pointer) {
        buffer.add(TextSpan(text: text.substring(pointer, start), style: baseStyle));
      }

      if (end > start) {
        buffer.add(
          TextSpan(
            text: text.substring(start, end),
            style: baseStyle?.copyWith(backgroundColor: _parseColor(highlight.color)),
          ),
        );
      }
      pointer = end > pointer ? end : pointer;
    }

    if (pointer < text.length) {
      buffer.add(TextSpan(text: text.substring(pointer), style: baseStyle));
    }

    return buffer;
  }

  Color _parseColor(String hex) {
    final normalized = hex.replaceFirst('#', '');
    final value = normalized.length == 6 ? 'FF$normalized' : normalized;
    return Color(int.parse(value, radix: 16));
  }
}
