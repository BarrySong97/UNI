import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../entities/book-entity.dart';
import '../../entities/reading-progress-entity.dart';
import '../../repositories/progress/progress-repository.dart';
import '../../services/reader/data/chapter_data_source.dart';
import '../../services/reader/layout/knuth_plass/paragraph_prepare_cache.dart';
import '../../services/reader/layout/knuth_plass/width_cache.dart';
import '../../services/reader/layout/reader_layout_engine.dart';
import '../../services/reader/models/page_layout.dart';
import '../../services/reader/models/parsed_chapter.dart';
import '../../services/reader/reader_href_matcher.dart';
import '../../services/reader/models/reader_preferences.dart';
import 'page_navigation_strategy.dart';

/// Manages reader state: pagination, navigation, preferences, and progress.
class ReaderStore extends ChangeNotifier {
  ReaderStore({required ProgressRepository progressRepository})
    : _progressRepository = progressRepository;

  final ProgressRepository _progressRepository;
  final ReaderLayoutEngine _engine = const ReaderLayoutEngine();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  BookEntity? _book;
  ChapterDataSource? _dataSource;
  ParsedBook? _bookData;

  int _currentChapterIndex = 0;
  int _currentPageIndex = 0;
  ChapterPagination? _currentPagination;

  ReaderPreferences _preferences = const ReaderPreferences();
  bool _isLoading = false;
  String? _error;
  bool _showControls = false;

  Size _viewportSize = Size.zero;
  double _safeAreaTop = 0.0;
  double _safeAreaBottom = 0.0;
  double _devicePixelRatio = 1.0;
  bool _isDualPage = false;
  PageNavigationStrategy _strategy = const SinglePageStrategy();

  /// Cache: cacheKey → ChapterPagination (full layout with images).
  final Map<int, ChapterPagination> _cache = {};

  /// Spine items whose content has been merged into a preceding chapter's
  /// pagination (e.g. a title-only spine item merged with its content item).
  /// These chapters are skipped during navigation.
  final Set<int> _absorbedChapters = {};
  final Set<int> _tocChapterIndexes = {};
  final Map<int, String> _tocTitleByChapterIndex = {};

  /// Cache: cacheKey → page count (lightweight, survives across page-count runs).
  final Map<int, int> _pageCountCache = {};

  /// Shared width cache across chapters — avoids re-measuring common words.
  /// Cleared when layout-affecting preferences change.
  WidthCache? _widthCache;

  /// Shared paragraph prepare cache across chapters.
  /// Cleared when layout-affecting preferences change.
  ParagraphPrepareCache? _paragraphPrepareCache;

  // ---------------------------------------------------------------------------
  // Progress save throttle — at most one DB write per [_saveInterval].
  // ---------------------------------------------------------------------------
  Timer? _progressSaveTimer;
  bool _progressDirty = false;
  static const _saveInterval = Duration(seconds: 5);

  /// Per-chapter page counts for whole-book pagination (null = not yet computed).
  List<int?> _chapterPageCounts = [];
  bool _allPagesComputed = false;

  /// Serialized page count cache for DB persistence. Only set when all page
  /// counts have been computed; carried through on every [_saveProgress] call.
  String? _persistedPageCountsJson;

  /// Monotonic token to ignore stale async pagination results.
  int _chapterLoadToken = 0;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  BookEntity? get book => _book;
  ParsedBook? get bookData => _bookData;
  int get currentChapterIndex => _currentChapterIndex;
  int get currentPageIndex => _currentPageIndex;
  int get totalPagesInChapter => _currentPagination?.pages.length ?? 0;
  PageLayout? get currentPageLayout {
    if (_currentPagination == null) return null;
    final pages = _currentPagination!.pages;
    if (_currentPageIndex >= 0 && _currentPageIndex < pages.length) {
      return pages[_currentPageIndex];
    }
    return null;
  }

  ChapterPagination? get currentChapterPagination => _currentPagination;

  ReaderPreferences get preferences => _preferences;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get showControls => _showControls;
  int get chapterCount => _bookData?.chapters.length ?? 0;
  List<TocEntry> get toc => _bookData?.toc ?? const [];
  bool get isDualPage => _isDualPage;
  int get currentDisplayChapterIndex =>
      _resolveDisplayChapterIndex(_currentChapterIndex);

  /// Resolve a human-readable chapter title for [index].
  ///
  /// Looks up the TOC entry whose href matches the spine chapter's href first;
  /// falls back to ParsedChapter.title, then "Chapter N".
  String chapterTitleAt(int index) {
    if (_bookData == null || index < 0 || index >= _bookData!.chapters.length) {
      return 'Chapter ${index + 1}';
    }
    final displayIndex = _resolveDisplayChapterIndex(index);
    final tocTitle = _tocTitleByChapterIndex[displayIndex];
    if (tocTitle != null && tocTitle.isNotEmpty) return tocTitle;
    final chapter = _bookData!.chapters[index];
    // Fall back to spine chapter title.
    if (chapter.title.isNotEmpty) return chapter.title;
    return 'Chapter ${index + 1}';
  }

  String get currentChapterTitle => chapterTitleAt(_currentChapterIndex);

  int _resolveDisplayChapterIndex(int index) {
    if (_bookData == null || _bookData!.chapters.isEmpty) return index;
    if (_tocTitleByChapterIndex.containsKey(index)) return index;

    var nearestPrev = -1;
    for (final tocIndex in _tocTitleByChapterIndex.keys) {
      if (tocIndex <= index && tocIndex > nearestPrev) {
        nearestPrev = tocIndex;
      }
    }
    if (nearestPrev >= 0) return nearestPrev;
    return index;
  }

