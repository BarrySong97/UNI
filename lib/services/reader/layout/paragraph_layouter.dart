import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../models/page_layout.dart';
import '../models/reader_preferences.dart';
import '../models/render_node.dart';
import 'knuth_plass/width_cache.dart';
import 'knuth_plass/kp_item_builder.dart';
import 'knuth_plass/kp_items.dart';
import 'knuth_plass/kp_solver.dart';
import 'layout_context.dart';
import 'text_span_builder.dart';

class _KPLineFragment {
  const _KPLineFragment({
    required this.text,
    required this.style,
    required this.xOffset,
    required this.width,
  });

  final String text;
  final TextStyle? style;
  final double xOffset;
  final double width;
}

class _KPLineLayout {
  const _KPLineLayout({required this.fragments, required this.height});

  final List<_KPLineFragment> fragments;
  final double height;
}

/// Lays out a [ParagraphNode] within the pagination context.
///
/// Handles:
/// - TextSpan construction from children
/// - TextPainter measurement with correct width constraints
/// - Full paragraph placement when it fits on the current page
/// - Line-boundary splitting when a paragraph spans multiple pages
/// - Margin collapsing
/// - Text indent
/// - Background color
class ParagraphLayouter {
  const ParagraphLayouter._();

  /// Lay out a paragraph node. May split across pages.
  static void layout(
    ParagraphNode node,
    LayoutContext ctx, {
    int? headingLevel,
  }) {
    final prefs = ctx.preferences;

    // 1. Compute margins and padding in pixels.
    //    When CSS specifies zero margins (common in books that use text-indent
    //    for paragraph separation), apply a minimum gap so paragraphs don't
    //    visually stick together.
    final minParagraphGapPx = prefs.baseFontSizePx * 0.65;
    var marginTopPx =
        prefs.emToPx(node.marginTopEm) * prefs.paragraphSpacingMultiplier;
    var marginBottomPx =
        prefs.emToPx(node.marginBottomEm) * prefs.paragraphSpacingMultiplier;

    if (headingLevel == null &&
        marginTopPx == 0 &&
        marginBottomPx == 0 &&
        !ctx.isPageEmpty) {
      marginTopPx = minParagraphGapPx;
    }
    if (headingLevel == null && marginBottomPx < minParagraphGapPx) {
      marginBottomPx = minParagraphGapPx;
    }
    final marginLeftPx = prefs.emToPx(node.marginLeftEm);
    final marginRightPx = prefs.emToPx(node.marginRightEm);
    final paddingPx = node.paddingEm != null
        ? prefs.emToPx(node.paddingEm!)
        : 0.0;

    // 2. Apply top margin with collapsing.
    ctx.applyTopMargin(marginTopPx);

    // 3. Available width for text content.
    final availableWidth =
        ctx.contentWidth - marginLeftPx - marginRightPx - 2 * paddingPx;
    if (availableWidth <= 0) return;

    // 4. Common parameters for both K-P and greedy paths.
    final effectiveLineHeight = node.lineHeightEm ?? prefs.lineHeightMultiplier;
    final defaultColor = node.color != null ? Color(node.color!) : null;

    Paint? bgPaint;
    if (node.backgroundColor != null) {
      bgPaint = Paint()..color = Color(node.backgroundColor!);
    }

    // 5. Knuth-Plass justified layout path (attempted FIRST to avoid
    //    building a greedy TextSpan + TextPainter that would be discarded).
    if (node.align == TextAlign.justify && !ctx.pageCountOnly) {
      final kpDone = _tryKnuthPlassLayout(
        ctx: ctx,
        node: node,
        availableWidth: availableWidth,
        marginLeftPx: marginLeftPx,
        marginBottomPx: marginBottomPx,
        paddingPx: paddingPx,
        bgPaint: bgPaint,
        headingLevel: headingLevel,
        effectiveLineHeight: effectiveLineHeight,
        defaultColor: defaultColor,
      );
      if (kpDone) return;
      // K-P failed — fall through to greedy layout.
    }

    // 6. Build TextSpan + greedy TextPainter (only reached for non-justified
    //    paragraphs, or when K-P falls back to greedy).
    final textSpan = TextSpanBuilder.build(
      children: node.children,
      prefs: prefs,
      headingLevel: headingLevel,
      lineHeightOverride: effectiveLineHeight,
      defaultColor: defaultColor,
    );
    final painter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
      textAlign: node.align,
    )..layout(maxWidth: availableWidth);

