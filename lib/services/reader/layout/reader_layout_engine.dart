import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../models/page_layout.dart';
import '../models/reader_preferences.dart';
import '../models/render_node.dart';
import 'layout_context.dart';
import 'paragraph_layouter.dart';
import 'text_span_builder.dart';

/// The main pagination engine.
///
/// Takes a list of [RenderNode]s for a chapter, a viewport size, and user
/// preferences, then produces a [ChapterPagination] containing all pages.
class ReaderLayoutEngine {
  const ReaderLayoutEngine();

  /// Pre-decode all base64 images in a chapter's nodes.
  ///
  /// Call this before [paginate] so images are available during layout.
  /// Returns a map from the ImageNode's dataBase64 hash to the decoded image.
  Future<Map<String, ui.Image>> decodeImages(
    List<RenderNode> nodes,
    double maxWidth,
    double devicePixelRatio,
  ) async {
    final images = <String, ui.Image>{};
    // Decode at physical pixel width to stay sharp on Retina/HiDPI screens.
    final targetPx = (maxWidth * devicePixelRatio).toInt();
    for (final node in nodes) {
      if (node is ImageNode && node.dataBase64 != null) {
        try {
          final bytes = base64Decode(node.dataBase64!);
          // Only downscale if the image is wider than the display area.
          final nativeWidth = node.widthPx;
          final needsResize = nativeWidth != null && nativeWidth > targetPx;
          final codec = await ui.instantiateImageCodec(
            bytes,
            targetWidth: needsResize ? targetPx : null,
          );
          final frame = await codec.getNextFrame();
          images[node.dataBase64!.hashCode.toString()] = frame.image;
        } catch (_) {
          // Skip images that fail to decode.
        }
      }
    }
    return images;
  }

  /// Paginate a single chapter.
  ChapterPagination paginate({
    required int chapterIndex,
    required List<RenderNode> nodes,
    required Size viewportSize,
    required ReaderPreferences prefs,
    Map<String, ui.Image>? decodedImages,
    double safeAreaTop = 0.0,
    double safeAreaBottom = 0.0,
  }) {
    final contentWidth = viewportSize.width - 2 * prefs.pageHorizontalPaddingPx;
    final contentHeight =
        viewportSize.height -
        2 * prefs.pageVerticalPaddingPx -
        safeAreaTop -
        safeAreaBottom;

    final ctx = LayoutContext(
      contentWidth: contentWidth,
      contentHeight: contentHeight,
      preferences: prefs,
      chapterIndex: chapterIndex,
      decodedImages: decodedImages ?? const {},
    );

    for (final node in nodes) {
      _layoutNode(node, ctx);
    }

    final pages = ctx.finalize();

    return ChapterPagination(
      chapterIndex: chapterIndex,
      pages: pages,
      viewportSize: viewportSize,
      preferencesHash: prefs.layoutHash,
    );
  }

  void _layoutNode(RenderNode node, LayoutContext ctx) {
    switch (node) {
      case ParagraphNode():
        ParagraphLayouter.layout(node, ctx);
      case HeadingNode():
        _layoutHeading(node, ctx);
      case ImageNode():
        _layoutImage(node, ctx);
      case ListNode():
        _layoutList(node, ctx);
      case TableNode():
        _layoutTable(node, ctx);
      case BlockQuoteNode():
        _layoutBlockQuote(node, ctx);
      case CodeBlockNode():
        _layoutCodeBlock(node, ctx);
      case LineBreakNode():
        ctx.cursorY += ctx.preferences.baseFontSizePx * 0.5;
      case HorizontalRuleNode():
        _layoutHorizontalRule(ctx);
      case TextNode():
        // Bare text node outside a paragraph — wrap in a simple paragraph.
        ParagraphLayouter.layout(ParagraphNode(children: [node]), ctx);
    }
  }

  // ---------------------------------------------------------------------------
  // Heading
  // ---------------------------------------------------------------------------

  void _layoutHeading(HeadingNode node, LayoutContext ctx) {
    final prefs = ctx.preferences;

    // Widow prevention: if heading would be near the bottom of a page with
    // less than ~2 lines of space after it, push to next page.
    final estimatedHeadingHeight =
        prefs.baseFontSizePx *
        (TextSpanBuilder.headingScaleEm[node.level] ?? 1.5) *
        prefs.lineHeightMultiplier;
    final minFollowingSpace =
        prefs.baseFontSizePx * prefs.lineHeightMultiplier * 2;

    if (!ctx.isPageEmpty &&
        ctx.remainingHeight < estimatedHeadingHeight + minFollowingSpace) {
      ctx.startNewPage();
    }

    // Lay out as a paragraph, using CSS values with sensible defaults.
    final paragraphProxy = ParagraphNode(
      children: node.children,
      marginTopEm: node.marginTopEm != 0.0 ? node.marginTopEm : 0.8,
      marginBottomEm: node.marginBottomEm != 0.0 ? node.marginBottomEm : 0.4,
      marginLeftEm: node.marginLeftEm,
      marginRightEm: node.marginRightEm,
      align: node.align,
      textIndentEm: node.textIndentEm,
      backgroundColor: node.backgroundColor,
      lineHeightEm: node.lineHeightEm,
      paddingEm: node.paddingEm,
    );
    ParagraphLayouter.layout(paragraphProxy, ctx, headingLevel: node.level);
  }

