import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../models/page_layout.dart';
import '../models/render_node.dart';
import 'layout_context.dart';
import 'text_span_builder.dart';

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
    final minParagraphGapPx = prefs.baseFontSizePx * 0.35;
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

    // 4. Build TextSpan from children.
    final effectiveLineHeight = node.lineHeightEm ?? prefs.lineHeightMultiplier;
    final textSpan = TextSpanBuilder.build(
      children: node.children,
      prefs: prefs,
      headingLevel: headingLevel,
      lineHeightOverride: effectiveLineHeight,
    );

    // 5. Measure with TextPainter.
    final painter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
      textAlign: node.align,
    )..layout(maxWidth: availableWidth);

    final textHeight = painter.height;
    final totalHeight = textHeight + 2 * paddingPx;

    // 6. Background paint.
    Paint? bgPaint;
    if (node.backgroundColor != null) {
      bgPaint = Paint()..color = Color(node.backgroundColor!);
    }

    // 7. Check if entire paragraph fits on current page.
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

    // 8. Split paragraph across pages.
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
    final splitOffset = _findSplitOffset(painter, lineMetrics, fittingLines);

    // Build and place Part 1 (fits on current page).
    final fullText = _extractPlainText(textSpan);
    if (splitOffset <= 0 || splitOffset >= fullText.length) {
      // Edge case: can't split meaningfully, push to next page.
      ctx.startNewPage();
      layout(node, ctx, headingLevel: headingLevel);
      return;
    }

    final firstPartSpan = _truncateTextSpan(textSpan, splitOffset);
    final firstPainter = TextPainter(
      text: firstPartSpan,
      textDirection: ui.TextDirection.ltr,
      textAlign: node.align,
    )..layout(maxWidth: availableWidth);

    final x = marginLeftPx;
    final y = ctx.cursorY;

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
    final remainingSpan = _skipTextSpan(textSpan, splitOffset);
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
  static int _findSplitOffset(
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
  static String _extractPlainText(TextSpan span) {
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
  static TextSpan _truncateTextSpan(TextSpan span, int charCount) {
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
  static TextSpan _skipTextSpan(TextSpan span, int charCount) {
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