  /// Chapter title mapped from position-based percent.
  ///
  /// Uses real page-count distribution when available; otherwise falls back to
  /// chapter-uniform mapping.
  String chapterTitleAtPositionPercent(double percent) {
    if (_bookData == null || _bookData!.chapters.isEmpty) return '';
    final (chapterIndex, _) = _targetByPositionPercent(percent);
    return chapterTitleAt(chapterIndex);
  }

  /// Whether the current page is the absolute first page of the book.
  bool get isFirstPageOfBook =>
      _currentChapterIndex == 0 && _currentPageIndex == 0;

  /// Whether the current spread contains the absolute last page of the book.
  bool get isLastPageOfBook {
    if (_currentPagination == null) return true;
    final isLastChapter = _currentChapterIndex >= chapterCount - 1;
    return isLastChapter &&
        _strategy.coversLastPage(
          _currentPageIndex,
          _currentPagination!.pages.length,
        );
  }

  /// The page layout for the page after the current one (same or next chapter).
  /// Returns null if at the last page of the book or adjacent chapter not cached.
  /// Skips absorbed chapters so the correct next page is shown during swipe
  /// preview.
  PageLayout? get nextPageLayout {
    if (_currentPagination == null) return null;
    final nextIdx = _currentPageIndex + 1;
    if (nextIdx < _currentPagination!.pages.length) {
      return _currentPagination!.pages[nextIdx];
    }
    // Cross-chapter: skip absorbed chapters to find the actual next chapter.
    final nextCh = _nextVisibleChapterIndex(_currentChapterIndex);
    if (nextCh == null) return null;
    return _firstPageOfCachedChapter(nextCh);
  }

  /// The page layout for the page before the current one (same or prev chapter).
  /// Returns null if at the first page of the book or adjacent chapter not cached.
  /// Skips absorbed chapters so the correct previous page is shown during swipe
  /// preview.
  PageLayout? get previousPageLayout {
    if (_currentPagination == null) return null;
    if (_currentPageIndex > 0) {
      return _currentPagination!.pages[_currentPageIndex - 1];
    }
    // Cross-chapter: skip absorbed chapters to find the actual prev chapter.
    final prevCh = _prevVisibleChapterIndex(_currentChapterIndex);
    if (prevCh == null) return null;
    return _lastPageOfCachedChapter(prevCh);
  }

  /// The right page of the current spread (null in single-page mode).
  /// Never crosses chapter boundaries — short chapters (title pages) are
  /// merged with the next chapter at pagination time.
  PageLayout? get secondPageLayout {
    if (_currentPagination == null) return null;
    return _strategy.secondPage(_currentPagination!.pages, _currentPageIndex);
  }

  /// Left page of the next spread (for swipe preview).
  PageLayout? get nextSpreadLeftPage {
    if (_currentPagination == null) return null;
    return _strategy.nextPreviewLeft(
      pages: _currentPagination!.pages,
      currentIndex: _currentPageIndex,
      nextChapterPages: _nextVisibleChapterPages,
    );
  }

  /// Right page of the next spread (for swipe preview; null in single mode).
  PageLayout? get nextSpreadRightPage {
    if (_currentPagination == null) return null;
    return _strategy.nextPreviewRight(
      pages: _currentPagination!.pages,
      currentIndex: _currentPageIndex,
      nextChapterPages: _nextVisibleChapterPages,
    );
  }

  /// Left page of the previous spread (for swipe preview).
  PageLayout? get prevSpreadLeftPage {
    if (_currentPagination == null) return null;
    return _strategy.prevPreviewLeft(
      pages: _currentPagination!.pages,
      currentIndex: _currentPageIndex,
      prevChapterPages: _prevVisibleChapterPages,
    );
  }

  /// Right page of the previous spread (for swipe preview; null in single mode).
  PageLayout? get prevSpreadRightPage {
    if (_currentPagination == null) return null;
    return _strategy.prevPreviewRight(
      pages: _currentPagination!.pages,
      currentIndex: _currentPageIndex,
      prevChapterPages: _prevVisibleChapterPages,
    );
  }

  /// Retrieve a cached [PageLayout] by chapter and page index.
  ///
  /// Returns null if the chapter is not in the pagination cache.
  PageLayout? getPageLayout(int chapterIndex, int pageIndexInChapter) {
    final pagination = _cache[_cacheKey(chapterIndex)];
    if (pagination == null) return null;
    if (pageIndexInChapter < 0 ||
        pageIndexInChapter >= pagination.pages.length) {
      return null;
    }
    return pagination.pages[pageIndexInChapter];
  }

  ChapterPagination? getChapterPagination(int chapterIndex) {
    return _cache[_cacheKey(chapterIndex)];
  }

  /// Number of pages in a cached chapter, or null if not cached.
  int? pagesInChapter(int chapterIndex) {
    return _cache[_cacheKey(chapterIndex)]?.pages.length;
  }

  int _chapterPageCountForProgress(int chapterIndex) {
    final cached = _cache[_cacheKey(chapterIndex)];
    if (cached != null) return cached.pages.length;
    return _chapterPageCounts[chapterIndex] ?? 0;
  }

  /// Total pages across the entire book (0 while still computing).
  int get totalBookPages {
    if (!_allPagesComputed) return 0;
    var total = 0;
    for (var i = 0; i < _chapterPageCounts.length; i++) {
      total += _chapterPageCountForProgress(i);
    }
    return total;
  }

  /// Current page number across the entire book (1-based, 0 while computing).
  int get currentBookPage {
    if (!_allPagesComputed) return 0;
    var page = 0;
    for (var i = 0; i < _currentChapterIndex; i++) {
      page += _chapterPageCountForProgress(i);
    }
    final currentChapterPages = _chapterPageCountForProgress(
      _currentChapterIndex,
    );
    if (currentChapterPages <= 0) {
      return page;
    }
    final safePageIndex = _currentPageIndex.clamp(0, currentChapterPages - 1);
    page += safePageIndex + 1;
    return page;
  }

