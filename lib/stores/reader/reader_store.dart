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

  /// Cache: chapterIndex → ChapterPagination
  final Map<int, ChapterPagination> _cache = {};

  /// Per-chapter page counts for whole-book pagination (null = not yet computed).
  List<int?> _chapterPageCounts = [];
  bool _allPagesComputed = false;

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

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('[ReaderStore] loadBook ...');
      _bookData = await dataSource.loadBook();
      debugPrint('[ReaderStore] chapters=${_bookData!.chapters.length}');

      // Restore saved progress.
      final progress = await _progressRepository.getProgress(book.id);
      if (progress != null) {
        _restoreProgress(progress);
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

    // Background: compute page counts for all chapters.
    _computeAllPageCounts();
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

    _preferences = newPrefs;
    _cache.clear();

    if (_dataSource != null) {
      _isLoading = true;
      notifyListeners();

      await _loadChapter(_currentChapterIndex);

      _isLoading = false;
    }

    notifyListeners();
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

  Future<void> _loadChapter(int index) async {
    if (_dataSource == null) return;

    // Check cache.
    final cacheKey = _cacheKey(index);
    if (_cache.containsKey(cacheKey)) {
      _currentPagination = _cache[cacheKey];
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
      _currentPagination = pagination;
      _error = null;
    } catch (e, st) {
      debugPrint('[ReaderStore] _loadChapter error: $e\n$st');
      _error = e.toString();
      _currentPagination = null;
    }
  }

  /// Compute page counts for all chapters in the background.
  Future<void> _computeAllPageCounts() async {
    if (_dataSource == null || _bookData == null) return;

    final totalChapters = _bookData!.chapters.length;
    _chapterPageCounts = List<int?>.filled(totalChapters, null);
    _allPagesComputed = false;

    for (var i = 0; i < totalChapters; i++) {
      // Use cached pagination if available.
      final cacheKey = _cacheKey(i);
      if (_cache.containsKey(cacheKey)) {
        _chapterPageCounts[i] = _cache[cacheKey]!.pages.length;
        continue;
      }

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
        );
        _chapterPageCounts[i] = pagination.pages.length;
        _cache[cacheKey] = pagination;
      } catch (e) {
        debugPrint('[ReaderStore] _computeAllPageCounts chapter $i error: $e');
        _chapterPageCounts[i] = 0;
      }
    }

    _allPagesComputed = true;
    debugPrint('[ReaderStore] all page counts computed: total=$totalBookPages');
    notifyListeners();
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
      // If locator JSON is from old reader format, start from beginning.
      _currentChapterIndex = 0;
      _currentPageIndex = 0;
    }
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
      ),
    );
  }
}
