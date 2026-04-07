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
    Color? defaultColor,
  }) {
    final spans = <InlineSpan>[];
    for (final child in children) {
      _buildSpan(
        child,
        prefs,
        headingLevel,
        lineHeightOverride,
        defaultColor,
        spans,
      );
    }
    return TextSpan(children: spans);
  }

  static void _buildSpan(
    RenderNode node,
    ReaderPreferences prefs,
    int? headingLevel,
    double? lineHeightOverride,
    Color? defaultColor,
    List<InlineSpan> out,
  ) {
    switch (node) {
      case TextNode():
        out.add(
          _textNodeToSpan(
            node,
            prefs,
            headingLevel,
            lineHeightOverride,
            defaultColor,
          ),
        );
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

  /// Compute the [TextStyle] for a [TextNode].
  ///
  /// Shared between [TextSpanBuilder] (greedy path) and [KPItemBuilder]
  /// (justified path) so styles are computed once in a single location.
  static TextStyle styleForTextNode({
    required TextNode node,
    required ReaderPreferences prefs,
    required int? headingLevel,
    required double? lineHeightOverride,
    required Color? defaultColor,
  }) {
    var fontSizeEm = node.fontSizeEm;

    // Apply heading default scale when CSS didn't set one.
    if (headingLevel != null && fontSizeEm == 1.0) {
      fontSizeEm = headingScaleEm[headingLevel] ?? 1.0;
    }

    final effectiveLineHeight =
        lineHeightOverride ?? prefs.lineHeightMultiplier;

    // Color priority: node.color > defaultColor > theme.textColor
    final baseColor = node.color != null
        ? Color(node.color!)
        : defaultColor ?? prefs.theme.textColor;

    // Link styling: only external URLs (http/https/mailto) get the visible
    // link treatment (blue + underline).  Internal EPUB cross-references
    // (#fragment, relative paths) are rendered as plain text because the
    // canvas reader does not support in-book navigation.
    final href = node.href ?? '';
    final isExternalLink =
        href.startsWith('http://') ||
        href.startsWith('https://') ||
        href.startsWith('mailto:');
    final color = (isExternalLink && node.color == null)
        ? const Color(0xFF1A73E8)
        : baseColor;

    final decorations = <TextDecoration>[];
    final isLink = href.isNotEmpty;
    // For linked text, underline is controlled solely by isExternalLink —
    // ignore node.underline which may come from <a> tag styling in Rust.
    // For non-linked text, honour the node flag (e.g. <u>, CSS underline).
    if (node.underline && !isLink) decorations.add(TextDecoration.underline);
    if (node.lineThrough) decorations.add(TextDecoration.lineThrough);
    if (isExternalLink) decorations.add(TextDecoration.underline);

    // Superscript / subscript font features.
    final fontFeatures = <FontFeature>[];
    if (node.superscript) fontFeatures.add(const FontFeature('sups'));
    if (node.subscript) fontFeatures.add(const FontFeature('subs'));

    // Inline background color (e.g. <mark> highlight).
    final bgColor = node.backgroundColor != null
        ? Color(node.backgroundColor!)
        : null;

    return TextStyle(
      fontSize: prefs.emToPx(fontSizeEm),
      fontWeight: (node.bold || headingLevel != null)
          ? FontWeight.bold
          : FontWeight.normal,
      fontStyle: node.italic ? FontStyle.italic : FontStyle.normal,
      decoration: decorations.isEmpty
          ? TextDecoration.none
          : TextDecoration.combine(decorations),
      decorationColor: isExternalLink ? color : null,
      color: color,
      fontFamily: prefs.fontFamily,
      height: effectiveLineHeight,
      fontFeatures: fontFeatures.isNotEmpty ? fontFeatures : null,
      backgroundColor: bgColor,
    );
  }

  static TextSpan _textNodeToSpan(
    TextNode node,
    ReaderPreferences prefs,
    int? headingLevel,
    double? lineHeightOverride,
    Color? defaultColor,
  ) {
    return TextSpan(
      text: node.content,
      style: styleForTextNode(
        node: node,
        prefs: prefs,
        headingLevel: headingLevel,
        lineHeightOverride: lineHeightOverride,
        defaultColor: defaultColor,
      ),
    );
  }
}
