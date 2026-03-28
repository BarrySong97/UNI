import '../../services/reader/models/page_layout.dart';

/// Encapsulates display-mode-specific navigation and page addressing.
///
/// Two implementations:
/// - [SinglePageStrategy]: phone mode, one page at a time
/// - [DualPageStrategy]: tablet mode, two pages side-by-side as a spread
abstract class PageNavigationStrategy {
  /// Number of page indices to advance/retreat per navigation step.
  int get pageStep;

  /// Align a raw page index to a valid position for this display mode.
  ///
  /// Single-page: identity (already clamped).
  /// Dual-page: round down to nearest even index so the left page of a
  /// spread is always even.
  int alignPageIndex(int rawIndex, int maxIndex);

  /// Whether the current position covers the last page in the chapter.
  ///
  /// Single-page: true when [currentIndex] >= [totalPages] - 1.
  /// Dual-page: true when the spread [currentIndex, currentIndex+1]
  /// includes the last page.
  bool coversLastPage(int currentIndex, int totalPages);

  /// The right page of the current spread (always null in single-page mode).
  PageLayout? secondPage(List<PageLayout> pages, int currentIndex);

  /// The book page number for the right page of the current spread.
  /// Returns 0 when not applicable.
  int secondBookPage(int currentBookPage, bool hasSecondPage);

  // ---------------------------------------------------------------------------
  // Spread preview getters for swipe animation
  // ---------------------------------------------------------------------------

  /// Left page of the next spread preview.
  ///
  /// [nextChapterPages] provides the pages of the next visible chapter
  /// (skipping absorbed chapters) for cross-chapter transitions.
  PageLayout? nextPreviewLeft({
    required List<PageLayout> pages,
    required int currentIndex,
    required List<PageLayout>? Function() nextChapterPages,
  });

  /// Right page of the next spread preview (always null in single-page mode).
  PageLayout? nextPreviewRight({
    required List<PageLayout> pages,
    required int currentIndex,
    required List<PageLayout>? Function() nextChapterPages,
  });

  /// Left page of the previous spread preview.
  ///
  /// [prevChapterPages] provides the pages of the previous visible chapter
  /// (skipping absorbed chapters) for cross-chapter transitions.
  PageLayout? prevPreviewLeft({
    required List<PageLayout> pages,
    required int currentIndex,
    required List<PageLayout>? Function() prevChapterPages,
  });

  /// Right page of the previous spread preview (always null in single-page mode).
  PageLayout? prevPreviewRight({
    required List<PageLayout> pages,
    required int currentIndex,
    required List<PageLayout>? Function() prevChapterPages,
  });
}

// =============================================================================
// Single-page mode (phone)
// =============================================================================

/// Phone layout: one page visible at a time, step size of 1.
class SinglePageStrategy implements PageNavigationStrategy {
  const SinglePageStrategy();

  @override
  int get pageStep => 1;

  @override
  int alignPageIndex(int rawIndex, int maxIndex) =>
      rawIndex.clamp(0, maxIndex);

  @override
  bool coversLastPage(int currentIndex, int totalPages) =>
      totalPages <= 0 || currentIndex >= totalPages - 1;

  @override
  PageLayout? secondPage(List<PageLayout> pages, int currentIndex) => null;

  @override
  int secondBookPage(int currentBookPage, bool hasSecondPage) => 0;

  // -- Preview pages for swipe animation --

  @override
  PageLayout? nextPreviewLeft({
    required List<PageLayout> pages,
    required int currentIndex,
    required List<PageLayout>? Function() nextChapterPages,
  }) {
    final nextIdx = currentIndex + 1;
    if (nextIdx < pages.length) return pages[nextIdx];
    final next = nextChapterPages();
    return (next != null && next.isNotEmpty) ? next.first : null;
  }

  @override
  PageLayout? nextPreviewRight({
    required List<PageLayout> pages,
    required int currentIndex,
    required List<PageLayout>? Function() nextChapterPages,
  }) =>
      null;

