import '../models/page_layout.dart';
import 'page_hit_test.dart';

/// A position within the entire book, identifying a specific character.
class BookPosition implements Comparable<BookPosition> {
  const BookPosition({
    required this.chapterIndex,
    required this.pageIndexInChapter,
    required this.elementIndex,
    required this.charOffset,
  });

  final int chapterIndex;
  final int pageIndexInChapter;
  final int elementIndex;
  final int charOffset;

  /// Create from a [PagePosition] on a known page.
  factory BookPosition.fromPagePosition(
    PagePosition pos, {
    required int chapterIndex,
    required int pageIndexInChapter,
  }) => BookPosition(
    chapterIndex: chapterIndex,
    pageIndexInChapter: pageIndexInChapter,
    elementIndex: pos.elementIndex,
    charOffset: pos.charOffset,
  );

  /// Convert to a [PagePosition] (drops page/chapter info).
  PagePosition toPagePosition() =>
      PagePosition(elementIndex: elementIndex, charOffset: charOffset);

  @override
  int compareTo(BookPosition other) {
    var cmp = chapterIndex.compareTo(other.chapterIndex);
    if (cmp != 0) return cmp;
    cmp = pageIndexInChapter.compareTo(other.pageIndexInChapter);
    if (cmp != 0) return cmp;
    cmp = elementIndex.compareTo(other.elementIndex);
    if (cmp != 0) return cmp;
    return charOffset.compareTo(other.charOffset);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookPosition &&
          chapterIndex == other.chapterIndex &&
          pageIndexInChapter == other.pageIndexInChapter &&
          elementIndex == other.elementIndex &&
          charOffset == other.charOffset;

  @override
  int get hashCode =>
      Object.hash(chapterIndex, pageIndexInChapter, elementIndex, charOffset);
}

/// A text selection that may span multiple pages and chapters.
class CrossPageSelection {
  const CrossPageSelection({required this.start, required this.end});

  /// The earlier position (smaller in document order).
  final BookPosition start;

  /// The later position.
  final BookPosition end;

  /// Whether this selection is contained within a single page.
  bool get isSinglePage =>
      start.chapterIndex == end.chapterIndex &&
      start.pageIndexInChapter == end.pageIndexInChapter;

  /// Whether [page] identified by chapter/page index falls within this
  /// selection's range.
  bool containsPage(int chapterIndex, int pageIndexInChapter) {
    // Before selection start page.
    if (chapterIndex < start.chapterIndex ||
        (chapterIndex == start.chapterIndex &&
            pageIndexInChapter < start.pageIndexInChapter)) {
      return false;
    }
    // After selection end page.
    if (chapterIndex > end.chapterIndex ||
        (chapterIndex == end.chapterIndex &&
            pageIndexInChapter > end.pageIndexInChapter)) {
      return false;
    }
    return true;
  }

  /// Project this book-level selection onto a single [PageLayout].
  ///
  /// Returns the portion of the selection that falls on the given page, or
  /// `null` if the selection does not intersect this page at all.
  PageSelection? projectOntoPage(PageLayout page) {
    final ch = page.chapterIndex;
    final pg = page.pageIndexInChapter;
    if (!containsPage(ch, pg)) return null;

    final isStartPage =
        ch == start.chapterIndex && pg == start.pageIndexInChapter;
    final isEndPage = ch == end.chapterIndex && pg == end.pageIndexInChapter;

    if (isStartPage && isEndPage) {
      return PageSelection(
        start: start.toPagePosition(),
        end: end.toPagePosition(),
      );
    } else if (isStartPage) {
      return PageSelection(
        start: start.toPagePosition(),
        end: _endOfPage(page),
      );
    } else if (isEndPage) {
      return PageSelection(
        start: const PagePosition(elementIndex: 0, charOffset: 0),
        end: end.toPagePosition(),
      );
    } else {
      // Intermediate page — select everything.
      return PageSelection(
        start: const PagePosition(elementIndex: 0, charOffset: 0),
        end: _endOfPage(page),
      );
    }
  }

  /// Create a normalized selection (start <= end) from two arbitrary positions.
  factory CrossPageSelection.normalized(BookPosition a, BookPosition b) {
    if (a.compareTo(b) <= 0) {
      return CrossPageSelection(start: a, end: b);
    }
    return CrossPageSelection(start: b, end: a);
  }
}

/// The last position on a page (last element, last char offset).
PagePosition _endOfPage(PageLayout page) {
  if (page.elements.isEmpty) {
    return const PagePosition(elementIndex: 0, charOffset: 0);
  }
  for (var i = page.elements.length - 1; i >= 0; i--) {
    final painter = page.elements[i].ensurePainter();
    if (painter == null) continue;
    return PagePosition(
      elementIndex: i,
      charOffset: extractPainterTextLength(painter),
    );
  }
  return const PagePosition(elementIndex: 0, charOffset: 0);
}
