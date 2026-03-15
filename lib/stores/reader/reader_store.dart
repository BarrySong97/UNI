import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../entities/book-entity.dart';
import '../../entities/reading-progress-entity.dart';
import '../../repositories/progress/progress-repository.dart';
import '../../services/reader/data/chapter_data_source.dart';
import '../../services/reader/layout/reader_layout_engine.dart';
import '../../services/reader/models/page_layout.dart';
import '../../services/reader/models/parsed_chapter.dart';
import '../../services/reader/models/reader_preferences.dart';

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

  /// Cache: cacheKey → ChapterPagination (full layout with images).
  final Map<int, ChapterPagination> _cache = {};

  /// Cache: cacheKey → page count (lightweight, survives across page-count runs).
  final Map<int, int> _pageCountCache = {};

  /// Per-chapter page counts for whole-book pagination (null = not yet computed).
  List<int?> _chapterPageCounts = [];
  bool _allPagesComputed = false;

  /// Serialized page count cache for DB persistence. Only set when all page
  /// counts have been computed; carried through on every [_saveProgress] call.
  String? _persistedPageCountsJson;

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

  ReaderPreferences get preferences => _preferences;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get showControls => _showControls;
  int get chapterCount => _bookData?.chapters.length ?? 0;
  List<TocEntry> get toc => _bookData?.toc ?? const [];

  /// Whether the current page is the absolute first page of the book.
  bool get isFirstPageOfBook =>
      _currentChapterIndex == 0 && _currentPageIndex == 0;

  /// Whether the current page is the absolute last page of the book.
  bool get isLastPageOfBook {
    if (_currentPagination == null) return true;
    return _currentChapterIndex >= chapterCount - 1 &&
        _currentPageIndex >= _currentPagination!.pages.length - 1;
  }

  /// The page layout for the page after the current one (same or next chapter).
  /// Returns null if at the last page of the book or adjacent chapter not cached.
  PageLayout? get nextPageLayout {
    if (_currentPagination == null) return null;
    final nextIdx = _currentPageIndex + 1;
    if (nextIdx < _currentPagination!.pages.length) {
      return _currentPagination!.pages[nextIdx];
    }
    return _firstPageOfCachedChapter(_currentChapterIndex + 1);
  }

  /// The page layout for the page before the current one (same or prev chapter).
  /// Returns null if at the first page of the book or adjacent chapter not cached.
  PageLayout? get previousPageLayout {
    if (_currentPagination == null) return null;
    if (_currentPageIndex > 0) {
      return _currentPagination!.pages[_currentPageIndex - 1];
    }
    return _lastPageOfCachedChapter(_currentChapterIndex - 1);
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

  /// Number of pages in a cached chapter, or null if not cached.
  int? pagesInChapter(int chapterIndex) {
    return _cache[_cacheKey(chapterIndex)]?.pages.length;
  }

  /// Total pages across the entire book (0 while still computing).
  int get totalBookPages {
    if (!_allPagesComputed) return 0;
    var total = 0;
    for (final c in _chapterPageCounts) {
      total += c ?? 0;
    }
    return total;
  }

  /// Current page number across the entire book (1-based, 0 while computing).
  int get currentBookPage {
    if (!_allPagesComputed) return 0;
    var page = 0;
    for (var i = 0; i < _currentChapterIndex; i++) {
      page += _chapterPageCounts[i] ?? 0;
    }
    page += _currentPageIndex + 1;
    return page;
  }

  double get bookPercent {
    if (_bookData == null || _bookData!.chapters.isEmpty) return 0.0;
    final chapterFraction = 1.0 / _bookData!.chapters.length;
    final chapterBase = _currentChapterIndex * chapterFraction;
    final pageFraction = totalPagesInChapter > 0
        ? (_currentPageIndex / totalPagesInChapter) * chapterFraction
        : 0.0;
    return chapterBase + pageFraction;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Open a book for reading.
  Future<void> openBook({
    required BookEntity book,
    required ChapterDataSource dataSource,
    required Size viewportSize,
    required double safeAreaTop,
    required double safeAreaBottom,
    double devicePixelRatio = 1.0,
  }) async {
    _book = book;
    _dataSource = dataSource;
    _viewportSize = viewportSize;
    _safeAreaTop = safeAreaTop;
    _safeAreaBottom = safeAreaBottom;
    _devicePixelRatio = devicePixelRatio;
    _cache.clear();
    _pageCountCache.clear();
    _persistedPageCountsJson = null;
    _allPagesComputed = false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('[ReaderStore] loadBook ...');
      _bookData = await dataSource.loadBook();
      debugPrint('[ReaderStore] chapters=${_bookData!.chapters.length}');

      // Restore saved progress (position, preferences, and page count cache).
      final progress = await _progressRepository.getProgress(book.id);
      if (progress != null) {
        _restoreProgress(progress);
        _tryRestorePageCounts(progress.pageCountsJson);
      }
      debugPrint('[ReaderStore] loadChapter($_currentChapterIndex) ...');

      await _loadChapter(_currentChapterIndex);

      // Skip empty chapters (e.g. cover pages with unresolved images).
      while (_currentPagination != null &&
          _currentPagination!.pages.isEmpty &&
          _currentChapterIndex < chapterCount - 1) {
        _currentChapterIndex++;
        _currentPageIndex = 0;
        debugPrint('[ReaderStore] chapter empty, advancing to $_currentChapterIndex');
        await _loadChapter(_currentChapterIndex);
      }

      debugPrint(
        '[ReaderStore] done. pages=${_currentPagination?.pages.length}, '
        'error=$_error',
      );

      // Clamp page index to valid range after loading.
      if (_currentPagination != null &&
          _currentPageIndex >= _currentPagination!.pages.length) {
        _currentPageIndex = _currentPagination!.pages.isEmpty
            ? 0
            : _currentPagination!.pages.length - 1;
      }
    } catch (e, st) {
      debugPrint('[ReaderStore] openBook error: $e\n$st');
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();

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

    if (_dataSource != null) {
      await _loadChapter(_currentChapterIndex);
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void nextPage() {
    if (_currentPagination == null) return;

    if (_currentPageIndex < _currentPagination!.pages.length - 1) {
      _currentPageIndex++;
      notifyListeners();
      _saveProgress();
    } else {
      // Advance to next non-empty chapter.
      _goToNextNonEmptyChapter();
    }
  }

  Future<void> _goToNextNonEmptyChapter() async {
    var next = _currentChapterIndex + 1;
    while (next < chapterCount) {
      _currentChapterIndex = next;
      _currentPageIndex = 0;
      _isLoading = true;
      notifyListeners();

      await _loadChapter(next);
      if (_currentPagination != null && _currentPagination!.pages.isNotEmpty) {
        _isLoading = false;
        notifyListeners();
        _saveProgress();
        return;
      }
      next++;
    }
    // No more chapters with content.
    _isLoading = false;
    notifyListeners();
  }

  void previousPage() {
    if (_currentPageIndex > 0) {
      _currentPageIndex--;
      notifyListeners();
      _saveProgress();
    } else if (_currentChapterIndex > 0) {
      // Go to last page of previous chapter.
      goToChapter(_currentChapterIndex - 1, lastPage: true);
    }
  }

  Future<void> goToChapter(int index, {bool lastPage = false}) async {
    if (index < 0 || index >= chapterCount) return;
    _currentChapterIndex = index;
    _currentPageIndex = 0;

    _isLoading = true;
    notifyListeners();

    await _loadChapter(index);

    if (lastPage && _currentPagination != null) {
      _currentPageIndex = _currentPagination!.pages.length - 1;
    }

    _isLoading = false;
    notifyListeners();
    _saveProgress();
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
    _preferences = newPrefs;

    if (needsRelayout) {
      _cache.clear();
      _pageCountCache.clear();
      _persistedPageCountsJson = null;
      _allPagesComputed = false;
      if (_dataSource != null) {
        await _loadChapter(_currentChapterIndex);
      }
      _computeAllPageCounts();
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

    // Check cache.
    final cacheKey = _cacheKey(index);
    if (_cache.containsKey(cacheKey)) {
      if (!prefetchOnly) {
        _currentPagination = _cache[cacheKey];
      }
      return;
    }

    try {
      final chapter = await _dataSource!.loadChapter(index);
      debugPrint('[ReaderStore] chapter $index loaded: ${chapter.nodes.length} nodes');

      // Pre-decode images before pagination.
      final contentWidth =
          _viewportSize.width - 2 * _preferences.pageHorizontalPaddingPx;
      final decodedImages = await _engine.decodeImages(
        chapter.nodes,
        contentWidth,
        _devicePixelRatio,
      );
      debugPrint('[ReaderStore] decoded ${decodedImages.length} images');

      // Yield a frame so the loading indicator can animate smoothly while
      // the synchronous paginate() runs.
      await Future<void>.delayed(Duration.zero);

      final pagination = _engine.paginate(
        chapterIndex: index,
        nodes: chapter.nodes,
        viewportSize: _viewportSize,
        prefs: _preferences,
        decodedImages: decodedImages,
        safeAreaTop: _safeAreaTop,
        safeAreaBottom: _safeAreaBottom,
      );
      debugPrint('[ReaderStore] paginated: ${pagination.pages.length} pages');
      _cache[cacheKey] = pagination;

      if (!prefetchOnly) {
        _currentPagination = pagination;
        _error = null;

        // Fire-and-forget: prefetch the next chapter so cross-chapter
        // navigation is instant.
        _prefetchAdjacentChapters(index);
      }
    } catch (e, st) {
      debugPrint('[ReaderStore] _loadChapter error: $e\n$st');
      if (!prefetchOnly) {
        _error = e.toString();
        _currentPagination = null;
      }
    }
  }

  /// Prefetch the chapters adjacent to [currentIndex] in the background.
  void _prefetchAdjacentChapters(int currentIndex) {
    final next = currentIndex + 1;
    if (next < chapterCount && !_cache.containsKey(_cacheKey(next))) {
      _loadChapter(next, prefetchOnly: true).catchError((_) {});
    }
    final prev = currentIndex - 1;
    if (prev >= 0 && !_cache.containsKey(_cacheKey(prev))) {
      _loadChapter(prev, prefetchOnly: true).catchError((_) {});
    }
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

    for (var i = 0; i < totalChapters; i++) {
      // Abort if book or layout preferences changed while computing.
      if (_bookData != snapshotBook ||
          _preferences.layoutHash != snapshotHash) {
        return;
      }

      // Yield to the event loop to keep the UI responsive.
      await Future<void>.delayed(Duration.zero);

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
          final pagination = _engine.paginate(
            chapterIndex: i,
            nodes: chapter.nodes,
            viewportSize: _viewportSize,
            prefs: _preferences,
            safeAreaTop: _safeAreaTop,
            safeAreaBottom: _safeAreaBottom,
            pageCountOnly: true,
          );
          _chapterPageCounts[i] = pagination.pages.length;
          // Cache page count only (no full pagination — images not decoded).
          _pageCountCache[cacheKey] = pagination.pages.length;
        } catch (e) {
          debugPrint(
              '[ReaderStore] _computeAllPageCounts chapter $i error: $e');
          _chapterPageCounts[i] = 0;
        }
      }

      // Notify periodically so progress displays update incrementally.
      if (i % 5 == 0) notifyListeners();
    }

    _allPagesComputed = true;
    _persistedPageCountsJson = _serializePageCounts();
    debugPrint('[ReaderStore] all page counts computed: total=$totalBookPages');
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

  Future<void> _saveProgress() async {
    if (_book == null) return;

    final locator = jsonEncode({
      'chapterIndex': _currentChapterIndex,
      'pageIndex': _currentPageIndex,
    });

    await _progressRepository.saveProgress(
      ReadingProgressEntity(
        bookId: _book!.id,
        locatorJson: locator,
        percent: bookPercent,
        updatedAt: DateTime.now(),
        prefsJson: jsonEncode(_preferences.toJson()),
        pageCountsJson: _persistedPageCountsJson,
      ),
    );
  }
}
