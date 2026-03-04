import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../entities/chapter-entity.dart';
import '../../entities/reader-pagination-cache-entity.dart';
import '../../entities/reader-preferences-entity.dart';
import '../../entities/reading-progress-entity.dart';
import '../../repositories/book/book-repository.dart';
import '../../repositories/chapter/chapter-repository.dart';
import '../../repositories/progress/progress-repository.dart';
import '../../repositories/reader-pagination-cache/reader-pagination-cache-repository.dart';
import '../../repositories/reader-preferences/reader-preferences-repository.dart';
import '../../services/reader/reader-catalog-metrics-service.dart';
import '../../services/reader/reader-page-slice.dart';
import '../../services/reader/reader-pagination-engine.dart';
import '../../services/reader/reading-position-service.dart';
import '../../shared/constants/reader-constants.dart';
import 'reader-state.dart';

class ReaderStore extends ChangeNotifier {
  ReaderStore({
    required BookRepository bookRepository,
    required ChapterRepository chapterRepository,
    required ProgressRepository progressRepository,
    required ReaderPaginationCacheRepository readerPaginationCacheRepository,
    required ReaderPreferencesRepository readerPreferencesRepository,
    ReadingPositionService? readingPositionService,
    ReaderPaginationEngine? paginationEngine,
    ReaderCatalogMetricsService? catalogMetricsService,
  }) : _bookRepository = bookRepository,
       _chapterRepository = chapterRepository,
       _progressRepository = progressRepository,
       _readerPaginationCacheRepository = readerPaginationCacheRepository,
       _readerPreferencesRepository = readerPreferencesRepository,
       _readingPositionService =
           readingPositionService ?? ReadingPositionService(),
       _paginationEngine = paginationEngine ?? ReaderPaginationEngine(),
       _catalogMetricsService =
           catalogMetricsService ?? ReaderCatalogMetricsService();

  final BookRepository _bookRepository;
  final ChapterRepository _chapterRepository;
  final ProgressRepository _progressRepository;
  final ReaderPaginationCacheRepository _readerPaginationCacheRepository;
  final ReaderPreferencesRepository _readerPreferencesRepository;
  final ReadingPositionService _readingPositionService;
  final ReaderPaginationEngine _paginationEngine;
  final ReaderCatalogMetricsService _catalogMetricsService;

  ReaderState _state = const ReaderState();
  Timer? _saveTimer;
  String _lastPaginationKey = '';
  String _currentLayoutKey = '';
  static const int _cacheKeepCountPerBook = 3;
  Size? _lastViewport;
  TextStyle? _lastTextStyle;
  double? _lastHorizontalPadding;
  double? _lastVerticalPadding;
  // Cached font metrics from the most recent layout measurement.
  // Reused by warmUp and catalog passes to avoid redundant TextPainter calls.
  ReaderFontMetrics? _lastFontMetrics;
  Future<void>? _catalogMetricsTask;
  String _catalogMetricsCacheKey = '';

  ReaderState get state => _state;

  Future<void> openBook(String bookId) async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    final book = await _bookRepository.getBookById(bookId);
    final chapters = await _chapterRepository.getChapters(bookId);
    final progress = await _progressRepository.getProgress(bookId);
    final preferences =
        await _readerPreferencesRepository.getByBookId(bookId) ??
        ReaderPreferencesEntity.defaultsForBook(bookId);

