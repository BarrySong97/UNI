import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../models/reader_preferences.dart';
import '../../models/render_node.dart';
import '../text_span_builder.dart';
import 'kp_items.dart';
import 'width_cache.dart';

/// Converts a [ParagraphNode]'s children into a [KPItem] sequence suitable
/// for the Knuth-Plass solver.
///
/// For each [TextNode] child the text is split at word boundaries, then words
/// are measured with a reused [TextPainter] per styled run.
class KPItemBuilder {
  const KPItemBuilder._();

  /// Build the K-P item list for a paragraph's children.
  ///
  /// Returns `null` if the paragraph is empty or cannot be converted.
  static List<KPItem>? build({
    required List<RenderNode> children,
    required ReaderPreferences prefs,
    required WidthCache widthCache,
    int? headingLevel,
    double? lineHeightOverride,
    Color? defaultColor,
  }) {
    final items = <KPItem>[];

    for (final child in children) {
      switch (child) {
        case TextNode():
          _processTextNode(
            node: child,
            prefs: prefs,
            widthCache: widthCache,
            headingLevel: headingLevel,
            lineHeightOverride: lineHeightOverride,
            defaultColor: defaultColor,
            items: items,
          );

        case LineBreakNode():
          items.add(forcedBreak());

        default:
          // ImageNode, etc. — skip for now.
          break;
      }
    }

    if (items.isEmpty) return null;

    // Finishing sequence: glue that fills the rest of the last line,
    // then a forced break. Matches tex-linebreak helpers.ts:77-78.
    items.add(const KPGlue(width: 0, stretch: KPPenalty.maxCost, shrink: 0));
    items.add(forcedBreak());

    return items;
  }

  /// Process a single [TextNode]: split into words, measure widths via batch
  /// layout, emit boxes and glue.
  static void _processTextNode({
    required TextNode node,
    required ReaderPreferences prefs,
    required WidthCache widthCache,
    required int? headingLevel,
    required double? lineHeightOverride,
    required Color? defaultColor,
    required List<KPItem> items,
  }) {
    final content = node.content;
    if (content.isEmpty) return;

    // Compute the TextStyle for this node.
    final style = _styleForNode(
      node: node,
      prefs: prefs,
      headingLevel: headingLevel,
      lineHeightOverride: lineHeightOverride,
      defaultColor: defaultColor,
    );

    final sw = widthCache.spaceWidth(style);
    // Glue stretch/shrink matching tex-linebreak helpers.ts:47,54.
    final shrink = math.max(0.0, sw - 2);
    final stretch = sw * 1.5;

    // Split content into alternating non-space and whitespace tokens.
    final tokens = _splitIntoWords(content);
    if (tokens.isEmpty) return;

    for (final token in tokens) {
      if (token.trim().isEmpty) {
        // Space token → emit glue (only if preceded by a box).
        if (items.isNotEmpty && items.last is KPBox) {
          items.add(KPGlue(width: sw, stretch: stretch, shrink: shrink));
        }
      } else {
        _emitNonWhitespaceToken(token: token, style: style, items: items);
      }
    }
  }

  /// Split text into alternating word and whitespace tokens.
  ///
  /// Example: "Hello  world" → ["Hello", "  ", "world"]
  static List<String> _splitIntoWords(String text) {
    final tokens = <String>[];
    final re = RegExp(r'\S+|\s+');
    for (final match in re.allMatches(text)) {
      tokens.add(match.group(0)!);
    }
    return tokens;
  }

  static void _emitNonWhitespaceToken({
    required String token,
    required TextStyle style,
    required List<KPItem> items,
  }) {
    final runs = _splitByScriptRuns(token);
    if (runs.isEmpty) return;

    var prevWasCjk = false;
    var firstRun = true;

    for (final run in runs) {
      if (!firstRun && (prevWasCjk || run.isCjk)) {
        // Allow soft break between contiguous CJK/non-CJK runs.
        items.add(const KPPenalty(cost: 0));
      }
      firstRun = false;

      if (!run.isCjk) {
        final result = _measureWordWithPainter(run.text, style);
        items.add(KPBox(
          text: run.text,
          style: style,
          width: result.width,
          painter: result.painter,
        ));
        prevWasCjk = false;
        continue;
      }

      final graphemes = _splitToSimpleChars(run.text);
      final charResults = _batchMeasureWordsWithPainters(graphemes, style);
      final avgWidth = charResults.isEmpty
          ? 0.0
          : charResults.map((r) => r.width).reduce((a, b) => a + b) /
              charResults.length;
      final cjkStretch = avgWidth * 0.5;

      for (var i = 0; i < graphemes.length; i++) {
        items.add(
          KPBox(
            text: graphemes[i],
            style: style,
            width: charResults[i].width,
            painter: charResults[i].painter,
          ),
        );
        if (i < graphemes.length - 1) {
          // Zero-width glue lets K-P distribute extra spacing across CJK chars.
          items.add(KPGlue(width: 0, stretch: cjkStretch, shrink: 0));
        }
      }
      prevWasCjk = true;
    }
  }