  // ---------------------------------------------------------------------------
  // Image
  // ---------------------------------------------------------------------------

  void _layoutImage(ImageNode node, LayoutContext ctx) {
    // Determine aspect ratio from Rust-provided dimensions or decoded image.
    final key = node.dataBase64?.hashCode.toString();
    final decodedImage = key != null ? ctx.decodedImages[key] : null;

    double? aspectRatio;
    if (node.widthPx != null && node.heightPx != null && node.heightPx! > 0) {
      aspectRatio = node.widthPx! / node.heightPx!;
    } else if (decodedImage != null) {
      aspectRatio = decodedImage.width / decodedImage.height;
    }

    if (aspectRatio == null || node.dataBase64 == null) {
      // No sizing info and no data — render alt text placeholder.
      _layoutImagePlaceholder(node, ctx);
      return;
    }

    final topMargin = ctx.preferences.emToPx(0.5);
    final bottomMargin = ctx.preferences.emToPx(0.5);
    ctx.applyTopMargin(topMargin);

    // Scale image to fit content width, respecting widthHint.
    final maxW = node.widthHint != null
        ? ctx.contentWidth * node.widthHint!
        : ctx.contentWidth;
    var displayW = maxW.clamp(0.0, ctx.contentWidth);
    var displayH = displayW / aspectRatio;

    // Cap height to 80% of page to avoid images taller than a page.
    final maxH = ctx.contentHeight * 0.8;
    if (displayH > maxH) {
      displayH = maxH;
      displayW = displayH * aspectRatio;
    }

    // If image doesn't fit on this page, start a new one.
    if (displayH > ctx.remainingHeight && !ctx.isPageEmpty) {
      ctx.startNewPage();
    }

    // Center horizontally.
    final x = (ctx.contentWidth - displayW) / 2;
    ctx.addElement(
      LayoutElement(
        rect: Rect.fromLTWH(x, ctx.cursorY, displayW, displayH),
        sourceNode: node,
        image: decodedImage,
      ),
    );

    ctx.cursorY += displayH;
    ctx.recordBottomMargin(bottomMargin);
  }

  void _layoutImagePlaceholder(ImageNode node, LayoutContext ctx) {
    final altText = node.alt ?? 'Image';
    final placeholder = ParagraphNode(
      children: [
        TextNode(content: '[$altText]', italic: true, fontSizeEm: 0.9),
      ],
      marginTopEm: 0.5,
      marginBottomEm: 0.5,
      align: ui.TextAlign.center,
    );
    ParagraphLayouter.layout(placeholder, ctx);
  }

  // ---------------------------------------------------------------------------
  // List
  // ---------------------------------------------------------------------------

  void _layoutList(ListNode node, LayoutContext ctx) {
    for (var i = 0; i < node.items.length; i++) {
      final item = node.items[i];
      final prefix = node.ordered ? '${i + 1}. ' : '\u2022 '; // bullet

      // Prepend prefix to the first TextNode in the item's children.
      final children = <RenderNode>[];
      var prefixAdded = false;
      for (final child in item.children) {
        if (!prefixAdded && child is TextNode) {
          children.add(
            TextNode(
              content: prefix + child.content,
              bold: child.bold,
              italic: child.italic,
              underline: child.underline,
              lineThrough: child.lineThrough,
              fontSizeEm: child.fontSizeEm,
              color: child.color,
              nodeIndex: child.nodeIndex,
            ),
          );
          prefixAdded = true;
        } else {
          children.add(child);
        }
      }
      if (!prefixAdded && children.isEmpty) {
        children.add(TextNode(content: prefix));
      }

      final listParagraph = ParagraphNode(
        children: children,
        marginTopEm: 0.0,
        marginBottomEm: 0.2,
        marginLeftEm: 1.5,
      );
      ParagraphLayouter.layout(listParagraph, ctx);
    }
  }

  // ---------------------------------------------------------------------------
  // Table
  // ---------------------------------------------------------------------------

