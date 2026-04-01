import 'package:flutter/painting.dart';

import '../models/page_layout.dart';
import '../models/render_node.dart';

class RenderDiffStyleSignature {
  const RenderDiffStyleSignature._();

  static String forLayoutBlock({
    required RenderNode sourceNode,
    required List<LayoutElement> elements,
  }) {
    final textStyle = _firstTextStyle(elements);
    final lineCount = elements.fold<int>(
      0,
      (sum, element) => sum + _lineCountForElement(element),
    );
    final backgroundColor =
        elements.firstWhere(
          (element) => element.backgroundPaint != null,
          orElse: () => elements.first,
        ).backgroundPaint?.color;

    final parts = <String>[
      'node=${sourceNode.runtimeType}',
      'kind=${_blockKind(sourceNode, elements)}',
      if (textStyle != null) 'size=${_double(textStyle.fontSize)}',
      if (textStyle != null) 'weight=${textStyle.fontWeight?.value ?? 400}',
      if (textStyle != null) 'italic=${textStyle.fontStyle == FontStyle.italic}',
      if (textStyle != null) 'underline=${_hasUnderline(textStyle)}',
      if (textStyle != null)
        'strike=${_hasLineThrough(textStyle)}',
      if (textStyle?.color != null) 'color=${_color(textStyle!.color!)}',
      if (backgroundColor != null) 'bg=${_color(backgroundColor)}',
      'lines=$lineCount',
      'text=${elements.any((e) => e.hasText)}',
      'image=${elements.any((e) => e.image != null)}',
    ];
    return parts.join('|');
  }

  static String forReferenceBlock({
    required String nodeType,
    required String kind,
    required double? fontSize,
    required int? fontWeight,
    required bool italic,
    required bool underline,
    required bool strike,
    required String? colorHex,
    required String? backgroundHex,
    required int lineCount,
  }) {
    final parts = <String>[
      'node=$nodeType',
      'kind=$kind',
      if (fontSize != null) 'size=${_double(fontSize)}',
      'weight=${fontWeight ?? 400}',
      'italic=$italic',
      'underline=$underline',
      'strike=$strike',
      if (colorHex != null && colorHex.isNotEmpty) 'color=$colorHex',
      if (backgroundHex != null && backgroundHex.isNotEmpty) 'bg=$backgroundHex',
      'lines=$lineCount',
    ];
    return parts.join('|');
  }

  static String _blockKind(RenderNode node, List<LayoutElement> elements) {
    if (elements.any((element) => element.image != null)) {
      return 'image';
    }
    return switch (node) {
      HeadingNode() => 'heading',
      ParagraphNode() => 'paragraph',
      ListNode() => 'list',
      TableNode() => 'table',
      BlockQuoteNode() => 'blockquote',
      CodeBlockNode() => 'code',
      HorizontalRuleNode() => 'rule',
      ImageNode() => 'image',
      _ => 'text',
    };
  }

  static TextStyle? _firstTextStyle(List<LayoutElement> elements) {
    for (final element in elements) {
      final painter = element.ensurePainter();
      final style = painter?.text?.style;
      if (style != null) {
        return style;
      }
    }
    return null;
  }

  static int _lineCountForElement(LayoutElement element) {
    final painter = element.ensurePainter();
    if (painter == null) {
      return 0;
    }
    return painter.computeLineMetrics().length;
  }

  static bool _hasUnderline(TextStyle style) {
    return style.decoration?.contains(TextDecoration.underline) ?? false;
  }

  static bool _hasLineThrough(TextStyle style) {
    return style.decoration?.contains(TextDecoration.lineThrough) ?? false;
  }

  static String _double(double? value) {
    if (value == null) {
      return '0';
    }
    return value.toStringAsFixed(2);
  }

  static String _color(Color color) {
    return color.toARGB32().toRadixString(16).padLeft(8, '0');
  }
}
