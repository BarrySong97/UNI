import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/reader/models/page_layout.dart';
import 'package:uni/stores/reader/page_navigation_strategy.dart';

/// Helper to create a minimal PageLayout for testing.
PageLayout _page(int chapter, int page) =>
    PageLayout(chapterIndex: chapter, pageIndexInChapter: page);

void main() {
  // ===========================================================================
  // SinglePageStrategy
  // ===========================================================================
  group('SinglePageStrategy', () {
    const strategy = SinglePageStrategy();

    test('pageStep is 1', () {
      expect(strategy.pageStep, 1);
    });

    test('alignPageIndex returns raw index clamped', () {
      expect(strategy.alignPageIndex(0, 10), 0);
      expect(strategy.alignPageIndex(5, 10), 5);
      expect(strategy.alignPageIndex(10, 10), 10);
      // Odd index stays odd — no alignment.
      expect(strategy.alignPageIndex(3, 10), 3);
      expect(strategy.alignPageIndex(7, 10), 7);
    });

    test('coversLastPage when at last page', () {
      expect(strategy.coversLastPage(9, 10), true);
      expect(strategy.coversLastPage(8, 10), false);
      expect(strategy.coversLastPage(0, 1), true);
      expect(strategy.coversLastPage(0, 0), true);
    });

    test('secondPage always returns null', () {
      final pages = [_page(0, 0), _page(0, 1), _page(0, 2)];
      expect(strategy.secondPage(pages, 0), isNull);
      expect(strategy.secondPage(pages, 1), isNull);
    });

    test('secondBookPage always returns 0', () {
      expect(strategy.secondBookPage(5, true), 0);
      expect(strategy.secondBookPage(5, false), 0);
    });

    // -- Preview pages --

    test('nextPreviewLeft returns next page in chapter', () {
      final pages = [_page(0, 0), _page(0, 1), _page(0, 2)];
      expect(
        strategy.nextPreviewLeft(
          pages: pages,
          currentIndex: 0,
          nextChapterPages: () => null,
        ),
        same(pages[1]),
      );
    });

    test('nextPreviewLeft falls back to next chapter first page', () {
      final pages = [_page(0, 0)];
      final nextCh = [_page(1, 0), _page(1, 1)];
      expect(
        strategy.nextPreviewLeft(
          pages: pages,
          currentIndex: 0,
          nextChapterPages: () => nextCh,
        ),
        same(nextCh[0]),
      );
    });

    test('nextPreviewLeft returns null when no more pages', () {
      final pages = [_page(0, 0)];
      expect(
        strategy.nextPreviewLeft(
          pages: pages,
          currentIndex: 0,
          nextChapterPages: () => null,
        ),
        isNull,
      );
    });

    test('nextPreviewRight always returns null', () {
      final pages = [_page(0, 0), _page(0, 1)];
      expect(
        strategy.nextPreviewRight(
          pages: pages,
          currentIndex: 0,
          nextChapterPages: () => null,
        ),
        isNull,
      );
    });

    test('prevPreviewLeft returns previous page in chapter', () {
      final pages = [_page(0, 0), _page(0, 1), _page(0, 2)];
      expect(
        strategy.prevPreviewLeft(
          pages: pages,
          currentIndex: 2,
          prevChapterPages: () => null,
        ),
        same(pages[1]),
      );
    });

    test('prevPreviewLeft falls back to prev chapter last page', () {
      final pages = [_page(1, 0)];
      final prevCh = [_page(0, 0), _page(0, 1), _page(0, 2)];
      expect(
        strategy.prevPreviewLeft(
          pages: pages,
          currentIndex: 0,
          prevChapterPages: () => prevCh,
        ),
        same(prevCh[2]),
      );
    });

    test('prevPreviewRight always returns null', () {
      final pages = [_page(0, 0), _page(0, 1)];
      expect(
        strategy.prevPreviewRight(
          pages: pages,
          currentIndex: 1,
          prevChapterPages: () => null,
        ),
        isNull,
      );
    });
  });

  // ===========================================================================
  // DualPageStrategy
  // ===========================================================================
  group('DualPageStrategy', () {
    const strategy = DualPageStrategy();

    test('pageStep is 2', () {
      expect(strategy.pageStep, 2);
    });

    test('alignPageIndex rounds odd down to even', () {
      expect(strategy.alignPageIndex(0, 10), 0);
      expect(strategy.alignPageIndex(1, 10), 0); // 1 → 0
      expect(strategy.alignPageIndex(2, 10), 2);
      expect(strategy.alignPageIndex(3, 10), 2); // 3 → 2
      expect(strategy.alignPageIndex(9, 10), 8); // 9 → 8
      expect(strategy.alignPageIndex(10, 10), 10);
    });

    test('alignPageIndex handles single-page chapter', () {
      // maxIndex = 0, raw = 0 → 0
      expect(strategy.alignPageIndex(0, 0), 0);
    });

    test('coversLastPage with even total pages', () {
      // 10 pages, spread [8,9] covers last
      expect(strategy.coversLastPage(8, 10), true);
      // spread [6,7] does not
      expect(strategy.coversLastPage(6, 10), false);
    });

    test('coversLastPage with odd total pages', () {
      // 9 pages (lastIdx=8), spread [8,9] — 8 >= 8, covers
      expect(strategy.coversLastPage(8, 9), true);
      // spread [6,7] — 7 < 8, does not cover
      expect(strategy.coversLastPage(6, 9), false);
    });

    test('coversLastPage edge: 1-page chapter', () {
      expect(strategy.coversLastPage(0, 1), true);
    });

    test('coversLastPage edge: 2-page chapter', () {
      expect(strategy.coversLastPage(0, 2), true);
    });

    test('coversLastPage edge: empty chapter', () {
      expect(strategy.coversLastPage(0, 0), true);
    });

    test('secondPage returns page at currentIndex+1', () {
      final pages = [_page(0, 0), _page(0, 1), _page(0, 2), _page(0, 3)];
      expect(strategy.secondPage(pages, 0), same(pages[1]));
      expect(strategy.secondPage(pages, 2), same(pages[3]));
    });

    test('secondPage returns null for odd-page chapter at last spread', () {
      final pages = [_page(0, 0), _page(0, 1), _page(0, 2)];
      // Spread starts at 2, no page at 3
      expect(strategy.secondPage(pages, 2), isNull);
    });

    test('secondBookPage returns currentBookPage+1 when second exists', () {
      expect(strategy.secondBookPage(5, true), 6);
    });

    test('secondBookPage returns 0 when no second page', () {
      expect(strategy.secondBookPage(5, false), 0);
    });

    // -- Preview pages --

    test('nextPreviewLeft returns page at currentIndex+2', () {
      final pages = List.generate(6, (i) => _page(0, i));
      expect(
        strategy.nextPreviewLeft(
          pages: pages,
          currentIndex: 0,
          nextChapterPages: () => null,
        ),
        same(pages[2]),
      );
      expect(
        strategy.nextPreviewLeft(
          pages: pages,
          currentIndex: 2,
          nextChapterPages: () => null,
        ),
        same(pages[4]),
      );
    });

    test('nextPreviewLeft falls back to next chapter first page', () {
      final pages = [_page(0, 0), _page(0, 1)];
      final nextCh = [_page(1, 0), _page(1, 1)];
      expect(
        strategy.nextPreviewLeft(
          pages: pages,
          currentIndex: 0,
          nextChapterPages: () => nextCh,
        ),
        same(nextCh[0]),
      );
    });

    test('nextPreviewRight returns page at currentIndex+3', () {
      final pages = List.generate(6, (i) => _page(0, i));
      expect(
        strategy.nextPreviewRight(
          pages: pages,
          currentIndex: 0,
          nextChapterPages: () => null,
        ),
        same(pages[3]),
      );
    });

    test('nextPreviewRight returns null for odd remaining pages', () {
      // 3 pages, current spread [0,1], next left would be pages[2] but
      // no pages[3], so right is null.
      final pages = [_page(0, 0), _page(0, 1), _page(0, 2)];
      expect(
        strategy.nextPreviewRight(
          pages: pages,
          currentIndex: 0,
          nextChapterPages: () => null,
        ),
        isNull,
      );
    });

    test('nextPreviewRight cross-chapter returns second page', () {
      final pages = [_page(0, 0), _page(0, 1)];
      final nextCh = [_page(1, 0), _page(1, 1)];
      expect(
        strategy.nextPreviewRight(
          pages: pages,
          currentIndex: 0,
          nextChapterPages: () => nextCh,
        ),
        same(nextCh[1]),
      );
    });

    test('nextPreviewRight cross-chapter null if next chapter has < 2 pages',
        () {
      final pages = [_page(0, 0), _page(0, 1)];
      final nextCh = [_page(1, 0)];
      expect(
        strategy.nextPreviewRight(
          pages: pages,
          currentIndex: 0,
          nextChapterPages: () => nextCh,
        ),
        isNull,
      );
    });

    test('prevPreviewLeft returns page at currentIndex-2', () {
      final pages = List.generate(6, (i) => _page(0, i));
      expect(
        strategy.prevPreviewLeft(
          pages: pages,
          currentIndex: 4,
          prevChapterPages: () => null,
        ),
        same(pages[2]),
      );
    });

    test('prevPreviewLeft cross-chapter even total (no right page)', () {
      // Prev chapter has 4 pages: lastIdx=3 (odd) → leftIdx=2
      final pages = [_page(1, 0), _page(1, 1)];
      final prevCh = List.generate(4, (i) => _page(0, i));
      expect(
        strategy.prevPreviewLeft(
          pages: pages,
          currentIndex: 0,
          prevChapterPages: () => prevCh,
        ),
        same(prevCh[2]),
      );
    });

    test('prevPreviewLeft cross-chapter odd total', () {
      // Prev chapter has 3 pages: lastIdx=2 (even) → leftIdx=2
      final pages = [_page(1, 0), _page(1, 1)];
      final prevCh = List.generate(3, (i) => _page(0, i));
      expect(
        strategy.prevPreviewLeft(
          pages: pages,
          currentIndex: 0,
          prevChapterPages: () => prevCh,
        ),
        same(prevCh[2]),
      );
    });

    test('prevPreviewRight returns page at currentIndex-1', () {
      final pages = List.generate(6, (i) => _page(0, i));
      expect(
        strategy.prevPreviewRight(
          pages: pages,
          currentIndex: 4,
          prevChapterPages: () => null,
        ),
        same(pages[3]),
      );
    });

    test('prevPreviewRight cross-chapter odd lastIdx returns last page', () {
      // Prev chapter has 4 pages: lastIdx=3 (odd) → right page exists
      final pages = [_page(1, 0), _page(1, 1)];
      final prevCh = List.generate(4, (i) => _page(0, i));
      expect(
        strategy.prevPreviewRight(
          pages: pages,
          currentIndex: 0,
          prevChapterPages: () => prevCh,
        ),
        same(prevCh[3]),
      );
    });

    test('prevPreviewRight cross-chapter even lastIdx returns null', () {
      // Prev chapter has 3 pages: lastIdx=2 (even) → no right page
      final pages = [_page(1, 0), _page(1, 1)];
      final prevCh = List.generate(3, (i) => _page(0, i));
      expect(
        strategy.prevPreviewRight(
          pages: pages,
          currentIndex: 0,
          prevChapterPages: () => prevCh,
        ),
        isNull,
      );
    });
  });
}
