import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../models/reader_preferences.dart';
import '../../models/render_node.dart';
import '../text_span_builder.dart';
import 'paragraph_prepare_cache.dart';
import 'kp_items.dart';
import 'width_cache.dart';

/// Converts a [ParagraphNode]'s children into a [KPItem] sequence suitable
/// for the Knuth-Plass solver.
///
/// For each [TextNode] child the text is split at word boundaries, then words
/// are measured with a reused [TextPainter] per styled run.
class KPItemBuilder {
  const KPItemBuilder._();
  static const _softHyphenChar = '\u00ad';
  static const _softHyphenPenaltyCost = 50.0;

  /// Build the K-P item list for a paragraph's children.
  ///
  /// Returns `null` if the paragraph is empty or cannot be converted.
  static List<KPItem>? build({
    required List<RenderNode> children,
    required ReaderPreferences prefs,
    required WidthCache widthCache,
    ParagraphPrepareCache? paragraphPrepareCache,
    double? availableWidth,
    int? headingLevel,
    double? lineHeightOverride,
    Color? defaultColor,
  }) {
    final cache = paragraphPrepareCache;
    final cacheKey = cache != null
        ? _buildCacheKey(
            children: children,
            prefs: prefs,
            availableWidth: availableWidth,
            headingLevel: headingLevel,
            lineHeightOverride: lineHeightOverride,
            defaultColor: defaultColor,
          )
        : null;
    if (cacheKey != null) {
      final cached = cache!.get(cacheKey);
      if (cached != null) return cached;
    }

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

    if (cacheKey != null) {
      cache!.put(cacheKey, items);
      return cache.get(cacheKey);
    }

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

    final hyphenWidth = widthCache.wordWidth('-', style);
    for (final token in tokens) {
      if (token.trim().isEmpty) {
        // Space token → emit glue (only if preceded by a box).
        if (items.isNotEmpty && items.last is KPBox) {
          items.add(KPGlue(width: sw, stretch: stretch, shrink: shrink));
        }
      } else {
        _emitTokenWithSoftHyphenBreaks(
          token: token,
          style: style,
          hyphenWidth: hyphenWidth,
          items: items,
          widthCache: widthCache,
        );
      }
    }
  }

  static final _wordSplitRe = RegExp(r'\S+|\s+');

  /// Split text into alternating word and whitespace tokens.
  ///
  /// Example: "Hello  world" → ["Hello", "  ", "world"]
  static List<String> _splitIntoWords(String text) {
    final tokens = <String>[];
    for (final match in _wordSplitRe.allMatches(text)) {
      tokens.add(match.group(0)!);
    }
    return tokens;
  }

  static void _emitNonWhitespaceToken({
    required String token,
    required TextStyle style,
    required List<KPItem> items,
    required WidthCache widthCache,
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
        final w = widthCache.wordWidth(run.text, style);
        items.add(KPBox(text: run.text, style: style, width: w));
        prevWasCjk = false;
        continue;
      }

      final graphemes = _splitToSimpleChars(run.text);
      final charWidths = graphemes
          .map((ch) => widthCache.wordWidth(ch, style))
          .toList(growable: false);
      final avgWidth = charWidths.isEmpty
          ? 0.0
          : charWidths.reduce((a, b) => a + b) / charWidths.length;
      final cjkStretch = avgWidth * 0.5;

      for (var i = 0; i < graphemes.length; i++) {
        items.add(
          KPBox(text: graphemes[i], style: style, width: charWidths[i]),
        );
        if (i < graphemes.length - 1) {
          // Zero-width glue lets K-P distribute extra spacing across CJK chars.
          items.add(KPGlue(width: 0, stretch: cjkStretch, shrink: 0));
        }
      }
      prevWasCjk = true;
    }
  }

  /// Emit a token, converting embedded soft hyphens (`\u00AD`) into
  /// discretionary break penalties with visible `-` width only at line breaks.
  static void _emitTokenWithSoftHyphenBreaks({
    required String token,
    required TextStyle style,
    required double hyphenWidth,
    required List<KPItem> items,
    required WidthCache widthCache,
  }) {
    if (!token.contains(_softHyphenChar)) {
      _emitNonWhitespaceToken(
        token: token,
        style: style,
        items: items,
        widthCache: widthCache,
      );
      return;
    }

    final parts = token.split(_softHyphenChar);
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.isNotEmpty) {
        _emitNonWhitespaceToken(
          token: part,
          style: style,
          items: items,
          widthCache: widthCache,
        );
      }
      if (i == parts.length - 1) continue;

      final hasFollowingContent = parts
          .skip(i + 1)
          .any((segment) => segment.isNotEmpty);
      if (hasFollowingContent && items.isNotEmpty && items.last is KPBox) {
        items.add(
          KPPenalty(
            cost: _softHyphenPenaltyCost,
            width: hyphenWidth,
            flagged: true,
          ),
        );
      }
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

  /// Compute the [TextStyle] for a [TextNode].
  ///
  /// Delegates to [TextSpanBuilder.styleForTextNode] to avoid duplication.
  static TextStyle _styleForNode({
    required TextNode node,
    required ReaderPreferences prefs,
    required int? headingLevel,
    required double? lineHeightOverride,
    required Color? defaultColor,
  }) {
    return TextSpanBuilder.styleForTextNode(
      node: node,
      prefs: prefs,
      headingLevel: headingLevel,
      lineHeightOverride: lineHeightOverride,
      defaultColor: defaultColor,
    );
  }

  static String _buildCacheKey({
    required List<RenderNode> children,
    required ReaderPreferences prefs,
    required double? availableWidth,
    required int? headingLevel,
    required double? lineHeightOverride,
    required Color? defaultColor,
  }) {
    final buffer = StringBuffer()
      ..write('lh=')
      ..write(prefs.layoutHash)
      ..write('|aw=')
      ..write(availableWidth?.toStringAsFixed(3) ?? 'na')
      ..write('|hl=')
      ..write(headingLevel ?? -1)
      ..write('|lhov=')
      ..write(lineHeightOverride?.toStringAsFixed(3) ?? 'na')
      ..write('|dc=')
      ..write(defaultColor?.toARGB32() ?? -1);

    for (final child in children) {
      switch (child) {
        case TextNode():
          buffer
            ..write('|T:')
            ..write(child.content)
            ..write(':')
            ..write(child.bold ? 1 : 0)
            ..write(child.italic ? 1 : 0)
            ..write(child.underline ? 1 : 0)
            ..write(child.lineThrough ? 1 : 0)
            ..write(':')
            ..write(child.fontSizeEm.toStringAsFixed(4))
            ..write(':')
            ..write(child.color ?? -1)
            ..write(':')
            ..write(child.href ?? '')
            ..write(':')
            ..write(child.superscript ? 1 : 0)
            ..write(child.subscript ? 1 : 0)
            ..write(':')
            ..write(child.backgroundColor ?? -1);
        case LineBreakNode():
          buffer.write('|BR');
        default:
          buffer
            ..write('|N:')
            ..write(child.runtimeType.toString());
      }
    }

    return buffer.toString();
  }
}

class _ScriptRun {
  const _ScriptRun({required this.text, required this.isCjk});

  final String text;
  final bool isCjk;
}
