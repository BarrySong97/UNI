import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../entities/book-entity.dart';
import '../../repositories/progress/progress-repository.dart';
import '../../services/reader/data/chapter_data_source.dart';
import '../../services/reader/models/page_layout.dart';
import '../../services/reader/models/reader_preferences.dart';
import '../../services/reader/selection/cross_page_selection.dart';
import '../../services/reader/selection/page_hit_test.dart';
import '../../stores/reader/reader_store.dart';
import 'widgets/reader_canvas_painter.dart';
import 'widgets/reader_controls_overlay.dart';
import 'widgets/reader_selection_handle.dart';
import 'widgets/reader_toc_sheet.dart';

/// Main reader page with multi-chapter navigation.
///
/// Uses [ReaderStore] to manage pagination, chapter loading, and progress.
class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.book,
    required this.dataSource,
    required this.progressRepository,
  });

  final BookEntity book;
  final ChapterDataSource dataSource;
  final ProgressRepository progressRepository;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage>
    with SingleTickerProviderStateMixin {
  late final ReaderStore _store;

  // -- Page swipe animation state --
  late final AnimationController _pageAnimController;
  double _dragOffset = 0.0;
  bool _isAnimating = false;
  int _animDirection = 0; // -1 = next, 1 = prev, 0 = snap back
  Animation<double>? _curvedDragAnim;

  // -- Text selection state --
  CrossPageSelection? _crossSelection;
  List<Rect> _selectionRects = const [];
  bool _isLongPressing = false;

  // Anchor/moving model for handle drag: the anchor is the fixed end,
  // the moving end is the handle being dragged.
  BookPosition? _selectionAnchor;
  BookPosition? _selectionMoving;

  // Prevent clearing selection during selection-triggered page turns.
  bool _preserveSelectionOnPageChange = false;

  // Edge dwell timer for auto page turn during handle drag.
  Timer? _edgeDwellTimer;
  static const double _edgeZoneWidth = 40.0;
  static const Duration _edgeDwellDuration = Duration(milliseconds: 300);

  // Cached page identity to detect page changes.
  int _lastChapterIndex = -1;
  int _lastPageIndex = -1;

  @override
  void initState() {
    super.initState();
    _store = ReaderStore(progressRepository: widget.progressRepository);
    _store.addListener(_onStoreChanged);

    _pageAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(_onAnimTick)
     ..addStatusListener(_onAnimStatus);

    WidgetsBinding.instance.addPostFrameCallback((_) => _initReader());
  }

  Future<void> _initReader() async {
    if (!mounted) return;

    final mq = MediaQuery.of(context);

    await _store.openBook(
      book: widget.book,
      dataSource: widget.dataSource,
      viewportSize: mq.size,
      safeAreaTop: mq.padding.top,
      safeAreaBottom: mq.padding.bottom,
      devicePixelRatio: mq.devicePixelRatio,
    );
  }

  void _onStoreChanged() {
    if (!mounted) return;

    if (_store.currentChapterIndex != _lastChapterIndex ||
        _store.currentPageIndex != _lastPageIndex) {
      _lastChapterIndex = _store.currentChapterIndex;
      _lastPageIndex = _store.currentPageIndex;

      if (_preserveSelectionOnPageChange) {
        // Selection-triggered page turn: keep selection, recompute rects.
        _updateSelectionRects();
      } else {
        _clearSelection();
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    _edgeDwellTimer?.cancel();
    _pageAnimController.dispose();
    _store.removeListener(_onStoreChanged);
    _store.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Animation callbacks
  // ---------------------------------------------------------------------------

  void _onAnimTick() {
    if (_curvedDragAnim == null) return;
    setState(() {
      _dragOffset = _curvedDragAnim!.value;
    });
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final direction = _animDirection;
    _isAnimating = false;
    _dragOffset = 0.0;
    _animDirection = 0;
    _curvedDragAnim = null;

    if (direction < 0) {
      _store.nextPage();
    } else if (direction > 0) {
      _store.previousPage();
    } else {
      setState(() {});
    }
  }

  // ---------------------------------------------------------------------------
  // Coordinate transform
  // ---------------------------------------------------------------------------

  /// Convert a global position to content-area coordinates.
  Offset _toContentOffset(Offset global) {
    final mq = MediaQuery.of(context);
    final prefs = _store.preferences;
    return Offset(
      global.dx - prefs.pageHorizontalPaddingPx,
      global.dy - prefs.pageVerticalPaddingPx - mq.padding.top,
    );
  }

  /// Convert content-area coordinates to screen coordinates.
  Offset _toScreenOffset(Offset content) {
    final mq = MediaQuery.of(context);
    final prefs = _store.preferences;
    return Offset(
      content.dx + prefs.pageHorizontalPaddingPx,
      content.dy + prefs.pageVerticalPaddingPx + mq.padding.top,
    );
  }

  // ---------------------------------------------------------------------------
  // Text selection
  // ---------------------------------------------------------------------------

  void _clearSelection() {
    _crossSelection = null;
    _selectionRects = const [];
    _isLongPressing = false;
    _selectionAnchor = null;
    _selectionMoving = null;
    _edgeDwellTimer?.cancel();
    _edgeDwellTimer = null;
    _preserveSelectionOnPageChange = false;
  }

  void _updateSelectionRects() {
    final page = _store.currentPageLayout;
    if (_crossSelection == null || page == null) {
      _selectionRects = const [];
      return;
    }

    final pageSelection = _crossSelection!.projectOntoPage(page);
    if (pageSelection == null) {
      _selectionRects = const [];
      return;
    }

    _selectionRects = getSelectionRects(page, pageSelection);
  }

  void _onLongPressStart(LongPressStartDetails details) {
    final page = _store.currentPageLayout;
    if (page == null) return;

    final contentOffset = _toContentOffset(details.globalPosition);
    final hit = hitTestPage(page, contentOffset);
    if (hit == null) return;

    final wordSel = expandToWord(page, hit);
    if (wordSel == null) return;

    _isLongPressing = true;

    final startPos = BookPosition.fromPagePosition(
      wordSel.start,
      chapterIndex: page.chapterIndex,
      pageIndexInChapter: page.pageIndexInChapter,
    );
    final endPos = BookPosition.fromPagePosition(
      wordSel.end,
      chapterIndex: page.chapterIndex,
      pageIndexInChapter: page.pageIndexInChapter,
    );

    setState(() {
      _crossSelection = CrossPageSelection(start: startPos, end: endPos);
      _selectionAnchor = startPos;
      _selectionMoving = endPos;
      _updateSelectionRects();
    });

    HapticFeedback.selectionClick();
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_isLongPressing) return;
    final page = _store.currentPageLayout;
    if (page == null || _crossSelection == null) return;

    final contentOffset = _toContentOffset(details.globalPosition);
    final hit = hitTestPage(page, contentOffset);
    if (hit == null) return;

    final movingPos = BookPosition.fromPagePosition(
      hit,
      chapterIndex: page.chapterIndex,
      pageIndexInChapter: page.pageIndexInChapter,
    );

    setState(() {
      _selectionMoving = movingPos;
      _crossSelection =
          CrossPageSelection.normalized(_selectionAnchor!, movingPos);
      _updateSelectionRects();
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    setState(() {
      _isLongPressing = false;
    });
    // Selection and handles remain visible.
  }

  void _onHandleDrag(DragUpdateDetails details, {required bool isStart}) {
    final page = _store.currentPageLayout;
    if (page == null || _crossSelection == null) return;

    // Determine which end is anchor vs moving based on handle identity.
    // When dragging the start handle, the end is the anchor, and vice versa.
    if (_selectionAnchor == null || _selectionMoving == null) return;

    // Update anchor/moving based on which handle is being dragged.
    final BookPosition anchor;
    if (isStart) {
      anchor = _crossSelection!.end;
    } else {
      anchor = _crossSelection!.start;
    }
    _selectionAnchor = anchor;

    final screenWidth = MediaQuery.of(context).size.width;
    final globalX = details.globalPosition.dx;

    // --- Edge detection for cross-page selection ---
    final inLeftEdge = globalX < _edgeZoneWidth;
    final inRightEdge = globalX > screenWidth - _edgeZoneWidth;

    if (inLeftEdge && !_store.isFirstPageOfBook) {
      _startEdgeDwell(direction: -1);
      return;
    } else if (inRightEdge && !_store.isLastPageOfBook) {
      _startEdgeDwell(direction: 1);
      return;
    } else {
      _cancelEdgeDwell();
    }

    // --- Normal hit-test on current page ---
    final contentOffset = _toContentOffset(details.globalPosition);
    final hit = hitTestPage(page, contentOffset);
    if (hit == null) return;

    final movingPos = BookPosition.fromPagePosition(
      hit,
      chapterIndex: page.chapterIndex,
      pageIndexInChapter: page.pageIndexInChapter,
    );

    setState(() {
      _selectionMoving = movingPos;
      _crossSelection =
          CrossPageSelection.normalized(_selectionAnchor!, movingPos);
      _updateSelectionRects();
    });
  }

  void _onHandleDragEnd(DragEndDetails details) {
    _cancelEdgeDwell();
  }

  // ---------------------------------------------------------------------------
  // Edge dwell & selection page turn
  // ---------------------------------------------------------------------------

  void _startEdgeDwell({required int direction}) {
    if (_edgeDwellTimer != null) return;

    _edgeDwellTimer = Timer(_edgeDwellDuration, () {
      _edgeDwellTimer = null;
      _triggerSelectionPageTurn(direction);
    });
  }

  void _cancelEdgeDwell() {
    _edgeDwellTimer?.cancel();
    _edgeDwellTimer = null;
  }

  /// End of the first visual line on [page].
  ///
  /// For K-P layout (one word per element), finds all elements whose rects
  /// overlap vertically with the first text element. For greedy layout (one
  /// element per paragraph), uses the first element's full extent.
  BookPosition _firstLineEnd(PageLayout page) {
    // Find first text element.
    int firstIdx = -1;
    for (var i = 0; i < page.elements.length; i++) {
      if (page.elements[i].textPainter != null) {
        firstIdx = i;
        break;
      }
    }
    if (firstIdx == -1) {
      return BookPosition(
        chapterIndex: page.chapterIndex,
        pageIndexInChapter: page.pageIndexInChapter,
        elementIndex: 0,
        charOffset: 0,
      );
    }

    final firstRect = page.elements[firstIdx].rect;

    // Walk forward to find the last element on the same visual line.
    int lastOnLine = firstIdx;
    for (var i = firstIdx + 1; i < page.elements.length; i++) {
      final el = page.elements[i];
      if (el.textPainter == null) continue;
      // Same line: significant vertical overlap.
      final overlapTop = el.rect.top < firstRect.bottom
          ? (el.rect.top > firstRect.top ? el.rect.top : firstRect.top)
          : el.rect.top;
      final overlapBot = el.rect.bottom > firstRect.top
          ? (el.rect.bottom < firstRect.bottom
              ? el.rect.bottom
              : firstRect.bottom)
          : el.rect.bottom;
      if (overlapBot - overlapTop > firstRect.height * 0.5) {
        lastOnLine = i;
      } else {
        break;
      }
    }

    final lastEl = page.elements[lastOnLine];
    final textLen = extractPainterTextLength(lastEl.textPainter!);
    return BookPosition(
      chapterIndex: page.chapterIndex,
      pageIndexInChapter: page.pageIndexInChapter,
      elementIndex: lastOnLine,
      charOffset: textLen,
    );
  }

  /// Start of the last visual line on [page].
  BookPosition _lastLineStart(PageLayout page) {
    // Find last text element.
    int lastIdx = -1;
    for (var i = page.elements.length - 1; i >= 0; i--) {
      if (page.elements[i].textPainter != null) {
        lastIdx = i;
        break;
      }
    }
    if (lastIdx == -1) {
      return BookPosition(
        chapterIndex: page.chapterIndex,
        pageIndexInChapter: page.pageIndexInChapter,
        elementIndex: 0,
        charOffset: 0,
      );
    }

    final lastRect = page.elements[lastIdx].rect;

    // Walk backward to find the first element on the same visual line.
    int firstOnLine = lastIdx;
    for (var i = lastIdx - 1; i >= 0; i--) {
      final el = page.elements[i];
      if (el.textPainter == null) continue;
      final overlapTop = el.rect.top < lastRect.bottom
          ? (el.rect.top > lastRect.top ? el.rect.top : lastRect.top)
          : el.rect.top;
      final overlapBot = el.rect.bottom > lastRect.top
          ? (el.rect.bottom < lastRect.bottom
              ? el.rect.bottom
              : lastRect.bottom)
          : el.rect.bottom;
      if (overlapBot - overlapTop > lastRect.height * 0.5) {
        firstOnLine = i;
      } else {
        break;
      }
    }

    return BookPosition(
      chapterIndex: page.chapterIndex,
      pageIndexInChapter: page.pageIndexInChapter,
      elementIndex: firstOnLine,
      charOffset: 0,
    );
  }

  void _triggerSelectionPageTurn(int direction) {
    if (_isAnimating) return;
    if (_crossSelection == null || _selectionAnchor == null) return;

    final adjacentPage = direction > 0
        ? _store.nextPageLayout
        : _store.previousPageLayout;
    if (adjacentPage == null) return;

    _preserveSelectionOnPageChange = true;

    // Place the moving anchor at the first/last visual line of the adjacent
    // page so the user sees a small highlighted region (not the whole page)
    // and can keep dragging to adjust.
    final BookPosition newMoving;
    if (direction > 0) {
      newMoving = _firstLineEnd(adjacentPage);
    } else {
      newMoving = _lastLineStart(adjacentPage);
    }

    _selectionMoving = newMoving;
    _crossSelection =
        CrossPageSelection.normalized(_selectionAnchor!, newMoving);

    // Animate page turn.
    final screenWidth = MediaQuery.of(context).size.width;
    _isAnimating = true;

    if (direction > 0) {
      _animDirection = -1; // next page: slide left
      final tween = Tween<double>(begin: 0.0, end: -screenWidth);
      _pageAnimController.duration = const Duration(milliseconds: 250);
      _curvedDragAnim = tween.animate(
        CurvedAnimation(parent: _pageAnimController, curve: Curves.easeInOut),
      );
    } else {
      _animDirection = 1; // previous page: slide right
      final tween = Tween<double>(begin: 0.0, end: screenWidth);
      _pageAnimController.duration = const Duration(milliseconds: 250);
      _curvedDragAnim = tween.animate(
        CurvedAnimation(parent: _pageAnimController, curve: Curves.easeInOut),
      );
    }

    _pageAnimController.forward(from: 0.0);

    HapticFeedback.selectionClick();
  }

  // ---------------------------------------------------------------------------
  // Cross-page text extraction
  // ---------------------------------------------------------------------------

  String extractCrossPageText() {
    if (_crossSelection == null) return '';

    final sel = _crossSelection!;
    final buffer = StringBuffer();

    for (var ch = sel.start.chapterIndex; ch <= sel.end.chapterIndex; ch++) {
      final startPage =
          (ch == sel.start.chapterIndex) ? sel.start.pageIndexInChapter : 0;
      final totalPages = _store.pagesInChapter(ch);
      if (totalPages == null) continue;
      final endPage = (ch == sel.end.chapterIndex)
          ? sel.end.pageIndexInChapter
          : totalPages - 1;

      for (var pg = startPage; pg <= endPage; pg++) {
        final pageLayout = _store.getPageLayout(ch, pg);
        if (pageLayout == null) continue;

        final pageSel = sel.projectOntoPage(pageLayout);
        if (pageSel == null) continue;

        buffer.write(extractSelectedText(pageLayout, pageSel));
      }
    }

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Tap handling
  // ---------------------------------------------------------------------------

  void _onTapUp(TapUpDetails details) {
    // If selection is active, tap clears it.
    if (_crossSelection != null) {
      setState(() => _clearSelection());
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final x = details.globalPosition.dx;

    if (x < screenWidth * 0.3) {
      _store.previousPage();
    } else if (x > screenWidth * 0.7) {
      _store.nextPage();
    } else {
      _store.toggleControls();
    }
  }

  // ---------------------------------------------------------------------------
  // Horizontal drag handling
  // ---------------------------------------------------------------------------

  void _onDragStart(DragStartDetails details) {
    // Suppress page swipe during selection.
    if (_crossSelection != null) return;

    if (_isAnimating) {
      _pageAnimController.stop();
      if (_animDirection < 0) {
        _store.nextPage();
      } else if (_animDirection > 0) {
        _store.previousPage();
      }
      _isAnimating = false;
      _animDirection = 0;
      _curvedDragAnim = null;
    }
    _dragOffset = 0.0;
    if (_store.showControls) _store.hideControls();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_crossSelection != null) return;

    setState(() {
      final delta = details.delta.dx;

      if (_store.isFirstPageOfBook && _dragOffset + delta > 0) {
        _dragOffset += delta * 0.3;
      } else if (_store.isLastPageOfBook && _dragOffset + delta < 0) {
        _dragOffset += delta * 0.3;
      } else {
        _dragOffset += delta;
      }
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_crossSelection != null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final velocity = details.primaryVelocity ?? 0.0;

    const distanceThreshold = 0.25;
    const velocityThreshold = 500.0;

    bool goNext = false;
    bool goPrev = false;

    if (_dragOffset < -screenWidth * distanceThreshold ||
        velocity < -velocityThreshold) {
      if (!_store.isLastPageOfBook && _store.nextPageLayout != null) {
        goNext = true;
      }
    } else if (_dragOffset > screenWidth * distanceThreshold ||
        velocity > velocityThreshold) {
      if (!_store.isFirstPageOfBook && _store.previousPageLayout != null) {
        goPrev = true;
      }
    }

    _isAnimating = true;

    final Tween<double> tween;
    if (goNext) {
      _animDirection = -1;
      tween = Tween<double>(begin: _dragOffset, end: -screenWidth);
    } else if (goPrev) {
      _animDirection = 1;
      tween = Tween<double>(begin: _dragOffset, end: screenWidth);
    } else {
      _animDirection = 0;
      tween = Tween<double>(begin: _dragOffset, end: 0.0);
    }

    final remaining = (tween.end! - _dragOffset).abs();
    final durationMs =
        (remaining / screenWidth * 300).clamp(100, 400).toInt();
    _pageAnimController.duration = Duration(milliseconds: durationMs);

    _curvedDragAnim = tween.animate(
      CurvedAnimation(parent: _pageAnimController, curve: Curves.easeOut),
    );
    _pageAnimController.forward(from: 0.0);
  }

  // ---------------------------------------------------------------------------
  // TOC
  // ---------------------------------------------------------------------------

  void _onTocPressed() {
    _store.hideControls();
    ReaderTocSheet.show(
      context: context,
      toc: _store.toc,
      currentChapterIndex: _store.currentChapterIndex,
      preferences: _store.preferences,
      onChapterSelected: (index) => _store.goToChapter(index),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final prefs = _store.preferences;

    final initialLoading = _store.book == null || _store.isLoading;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: prefs.theme == ReaderTheme.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: prefs.theme.backgroundColor,
        body: initialLoading
            ? _buildLoading(prefs)
            : _store.error != null
            ? _buildError(prefs)
            : _buildReader(prefs),
      ),
    );
  }

  Widget _buildLoading(ReaderPreferences prefs) {
    return Center(
      child: CircularProgressIndicator(color: prefs.theme.textColor),
    );
  }

  Widget _buildError(ReaderPreferences prefs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _store.error!,
              style: TextStyle(color: prefs.theme.textColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Go Back',
                style: TextStyle(color: prefs.theme.textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReader(ReaderPreferences prefs) {
    final page = _store.currentPageLayout;
    if (page == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No content to display.',
              style: TextStyle(color: prefs.theme.textColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Chapter: ${_store.currentChapterIndex}, '
              'Total chapters: ${_store.chapterCount}, '
              'Pages: ${_store.totalPagesInChapter}',
              style: TextStyle(
                color: prefs.theme.textColor.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Go Back',
                style: TextStyle(color: prefs.theme.textColor),
              ),
            ),
          ],
        ),
      );
    }

    final mediaPadding = MediaQuery.of(context).padding;
    final screenWidth = MediaQuery.of(context).size.width;
    final chapterTitle = _store.bookData?.chapters.isNotEmpty == true
        ? (_store
                  .bookData!
                  .chapters[_store.currentChapterIndex]
                  .title
                  .isNotEmpty
              ? _store.bookData!.chapters[_store.currentChapterIndex].title
              : 'Chapter ${_store.currentChapterIndex + 1}')
        : widget.book.title;

    // Determine which adjacent page to show during drag/animation.
    final PageLayout? adjacentPage;
    if (_dragOffset < 0) {
      adjacentPage = _store.nextPageLayout;
    } else if (_dragOffset > 0) {
      adjacentPage = _store.previousPageLayout;
    } else {
      adjacentPage = null;
    }

    // Selection handle color.
    const handleColor = Color(0xFF3B82F6);

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // Background fill to prevent flicker between pages.
        ColoredBox(
          color: prefs.theme.backgroundColor,
          child: const SizedBox.expand(),
        ),

        // Adjacent page (always in tree; positioned off-screen when idle).
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(
              _dragOffset == 0
                  ? screenWidth
                  : (_dragOffset < 0
                      ? _dragOffset + screenWidth
                      : _dragOffset - screenWidth),
              0,
            ),
            child: adjacentPage != null
                ? RepaintBoundary(
                    child: CustomPaint(
                      painter: ReaderCanvasPainter(
                        page: adjacentPage,
                        preferences: prefs,
                        safeAreaTop: mediaPadding.top,
                        safeAreaBottom: mediaPadding.bottom,
                      ),
                      size: Size.infinite,
                    ),
                  )
                : const SizedBox.expand(),
          ),
        ),

        // Current page (translates with drag).
        Positioned.fill(
          child: GestureDetector(
            onTapUp: _onTapUp,
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            onLongPressStart: _onLongPressStart,
            onLongPressMoveUpdate: _onLongPressMoveUpdate,
            onLongPressEnd: _onLongPressEnd,
            child: Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: ReaderCanvasPainter(
                    page: page,
                    preferences: prefs,
                    safeAreaTop: mediaPadding.top,
                    safeAreaBottom: mediaPadding.bottom,
                    selectionRects:
                        _selectionRects.isNotEmpty ? _selectionRects : null,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),

        // Selection handles.
        if (_crossSelection != null &&
            _selectionRects.isNotEmpty &&
            !_isLongPressing)
          ..._buildSelectionHandles(handleColor),

        // Page indicator at bottom.
        Positioned(
          left: prefs.pageHorizontalPaddingPx,
          right: prefs.pageHorizontalPaddingPx,
          bottom: mediaPadding.bottom + 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _store.totalBookPages > 0
                    ? '${_store.currentBookPage} / ${_store.totalBookPages}'
                    : '${_store.currentPageIndex + 1} / ${_store.totalPagesInChapter}',
                style: TextStyle(
                  color: prefs.theme.textColor.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
              Text(
                '${(_store.bookPercent * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: prefs.theme.textColor.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),

        // Controls overlay.
        if (_store.showControls)
          ReaderControlsOverlay(
            preferences: prefs,
            chapterTitle: chapterTitle,
            currentPage: _store.currentPageIndex,
            totalPages: _store.totalPagesInChapter,
            bookPercent: _store.bookPercent,
            onClose: () => _store.hideControls(),
            onBack: () => Navigator.of(context).pop(),
            onPreferencesChanged: (newPrefs) {
              _store.updatePreferences(newPrefs);
            },
            onTocPressed: _onTocPressed,
          ),
      ],
    );
  }

  /// Build selection handle widgets.
  ///
  /// Only shows handles whose anchor falls on the current page. For off-page
  /// handles, shows a thin edge indicator instead.
  List<Widget> _buildSelectionHandles(Color color) {
    if (_crossSelection == null || _selectionRects.isEmpty) return const [];

    final page = _store.currentPageLayout;
    if (page == null) return const [];

    final ch = page.chapterIndex;
    final pg = page.pageIndexInChapter;

    final startOnPage = _crossSelection!.start.chapterIndex == ch &&
        _crossSelection!.start.pageIndexInChapter == pg;
    final endOnPage = _crossSelection!.end.chapterIndex == ch &&
        _crossSelection!.end.pageIndexInChapter == pg;

    const hitSize = ReaderSelectionHandle.hitSize;
    final handles = <Widget>[];

    if (startOnPage) {
      final firstRect = _selectionRects.first;
      final startScreen = _toScreenOffset(firstRect.bottomLeft);
      handles.add(Positioned(
        left: startScreen.dx - hitSize / 2,
        top: startScreen.dy - hitSize / 2,
        child: ReaderSelectionHandle(
          color: color,
          isStart: true,
          onDragUpdate: (d) => _onHandleDrag(d, isStart: true),
          onDragEnd: _onHandleDragEnd,
        ),
      ));
    } else {
      // Selection continues from a previous page — left edge indicator.
      handles.add(_buildEdgeIndicator(isLeft: true, color: color));
    }

    if (endOnPage) {
      final lastRect = _selectionRects.last;
      final endScreen = _toScreenOffset(lastRect.bottomRight);
      handles.add(Positioned(
        left: endScreen.dx - hitSize / 2,
        top: endScreen.dy - hitSize / 2,
        child: ReaderSelectionHandle(
          color: color,
          isStart: false,
          onDragUpdate: (d) => _onHandleDrag(d, isStart: false),
          onDragEnd: _onHandleDragEnd,
        ),
      ));
    } else {
      // Selection continues to a later page — right edge indicator.
      handles.add(_buildEdgeIndicator(isLeft: false, color: color));
    }

    return handles;
  }

  /// A thin vertical bar at the left/right edge indicating selection continues
  /// beyond the visible page.
  Widget _buildEdgeIndicator({required bool isLeft, required Color color}) {
    final mq = MediaQuery.of(context);
    return Positioned(
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      top: mq.padding.top,
      bottom: mq.padding.bottom,
      child: Container(
        width: 3,
        color: color.withValues(alpha: 0.5),
      ),
    );
  }
}
