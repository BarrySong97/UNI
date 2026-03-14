import 'dart:convert';
import 'dart:math' as math;
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
    final imageNodes = <ImageNode>[];
    for (final node in nodes) {
      _collectImageNodes(node, imageNodes);
    }

    // Decode at physical pixel width to stay sharp on Retina/HiDPI screens.
    final targetPx = (maxWidth * devicePixelRatio).toInt();
    for (final node in imageNodes) {
      if (node.dataBase64 == null) continue;
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

  void _layoutNode(
    RenderNode node,
    LayoutContext ctx, {
    double nestingIndentEm = 0.0,
  }) {
    switch (node) {
      case ParagraphNode():
        final paragraph = nestingIndentEm > 0
            ? ParagraphNode(
                children: node.children,
                marginTopEm: node.marginTopEm,
                marginBottomEm: node.marginBottomEm,
                marginLeftEm: node.marginLeftEm + nestingIndentEm,
                marginRightEm: node.marginRightEm,
                align: node.align,
                textIndentEm: node.textIndentEm,
                lineHeightEm: node.lineHeightEm,
                paddingEm: node.paddingEm,
                backgroundColor: node.backgroundColor,
                color: node.color,
              )
            : node;
        ParagraphLayouter.layout(paragraph, ctx);
      case HeadingNode():
        _layoutHeading(node, ctx, nestingIndentEm: nestingIndentEm);
      case ImageNode():
        _layoutImage(node, ctx, nestingIndentEm: nestingIndentEm);
      case ListNode():
        _layoutList(node, ctx, nestingIndentEm: nestingIndentEm);
      case TableNode():
        _layoutTable(node, ctx, nestingIndentEm: nestingIndentEm);
      case BlockQuoteNode():
        _layoutBlockQuote(node, ctx, nestingIndentEm: nestingIndentEm);
      case CodeBlockNode():
        _layoutCodeBlock(node, ctx, nestingIndentEm: nestingIndentEm);
      case LineBreakNode():
        ctx.cursorY += ctx.preferences.baseFontSizePx * 0.5;
      case HorizontalRuleNode():
        _layoutHorizontalRule(ctx);
      case TextNode():
        // Bare text node outside a paragraph — wrap in a simple paragraph.
        ParagraphLayouter.layout(
          ParagraphNode(children: [node], marginLeftEm: nestingIndentEm),
          ctx,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Heading
  // ---------------------------------------------------------------------------

  void _layoutHeading(
    HeadingNode node,
    LayoutContext ctx, {
    double nestingIndentEm = 0.0,
  }) {
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
      marginLeftEm: node.marginLeftEm + nestingIndentEm,
      marginRightEm: node.marginRightEm,
      align: node.align,
      textIndentEm: node.textIndentEm,
      backgroundColor: node.backgroundColor,
      lineHeightEm: node.lineHeightEm,
      paddingEm: node.paddingEm,
      color: node.color,
    );
    ParagraphLayouter.layout(paragraphProxy, ctx, headingLevel: node.level);
  }

  // ---------------------------------------------------------------------------
  // Image
  // ---------------------------------------------------------------------------

  void _layoutImage(
    ImageNode node,
    LayoutContext ctx, {
    double nestingIndentEm = 0.0,
  }) {
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
    final indentPx = ctx.preferences.emToPx(nestingIndentEm);
    final availableWidth = math.max(0.0, ctx.contentWidth - indentPx);
    final maxW = node.widthHint != null
        ? availableWidth * node.widthHint!
        : availableWidth;
    var displayW = maxW.clamp(0.0, availableWidth);
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
    final x = indentPx + (availableWidth - displayW) / 2;
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

  void _layoutList(
    ListNode node,
    LayoutContext ctx, {
    double nestingIndentEm = 0.0,
  }) {
    final prefs = ctx.preferences;
    final indentEm = nestingIndentEm + 1.5;

    for (var i = 0; i < node.items.length; i++) {
      final item = node.items[i];
      final prefix = _listItemPrefix(node, i);

      // Measure marker for hanging-indent placement.
      final markerSpan = TextSpan(
        text: prefix,
        style: TextStyle(
          fontSize: prefs.baseFontSizePx,
          fontFamily: prefs.fontFamily,
          height: prefs.lineHeightMultiplier,
          color: prefs.theme.textColor,
        ),
      );
      final markerPainter = TextPainter(
        text: markerSpan,
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final markerWidth = markerPainter.width;

      // Snapshot layout state before placing any content for this item.
      final preLayoutCursorY = ctx.cursorY;
      final preLayoutPageCount = ctx.pages.length;
      final preLayoutElementCount = ctx.currentPage.elements.length;

      // Layout inline children as a paragraph (skip if empty).
      if (item.children.isNotEmpty) {
        final listParagraph = ParagraphNode(
          children: item.children,
          marginTopEm: 0.0,
          marginBottomEm: 0.2,
          marginLeftEm: indentEm,
        );
        ParagraphLayouter.layout(listParagraph, ctx);
      }

      // Layout block-level sub-nodes (nested lists, paragraphs, etc.)
      for (final subNode in item.subNodes) {
        _layoutNode(subNode, ctx, nestingIndentEm: indentEm);
      }

      // Find where the first text element of this item was placed,
      // then position the marker on the same page and Y.
      final markerGap = prefs.emToPx(0.3);
      final markerX = math.max(0.0, prefs.emToPx(indentEm) - markerWidth - markerGap);
      final (markerPage, markerY) = _findFirstTextPosition(
        ctx: ctx,
        preLayoutPageCount: preLayoutPageCount,
        preLayoutElementCount: preLayoutElementCount,
        preLayoutCursorY: preLayoutCursorY,
      );
      final markerElement = LayoutElement(
        rect: Rect.fromLTWH(
          markerX,
          markerY,
          markerWidth,
          markerPainter.height,
        ),
        sourceNode: node,
        textPainter: markerPainter,
      );
      if (markerPage != null) {
        markerPage.elements.add(markerElement);
      } else {
        ctx.addElement(markerElement);
      }
    }
  }

  /// Search for the first text element placed after a layout snapshot.
  ///
  /// Returns `(page, y)` where page is a completed [PageLayout] (or null
  /// for the current page) and y is the top of the first text element.
  (PageLayout?, double) _findFirstTextPosition({
    required LayoutContext ctx,
    required int preLayoutPageCount,
    required int preLayoutElementCount,
    required double preLayoutCursorY,
  }) {
    // 1. Check the page that was current at snapshot time (now possibly completed).
    if (ctx.pages.length > preLayoutPageCount) {
      final snapshotPage = ctx.pages[preLayoutPageCount];
      for (var j = preLayoutElementCount; j < snapshotPage.elements.length; j++) {
        if (snapshotPage.elements[j].textPainter != null) {
          return (snapshotPage, snapshotPage.elements[j].rect.top);
        }
      }
      // 2. Check pages created after the snapshot page.
      for (var p = preLayoutPageCount + 1; p < ctx.pages.length; p++) {
        for (final el in ctx.pages[p].elements) {
          if (el.textPainter != null) return (ctx.pages[p], el.rect.top);
        }
      }
    }
    // 3. Check the current page (either no page break happened, or text
    //    ended up on the still-open current page).
    final elements = ctx.currentPage.elements;
    final startIdx = ctx.pages.length > preLayoutPageCount
        ? 0
        : preLayoutElementCount;
    for (var j = startIdx; j < elements.length; j++) {
      if (elements[j].textPainter != null) {
        return (null, elements[j].rect.top);
      }
    }
    // Fallback: no text element found, use pre-layout cursor.
    return (null, preLayoutCursorY);
  }

  // ---------------------------------------------------------------------------
  // Table
  // ---------------------------------------------------------------------------

  void _layoutTable(
    TableNode node,
    LayoutContext ctx, {
    double nestingIndentEm = 0.0,
  }) {
    final prefs = ctx.preferences;
    if (node.rows.isEmpty) return;
    final leftIndentPx = prefs.emToPx(nestingIndentEm);
    final tableWidth = math.max(0.0, ctx.contentWidth - leftIndentPx);
    if (tableWidth <= 0) return;

    // Render table caption if present.
    if (node.caption != null && node.caption!.isNotEmpty) {
      final captionParagraph = ParagraphNode(
        children: node.caption!,
        marginTopEm: 0.3,
        marginBottomEm: 0.3,
        marginLeftEm: nestingIndentEm,
        align: ui.TextAlign.center,
      );
      ParagraphLayouter.layout(captionParagraph, ctx);
    }

    // Compute logical column count accounting for colspan.
    final numCols = node.rows
        .map(
          (r) => r.cells.fold<int>(0, (sum, cell) => sum + (cell.colspan ?? 1)),
        )
        .reduce((a, b) => a > b ? a : b);
    if (numCols == 0) return;

    final slotWidth = tableWidth / numCols;

    for (final row in node.rows) {
      var maxCellHeight = 0.0;
      final cellPaintData = <_TableCellPaintData>[];

      for (final cell in row.cells) {
        final cellColspan = cell.colspan ?? 1;
        final cellWidth = slotWidth * cellColspan;
        final cellPadding = cell.paddingEm != null
            ? prefs.emToPx(cell.paddingEm!)
            : 4.0;
        final cellContentWidth = cellWidth - 2 * cellPadding;

        final textSpan = TextSpanBuilder.build(
          children: cell.children.expand(_flattenToInline).toList(),
          prefs: prefs,
        );

        final painter = _newTableCellPainter(textSpan, cellContentWidth);

        final cellHeight = painter.height + 2 * cellPadding;
        if (cellHeight > maxCellHeight) maxCellHeight = cellHeight;

        cellPaintData.add(
          _TableCellPaintData(
            painter: painter,
            cell: cell,
            cellWidth: cellWidth,
            cellPadding: cellPadding,
            contentWidth: cellContentWidth,
            remainingText: textSpan,
          ),
        );
      }

      // Check if row fits on current page.
      if (maxCellHeight > ctx.contentHeight) {
        _layoutOversizedTableRow(
          node: node,
          ctx: ctx,
          rowData: cellPaintData,
          leftIndentPx: leftIndentPx,
        );
        continue;
      }

      if (maxCellHeight > ctx.remainingHeight) {
        ctx.startNewPage();
      }

      // Place cells.
      var cellX = leftIndentPx;
      for (final data in cellPaintData) {
        final painter = data.painter;
        final cell = data.cell;
        final cellWidth = data.cellWidth;
        final cellPadding = data.cellPadding;

        // Cell background.
        if (cell.backgroundColor != null) {
          ctx.addElement(
            LayoutElement(
              rect: Rect.fromLTWH(cellX, ctx.cursorY, cellWidth, maxCellHeight),
              sourceNode: node,
              backgroundPaint: Paint()..color = Color(cell.backgroundColor!),
            ),
          );
        }

        // Cell border (default thin border when CSS doesn't specify one).
        ctx.addElement(
          LayoutElement(
            rect: Rect.fromLTWH(cellX, ctx.cursorY, cellWidth, maxCellHeight),
            sourceNode: node,
            backgroundPaint: _tableCellBorderPaint(cell.border, prefs),
          ),
        );

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

        cellX += cellWidth;
      }

      ctx.cursorY += maxCellHeight;
    }

    // Table bottom spacing.
    ctx.cursorY += prefs.emToPx(0.5);
    ctx.previousBottomMargin = prefs.emToPx(0.5);
  }

  void _layoutOversizedTableRow({
    required TableNode node,
    required LayoutContext ctx,
    required List<_TableCellPaintData> rowData,
    required double leftIndentPx,
  }) {
    final remainingSpans = rowData.map((e) => e.remainingText).toList();

    while (true) {
      if (ctx.remainingHeight <= 0) {
        ctx.startNewPage();
      }

      var rowChunkHeight = 0.0;
      final chunkPainters = <TextPainter?>[];
      final nextSpans = <TextSpan>[];
      var hasVisibleContent = false;
      var hasRemainingContent = false;

      for (var i = 0; i < rowData.length; i++) {
        final data = rowData[i];
        final currentSpan = remainingSpans[i];
        final contentMaxHeight = ctx.remainingHeight - 2 * data.cellPadding;

        if (_isTextSpanEmpty(currentSpan) || contentMaxHeight <= 0) {
          chunkPainters.add(null);
          nextSpans.add(currentSpan);
          continue;
        }

        final fullPainter = _newTableCellPainter(
          currentSpan,
          data.contentWidth,
        );
        final metrics = fullPainter.computeLineMetrics();

        var fittingLines = 0;
        var usedHeight = 0.0;
        for (final line in metrics) {
          if (usedHeight + line.height > contentMaxHeight) break;
          usedHeight += line.height;
          fittingLines++;
        }

        if (fittingLines == 0) {
          chunkPainters.add(null);
          nextSpans.add(currentSpan);
          hasRemainingContent = true;
          continue;
        }

        if (fittingLines >= metrics.length) {
          chunkPainters.add(fullPainter);
          nextSpans.add(const TextSpan(children: []));
          rowChunkHeight = math.max(
            rowChunkHeight,
            fullPainter.height + 2 * data.cellPadding,
          );
          hasVisibleContent = true;
          continue;
        }

        final splitOffset = ParagraphLayouter.findSplitOffset(
          fullPainter,
          metrics,
          fittingLines,
        );
        final firstPart = ParagraphLayouter.truncateTextSpan(
          currentSpan,
          splitOffset,
        );
        final remainingPart = ParagraphLayouter.skipTextSpan(
          currentSpan,
          splitOffset,
        );
        final firstPainter = _newTableCellPainter(firstPart, data.contentWidth);

        chunkPainters.add(firstPainter);
        nextSpans.add(remainingPart);
        rowChunkHeight = math.max(
          rowChunkHeight,
          firstPainter.height + 2 * data.cellPadding,
        );
        hasVisibleContent = true;
        hasRemainingContent = true;
      }

      if (!hasVisibleContent) {
        if (!ctx.isPageEmpty) {
          ctx.startNewPage();
          continue;
        }
        return;
      }

      var cellX = leftIndentPx;
      for (var i = 0; i < rowData.length; i++) {
        final data = rowData[i];
        final painter = chunkPainters[i];

        if (data.cell.backgroundColor != null) {
          ctx.addElement(
            LayoutElement(
              rect: Rect.fromLTWH(
                cellX,
                ctx.cursorY,
                data.cellWidth,
                rowChunkHeight,
              ),
              sourceNode: node,
              backgroundPaint: Paint()
                ..color = Color(data.cell.backgroundColor!),
            ),
          );
        }

        ctx.addElement(
          LayoutElement(
            rect: Rect.fromLTWH(
              cellX,
              ctx.cursorY,
              data.cellWidth,
              rowChunkHeight,
            ),
            sourceNode: node,
            backgroundPaint: _tableCellBorderPaint(
              data.cell.border,
              ctx.preferences,
            ),
          ),
        );

        if (painter != null) {
          ctx.addElement(
            LayoutElement(
              rect: Rect.fromLTWH(
                cellX + data.cellPadding,
                ctx.cursorY + data.cellPadding,
                painter.width,
                painter.height,
              ),
              sourceNode: node,
              textPainter: painter,
            ),
          );
        }

        cellX += data.cellWidth;
      }

      ctx.cursorY += rowChunkHeight;
      for (var i = 0; i < nextSpans.length; i++) {
        remainingSpans[i] = nextSpans[i];
      }

      if (!hasRemainingContent || nextSpans.every(_isTextSpanEmpty)) {
        return;
      }
      ctx.startNewPage();
    }
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

  void _layoutBlockQuote(
    BlockQuoteNode node,
    LayoutContext ctx, {
    double nestingIndentEm = 0.0,
  }) {
    final paragraph = ParagraphNode(
      children: node.children,
      marginTopEm: node.marginTopEm,
      marginBottomEm: node.marginBottomEm,
      marginLeftEm: node.marginLeftEm + nestingIndentEm,
      marginRightEm: node.marginRightEm,
      backgroundColor: node.backgroundColor,
    );
    ParagraphLayouter.layout(paragraph, ctx);
  }

  // ---------------------------------------------------------------------------
  // CodeBlock
  // ---------------------------------------------------------------------------

  void _layoutCodeBlock(
    CodeBlockNode node,
    LayoutContext ctx, {
    double nestingIndentEm = 0.0,
  }) {
    // Prefer styled children (syntax-highlighted spans) over plain content.
    final children = node.children.isNotEmpty
        ? node.children
        : <RenderNode>[TextNode(content: node.content, fontSizeEm: 0.85)];

    final bgColor =
        node.backgroundColor ??
        (ctx.preferences.theme == ReaderTheme.dark ? 0xFF2D2D2D : 0xFFF5F5F5);

    final paragraph = ParagraphNode(
      children: children,
      marginTopEm: 0.5,
      marginBottomEm: 0.5,
      marginLeftEm: nestingIndentEm,
      paddingEm: node.paddingEm ?? 0.5,
      backgroundColor: bgColor,
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

  Paint _tableCellBorderPaint(BorderNode? border, ReaderPreferences prefs) {
    if (border != null && border.widthPx > 0) {
      return Paint()
        ..color = border.color != null
            ? Color(border.color!)
            : prefs.theme.textColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = border.widthPx;
    }
    return Paint()
      ..color = prefs.theme.textColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
  }

  TextPainter _newTableCellPainter(TextSpan span, double maxWidth) {
    return TextPainter(text: span, textDirection: ui.TextDirection.ltr)
      ..layout(maxWidth: maxWidth > 0 ? maxWidth : 10);
  }

  bool _isTextSpanEmpty(TextSpan span) {
    final text = span.toPlainText();
    return text.trim().isEmpty;
  }

  String _listItemPrefix(ListNode node, int index) {
    if (!node.ordered) {
      return switch (node.listStyle?.toLowerCase()) {
        'circle' => '○',
        'square' => '■',
        _ => '\u2022',
      };
    }

    final number = index + 1;
    return switch (node.listStyle?.toLowerCase()) {
      'lower-alpha' => '${_toAlpha(number, upper: false)}.',
      'upper-alpha' => '${_toAlpha(number, upper: true)}.',
      'lower-roman' => '${_toRoman(number).toLowerCase()}.',
      'upper-roman' => '${_toRoman(number)}.',
      _ => '$number.',
    };
  }

  String _toAlpha(int value, {required bool upper}) {
    var n = value;
    final chars = <int>[];
    while (n > 0) {
      n -= 1;
      chars.add((upper ? 65 : 97) + (n % 26));
      n = n ~/ 26;
    }
    return String.fromCharCodes(chars.reversed);
  }

  String _toRoman(int value) {
    if (value <= 0) return '0';
    final map = <(int, String)>[
      (1000, 'M'),
      (900, 'CM'),
      (500, 'D'),
      (400, 'CD'),
      (100, 'C'),
      (90, 'XC'),
      (50, 'L'),
      (40, 'XL'),
      (10, 'X'),
      (9, 'IX'),
      (5, 'V'),
      (4, 'IV'),
      (1, 'I'),
    ];
    var n = value;
    final buffer = StringBuffer();
    for (final (v, symbol) in map) {
      while (n >= v) {
        buffer.write(symbol);
        n -= v;
      }
    }
    return buffer.toString();
  }

  void _collectImageNodes(RenderNode node, List<ImageNode> out) {
    switch (node) {
      case ImageNode():
        out.add(node);
      case ParagraphNode():
        for (final child in node.children) {
          _collectImageNodes(child, out);
        }
      case HeadingNode():
        for (final child in node.children) {
          _collectImageNodes(child, out);
        }
      case ListNode():
        for (final item in node.items) {
          for (final child in item.children) {
            _collectImageNodes(child, out);
          }
          for (final subNode in item.subNodes) {
            _collectImageNodes(subNode, out);
          }
        }
      case TableNode():
        if (node.caption != null) {
          for (final child in node.caption!) {
            _collectImageNodes(child, out);
          }
        }
        for (final row in node.rows) {
          for (final cell in row.cells) {
            for (final child in cell.children) {
              _collectImageNodes(child, out);
            }
          }
        }
      case BlockQuoteNode():
        for (final child in node.children) {
          _collectImageNodes(child, out);
        }
      case CodeBlockNode():
        for (final child in node.children) {
          _collectImageNodes(child, out);
        }
      case TextNode() || LineBreakNode() || HorizontalRuleNode():
        break;
    }
  }
}

class _TableCellPaintData {
  const _TableCellPaintData({
    required this.painter,
    required this.cell,
    required this.cellWidth,
    required this.cellPadding,
    required this.contentWidth,
    required this.remainingText,
  });

  final TextPainter painter;
  final TableCellNode cell;
  final double cellWidth;
  final double cellPadding;
  final double contentWidth;
  final TextSpan remainingText;
}