  /// The book page number for the right page of the current spread (1-based).
  /// Returns 0 if no second page or page counts not yet computed.
  int get secondBookPage {
    if (!_allPagesComputed) return 0;
    return _strategy.secondBookPage(currentBookPage, secondPageLayout != null);
  }

  /// Position-based progress:
  /// first page = 0%, last page = 100%.
  double get bookPositionPercent {
    if (_bookData == null || _bookData!.chapters.isEmpty) return 0.0;

    if (_allPagesComputed) {
      if (totalBookPages <= 0) return 0.0;
      if (totalBookPages == 1) return 1.0;
      return ((currentBookPage - 1) / (totalBookPages - 1)).clamp(0.0, 1.0);
    }

    return _chapterFallbackPositionPercent();
  }

  /// Read-based progress:
  /// first page > 0%, last page = 100%.
  double get bookReadPercent {
    if (_bookData == null || _bookData!.chapters.isEmpty) return 0.0;

    if (_allPagesComputed) {
      if (totalBookPages <= 0) return 0.0;
      return (currentBookPage / totalBookPages).clamp(0.0, 1.0);
    }

    return _chapterFallbackReadPercent();
  }

  /// Backward-compatible alias for existing consumers.
  double get bookPercent => bookPositionPercent;

  double _chapterFallbackPositionPercent() {
    final chapters = _bookData!.chapters.length;
    final chapterFraction = 1.0 / chapters;
    final chapterBase = _currentChapterIndex * chapterFraction;
    final pageFraction = totalPagesInChapter > 0
        ? (_currentPageIndex / totalPagesInChapter) * chapterFraction
        : 0.0;
    return (chapterBase + pageFraction).clamp(0.0, 1.0);
  }