  static List<_ScriptRun> _splitByScriptRuns(String token) {
    final chars = _splitToSimpleChars(token);
    if (chars.isEmpty) return const [];

    final runs = <_ScriptRun>[];
    final buf = StringBuffer();
    var currentIsCjk = _isCjk(chars.first);

    for (final ch in chars) {
      final isCjk = _isCjk(ch);
      if (isCjk != currentIsCjk && buf.isNotEmpty) {
        runs.add(_ScriptRun(text: buf.toString(), isCjk: currentIsCjk));
        buf.clear();
        currentIsCjk = isCjk;
      }
      buf.write(ch);
    }
    if (buf.isNotEmpty) {
      runs.add(_ScriptRun(text: buf.toString(), isCjk: currentIsCjk));
    }
    return runs;
  }

  static List<String> _splitToSimpleChars(String text) {
    return text.runes.map(String.fromCharCode).toList(growable: false);
  }

  static bool _isCjk(String ch) {
    if (ch.isEmpty) return false;
    final cp = ch.runes.first;
    return (cp >= 0x4E00 && cp <= 0x9FFF) ||
        (cp >= 0x3400 && cp <= 0x4DBF) ||
        (cp >= 0xF900 && cp <= 0xFAFF) ||
        (cp >= 0x3040 && cp <= 0x309F) ||
        (cp >= 0x30A0 && cp <= 0x30FF) ||
        (cp >= 0xAC00 && cp <= 0xD7AF);
  }

  /// Measure word widths, returning both width and painter for each word.
  static List<_MeasureResult> _batchMeasureWordsWithPainters(
    List<String> words,
    TextStyle style,
  ) {
    if (words.isEmpty) return [];
    return words
        .map((w) => _measureWordWithPainter(w, style))
        .toList(growable: false);
  }

  /// Measure the width of a single word and return both width and painter.
  /// The painter is kept alive for reuse at render time.
  static _MeasureResult _measureWordWithPainter(String word, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: word, style: style),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    return _MeasureResult(width: painter.width, painter: painter);
  }

  /// Compute the [TextStyle] for a [TextNode], mirroring
  /// [TextSpanBuilder._textNodeToSpan].
  static TextStyle _styleForNode({
    required TextNode node,
    required ReaderPreferences prefs,
    required int? headingLevel,
    required double? lineHeightOverride,
    required Color? defaultColor,
  }) {
    var fontSizeEm = node.fontSizeEm;

    if (headingLevel != null && fontSizeEm == 1.0) {
      fontSizeEm = TextSpanBuilder.headingScaleEm[headingLevel] ?? 1.0;
    }

    final effectiveLineHeight =
        lineHeightOverride ?? prefs.lineHeightMultiplier;

    final baseColor = node.color != null
        ? Color(node.color!)
        : defaultColor ?? prefs.theme.textColor;

    final isLink = node.href != null && node.href!.isNotEmpty;
    final color = (isLink && node.color == null)
        ? const Color(0xFF1A73E8)
        : baseColor;

    final decorations = <TextDecoration>[];
    if (node.underline) decorations.add(TextDecoration.underline);
    if (node.lineThrough) decorations.add(TextDecoration.lineThrough);
    if (isLink) decorations.add(TextDecoration.underline);

    final fontFeatures = <FontFeature>[];
    if (node.superscript) fontFeatures.add(const FontFeature('sups'));
    if (node.subscript) fontFeatures.add(const FontFeature('subs'));

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
      decorationColor: isLink ? color : null,
      color: color,
      fontFamily: prefs.fontFamily,
      height: effectiveLineHeight,
      fontFeatures: fontFeatures.isNotEmpty ? fontFeatures : null,
      backgroundColor: bgColor,
    );
  }
}

class _ScriptRun {
  const _ScriptRun({required this.text, required this.isCjk});

  final String text;
  final bool isCjk;
}

class _MeasureResult {
  const _MeasureResult({required this.width, required this.painter});

  final double width;
  final TextPainter painter;
}