    if (book == null || chapters.isEmpty) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return;
    }

    final targetChapter = progress == null
        ? chapters.first
        : chapters.firstWhere(
            (item) => item.id == progress.chapterId,
            orElse: () => chapters.first,
          );

    final maxOffset = targetChapter.content.length;
    final charOffset = _readingPositionService.clampOffset(
      offset: progress?.charOffset ?? 0,
      totalLength: maxOffset,
    );
    final targetChapterIndex = chapters.indexWhere(
      (item) => item.id == targetChapter.id,
    );
    final currentChapterIndex = targetChapterIndex < 0 ? 0 : targetChapterIndex;

    _state = _state.copyWith(
      book: book,
      chapters: chapters,
      chapter: targetChapter,
      currentChapterIndex: currentChapterIndex,
      charOffset: charOffset,
      bookPercent: progress?.percent ?? 0,
      currentPage: 1,
      totalPages:
          book.estimatedTotalPages != null && book.estimatedTotalPages! > 0
          ? book.estimatedTotalPages!
          : 1,
      currentPageIndex: 0,
      pageSlices: const <ReaderPageSlice>[],
      windowChapterStart: _windowChapterStart(currentChapterIndex, chapters),
      windowChapterEnd: _windowChapterEnd(currentChapterIndex, chapters),
      isWindowReady: false,
      paginationSource: 'live',
      preferences: preferences,
      isLoading: false,
      catalogMetricsStatus: 'idle',
      catalogChapterStartPages: const <int, int>{},
      catalogTotalPages: 1,
    );
    _lastPaginationKey = '';
    _lastFontMetrics = null;
    _catalogMetricsCacheKey = '';
    notifyListeners();
  }

  Future<void> loadPreferences(String bookId) async {
    final preferences =
        await _readerPreferencesRepository.getByBookId(bookId) ??
        ReaderPreferencesEntity.defaultsForBook(bookId);
    _state = _state.copyWith(preferences: preferences);
    notifyListeners();
  }

  Future<void> updatePreferences(
    ReaderPreferencesEntity Function(ReaderPreferencesEntity current) updater,
  ) async {
    final current =
        _state.preferences ??
        ReaderPreferencesEntity.defaultsForBook(_state.book?.id ?? '');
    final next = updater(current);
    _state = _state.copyWith(preferences: next);
    notifyListeners();
    if (next.bookId.isNotEmpty) {
      await _readerPreferencesRepository.savePreferences(next);
    }
  }

  Future<void> switchChapter(String chapterId) async {
    final chapterIndex = _state.chapters.indexWhere(
      (item) => item.id == chapterId,
    );
    if (chapterIndex < 0) {
      return;
    }
    await switchChapterByIndex(chapterIndex);
  }

  Future<void> switchChapterByIndex(int chapterIndex) async {
    final chapters = _state.chapters;
    if (chapters.isEmpty) {
      return;
    }
    final safeChapterIndex = chapterIndex.clamp(0, chapters.length - 1).toInt();
    final chapter = chapters[safeChapterIndex];
    _state = _state.copyWith(
      chapter: chapter,
      currentChapterIndex: safeChapterIndex,
      charOffset: 0,
    );
    notifyListeners();
    await flushProgress();
  }

  void updateOffset(int offset) {
    final chapter = _state.chapter;
    if (chapter == null) {
      return;
    }

    final clamped = _readingPositionService.clampOffset(
      offset: offset,
      totalLength: chapter.content.length,
    );
    final percent = _readingPositionService.toPercent(
      offset: clamped,
      totalLength: chapter.content.length,
    );

    _state = _state.copyWith(charOffset: clamped, bookPercent: percent);
    notifyListeners();
    _scheduleProgressSave();
  }

  void updateReadingMetrics({
    required int chapterIndex,
    required int chapterCharOffset,
    required double bookPercent,
    required int currentPage,
    required int totalPages,
    int? currentPageIndex,
  }) {
    final chapters = _state.chapters;
    if (chapters.isEmpty) {
      return;
    }
    final safeChapterIndex = chapterIndex.clamp(0, chapters.length - 1).toInt();
    final chapter = chapters[safeChapterIndex];
    final clampedOffset = _readingPositionService.clampOffset(
      offset: chapterCharOffset,
      totalLength: chapter.content.length,
    );
    final clampedBookPercent = bookPercent.clamp(0, 1).toDouble();
    final safeTotalPages = totalPages <= 0 ? 1 : totalPages;
    final safeCurrentPage = currentPage <= 0 ? 1 : currentPage;

    _state = _state.copyWith(
      chapter: chapter,
      currentChapterIndex: safeChapterIndex,
      charOffset: clampedOffset,
      bookPercent: clampedBookPercent,
      currentPage: safeCurrentPage.clamp(1, safeTotalPages).toInt(),
      totalPages: safeTotalPages,
      currentPageIndex: (currentPageIndex ?? _state.currentPageIndex).clamp(
        0,
        math.max(0, safeTotalPages - 1),
      ),
    );
    notifyListeners();
    _scheduleProgressSave();
  }

  void rebuildPagination({
    required String layoutKey,
    required Size viewport,
    required TextStyle textStyle,
    required double horizontalPadding,
    required double verticalPadding,
  }) {
    _currentLayoutKey = layoutKey;
    _lastViewport = viewport;
    _lastTextStyle = textStyle;
    _lastHorizontalPadding = horizontalPadding;
    _lastVerticalPadding = verticalPadding;
    _invalidateCatalogMetricsIfStale();
    final chapters = _state.chapters;
    if (chapters.isEmpty || viewport.width <= 0 || viewport.height <= 0) {
      return;
    }
    if (_lastPaginationKey == layoutKey && _state.pageSlices.isNotEmpty) {
      return;
    }

    final maxWidth = math.max(120.0, viewport.width - horizontalPadding * 2);
    final maxHeight = math.max(160.0, viewport.height - verticalPadding * 2);
    final fontMetrics = ReaderPaginationEngine.measureFontMetrics(
      style: textStyle,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    _lastFontMetrics = fontMetrics;

    final windowStart = _windowChapterStart(
      _state.currentChapterIndex,
      chapters,
    );
    final windowEnd = _windowChapterEnd(_state.currentChapterIndex, chapters);
    final pages = _paginationEngine.buildPagesMath(
      chapters: chapters,
      metrics: fontMetrics,
      chapterStart: windowStart,
      chapterEnd: windowEnd,
    );

    final restoredPageIndex = _pageIndexForPosition(
      pages: pages,
      chapterIndex: _state.currentChapterIndex,
      chapterOffset: _state.charOffset,
    );

    _state = _state.copyWith(
      pageSlices: pages,
      totalPages: pages.length,
      currentPageIndex: restoredPageIndex,
      currentPage: restoredPageIndex + 1,
      windowChapterStart: windowStart,
      windowChapterEnd: windowEnd,
      isWindowReady: true,
      paginationSource: 'precise',
    );
    _lastPaginationKey = layoutKey;
    notifyListeners();

    unawaited(
      buildAndPersistWindowPagination(
        layoutKey: layoutKey,
        chapterStart: windowStart,
        chapterEnd: windowEnd,
        pages: pages,
        cacheKind: 'precise',
      ),
    );
  }

  Future<void> warmUpWindowPagination({required int chapterIndex}) async {
    final chapters = _state.chapters;
    if (chapters.isEmpty || _currentLayoutKey.isEmpty) {
      return;
    }
    final windowStart = _windowChapterStart(chapterIndex, chapters);
    final windowEnd = _windowChapterEnd(chapterIndex, chapters);
    if (windowStart == _state.windowChapterStart &&
        windowEnd == _state.windowChapterEnd) {
      return;
    }
    await restoreWindowFromCache(
      layoutKey: _currentLayoutKey,
      chapterStart: windowStart,
      chapterEnd: windowEnd,
    );
    if (_state.windowChapterStart == windowStart &&
        _state.windowChapterEnd == windowEnd) {
      return;
    }

    final viewport = _lastViewport;
    final textStyle = _lastTextStyle;
    final horizontalPadding = _lastHorizontalPadding;
    final verticalPadding = _lastVerticalPadding;
    if (viewport == null ||
        textStyle == null ||
        horizontalPadding == null ||
        verticalPadding == null) {
      return;
    }

    final maxWidth = math.max(120.0, viewport.width - horizontalPadding * 2);
    final maxHeight = math.max(160.0, viewport.height - verticalPadding * 2);
    final fontMetrics =
        _lastFontMetrics ??
        ReaderPaginationEngine.measureFontMetrics(
          style: textStyle,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        );
    _lastFontMetrics = fontMetrics;

    final pages = _paginationEngine.buildPagesMath(
      chapters: chapters,
      metrics: fontMetrics,
      chapterStart: windowStart,
      chapterEnd: windowEnd,
    );
    final restoredPageIndex = _pageIndexForPosition(
      pages: pages,
      chapterIndex: _state.currentChapterIndex,
      chapterOffset: _state.charOffset,
    );
    _state = _state.copyWith(
      pageSlices: pages,
      totalPages: pages.length,
      currentPageIndex: restoredPageIndex,
      currentPage: restoredPageIndex + 1,
      windowChapterStart: windowStart,
      windowChapterEnd: windowEnd,
      isWindowReady: true,
      paginationSource: 'precise',
    );
    notifyListeners();
    await buildAndPersistWindowPagination(
      layoutKey: _currentLayoutKey,
      chapterStart: windowStart,
      chapterEnd: windowEnd,
      pages: pages,
      cacheKind: 'precise',
    );
  }

  Future<bool> restoreWindowFromCache({
    required String layoutKey,
    required int chapterStart,
    required int chapterEnd,
  }) async {
    final bookId = _state.book?.id;
    if (bookId == null || _state.chapters.isEmpty) {
      return false;
    }
    final cache = await _readerPaginationCacheRepository.getCache(
      bookId: bookId,
      layoutKey: layoutKey,
      cacheKind: 'precise',
      chapterStart: chapterStart,
      chapterEnd: chapterEnd,
    );
    if (cache == null || cache.slices.isEmpty) {
      return false;
    }
    if (cache.chapterStart != chapterStart || cache.chapterEnd != chapterEnd) {
      return false;
    }
    final pages = _paginationEngine.pagesFromCachedSlices(
      chapters: _state.chapters,
      slices: cache.slices,
    );
    final restoredPageIndex = _pageIndexForPosition(
      pages: pages,
      chapterIndex: _state.currentChapterIndex,
      chapterOffset: _state.charOffset,
    );
    _state = _state.copyWith(
      pageSlices: pages,
      totalPages: pages.length,
      currentPageIndex: restoredPageIndex,
      currentPage: restoredPageIndex + 1,
      windowChapterStart: chapterStart,
      windowChapterEnd: chapterEnd,
      isWindowReady: true,
      paginationSource: 'cache',
    );
    _lastPaginationKey = layoutKey;
    notifyListeners();
    return true;
  }

  Future<void> buildAndPersistWindowPagination({
    required String layoutKey,
    required int chapterStart,
    required int chapterEnd,
    required List<ReaderPageSlice> pages,
    required String cacheKind,
  }) async {
    final bookId = _state.book?.id;
    if (bookId == null || pages.isEmpty) {
      return;
    }
    final cache = ReaderPaginationCacheEntity(
      id: '${bookId}_${layoutKey}_${chapterStart}_${chapterEnd}_$cacheKind',
      bookId: bookId,
      layoutKey: layoutKey,
      cacheKind: cacheKind,
      chapterStart: chapterStart,
      chapterEnd: chapterEnd,
      pageCount: pages.length,
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      slices: List<ReaderPaginationSliceEntity>.generate(
        pages.length,
        (index) => ReaderPaginationSliceEntity(
          pageIndex: index,
          chapterIndex: pages[index].chapterIndex,
          startOffset: pages[index].startOffset,
          endOffset: pages[index].endOffset,
        ),
        growable: false,
      ),
    );
    await _readerPaginationCacheRepository.saveCache(cache);
    await _readerPaginationCacheRepository.pruneBookCaches(
      bookId: bookId,
      keepCount: _cacheKeepCountPerBook,
    );
  }

  void jumpToPage(int pageIndex) {
    final pages = _state.pageSlices;
    if (pages.isEmpty) {
      return;
    }
    final safePageIndex = pageIndex.clamp(0, pages.length - 1).toInt();
    final page = pages[safePageIndex];
    final percent = pages.length <= 1
        ? 0.0
        : (safePageIndex / (pages.length - 1)).clamp(0, 1).toDouble();

    updateReadingMetrics(
      chapterIndex: page.chapterIndex,
      chapterCharOffset: page.startOffset,
      bookPercent: percent,
      currentPage: safePageIndex + 1,
      totalPages: pages.length,
      currentPageIndex: safePageIndex,
    );
  }

  int _pageIndexForPosition({
    required List<ReaderPageSlice> pages,
    required int chapterIndex,
    required int chapterOffset,
  }) {
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      if (page.chapterIndex != chapterIndex) {
        continue;
      }
      if (chapterOffset >= page.startOffset && chapterOffset < page.endOffset) {
        return i;
      }
    }
    return 0;
  }

  int _windowChapterStart(int chapterIndex, List<ChapterEntity> chapters) {
    if (chapters.isEmpty) {
      return 0;
    }
    return math.max(0, chapterIndex - 1);
  }

  int _windowChapterEnd(int chapterIndex, List<ChapterEntity> chapters) {
    if (chapters.isEmpty) {
      return 0;
    }
    return math.min(chapters.length - 1, chapterIndex + 1);
  }

  String buildTextVersion(List<ChapterEntity> chapters) {
    final buffer = StringBuffer();
    for (final chapter in chapters) {
      final content = chapter.content;
      final head = content.substring(0, math.min(64, content.length));
      final tail = content.substring(math.max(0, content.length - 64));
      buffer
        ..write(chapter.id)
        ..write(':')
        ..write(content.length)
        ..write(':')
        ..write(head.hashCode)
        ..write(':')
        ..write(tail.hashCode)
        ..write(';');
    }
    final encoded = base64Url.encode(utf8.encode(buffer.toString()));
    if (encoded.length <= 24) {
      return encoded;
    }
    return encoded.substring(0, 24);
  }

  void _scheduleProgressSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: ReaderConstants.progressSaveThrottleMs),
      () {
        unawaited(saveProgress());
      },
    );
  }

  Future<void> saveProgress({bool emitStateChanges = true}) async {
    final book = _state.book;
    final chapter = _state.chapter;
    if (book == null || chapter == null) {
      return;
    }

    if (emitStateChanges) {
      _state = _state.copyWith(isSaving: true);
      notifyListeners();
    }

    final progress = ReadingProgressEntity(
      bookId: book.id,
      chapterId: chapter.id,
      charOffset: _state.charOffset,
      percent: _state.bookPercent,
      updatedAt: DateTime.now(),
    );
    await _progressRepository.saveProgress(progress);

    if (emitStateChanges) {
      _state = _state.copyWith(isSaving: false);
      notifyListeners();
    }
  }

  Future<void> flushProgress({bool emitStateChanges = true}) async {
    _saveTimer?.cancel();
    await saveProgress(emitStateChanges: emitStateChanges);
  }

  ({Map<int, int> chapterStartPages, int totalPages})
  catalogPaginationMetrics() {
    final fromState = (
      chapterStartPages: _state.catalogChapterStartPages,
      totalPages: _state.catalogTotalPages,
    );
    if (_state.catalogMetricsStatus == 'ready' &&
        _state.catalogChapterStartPages.isNotEmpty) {
      return fromState;
    }

    final chapters = _state.chapters;
    if (chapters.isEmpty) {
      return (chapterStartPages: const <int, int>{}, totalPages: 1);
    }

    final viewport = _lastViewport;
    final textStyle = _lastTextStyle;
    final horizontalPadding = _lastHorizontalPadding;
    final verticalPadding = _lastVerticalPadding;
    if (viewport == null ||
        textStyle == null ||
        horizontalPadding == null ||
        verticalPadding == null ||
        viewport.width <= 0 ||
        viewport.height <= 0) {
      final fallback = <int, int>{
        for (var i = 0; i < chapters.length; i++) i: 1,
      };
      return (chapterStartPages: fallback, totalPages: 1);
    }

    final fallback = <int, int>{for (var i = 0; i < chapters.length; i++) i: 1};
    return (
      chapterStartPages: _state.catalogChapterStartPages.isEmpty
          ? fallback
          : _state.catalogChapterStartPages,
      totalPages: _state.catalogTotalPages <= 0 ? 1 : _state.catalogTotalPages,
    );
  }

  Future<void> ensureCatalogMetricsReady() async {
    final chapters = _state.chapters;
    if (chapters.isEmpty) {
      return;
    }
    final cacheKey = _currentCatalogCacheKey();
    if (cacheKey == null) {
      return;
    }
    if (_state.catalogMetricsStatus == 'ready' &&
        _catalogMetricsCacheKey == cacheKey &&
        _state.catalogChapterStartPages.isNotEmpty) {
      return;
    }
    if (_catalogMetricsTask != null) {
      await _catalogMetricsTask;
      return;
    }

    _state = _state.copyWith(catalogMetricsStatus: 'loading');
    notifyListeners();

    _catalogMetricsTask = Future<void>(() {
      final stableCacheKey = _currentCatalogCacheKey();
      if (stableCacheKey == null) {
        _state = _state.copyWith(catalogMetricsStatus: 'error');
        notifyListeners();
        return;
      }
      try {
        final viewport = _lastViewport!;
        final textStyle = _lastTextStyle!;
        final horizontalPadding = _lastHorizontalPadding!;
        final verticalPadding = _lastVerticalPadding!;
        final maxWidth = math.max(
          120.0,
          viewport.width - horizontalPadding * 2,
        );
        final maxHeight = math.max(
          160.0,
          viewport.height - verticalPadding * 2,
        );
        final fontMetrics =
            _lastFontMetrics ??
            ReaderPaginationEngine.measureFontMetrics(
              style: textStyle,
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            );
        final metrics = _catalogMetricsService.resolve(
          cacheKey: stableCacheKey,
          chapterCount: chapters.length,
          buildAllPages: () => _paginationEngine.buildPagesMath(
            chapters: chapters,
            metrics: fontMetrics,
            chapterStart: 0,
            chapterEnd: chapters.length - 1,
          ),
        );
        if (_currentCatalogCacheKey() != stableCacheKey) {
          return;
        }
        _catalogMetricsCacheKey = stableCacheKey;
        _state = _state.copyWith(
          catalogMetricsStatus: 'ready',
          catalogChapterStartPages: metrics.chapterStartPages,
          catalogTotalPages: metrics.totalPages,
        );
        notifyListeners();
      } catch (_) {
        _state = _state.copyWith(catalogMetricsStatus: 'error');
        notifyListeners();
      }
    });

    try {
      await _catalogMetricsTask;
    } finally {
      _catalogMetricsTask = null;
    }
  }

  String? _currentCatalogCacheKey() {
    final chapters = _state.chapters;
    final viewport = _lastViewport;
    final textStyle = _lastTextStyle;
    final horizontalPadding = _lastHorizontalPadding;
    final verticalPadding = _lastVerticalPadding;
    if (chapters.isEmpty ||
        viewport == null ||
        textStyle == null ||
        horizontalPadding == null ||
        verticalPadding == null ||
        viewport.width <= 0 ||
        viewport.height <= 0) {
      return null;
    }
    return <Object?>[
      _currentLayoutKey,
      viewport.width.toStringAsFixed(2),
      viewport.height.toStringAsFixed(2),
      textStyle.fontSize,
      textStyle.height,
      textStyle.letterSpacing,
      textStyle.fontFamily,
      horizontalPadding,
      verticalPadding,
      buildTextVersion(chapters),
    ].join('_');
  }

  void _invalidateCatalogMetricsIfStale() {
    final cacheKey = _currentCatalogCacheKey();
    if (cacheKey == null) {
      return;
    }
    if (_catalogMetricsCacheKey == cacheKey &&
        _state.catalogMetricsStatus == 'ready') {
      return;
    }
    if (_state.catalogMetricsStatus == 'idle' &&
        _state.catalogChapterStartPages.isEmpty) {
      return;
    }
    _state = _state.copyWith(
      catalogMetricsStatus: 'idle',
      catalogChapterStartPages: const <int, int>{},
      catalogTotalPages: 1,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