  double _chapterFallbackReadPercent() {
    final chapters = _bookData!.chapters.length;
    final chapterFraction = 1.0 / chapters;
    final chapterBase = _currentChapterIndex * chapterFraction;
    final pageFraction = totalPagesInChapter > 0
        ? ((_currentPageIndex + 1) / totalPagesInChapter) * chapterFraction
        : 0.0;
    return (chapterBase + pageFraction).clamp(0.0, 1.0);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Open a book for reading.
  ///
  /// If this store already has the same book loaded with a matching viewport
  /// and valid pagination cache, the full load is skipped (instant re-open).
  Future<void> openBook({
    required BookEntity book,
    required ChapterDataSource dataSource,
    required Size viewportSize,
    required double safeAreaTop,
    required double safeAreaBottom,
    double devicePixelRatio = 1.0,
    bool isDualPage = false,
  }) async {
    // Fast path: same book, same viewport, still has valid pagination.
    if (_book?.id == book.id &&
        _viewportSize == viewportSize &&
        _safeAreaTop == safeAreaTop &&
        _safeAreaBottom == safeAreaBottom &&
        _isDualPage == isDualPage &&
        _currentPagination != null) {
      _dataSource = dataSource;
      _isLoading = false;
      notifyListeners();
      _saveProgress();
      return;
    }

    _book = book;
    _dataSource = dataSource;
    _viewportSize = viewportSize;
    _safeAreaTop = safeAreaTop;
    _safeAreaBottom = safeAreaBottom;
    _devicePixelRatio = devicePixelRatio;
    _isDualPage = isDualPage;
    _strategy = isDualPage
        ? const DualPageStrategy()
        : const SinglePageStrategy();
    _cache.clear();
    _absorbedChapters.clear();
    _tocChapterIndexes.clear();
    _tocTitleByChapterIndex.clear();
    _pageCountCache.clear();
    _widthCache = null;
    _paragraphPrepareCache = null;
    _persistedPageCountsJson = null;
    _allPagesComputed = false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    final sw = Stopwatch()..start();

    try {
      _bookData = await dataSource.loadBook();
      final hrefIndex = ReaderHrefIndex.fromChapters(_bookData!.chapters);
      _tocChapterIndexes
        ..clear()
        ..addAll(
          ReaderHrefIndex.collectTocChapterIndexes(
            toc: _bookData!.toc,
            hrefIndex: hrefIndex,
          ),
        );
      _tocTitleByChapterIndex
        ..clear()
        ..addAll(
          ReaderHrefIndex.collectTocTitlesByChapterIndex(
            toc: _bookData!.toc,
            hrefIndex: hrefIndex,
          ),
        );
      debugPrint(
        '[ReaderStore] loadBook: ${sw.elapsedMilliseconds}ms, chapters=${_bookData!.chapters.length}',
      );

      // Restore saved progress (position, preferences, and page count cache).
      final progress = await _progressRepository.getProgress(book.id);
      if (progress != null) {
        _restoreProgress(progress);
        _tryRestorePageCounts(progress.pageCountsJson);
      }
      debugPrint('[ReaderStore] restoreProgress: ${sw.elapsedMilliseconds}ms');

      await _loadChapter(_currentChapterIndex);
      debugPrint(
        '[ReaderStore] loadChapter($_currentChapterIndex): ${sw.elapsedMilliseconds}ms',
      );

      // Skip empty or absorbed chapters.
      while ((_currentPagination != null && _currentPagination!.pages.isEmpty ||
              _absorbedChapters.contains(_currentChapterIndex)) &&
          _currentChapterIndex < chapterCount - 1) {
        _currentChapterIndex++;
        _currentPageIndex = 0;
        await _loadChapter(_currentChapterIndex);
        debugPrint(
          '[ReaderStore] skip empty → ch $_currentChapterIndex: ${sw.elapsedMilliseconds}ms',
        );
      }

      debugPrint(
        '[ReaderStore] openBook done: ${sw.elapsedMilliseconds}ms, '
        'pages=${_currentPagination?.pages.length}',
      );
      _debugChapterResolution('openBook');

      // Clamp page index to valid range after loading.
      if (_currentPagination != null &&
          _currentPageIndex >= _currentPagination!.pages.length) {
        _currentPageIndex = _currentPagination!.pages.isEmpty
            ? 0
            : _currentPagination!.pages.length - 1;
      }

      // Align page index for the current display mode (e.g. even index for
      // dual-page spreads).
      if (_currentPagination != null && _currentPagination!.pages.isNotEmpty) {
        _currentPageIndex = _strategy.alignPageIndex(
          _currentPageIndex,
          _currentPagination!.pages.length - 1,
        );
      }
    } catch (e, st) {
      debugPrint(
        '[ReaderStore] openBook error at ${sw.elapsedMilliseconds}ms: $e\n$st',
      );
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();

    // Persist progress so updatedAt reflects this open (drives Now Reading).
    if (_error == null) {
      _saveProgress();
    }

    // Background: compute page counts for all chapters (skip if restored
    // from persisted cache).
    if (!_allPagesComputed) {
      _computeAllPageCounts();
    }
  }

  /// Update viewport size (e.g. after rotation).
  Future<void> updateViewport({
    required Size viewportSize,
    required double safeAreaTop,
    required double safeAreaBottom,
  }) async {
    if (viewportSize == _viewportSize &&
        safeAreaTop == _safeAreaTop &&
        safeAreaBottom == _safeAreaBottom) {
      return;
    }
    _viewportSize = viewportSize;
    _safeAreaTop = safeAreaTop;
    _safeAreaBottom = safeAreaBottom;
    _cache.clear();
    _absorbedChapters.clear();
    _paragraphPrepareCache?.clear();

    if (_dataSource != null) {
      await _loadChapter(_currentChapterIndex);
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void nextPage() {
    if (_currentPagination == null) return;

    final step = _strategy.pageStep;
    final lastIdx = _currentPagination!.pages.length - 1;

    if (_currentPageIndex + step <= lastIdx) {
      _currentPageIndex += step;
      _debugChapterResolution('nextPage');
      notifyListeners();
      _saveProgress();
      // Proactively prefetch the next chapter when approaching the end of
      // the current chapter (within the last spread/page).
      if (_strategy.coversLastPage(
        _currentPageIndex,
        _currentPagination!.pages.length,
      )) {
        _ensureNextChapterPrefetched();
      }
    } else {
      _goToNextNonEmptyChapter();
    }
  }

  /// Move forward by exactly one page, ignoring display mode step size.
  /// Used for selection-triggered page turns where single-step is always
  /// correct regardless of single/dual page mode.
  void nextSinglePage() {
    if (_currentPagination == null) return;
    final lastIdx = _currentPagination!.pages.length - 1;
    if (_currentPageIndex + 1 <= lastIdx) {
      _currentPageIndex += 1;
      notifyListeners();
      _saveProgress();
    } else {
      _goToNextNonEmptyChapter();
    }
  }

  Future<void> _goToNextNonEmptyChapter() async {
    var next = _currentChapterIndex + 1;
    // Skip chapters that were absorbed into a previous chapter.
    while (next < chapterCount && _absorbedChapters.contains(next)) {
      next++;
    }
    while (next < chapterCount) {
      _currentChapterIndex = next;
      _currentPageIndex = 0;

      // Fast path: if the chapter is already cached, switch SYNCHRONOUSLY
      // to avoid any visual flash. The async _loadChapter would introduce
      // a microtask delay even for cache hits, causing one frame where
      // _currentPagination still points to the old chapter.
      final cachedPagination = _cache[_cacheKey(next)];
      if (cachedPagination != null && cachedPagination.pages.isNotEmpty) {
        _currentPagination = cachedPagination;
        _isLoading = false;
        notifyListeners();
        _saveProgress();
        _prefetchAdjacentChapters(next);
        return;
      }

      // Slow path: chapter not cached — show loading and load async.
      _isLoading = true;
      notifyListeners();

      await _loadChapter(next);
      if (_currentPagination != null && _currentPagination!.pages.isNotEmpty) {
        _isLoading = false;
        notifyListeners();
        _saveProgress();
        return;
      }
      // Skip absorbed chapters.
      next++;
      while (next < chapterCount && _absorbedChapters.contains(next)) {
        next++;
      }
    }
    // No more chapters with content.
    _isLoading = false;
    notifyListeners();
  }

  void previousPage() {
    final step = _strategy.pageStep;
    if (_currentPageIndex >= step) {
      _currentPageIndex -= step;
      _debugChapterResolution('previousPage');
      notifyListeners();
      _saveProgress();
    } else if (_currentChapterIndex > 0) {
      // Go to last spread of previous chapter.
      goToChapter(_currentChapterIndex - 1, lastPage: true);
    }
  }

  /// Move backward by exactly one page, ignoring display mode step size.
  /// Used for selection-triggered page turns.
  void previousSinglePage() {
    if (_currentPageIndex >= 1) {
      _currentPageIndex -= 1;
      notifyListeners();
      _saveProgress();
    } else if (_currentChapterIndex > 0) {
      goToChapter(_currentChapterIndex - 1, lastPage: true);
    }
  }

  Future<void> goToChapter(int index, {bool lastPage = false}) async {
    if (index < 0 || index >= chapterCount) return;
    // If this chapter was absorbed into a previous one, redirect there.
    var target = index;
    while (_absorbedChapters.contains(target) && target > 0) {
      target--;
    }
    _currentChapterIndex = target;
    _currentPageIndex = 0;

    // Fast path: if cached, switch synchronously to avoid visual flash.
    final cachedPagination = _cache[_cacheKey(target)];
    if (cachedPagination != null) {
      _currentPagination = cachedPagination;
      if (lastPage && cachedPagination.pages.isNotEmpty) {
        _currentPageIndex = cachedPagination.pages.length - 1;
      }
      if (cachedPagination.pages.isNotEmpty) {
        _currentPageIndex = _strategy.alignPageIndex(
          _currentPageIndex,
          cachedPagination.pages.length - 1,
        );
      }
      _isLoading = false;
      _debugChapterResolution('goToChapter(cache)');
      notifyListeners();
      _saveProgress();
      _prefetchAdjacentChapters(target);
      return;
    }

    // Slow path: chapter not cached — show loading and load async.
    _isLoading = true;
    notifyListeners();

    await _loadChapter(target);

    if (lastPage && _currentPagination != null) {
      _currentPageIndex = _currentPagination!.pages.length - 1;
    }

    // Align page index for the current display mode.
    if (_currentPagination != null && _currentPagination!.pages.isNotEmpty) {
      _currentPageIndex = _strategy.alignPageIndex(
        _currentPageIndex,
        _currentPagination!.pages.length - 1,
      );
    }

    _isLoading = false;
    _debugChapterResolution('goToChapter(load)');
    notifyListeners();
    _saveProgress();
  }

  /// Jump to an approximate position in the book by percent (0.0–1.0).
  ///
  /// The input uses position semantics:
  /// 0.0 = first page, 1.0 = last page.
  Future<void> goToBookPercent(double percent) async {
    if (_bookData == null || chapterCount == 0) return;
    final clamped = percent.clamp(0.0, 1.0);
    final (targetChapter, targetPageInChapter) = _targetByPositionPercent(
      clamped,
    );

    // Fast path: if cached, switch synchronously to avoid visual flash.
    final cachedPagination = _cache[_cacheKey(targetChapter)];
    if (cachedPagination != null && cachedPagination.pages.isNotEmpty) {
      _currentChapterIndex = targetChapter;
      _currentPageIndex = targetPageInChapter.clamp(
        0,
        cachedPagination.pages.length - 1,
      );
      _currentPageIndex = _strategy.alignPageIndex(
        _currentPageIndex,
        cachedPagination.pages.length - 1,
      );
      _currentPagination = cachedPagination;
      _isLoading = false;
      notifyListeners();
      _saveProgress();
      _prefetchAdjacentChapters(targetChapter);
      return;
    }

    // Slow path: chapter not cached — show loading and load async.
    _isLoading = true;
    notifyListeners();

    await _loadChapter(targetChapter);

    if (_currentPagination != null && _currentPagination!.pages.isNotEmpty) {
      _currentChapterIndex = targetChapter;
      _currentPageIndex = targetPageInChapter.clamp(
        0,
        _currentPagination!.pages.length - 1,
      );
      // Align page index for the current display mode.
      _currentPageIndex = _strategy.alignPageIndex(
        _currentPageIndex,
        _currentPagination!.pages.length - 1,
      );
    }

    _isLoading = false;
    notifyListeners();
    _saveProgress();
  }

  (int chapterIndex, int pageIndexInChapter) _targetByPositionPercent(
    double percent,
  ) {
    final clamped = percent.clamp(0.0, 1.0);
    var targetChapter = 0;
    var targetPageInChapter = 0;

    if (_allPagesComputed && totalBookPages > 0) {
      // Inverse of position percent:
      // p = (page - 1) / (total - 1), page in [1, total].
      final targetPage = totalBookPages == 1
          ? 1
          : (clamped * (totalBookPages - 1)).round() + 1;

      var remaining = targetPage;
      for (var i = 0; i < chapterCount; i++) {
        final pages = _chapterPageCountForProgress(i);
        if (pages <= 0) continue;
        if (remaining <= pages) {
          targetChapter = i;
          targetPageInChapter = remaining - 1;
          break;
        }
        remaining -= pages;
        targetChapter = i;
        targetPageInChapter = pages - 1;
      }
      return (targetChapter, targetPageInChapter);
    }

    // Fallback before whole-book page counts are ready: chapter-uniform map.
    final chapterFraction = 1.0 / chapterCount;
    targetChapter = (clamped / chapterFraction).floor().clamp(
      0,
      chapterCount - 1,
    );
    final remainInChapter = clamped - targetChapter * chapterFraction;
    final pageFraction = (remainInChapter / chapterFraction).clamp(0.0, 1.0);

    // Will be clamped again after pagination is loaded.
    final estimatedPages =
        _cache[_cacheKey(targetChapter)]?.pages.length ?? totalPagesInChapter;
    if (estimatedPages <= 1) {
      targetPageInChapter = 0;
    } else {
      targetPageInChapter = (pageFraction * (estimatedPages - 1)).floor().clamp(
        0,
        estimatedPages - 1,
      );
    }
    return (targetChapter, targetPageInChapter);
  }

  // ---------------------------------------------------------------------------
  // Preferences
  // ---------------------------------------------------------------------------

  Future<void> updatePreferences(ReaderPreferences newPrefs) async {
    if (newPrefs.layoutHash == _preferences.layoutHash &&
        newPrefs.theme == _preferences.theme) {
      return;
    }

    final needsRelayout = newPrefs.layoutHash != _preferences.layoutHash;
    final themeChanged = newPrefs.theme != _preferences.theme;
    _preferences = newPrefs;

    if (needsRelayout || themeChanged) {
      // Theme changes require re-pagination because text colors are baked
      // into TextPainter instances during layout.
      _cache.clear();
      _absorbedChapters.clear();
      if (needsRelayout) {
        _pageCountCache.clear();
        _widthCache = null;
        _paragraphPrepareCache = null;
        _persistedPageCountsJson = null;
        _allPagesComputed = false;
      }
      if (_dataSource != null) {
        await _loadChapter(_currentChapterIndex);
      }
      if (needsRelayout) {
        _computeAllPageCounts();
      }
    }

    notifyListeners();
    _saveProgress();
  }

  // ---------------------------------------------------------------------------
  // Controls overlay
  // ---------------------------------------------------------------------------

  void toggleControls() {
    _showControls = !_showControls;
    notifyListeners();
  }

  void hideControls() {
    if (_showControls) {
      _showControls = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<void> _loadChapter(int index, {bool prefetchOnly = false}) async {
    if (_dataSource == null) return;
    final requestToken = prefetchOnly ? _chapterLoadToken : ++_chapterLoadToken;

    // Check cache.
    final cacheKey = _cacheKey(index);
    if (_cache.containsKey(cacheKey)) {
      if (!prefetchOnly) {
        _currentPagination = _cache[cacheKey];
      }
      return;
    }

    try {
      final lsw = Stopwatch()..start();

      final chapter = await _dataSource!.loadChapter(index);
      if (requestToken != _chapterLoadToken) return;
      debugPrint(
        '[ReaderStore] ch$index readJson: ${lsw.elapsedMilliseconds}ms, ${chapter.nodes.length} nodes',
      );

      // Pre-decode images before pagination.
      final contentWidth =
          _viewportSize.width - 2 * _preferences.pageHorizontalPaddingPx;
      final decodedImages = await _engine.decodeImages(
        chapter.nodes,
        contentWidth,
        _devicePixelRatio,
      );
      if (requestToken != _chapterLoadToken) return;
      debugPrint(
        '[ReaderStore] ch$index decodeImages: ${lsw.elapsedMilliseconds}ms, ${decodedImages.length} images',
      );

      _widthCache ??= WidthCache();
      _paragraphPrepareCache ??= ParagraphPrepareCache();

      var allNodes = chapter.nodes;
      var allImages = decodedImages;

      // Merge consecutive short chapters (e.g. title-only spine items) with
      // the following chapter so title and content paginate together.
      var mergeTarget = index + 1;
      final isTocTargetChapter = _tocChapterIndexes.contains(index);
      while (mergeTarget < chapterCount && !_absorbedChapters.contains(index)) {
        // Keep TOC-addressable chapters stable so TOC jumps remain deterministic.
        if (isTocTargetChapter || _tocChapterIndexes.contains(mergeTarget)) {
          break;
        }
        // Quick paginate to check page count.
        final testPagination = await _engine.paginateAsync(
          chapterIndex: index,
          nodes: allNodes,
          viewportSize: _viewportSize,
          prefs: _preferences,
          decodedImages: allImages,
          safeAreaTop: _safeAreaTop,
          safeAreaBottom: _safeAreaBottom,
          widthCache: _widthCache,
          paragraphPrepareCache: _paragraphPrepareCache,
        );
        if (requestToken != _chapterLoadToken) return;

        if (testPagination.pages.length > 1) {
          // Chapter is long enough — no more merging needed.
          break;
        }

        // This chapter is very short — merge with the next one.
        final nextChapter = await _dataSource!.loadChapter(mergeTarget);
        if (requestToken != _chapterLoadToken) return;
        final nextImages = await _engine.decodeImages(
          nextChapter.nodes,
          contentWidth,
          _devicePixelRatio,
        );
        if (requestToken != _chapterLoadToken) return;

        allNodes = [...allNodes, ...nextChapter.nodes];
        allImages = {...allImages, ...nextImages};
        _absorbedChapters.add(mergeTarget);
        debugPrint('[ReaderStore] ch$mergeTarget absorbed into ch$index');
        mergeTarget++;
      }

      final pagination = await _engine.paginateAsync(
        chapterIndex: index,
        nodes: allNodes,
        viewportSize: _viewportSize,
        prefs: _preferences,
        decodedImages: allImages,
        safeAreaTop: _safeAreaTop,
        safeAreaBottom: _safeAreaBottom,
        widthCache: _widthCache,
        paragraphPrepareCache: _paragraphPrepareCache,
      );
      if (requestToken != _chapterLoadToken) return;
      debugPrint(
        '[ReaderStore] ch$index paginate: ${lsw.elapsedMilliseconds}ms, ${pagination.pages.length} pages',
      );
      _cache[cacheKey] = pagination;

      if (!prefetchOnly) {
        _currentPagination = pagination;
        _error = null;

        // Fire-and-forget: prefetch adjacent chapters in the background.
        _prefetchAdjacentChapters(index);
      }
    } catch (e, st) {
      if (requestToken != _chapterLoadToken) return;
      debugPrint('[ReaderStore] _loadChapter error: $e\n$st');
      if (!prefetchOnly) {
        _error = e.toString();
        _currentPagination = null;
      }
    }
  }

  /// Prefetch the chapters adjacent to [currentIndex] in the background.
  ///
  /// Uses [_nextVisibleChapterIndex] / [_prevVisibleChapterIndex] to skip
  /// absorbed chapters so the correct chapter is ready when the user
  /// navigates past a chapter boundary.
  ///
  /// Next chapter is loaded immediately; previous chapter is deferred by 500ms
  /// to avoid competing with the first frame render.
  void _prefetchAdjacentChapters(int currentIndex) {
    Future<void>(() async {
      // Next visible chapter (skipping absorbed ones) — load immediately.
      final next = _nextVisibleChapterIndex(currentIndex);
      if (next != null && !_cache.containsKey(_cacheKey(next))) {
        await _loadChapter(next, prefetchOnly: true).catchError((_) {});
      }

      // Previous visible chapter — deferred.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final prev = _prevVisibleChapterIndex(currentIndex);
      if (prev != null && !_cache.containsKey(_cacheKey(prev))) {
        await _loadChapter(prev, prefetchOnly: true).catchError((_) {});
      }
    });
  }

  /// Ensure the next visible chapter is prefetched when the user is near
  /// the end of the current chapter. This is called proactively from
  /// [nextPage] so that cross-chapter transitions are instant.
  void _ensureNextChapterPrefetched() {
    final next = _nextVisibleChapterIndex(_currentChapterIndex);
    if (next != null && !_cache.containsKey(_cacheKey(next))) {
      _loadChapter(next, prefetchOnly: true).catchError((_) {});
    }
  }

  /// Next chapter index that is not absorbed, or null.
  int? _nextVisibleChapterIndex(int from) {
    var i = from + 1;
    while (i < chapterCount && _absorbedChapters.contains(i)) {
      i++;
    }
    return i < chapterCount ? i : null;
  }

  /// Previous chapter index that is not absorbed, or null.
  int? _prevVisibleChapterIndex(int from) {
    var i = from - 1;
    while (i >= 0 && _absorbedChapters.contains(i)) {
      i--;
    }
    return i >= 0 ? i : null;
  }

  void _debugChapterResolution(String reason) {
    if (_bookData == null ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _bookData!.chapters.length) {
      return;
    }
    final resolved = _resolveDisplayChapterIndex(_currentChapterIndex);
    final chapter = _bookData!.chapters[_currentChapterIndex];
    final resolvedTitle = _tocTitleByChapterIndex[resolved] ?? '';
    debugPrint(
      '[ReaderStore] $reason chapter=$_currentChapterIndex '
      'displayChapter=$resolved href=${chapter.href} '
      'rawTitle="${chapter.title}" displayTitle="$resolvedTitle"',
    );
  }

  /// Pages of the next non-absorbed chapter from cache, or null.
  List<PageLayout>? _nextVisibleChapterPages() {
    final nextCh = _nextVisibleChapterIndex(_currentChapterIndex);
    if (nextCh == null) return null;
    return _cache[_cacheKey(nextCh)]?.pages;
  }

  /// Pages of the previous non-absorbed chapter from cache, or null.
  List<PageLayout>? _prevVisibleChapterPages() {
    final prevCh = _prevVisibleChapterIndex(_currentChapterIndex);
    if (prevCh == null) return null;
    return _cache[_cacheKey(prevCh)]?.pages;
  }

  /// First page of a chapter from the full-layout cache, or null.
  PageLayout? _firstPageOfCachedChapter(int chapterIndex) {
    if (chapterIndex < 0 || chapterIndex >= chapterCount) return null;
    final pagination = _cache[_cacheKey(chapterIndex)];
    if (pagination == null || pagination.pages.isEmpty) return null;
    return pagination.pages.first;
  }

  /// Last page of a chapter from the full-layout cache, or null.
  PageLayout? _lastPageOfCachedChapter(int chapterIndex) {
    if (chapterIndex < 0 || chapterIndex >= chapterCount) return null;
    final pagination = _cache[_cacheKey(chapterIndex)];
    if (pagination == null || pagination.pages.isEmpty) return null;
    return pagination.pages.last;
  }

  /// Compute page counts for all chapters in the background.
  ///
  /// Yields to the event loop between chapters so the UI stays responsive.
  /// Stores page counts in [_pageCountCache] so they survive across calls.
  Future<void> _computeAllPageCounts() async {
    if (_dataSource == null || _bookData == null) return;

    final totalChapters = _bookData!.chapters.length;
    // Snapshot identity to detect if book/prefs changed mid-computation.
    final snapshotBook = _bookData;
    final snapshotHash = _preferences.layoutHash;

    _chapterPageCounts = List<int?>.filled(totalChapters, null);
    _allPagesComputed = false;

    final pcsw = Stopwatch()..start();
    debugPrint(
      '[ReaderStore] _computeAllPageCounts start ($totalChapters chapters)',
    );

    for (var i = 0; i < totalChapters; i++) {
      // Abort if book or layout preferences changed while computing.
      if (_bookData != snapshotBook ||
          _preferences.layoutHash != snapshotHash) {
        return;
      }

      // Yield to the event loop to keep the UI responsive.
      await Future<void>.delayed(Duration.zero);

      // Absorbed chapters have 0 pages (content merged into predecessor).
      if (_absorbedChapters.contains(i)) {
        _chapterPageCounts[i] = 0;
        continue;
      }

      // Use full pagination cache if available.
      final cacheKey = _cacheKey(i);
      if (_cache.containsKey(cacheKey)) {
        _chapterPageCounts[i] = _cache[cacheKey]!.pages.length;
      } else if (_pageCountCache.containsKey(cacheKey)) {
        _chapterPageCounts[i] = _pageCountCache[cacheKey];
      } else {
        try {
          final chapter = await _dataSource!.loadChapter(i);
          // Paginate without decoding images (dimensions from Rust suffice).
          _widthCache ??= WidthCache();
          _paragraphPrepareCache ??= ParagraphPrepareCache();
          final pagination = await _engine.paginateAsync(
            chapterIndex: i,
            nodes: chapter.nodes,
            viewportSize: _viewportSize,
            prefs: _preferences,
            safeAreaTop: _safeAreaTop,
            safeAreaBottom: _safeAreaBottom,
            pageCountOnly: true,
            widthCache: _widthCache,
            paragraphPrepareCache: _paragraphPrepareCache,
          );
          _chapterPageCounts[i] = pagination.pages.length;
          // Cache page count only (no full pagination — images not decoded).
          _pageCountCache[cacheKey] = pagination.pages.length;
        } catch (e) {
          debugPrint(
            '[ReaderStore] _computeAllPageCounts chapter $i error: $e',
          );
          _chapterPageCounts[i] = 0;
        }
      }

      // Notify periodically so progress displays update incrementally.
      if (i % 5 == 0) notifyListeners();
    }

    _allPagesComputed = true;
    _persistedPageCountsJson = _serializePageCounts();
    debugPrint(
      '[ReaderStore] all page counts done: ${pcsw.elapsedMilliseconds}ms, total=$totalBookPages',
    );
    notifyListeners();
    _saveProgress();
  }

  int _cacheKey(int chapterIndex) {
    // Simple cache key combining chapter and layout parameters.
    return Object.hash(chapterIndex, _viewportSize, _preferences.layoutHash);
  }

  void _restoreProgress(ReadingProgressEntity progress) {
    try {
      final locator = jsonDecode(progress.locatorJson) as Map<String, dynamic>;
      _currentChapterIndex = locator['chapterIndex'] as int? ?? 0;
      _currentPageIndex = locator['pageIndex'] as int? ?? 0;
    } catch (_) {
      _currentChapterIndex = 0;
      _currentPageIndex = 0;
    }

    // Restore per-book preferences.
    if (progress.prefsJson != null) {
      try {
        final prefsMap =
            jsonDecode(progress.prefsJson!) as Map<String, dynamic>;
        _preferences = ReaderPreferences.fromJson(prefsMap);
      } catch (_) {
        // Ignore malformed preferences JSON; keep defaults.
      }
    }
  }

  /// Try to restore page counts from a persisted JSON blob.
  ///
  /// Validates that viewport size and all layout-affecting preferences match
  /// the current values. On any mismatch the cache is silently discarded and
  /// [_computeAllPageCounts] will recompute from scratch.
  void _tryRestorePageCounts(String? json) {
    if (json == null || _bookData == null) return;

    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final v = map['v'] as int? ?? 0;
      if (v != 1) return;

      // Compare raw layout parameters (Object.hash is not stable across VM
      // restarts, so we store and compare the raw values).
      final vw = (map['vw'] as num?)?.toDouble();
      final vh = (map['vh'] as num?)?.toDouble();
      final fontSize = (map['fontSize'] as num?)?.toDouble();
      final fontFamily = map['fontFamily'] as String?;
      final hPad = (map['hPad'] as num?)?.toDouble();
      final vPad = (map['vPad'] as num?)?.toDouble();
      final lineHeight = (map['lineHeight'] as num?)?.toDouble();
      final paraSpacing = (map['paraSpacing'] as num?)?.toDouble();

      if (vw != _viewportSize.width ||
          vh != _viewportSize.height ||
          fontSize != _preferences.baseFontSizePx ||
          fontFamily != _preferences.fontFamily ||
          hPad != _preferences.pageHorizontalPaddingPx ||
          vPad != _preferences.pageVerticalPaddingPx ||
          lineHeight != _preferences.lineHeightMultiplier ||
          paraSpacing != _preferences.paragraphSpacingMultiplier) {
        return;
      }

      final pageCounts = (map['pc'] as List).cast<int>();
      if (pageCounts.length != _bookData!.chapters.length) return;

      _chapterPageCounts = pageCounts.map<int?>((c) => c).toList();
      _allPagesComputed = true;
      _persistedPageCountsJson = json;
      debugPrint(
        '[ReaderStore] restored persisted page counts: total=$totalBookPages',
      );
    } catch (e) {
      debugPrint('[ReaderStore] failed to restore page counts: $e');
    }
  }

  /// Serialize current page counts + layout parameters to JSON for persistence.
  String _serializePageCounts() {
    return jsonEncode({
      'v': 1,
      'vw': _viewportSize.width,
      'vh': _viewportSize.height,
      'fontSize': _preferences.baseFontSizePx,
      'fontFamily': _preferences.fontFamily,
      'hPad': _preferences.pageHorizontalPaddingPx,
      'vPad': _preferences.pageVerticalPaddingPx,
      'lineHeight': _preferences.lineHeightMultiplier,
      'paraSpacing': _preferences.paragraphSpacingMultiplier,
      'pc': _chapterPageCounts.map((c) => c ?? 0).toList(),
    });
  }

  /// Mark progress dirty and schedule a throttled DB write.
  ///
  /// At most one actual write happens per [_saveInterval]. On [dispose] the
  /// latest state is flushed so no progress is lost.
  void _saveProgress() {
    _progressDirty = true;
    if (_progressSaveTimer?.isActive ?? false) return;
    _progressSaveTimer = Timer(_saveInterval, flushProgress);
  }

  /// Flush any pending throttled progress write immediately.
  ///
  /// Called on app background and dispose to avoid losing recent position.
  Future<void> flushProgress() async {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = null;
    if (!_progressDirty || _book == null) return;
    _progressDirty = false;

    final locator = jsonEncode({
      'chapterIndex': _currentChapterIndex,
      'pageIndex': _currentPageIndex,
    });

    await _progressRepository.saveProgress(
      ReadingProgressEntity(
        bookId: _book!.id,
        locatorJson: locator,
        percent: bookReadPercent,
        updatedAt: DateTime.now(),
        prefsJson: jsonEncode(_preferences.toJson()),
        pageCountsJson: _persistedPageCountsJson,
      ),
    );
  }

  @override
  void dispose() {
    flushProgress();
    super.dispose();
  }
}
