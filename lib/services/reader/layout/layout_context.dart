import 'dart:ui' as ui;

import '../models/page_layout.dart';
import '../models/reader_preferences.dart';

/// Mutable context passed through the pagination pipeline.
///
/// Tracks the cursor position, current page being built, and accumulated pages.
class LayoutContext {
  LayoutContext({
    required this.contentWidth,
    required this.contentHeight,
    required this.preferences,
    required this.chapterIndex,
    this.decodedImages = const {},
  });

  final double contentWidth;
  final double contentHeight;
  final ReaderPreferences preferences;
  final int chapterIndex;

  /// Pre-decoded images keyed by dataBase64 hashCode string.
  final Map<String, ui.Image> decodedImages;

  /// Vertical cursor position within the current page's content area.
  double cursorY = 0.0;

  /// The page currently being built.
  late PageLayout currentPage = _newPage(0);

  /// All completed pages so far.
  final List<PageLayout> pages = [];

  /// Bottom margin of the previous element (for margin collapsing).
  double previousBottomMargin = 0.0;

  /// Whether the current page has any content elements.
  bool get isPageEmpty => currentPage.elements.isEmpty;

  /// Remaining vertical space on the current page.
  double get remainingHeight => contentHeight - cursorY;

  /// Start a new page and push the current one (if non-empty).
  void startNewPage() {
    if (currentPage.elements.isNotEmpty) {
      pages.add(currentPage);
    }
    currentPage = _newPage(pages.length);
    cursorY = 0.0;
    previousBottomMargin = 0.0;
  }

  /// Apply top margin with CSS margin collapsing.
  ///
  /// If page is empty, top margin is suppressed.
  /// Otherwise, effective gap = max(previousBottomMargin, thisTopMargin) - previousBottomMargin.
  void applyTopMargin(double topMarginPx) {
    if (isPageEmpty) return;

    final effectiveGap = (topMarginPx > previousBottomMargin)
        ? topMarginPx - previousBottomMargin
        : 0.0;
    cursorY += effectiveGap;
  }

  /// Record the bottom margin of the just-placed element.
  void recordBottomMargin(double bottomMarginPx) {
    previousBottomMargin = bottomMarginPx;
    cursorY += bottomMarginPx;
  }

  /// Add a layout element to the current page.
  void addElement(LayoutElement element) {
    currentPage.elements.add(element);

    // Track nodeIndex range for progress.
    final node = element.sourceNode;
    if (node is! ui.Image) {
      // Update start/end nodeIndex if this is a text-bearing element.
      _updateNodeIndexRange(element);
    }
  }

  /// Finalize: push the last page if it has content.
  List<PageLayout> finalize() {
    if (currentPage.elements.isNotEmpty) {
      pages.add(currentPage);
    }
    return pages;
  }

  PageLayout _newPage(int pageIndex) {
    return PageLayout(
      chapterIndex: chapterIndex,
      pageIndexInChapter: pageIndex,
    );
  }

  void _updateNodeIndexRange(LayoutElement element) {
    // Extract nodeIndex from text painters by checking the source node.
    // This is a simplified version; the full implementation would walk
    // the TextSpan tree. For now, we rely on the layout engine to set
    // startNodeIndex/endNodeIndex on the page after placement.
  }
}
