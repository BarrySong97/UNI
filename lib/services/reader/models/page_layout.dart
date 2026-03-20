import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'render_node.dart';

/// A single laid-out element on a page, with absolute position within the
/// page's content area.
class LayoutElement {
  LayoutElement({
    required this.rect,
    required this.sourceNode,
    this.textPainter,
    this.image,
    this.backgroundPaint,
    this.deferredText,
    this.deferredStyle,
  });

  /// Position and size within the page content area.
  final Rect rect;

  /// Reference to the original RenderNode that produced this element.
  final RenderNode sourceNode;

  /// For text elements: the measured and laid-out TextPainter.
  TextPainter? textPainter;

  /// For image elements: the decoded image.
  final ui.Image? image;

  /// Background color fill (if the source node has a background_color).
  final Paint? backgroundPaint;

  /// Deferred text payload for lazily creating [textPainter] when needed.
  final String? deferredText;
  final TextStyle? deferredStyle;

  /// Whether this element contains text content (eager or deferred).
  bool get hasText =>
      textPainter != null || (deferredText != null && deferredStyle != null);

  /// Lazily create and cache a [TextPainter] for deferred text elements.
  TextPainter? ensurePainter() {
    if (textPainter != null) return textPainter;
    if (deferredText == null || deferredStyle == null) return null;
    textPainter = TextPainter(
      text: TextSpan(text: deferredText, style: deferredStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter;
  }
}

/// One complete page of content.
class PageLayout {
  PageLayout({
    required this.chapterIndex,
    required this.pageIndexInChapter,
    List<LayoutElement>? elements,
    this.startNodeIndex = 0,
    this.endNodeIndex = 0,
  }) : elements = elements ?? [];

  final int chapterIndex;
  final int pageIndexInChapter;
  final List<LayoutElement> elements;

  /// First TextNode.nodeIndex on this page (for progress tracking).
  int startNodeIndex;

  /// Last TextNode.nodeIndex on this page.
  int endNodeIndex;
}

/// Result of paginating an entire chapter.
class ChapterPagination {
  const ChapterPagination({
    required this.chapterIndex,
    required this.pages,
    required this.viewportSize,
    required this.preferencesHash,
  });

  final int chapterIndex;
  final List<PageLayout> pages;
  final Size viewportSize;
  final int preferencesHash;
}