  void _layoutTable(TableNode node, LayoutContext ctx) {
    final prefs = ctx.preferences;
    if (node.rows.isEmpty) return;

    final numCols = node.rows
        .map((r) => r.cells.length)
        .reduce((a, b) => a > b ? a : b);
    if (numCols == 0) return;

    final colWidth = ctx.contentWidth / numCols;

    for (final row in node.rows) {
      var maxCellHeight = 0.0;
      final cellPainters = <(TextPainter, TableCellNode)>[];

      for (final cell in row.cells) {
        final cellPadding = cell.paddingEm != null
            ? prefs.emToPx(cell.paddingEm!)
            : 4.0;
        final cellContentWidth = colWidth - 2 * cellPadding;

        final textSpan = TextSpanBuilder.build(
          children: cell.children.expand(_flattenToInline).toList(),
          prefs: prefs,
        );

        final painter = TextPainter(
          text: textSpan,
          textDirection: ui.TextDirection.ltr,
        )..layout(maxWidth: cellContentWidth > 0 ? cellContentWidth : 10);

        final cellHeight = painter.height + 2 * cellPadding;
        if (cellHeight > maxCellHeight) maxCellHeight = cellHeight;

        cellPainters.add((painter, cell));
      }

      // Check if row fits on current page.
      if (maxCellHeight > ctx.remainingHeight && !ctx.isPageEmpty) {
        ctx.startNewPage();
      }

      // Place cells.
      var cellX = 0.0;
      for (final (painter, cell) in cellPainters) {
        final cellPadding = cell.paddingEm != null
            ? prefs.emToPx(cell.paddingEm!)
            : 4.0;

        // Cell background.
        if (cell.backgroundColor != null) {
          ctx.addElement(
            LayoutElement(
              rect: Rect.fromLTWH(cellX, ctx.cursorY, colWidth, maxCellHeight),
              sourceNode: node,
              backgroundPaint: Paint()..color = Color(cell.backgroundColor!),
            ),
          );
        }

        // Cell border.
        if (cell.border != null && cell.border!.widthPx > 0) {
          ctx.addElement(
            LayoutElement(
              rect: Rect.fromLTWH(cellX, ctx.cursorY, colWidth, maxCellHeight),
              sourceNode: node,
              backgroundPaint: Paint()
                ..color = cell.border!.color != null
                    ? Color(cell.border!.color!)
                    : prefs.theme.textColor
                ..style = PaintingStyle.stroke
                ..strokeWidth = cell.border!.widthPx,
            ),
          );
        }

        // Cell text.
        ctx.addElement(
          LayoutElement(
            rect: Rect.fromLTWH(
              cellX + cellPadding,
              ctx.cursorY + cellPadding,
              painter.width,
              painter.height,
            ),
            sourceNode: node,
            textPainter: painter,
          ),
        );

        cellX += colWidth;
      }

      ctx.cursorY += maxCellHeight;
    }

    // Table bottom spacing.
    ctx.cursorY += prefs.emToPx(0.5);
    ctx.previousBottomMargin = prefs.emToPx(0.5);
  }

  /// Flatten nested block nodes into inline TextNodes for table cell rendering.
  List<RenderNode> _flattenToInline(RenderNode node) {
    return switch (node) {
      TextNode() => [node],
      ParagraphNode() => node.children.expand(_flattenToInline).toList(),
      HeadingNode() => node.children.expand(_flattenToInline).toList(),
      BlockQuoteNode() => node.children.expand(_flattenToInline).toList(),
      LineBreakNode() => [node],
      _ => [],
    };
  }

  // ---------------------------------------------------------------------------
  // BlockQuote
  // ---------------------------------------------------------------------------

  void _layoutBlockQuote(BlockQuoteNode node, LayoutContext ctx) {
    final paragraph = ParagraphNode(
      children: node.children,
      marginTopEm: 0.5,
      marginBottomEm: 0.5,
      marginLeftEm: 2.0,
      marginRightEm: 1.0,
      backgroundColor: node.backgroundColor,
    );
    ParagraphLayouter.layout(paragraph, ctx);
  }

  // ---------------------------------------------------------------------------
  // CodeBlock
  // ---------------------------------------------------------------------------

  void _layoutCodeBlock(CodeBlockNode node, LayoutContext ctx) {
    final paragraph = ParagraphNode(
      children: [TextNode(content: node.content, fontSizeEm: 0.85)],
      marginTopEm: 0.5,
      marginBottomEm: 0.5,
      paddingEm: 0.5,
      backgroundColor: ctx.preferences.theme == ReaderTheme.dark
          ? 0xFF2D2D2D
          : 0xFFF5F5F5,
    );
    ParagraphLayouter.layout(paragraph, ctx);
  }

  // ---------------------------------------------------------------------------
  // HorizontalRule
  // ---------------------------------------------------------------------------

  void _layoutHorizontalRule(LayoutContext ctx) {
    final prefs = ctx.preferences;
    final lineHeight = prefs.baseFontSizePx;

    if (lineHeight > ctx.remainingHeight && !ctx.isPageEmpty) {
      ctx.startNewPage();
    }

    final y = ctx.cursorY + lineHeight / 2;
    ctx.addElement(
      LayoutElement(
        rect: Rect.fromLTWH(0, y, ctx.contentWidth, 1),
        sourceNode: const HorizontalRuleNode(),
      ),
    );

    ctx.cursorY += lineHeight;
    ctx.previousBottomMargin = 0;
  }
}