  @override
  PageLayout? prevPreviewLeft({
    required List<PageLayout> pages,
    required int currentIndex,
    required List<PageLayout>? Function() prevChapterPages,
  }) {
    if (currentIndex > 0) return pages[currentIndex - 1];
    final prev = prevChapterPages();
    return (prev != null && prev.isNotEmpty) ? prev.last : null;
  }

  @override
  PageLayout? prevPreviewRight({
    required List<PageLayout> pages,
    required int currentIndex,
    required List<PageLayout>? Function() prevChapterPages,
  }) =>
      null;
}

// =============================================================================
// Dual-page mode (tablet)
// =============================================================================

/// Tablet layout: two pages shown as a spread, step size of 2.
/// The left page is always at an even index.
class DualPageStrategy implements PageNavigationStrategy {
  const DualPageStrategy();

  @override
  int get pageStep => 2;

  @override
  int alignPageIndex(int rawIndex, int maxIndex) {
    final clamped = rawIndex.clamp(0, maxIndex);
    return clamped.isOdd ? (clamped - 1).clamp(0, maxIndex) : clamped;
  }

  @override
  bool coversLastPage(int currentIndex, int totalPages) {
    if (totalPages <= 0) return true;
    final lastIdx = totalPages - 1;
    // The spread covers [currentIndex, currentIndex+1].
    return currentIndex >= lastIdx || currentIndex + 1 >= lastIdx;
  }

  @override
  PageLayout? secondPage(List<PageLayout> pages, int currentIndex) {
    final nextIdx = currentIndex + 1;
    if (nextIdx < pages.length) return pages[nextIdx];
    return null;
  }

  @override
  int secondBookPage(int currentBookPage, bool hasSecondPage) {
    if (!hasSecondPage) return 0;
    return currentBookPage + 1;
  }

  // -- Preview pages for swipe animation --

  @override
  PageLayout? nextPreviewLeft({
    required List<PageLayout> pages,
    required int currentIndex,
    required List<PageLayout>? Function() nextChapterPages,
  }) {
    final nextLeftIdx = currentIndex + 2;
    if (nextLeftIdx < pages.length) return pages[nextLeftIdx];
    final next = nextChapterPages();
    return (next != null && next.isNotEmpty) ? next.first : null;
  }

  @override
  PageLayout? nextPreviewRight({
    required List<PageLayout> pages,
    required int currentIndex,
    required List<PageLayout>? Function() nextChapterPages,
  }) {
    final nextLeftIdx = currentIndex + 2;
    if (nextLeftIdx < pages.length) {
      final nextRightIdx = nextLeftIdx + 1;
      if (nextRightIdx < pages.length) return pages[nextRightIdx];
      return null;
    }
    // Cross-chapter: return the second page (index 1) of the next chapter.
    final next = nextChapterPages();
    return (next != null && next.length >= 2) ? next[1] : null;
  }

  @override
  PageLayout? prevPreviewLeft({
    required List<PageLayout> pages,
    required int currentIndex,
    required List<PageLayout>? Function() prevChapterPages,
  }) {
    if (currentIndex >= 2) return pages[currentIndex - 2];
    final prev = prevChapterPages();
    if (prev == null || prev.isEmpty) return null;
    // The left page of the last spread in the previous chapter.
    final lastIdx = prev.length - 1;
    final leftIdx = lastIdx.isOdd ? lastIdx - 1 : lastIdx;
    return prev[leftIdx];
  }

  @override
  PageLayout? prevPreviewRight({
    required List<PageLayout> pages,
    required int currentIndex,
    required List<PageLayout>? Function() prevChapterPages,
  }) {
    if (currentIndex >= 2) return pages[currentIndex - 1];
    final prev = prevChapterPages();
    if (prev == null || prev.isEmpty) return null;
    // The right page of the last spread: only present if the chapter has
    // an odd number of pages (last index is odd → right page exists).
    final lastIdx = prev.length - 1;
    return lastIdx.isOdd ? prev[lastIdx] : null;
  }
}
