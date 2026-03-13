import 'package:flutter/painting.dart';

import '../models/render_node.dart';
import '../models/reader_preferences.dart';

/// Converts a list of child RenderNodes (from a Paragraph or Heading) into a
/// Flutter [TextSpan] tree ready for TextPainter measurement and rendering.
class TextSpanBuilder {
  const TextSpanBuilder._();

  /// Default heading font size scales when CSS does not specify one.
  static const Map<int, double> headingScaleEm = {
    1: 2.0,
    2: 1.5,
    3: 1.25,
    4: 1.125,
    5: 1.0,
    6: 0.875,
  };

  /// Build a [TextSpan] from a list of [RenderNode] children.
  ///
  /// [headingLevel] if non-null applies default heading scale to TextNodes
  /// whose fontSizeEm is 1.0 (no CSS override).
  static TextSpan build({
    required List<RenderNode> children,
    required ReaderPreferences prefs,
    int? headingLevel,
    double? lineHeightOverride,
  }) {
    final spans = <InlineSpan>[];
    for (final child in children) {
      _buildSpan(child, prefs, headingLevel, lineHeightOverride, spans);
    }
    return TextSpan(children: spans);
  }

  static void _buildSpan(
    RenderNode node,
    ReaderPreferences prefs,
    int? headingLevel,
    double? lineHeightOverride,
    List<InlineSpan> out,
  ) {
    switch (node) {
      case TextNode():
        out.add(_textNodeToSpan(node, prefs, headingLevel, lineHeightOverride));
      case LineBreakNode():
        out.add(const TextSpan(text: '\n'));
      case ImageNode():
        // Inline images are replaced with alt text placeholder.
        if (node.alt != null && node.alt!.isNotEmpty) {
          out.add(
            TextSpan(
              text: '[${node.alt}]',
              style: TextStyle(
                fontSize: prefs.baseFontSizePx,
                fontStyle: FontStyle.italic,
                color: prefs.theme.textColor.withValues(alpha: 0.5),
              ),
            ),
          );
        }
      default:
        break;
    }
  }

  static TextSpan _textNodeToSpan(
    TextNode node,
    ReaderPreferences prefs,
    int? headingLevel,
    double? lineHeightOverride,
  ) {
    var fontSizeEm = node.fontSizeEm;

    // Apply heading default scale when CSS didn't set one.
    if (headingLevel != null && fontSizeEm == 1.0) {
      fontSizeEm = headingScaleEm[headingLevel] ?? 1.0;
    }

    final effectiveLineHeight =
        lineHeightOverride ?? prefs.lineHeightMultiplier;

    final color = node.color != null
        ? Color(node.color!)
        : prefs.theme.textColor;

    final decorations = <TextDecoration>[];
    if (node.underline) decorations.add(TextDecoration.underline);
    if (node.lineThrough) decorations.add(TextDecoration.lineThrough);

    return TextSpan(
      text: node.content,
      style: TextStyle(
        fontSize: prefs.emToPx(fontSizeEm),
        fontWeight: (node.bold || headingLevel != null)
            ? FontWeight.bold
            : FontWeight.normal,
        fontStyle: node.italic ? FontStyle.italic : FontStyle.normal,
        decoration: decorations.isEmpty
            ? TextDecoration.none
            : TextDecoration.combine(decorations),
        color: color,
        fontFamily: prefs.fontFamily,
        height: effectiveLineHeight,
      ),
    );
  }
}