    // 7. Split paragraph across pages (greedy fallback).
    final textHeight = painter.height;
    final totalHeight = textHeight + 2 * paddingPx;
    if (totalHeight <= ctx.remainingHeight) {
      _placeParagraph(
        ctx: ctx,
        painter: painter,
        node: node,
        availableWidth: availableWidth,
        marginLeftPx: marginLeftPx,
        paddingPx: paddingPx,
        totalHeight: totalHeight,
        bgPaint: bgPaint,
      );
      ctx.recordBottomMargin(marginBottomPx);
      return;
    }

    _splitParagraph(
      ctx: ctx,
      textSpan: textSpan,
      node: node,
      painter: painter,
      availableWidth: availableWidth,
      marginLeftPx: marginLeftPx,
      marginBottomPx: marginBottomPx,
      paddingPx: paddingPx,
      bgPaint: bgPaint,
      headingLevel: headingLevel,
    );
  }

  /// Place the entire paragraph on the current page.
  static void _placeParagraph({
    required LayoutContext ctx,
    required TextPainter painter,
    required ParagraphNode node,
    required double availableWidth,
    required double marginLeftPx,
    required double paddingPx,
    required double totalHeight,
    required Paint? bgPaint,
  }) {
    final x = marginLeftPx;
    final y = ctx.cursorY;

    // Background rect covers the full paragraph area including padding.
    if (bgPaint != null) {
      ctx.addElement(
        LayoutElement(
          rect: Rect.fromLTWH(
            x,
            y,
            ctx.contentWidth -
                marginLeftPx -
                (ctx.preferences.emToPx(node.marginRightEm)),
            totalHeight,
          ),
          sourceNode: node,
          backgroundPaint: bgPaint,
        ),
      );
    }

    // Text element inside the padding.
    // Use availableWidth so TextPainter alignment (center/right) is visible.
    ctx.addElement(
      LayoutElement(
        rect: Rect.fromLTWH(
          x + paddingPx,
          y + paddingPx,
          availableWidth,
          painter.height,
        ),
        sourceNode: node,
        textPainter: painter,
      ),
    );

    ctx.cursorY += totalHeight;
  }

  // ---------------------------------------------------------------------------
  // Knuth-Plass justified layout
  // ---------------------------------------------------------------------------

  /// Attempt Knuth-Plass layout for a justified paragraph.
  ///
  /// Returns `true` if K-P produced a valid layout, `false` if the caller
  /// should fall back to the greedy algorithm.
  static bool _tryKnuthPlassLayout({
    required LayoutContext ctx,
    required ParagraphNode node,
    required double availableWidth,
    required double marginLeftPx,
    required double marginBottomPx,
    required double paddingPx,
    required Paint? bgPaint,
    required int? headingLevel,
    required double effectiveLineHeight,
    required Color? defaultColor,
  }) {
    final prefs = ctx.preferences;
    final widthCache = ctx.widthCache;

    // 1. Build K-P items from paragraph children.
    final items = KPItemBuilder.build(
      children: node.children,
      prefs: prefs,
      widthCache: widthCache,
      paragraphPrepareCache: ctx.paragraphPrepareCache,
      availableWidth: availableWidth,
      headingLevel: headingLevel,
      lineHeightOverride: effectiveLineHeight,
      defaultColor: defaultColor,
    );
    if (items == null || items.isEmpty) return false;

    // 2. Solve for optimal break points.
    // Match tex-linebreak's helper flow: strict ratio first, then relaxed.
    List<int> breakpoints;
    try {
      breakpoints = KPSolver.solve(
        items,
        availableWidth,
        const KPOptions(
          maxAdjustmentRatio: 1.0,
          initialMaxAdjustmentRatio: 1.0,
        ),
      );
    } on MaxAdjustmentExceededError {
      try {
        // We don't currently hyphenate, so fall back to an unrestricted pass.
        breakpoints = KPSolver.solve(items, availableWidth);
      } on MaxAdjustmentExceededError {
        // Solver could not fit within ratio limits — fall back to greedy.
        _disposeItemPainters(items);
        return false;
      }
    }
    if (breakpoints.length < 2) {
      _disposeItemPainters(items);
      return false;
    }

    // Single-line paragraph — nothing to justify, fall back to greedy.
    if (breakpoints.length == 2) {
      _disposeItemPainters(items);
      return false;
    }

    // 3. Position K-P items on each line.
    // Note: positionItems() caps the stretch ratio for non-last lines to
    // prevent excessively wide word spacing (see _maxVisualRatio).
    final positioned = KPSolver.positionItems(
      items,
      availableWidth,
      breakpoints,
    );

    // 4. Build per-line positioned fragments.
    final lines = _buildJustifiedLines(
      items: items,
      breakpoints: breakpoints,
      positioned: positioned,
      fallbackLineHeight: _fallbackKpLineHeight(
        items: items,
        widthCache: widthCache,
        prefs: prefs,
        headingLevel: headingLevel,
        effectiveLineHeight: effectiveLineHeight,
        defaultColor: defaultColor,
      ),
      availableWidth: availableWidth,
      widthCache: widthCache,
    );
    if (lines.isEmpty) return false;

    // 5. Place lines with page splitting.
    _placeJustifiedLines(
      ctx: ctx,
      node: node,
      lines: lines,
      marginLeftPx: marginLeftPx,
      marginBottomPx: marginBottomPx,
      paddingPx: paddingPx,
      bgPaint: bgPaint,
    );

    return true;
  }

  /// Build positioned fragments for each K-P line.
  ///
  /// Uses [KPSolver.positionItems] output instead of uniform word spacing so
  /// each glue stretch/shrink value is applied exactly.
  ///
  /// Creates [TextPainter]s on demand only for positioned items (the subset
  /// that actually appears in the chosen breakpoint layout). For non-last
  /// lines, distributes any residual right-edge gap across all glue intervals.
  static List<_KPLineLayout> _buildJustifiedLines({
    required List<KPItem> items,
    required List<int> breakpoints,
    required List<KPPositionedItem> positioned,
    required double fallbackLineHeight,
    required double availableWidth,
    required WidthCache widthCache,
  }) {
    final lines = <_KPLineLayout>[];
    final byLine = <int, List<KPPositionedItem>>{};
    for (final pos in positioned) {
      byLine.putIfAbsent(pos.line, () => <KPPositionedItem>[]).add(pos);
    }

    final isLastLine = breakpoints.length - 2;

    for (var b = 0; b < breakpoints.length - 1; b++) {
      final linePositions = byLine[b] ?? const <KPPositionedItem>[];
      final fragments = <_KPLineFragment>[];
      var lineHeight = 0.0;

      for (final pos in linePositions) {
        final item = items[pos.item];
        String? text;
        TextStyle? style;
        if (item is KPBox) {
          text = item.text;
          style = item.style;
        } else if (item is KPPenalty && item.width > 0) {
          text = '-';
          style = _lastBoxStyle(items, pos.item);
        }
        if (text == null) continue;

        if (style != null) {
          final height = widthCache.lineHeight(style);
          lineHeight = lineHeight < height ? height : lineHeight;
        }
        fragments.add(
          _KPLineFragment(
            text: text,
            style: style,
            xOffset: pos.xOffset,
            width: pos.width,
          ),
        );
      }

      // Correct sub-pixel drift for non-last lines: distribute the residual
      // gap evenly across all inter-fragment intervals.
      if (b != isLastLine && fragments.length >= 2) {
        final lastFrag = fragments.last;
        final lineEnd = lastFrag.xOffset + lastFrag.width;
        final gap = availableWidth - lineEnd;
        if (gap.abs() > 0.01 && gap.abs() < 5.0) {
          final intervalCount = fragments.length - 1;
          final perInterval = gap / intervalCount;
          final corrected = <_KPLineFragment>[];
          for (var i = 0; i < fragments.length; i++) {
            corrected.add(
              _KPLineFragment(
                text: fragments[i].text,
                style: fragments[i].style,
                xOffset: fragments[i].xOffset + perInterval * i,
                width: fragments[i].width,
              ),
            );
          }
          fragments
            ..clear()
            ..addAll(corrected);
        }
      }

      if (lineHeight == 0.0) {
        final start = b == 0 ? breakpoints[b] : breakpoints[b] + 1;
        final end = breakpoints[b + 1];
        lineHeight = _lineHeightForRange(
          items,
          start,
          end,
          widthCache: widthCache,
        );
      }
      if (lineHeight == 0.0) {
        lineHeight = fallbackLineHeight;
      }
      lines.add(_KPLineLayout(fragments: fragments, height: lineHeight));
    }

    return lines;
  }

  static double _lineHeightForRange(
    List<KPItem> items,
    int start,
    int end, {
    required WidthCache widthCache,
  }) {
    TextStyle? style;
    for (var i = start; i <= end; i++) {
      final it = items[i];
      if (it is KPBox) {
        style = it.style;
        break;
      }
    }
    style ??= _lastBoxStyle(items, end + 1);
    if (style == null) return 0.0;
    return widthCache.lineHeight(style);
  }

  static double _fallbackKpLineHeight({
    required List<KPItem> items,
    required WidthCache widthCache,
    required ReaderPreferences prefs,
    required int? headingLevel,
    required double effectiveLineHeight,
    required Color? defaultColor,
  }) {
    for (final item in items) {
      if (item is KPBox) {
        if (item.style != null) {
          return widthCache.lineHeight(item.style!);
        }
      }
    }

    final baseStyle = TextStyle(
      fontSize: prefs.emToPx(
        headingLevel != null
            ? (TextSpanBuilder.headingScaleEm[headingLevel] ?? 1.0)
            : 1.0,
      ),
      fontWeight: headingLevel != null ? FontWeight.bold : FontWeight.normal,
      fontFamily: prefs.fontFamily,
      height: effectiveLineHeight,
      color: defaultColor ?? prefs.theme.textColor,
    );
    return widthCache.lineHeight(baseStyle);
  }

  /// Find the style of the most recent KPBox at or before index [i].
  static TextStyle? _lastBoxStyle(List<KPItem> items, int i) {
    for (var j = i - 1; j >= 0; j--) {
      if (items[j] is KPBox) return (items[j] as KPBox).style;
    }
    return null;
  }

  /// Dispose all [TextPainter]s stored in [KPBox] items.
  /// Called when K-P layout fails and we fall back to greedy.
  static void _disposeItemPainters(List<KPItem> items) {
    for (final item in items) {
      if (item is KPBox) {
        item.painter?.dispose();
      }
    }
  }

  /// Place justified lines onto pages, splitting across pages as needed.
  static void _placeJustifiedLines({
    required LayoutContext ctx,
    required ParagraphNode node,
    required List<_KPLineLayout> lines,
    required double marginLeftPx,
    required double marginBottomPx,
    required double paddingPx,
    required Paint? bgPaint,
  }) {
    final x = marginLeftPx;
    var isFirstLine = true;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineHeight = line.height;

      // Add top padding before the first line.
      final extraTop = isFirstLine ? paddingPx : 0.0;
      // Add bottom padding after the last line.
      final extraBottom = i == lines.length - 1 ? paddingPx : 0.0;
      final totalLineHeight = lineHeight + extraTop + extraBottom;

      // Check if this line fits on the current page.
      if (totalLineHeight > ctx.remainingHeight && !ctx.isPageEmpty) {
        ctx.startNewPage();
        isFirstLine = true;
      }

      final y = ctx.cursorY;

      // Background for this line's area.
      if (bgPaint != null) {
        ctx.addElement(
          LayoutElement(
            rect: Rect.fromLTWH(
              x,
              y,
              ctx.contentWidth -
                  marginLeftPx -
                  (ctx.preferences.emToPx(node.marginRightEm)),
              totalLineHeight,
            ),
            sourceNode: node,
            backgroundPaint: bgPaint,
          ),
        );
      }

      // Text element.
      final lineY = y + (isFirstLine ? paddingPx : 0.0);
      for (final fragment in line.fragments) {
        ctx.addElement(
          LayoutElement(
            rect: Rect.fromLTWH(
              x + paddingPx + fragment.xOffset,
              lineY,
              fragment.width,
              lineHeight,
            ),
            sourceNode: node,
            deferredText: fragment.text,
            deferredStyle: fragment.style,
          ),
        );
      }

      ctx.cursorY += totalLineHeight;
      isFirstLine = false;
    }

    ctx.recordBottomMargin(marginBottomPx);
  }

  /// Split the paragraph at line boundaries across pages.
  static void _splitParagraph({
    required LayoutContext ctx,
    required TextSpan textSpan,
    required ParagraphNode node,
    required TextPainter painter,
    required double availableWidth,
    required double marginLeftPx,
    required double marginBottomPx,
    required double paddingPx,
    required Paint? bgPaint,
    int? headingLevel,
  }) {
    final lineMetrics = painter.computeLineMetrics();
    final remainingHeight = ctx.remainingHeight;

    // Find how many lines fit on the current page.
    var fittingLines = 0;
    var accHeight = paddingPx; // top padding
    for (final line in lineMetrics) {
      if (accHeight + line.height > remainingHeight) break;
      accHeight += line.height;
      fittingLines++;
    }

    if (fittingLines == 0) {
      // Not even one line fits. Start a new page and retry.
      ctx.startNewPage();
      layout(node, ctx, headingLevel: headingLevel);
      return;
    }

    if (fittingLines >= lineMetrics.length) {
      // All lines fit (should have been caught above, but safety).
      _placeParagraph(
        ctx: ctx,
        painter: painter,
        node: node,
        availableWidth: availableWidth,
        marginLeftPx: marginLeftPx,
        paddingPx: paddingPx,
        totalHeight: painter.height + 2 * paddingPx,
        bgPaint: bgPaint,
      );
      ctx.recordBottomMargin(marginBottomPx);
      return;
    }

    // Find character offset at the split point.
    final splitOffset = findSplitOffset(painter, lineMetrics, fittingLines);

    // Build and place Part 1 (fits on current page).
    final fullText = extractPlainText(textSpan);
    if (splitOffset <= 0 || splitOffset >= fullText.length) {
      // Edge case: can't split meaningfully, push to next page.
      ctx.startNewPage();
      layout(node, ctx, headingLevel: headingLevel);
      return;
    }

    final firstPartSpan = truncateTextSpan(textSpan, splitOffset);
    final firstPainter = TextPainter(
      text: firstPartSpan,
      textDirection: ui.TextDirection.ltr,
      textAlign: node.align,
    )..layout(maxWidth: availableWidth);

    final x = marginLeftPx;
    final y = ctx.cursorY;

    if (bgPaint != null) {
      ctx.addElement(
        LayoutElement(
          rect: Rect.fromLTWH(
            x,
            y,
            ctx.contentWidth -
                marginLeftPx -
                (ctx.preferences.emToPx(node.marginRightEm)),
            firstPainter.height + 2 * paddingPx,
          ),
          sourceNode: node,
          backgroundPaint: bgPaint,
        ),
      );
    }

    ctx.addElement(
      LayoutElement(
        rect: Rect.fromLTWH(
          x + paddingPx,
          y + paddingPx,
          availableWidth,
          firstPainter.height,
        ),
        sourceNode: node,
        textPainter: firstPainter,
      ),
    );

    // Start new page.
    ctx.startNewPage();

    // Build Part 2 (remaining text) as a new paragraph with zero top margin.
    final remainingSpan = skipTextSpan(textSpan, splitOffset);
    final remainingPainter = TextPainter(
      text: remainingSpan,
      textDirection: ui.TextDirection.ltr,
      textAlign: node.align,
    )..layout(maxWidth: availableWidth);

    final remainingHeight2 = remainingPainter.height + 2 * paddingPx;

    if (remainingHeight2 <= ctx.remainingHeight) {
      // Remaining part fits on the new page.
      _placeParagraph(
        ctx: ctx,
        painter: remainingPainter,
        node: node,
        availableWidth: availableWidth,
        marginLeftPx: marginLeftPx,
        paddingPx: paddingPx,
        totalHeight: remainingHeight2,
        bgPaint: bgPaint,
      );
      ctx.recordBottomMargin(marginBottomPx);
    } else {
      // Need to split again (recursive).
      _splitParagraph(
        ctx: ctx,
        textSpan: remainingSpan,
        node: node,
        painter: remainingPainter,
        availableWidth: availableWidth,
        marginLeftPx: marginLeftPx,
        marginBottomPx: marginBottomPx,
        paddingPx: paddingPx,
        bgPaint: bgPaint,
        headingLevel: headingLevel,
      );
    }
  }

  /// Find the character offset at the end of line [maxLines] (0-indexed count).
  static int findSplitOffset(
    TextPainter painter,
    List<ui.LineMetrics> metrics,
    int maxLines,
  ) {
    var y = 0.0;
    for (var i = 0; i < maxLines; i++) {
      y += metrics[i].height;
    }
    // Get position at the beginning of the line after the split.
    final pos = painter.getPositionForOffset(Offset(0, y + 1));
    return pos.offset;
  }

  /// Extract the plain text from a TextSpan tree.
  static String extractPlainText(TextSpan span) {
    final buffer = StringBuffer();
    span.visitChildren((child) {
      if (child is TextSpan && child.text != null) {
        buffer.write(child.text);
      }
      return true;
    });
    if (span.text != null) {
      return span.text! + buffer.toString();
    }
    return buffer.toString();
  }

  /// Create a new TextSpan containing only the first [charCount] characters.
  static TextSpan truncateTextSpan(TextSpan span, int charCount) {
    var remaining = charCount;
    final result = <InlineSpan>[];

    for (final child in (span.children ?? <InlineSpan>[])) {
      if (remaining <= 0) break;
      if (child is TextSpan && child.text != null) {
        if (child.text!.length <= remaining) {
          result.add(child);
          remaining -= child.text!.length;
        } else {
          result.add(
            TextSpan(
              text: child.text!.substring(0, remaining),
              style: child.style,
            ),
          );
          remaining = 0;
        }
      } else {
        result.add(child);
      }
    }

    return TextSpan(children: result);
  }

  /// Create a new TextSpan skipping the first [charCount] characters.
  static TextSpan skipTextSpan(TextSpan span, int charCount) {
    var remaining = charCount;
    final result = <InlineSpan>[];

    for (final child in (span.children ?? <InlineSpan>[])) {
      if (remaining <= 0) {
        result.add(child);
        continue;
      }
      if (child is TextSpan && child.text != null) {
        if (child.text!.length <= remaining) {
          remaining -= child.text!.length;
        } else {
          result.add(
            TextSpan(
              text: child.text!.substring(remaining),
              style: child.style,
            ),
          );
          remaining = 0;
        }
      }
    }

    return TextSpan(children: result);
  }
}
