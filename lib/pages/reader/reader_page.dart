import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/providers/app-providers.dart';
import '../../app/routes/route-names.dart';
import '../../entities/book-entity.dart';
import '../../services/db/app-database.dart';
import '../../services/reader/data/chapter_data_source.dart';
import '../../services/reader/models/page_layout.dart';
import '../../services/reader/models/reader_preferences.dart';
import '../../services/reader/reading_time_tracker.dart';
import '../../services/reader/selection/cross_page_selection.dart';
import '../../services/reader/selection/page_hit_test.dart';
import '../../shared/layout/responsive_layout.dart';
import '../../stores/reader/reader_store.dart';
import '../../stores/reader/reader_store_manager.dart';
import 'reader_coordinate_helper.dart';
import 'widgets/reader_canvas_painter.dart';
import 'widgets/reader_controls_overlay.dart';
import 'widgets/reader_explain_sheet.dart';
import 'widgets/reader_phonetics_sheet.dart';
import 'widgets/reader_selection_handle.dart';

/// Main reader page with multi-chapter navigation.
///
/// Uses [ReaderStore] to manage pagination, chapter loading, and progress.
class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.book,
    required this.dataSource,
    required this.storeManager,
  });

  final BookEntity book;
  final ChapterDataSource dataSource;
  final ReaderStoreManager storeManager;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final ReaderStore _store;
  late final AppDatabase _database;
  late final ReadingTimeTracker _readingTimeTracker;
  bool _didInitDependencies = false;

  // -- Page swipe animation state --
  late final AnimationController _pageAnimController;
  double _dragOffset = 0.0;
  bool _isAnimating = false;
  int _animDirection = 0; // -1 = next, 1 = prev, 0 = snap back
  Animation<double>? _curvedDragAnim;

  // Snapshot of adjacent pages captured at drag start. Using snapshots
  // prevents visual "pop-in" or flickering during the swipe animation
  // (e.g. if a background prefetch completes mid-gesture and changes what
  // nextPageLayout/nextSpreadLeftPage would return).
  PageLayout? _adjNextLeft;
  PageLayout? _adjNextRight;
  PageLayout? _adjPrevLeft;
  PageLayout? _adjPrevRight;
  PageLayout? _snapCurrentLeft;
  PageLayout? _snapCurrentRight;
  bool _isSwapWarmupFrame = false;

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

  // Track which page the selection is on in dual-page mode.
  bool _selectionOnRightPage = false;

  // Flag: the running animation is a selection-triggered page turn
  // (always steps by 1, ignoring dual-page spread step).
  bool _isSelectionPageTurn = false;

  // Coordinate helper: abstracts single/dual page coordinate transforms.
  ReaderCoordinateHelper? _coordHelper;

  // Cached page identity to detect page changes.
  int _lastChapterIndex = -1;
  int _lastPageIndex = -1;

  @override
  void initState() {
    super.initState();
    _store = widget.storeManager.getStore(widget.book.id);
    _store.addListener(_onStoreChanged);
    WidgetsBinding.instance.addObserver(this);

    _pageAnimController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 300),
          )
          ..addListener(_onAnimTick)
          ..addStatusListener(_onAnimStatus);

    WidgetsBinding.instance.addPostFrameCallback((_) => _initReader());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitDependencies) {
      return;
    }

    _database = AppProvidersScope.of(context).database;
    _readingTimeTracker = ReadingTimeTracker(onFlush: _flushReadingTime);
    _didInitDependencies = true;
  }

  Future<void> _initReader() async {
    if (!mounted) return;

    final mq = MediaQuery.of(context);
    _readingTimeTracker.onAppForeground();
    _readingTimeTracker.onInteraction();

    final isDual = mq.size.width >= kTabletBreakpoint;
    final viewportSize = isDual
        ? Size(mq.size.width / 2, mq.size.height)
        : mq.size;

    await _store.openBook(
      book: widget.book,
      dataSource: widget.dataSource,
      viewportSize: viewportSize,
      safeAreaTop: mq.padding.top,
      safeAreaBottom: mq.padding.bottom,
      devicePixelRatio: mq.devicePixelRatio,
      isDualPage: isDual,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_didInitDependencies) {
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        _readingTimeTracker.onAppForeground();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_readingTimeTracker.onAppBackground());
        unawaited(_store.flushProgress());
        break;
    }
  }

  Future<void> _flushReadingTime(int deltaSeconds) async {
    if (deltaSeconds <= 0) {
      return;
    }

    await _database.addReadingTime(
      bookId: widget.book.id,
      dateKey: _dateKeyForNow(),
      deltaSeconds: deltaSeconds,
    );
  }

  String _dateKeyForNow() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  void _recordInteraction() {
    if (!_didInitDependencies) {
      return;
    }
    _readingTimeTracker.onInteraction();
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
    _pageAnimController.dispose();
    _store.removeListener(_onStoreChanged);
    WidgetsBinding.instance.removeObserver(this);
    if (_didInitDependencies) {
      unawaited(_readingTimeTracker.dispose());
    }
    // Do NOT dispose the store — the ReaderStoreManager owns its lifecycle
    // so it can be reused when re-opening the same book.
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
    final isSelectionTurn = _isSelectionPageTurn;

    // Snap-back (no page turn): reset immediately.
    if (direction == 0) {
      _isAnimating = false;
      _dragOffset = 0.0;
      _animDirection = 0;
      _curvedDragAnim = null;
      _isSwapWarmupFrame = false;
      _isSelectionPageTurn = false;
      _adjNextLeft = null;
      _adjNextRight = null;
      _adjPrevLeft = null;
      _adjPrevRight = null;
      _snapCurrentLeft = null;
      _snapCurrentRight = null;
      setState(() {});
      return;
    }

    // --- Two-frame page swap ---
    //
    // Changing the page content AND resetting _dragOffset to 0 in the same
    // frame causes the RepaintBoundary compositing layer to simultaneously
    // discard its old content, paint new content, and move on-screen. On some
    // devices this produces a one-frame flash or "merge" artifact (especially
    // between image-only and text-only pages).
    //
    // Instead we split the transition across two frames:
    //
    // Frame 1 (this tick): advance the page in the store but keep _dragOffset
    //   at the animation-end value. The adjacent-page snapshot stays visible
    //   at its final on-screen position; the current-page slot shows the NEW
    //   page off-screen (painting it into the RepaintBoundary cache).
    //
    // Frame 2 (postFrameCallback): reset _dragOffset to 0 and clear snapshots.
    //   The RepaintBoundary already holds the new page's painting, so only the
    //   transform offset changes — no repaint, no compositing artifact.

    final screenWidth = MediaQuery.of(context).size.width;
    _dragOffset = direction < 0 ? -screenWidth : screenWidth;
    _animDirection = 0;
    _curvedDragAnim = null;
    _isSwapWarmupFrame = true;
    _isSelectionPageTurn = false;
    // Keep _isAnimating = true to block taps/gestures during the one-frame gap.
    // Keep _dragOffset at its animation-end value.
    // Keep adjacent-page snapshots alive.

    if (direction < 0) {
      isSelectionTurn ? _store.nextSinglePage() : _store.nextPage();
    } else if (direction > 0) {
      isSelectionTurn ? _store.previousSinglePage() : _store.previousPage();
    }

    // Complete the transition on the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // If a new gesture started during the gap (e.g. _onDragStart cleared
      // _isAnimating and reset _dragOffset), skip — the transition was
      // already completed early.
      if (!_isAnimating) return;
      _isAnimating = false;
      _dragOffset = 0.0;
      _isSwapWarmupFrame = false;
      _adjNextLeft = null;
      _adjNextRight = null;
      _adjPrevLeft = null;
      _adjPrevRight = null;
      _snapCurrentLeft = null;
      _snapCurrentRight = null;
      setState(() {});
    });
  }

  // ---------------------------------------------------------------------------
  // Coordinate transform (delegated to ReaderCoordinateHelper)
  // ---------------------------------------------------------------------------

  /// Get the PageLayout that a touch position falls on.
  /// Returns (page, isRightPage).
  (PageLayout?, bool) _hitPageForTouch(Offset global) =>
      _coordHelper!.hitPageForTouch(
        global,
        _store.currentPageLayout,
        _store.secondPageLayout,
      );

  /// Convert a global position to content-area coordinates.
  Offset _toContentOffset(Offset global, {bool isRightPage = false}) =>
      _coordHelper!.toContentOffset(global, isRightPage: isRightPage);

  /// Convert content-area coordinates to screen coordinates.
  Offset _toScreenOffset(Offset content, {bool isRightPage = false}) =>
      _coordHelper!.toScreenOffset(content, isRightPage: isRightPage);

  // ---------------------------------------------------------------------------
  // Text selection
  // ---------------------------------------------------------------------------

  void _clearSelection() {
    _crossSelection = null;
    _selectionRects = const [];
    _isLongPressing = false;
    _selectionAnchor = null;
    _selectionMoving = null;
    _preserveSelectionOnPageChange = false;
    _selectionOnRightPage = false;
  }

  void _updateSelectionRects() {
    if (_crossSelection == null) {
      _selectionRects = const [];
      return;
    }

    // In dual-page mode, try the page the selection is on.
    final PageLayout? page;
    if (_selectionOnRightPage && _store.isDualPage) {
      page = _store.secondPageLayout;
    } else {
      page = _store.currentPageLayout;
    }

    if (page == null) {
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
    final (page, isRight) = _hitPageForTouch(details.globalPosition);
    if (page == null) return;

    final contentOffset = _toContentOffset(
      details.globalPosition,
      isRightPage: isRight,
    );
    final hit = hitTestPage(page, contentOffset);
    if (hit == null) return;

    final wordSel = expandToWord(page, hit);
    if (wordSel == null) return;

    _isLongPressing = true;
    _selectionOnRightPage = isRight;

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
    if (_crossSelection == null) return;

    final (page, isRight) = _hitPageForTouch(details.globalPosition);
    if (page == null) return;

    // Update which page the selection is on if user drags to the other page.
    _selectionOnRightPage = isRight;

    final contentOffset = _toContentOffset(
      details.globalPosition,
      isRightPage: isRight,
    );
    final hit = hitTestPage(page, contentOffset);
    if (hit == null) return;

    // Snap to word boundary for word-granularity selection.
    // Build a temporary BookPosition to determine direction in book order.
    final movingBook = BookPosition.fromPagePosition(
      hit,
      chapterIndex: page.chapterIndex,
      pageIndexInChapter: page.pageIndexInChapter,
    );
    final isForward = movingBook.compareTo(_selectionAnchor!) >= 0;
    final snapped = snapToWordBoundary(page, hit, isForward: isForward);

    final movingPos = BookPosition.fromPagePosition(
      snapped,
      chapterIndex: page.chapterIndex,
      pageIndexInChapter: page.pageIndexInChapter,
    );

    setState(() {
      _selectionMoving = movingPos;
      _crossSelection = CrossPageSelection.normalized(
        _selectionAnchor!,
        movingPos,
      );
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
    if (_crossSelection == null) return;
    if (_selectionAnchor == null || _selectionMoving == null) return;

    final (page, isRight) = _hitPageForTouch(details.globalPosition);
    if (page == null) return;

    _selectionOnRightPage = isRight;

    // The anchor is the handle NOT being dragged.
    final BookPosition anchor;
    if (isStart) {
      anchor = _crossSelection!.end;
    } else {
      anchor = _crossSelection!.start;
    }
    _selectionAnchor = anchor;

    final contentOffset = _toContentOffset(
      details.globalPosition,
      isRightPage: isRight,
    );
    final hit = hitTestPage(page, contentOffset);
    if (hit == null) return;

    // --- Content boundary detection for cross-page selection ---
    // Turn the page only when the handle reaches the very first/last text
    // position AND the touch is past the content area (dragging beyond text).
    if (_isAtPageEnd(page, hit, contentOffset) && !_store.isLastPageOfBook) {
      _triggerSelectionPageTurn(1);
      return;
    }
    if (_isAtPageStart(page, hit, contentOffset) && !_store.isFirstPageOfBook) {
      _triggerSelectionPageTurn(-1);
      return;
    }

    // --- Normal update ---
    // Snap to word boundary for word-granularity selection.
    final movingBook = BookPosition.fromPagePosition(
      hit,
      chapterIndex: page.chapterIndex,
      pageIndexInChapter: page.pageIndexInChapter,
    );
    final isForward = movingBook.compareTo(_selectionAnchor!) >= 0;
    final snapped = snapToWordBoundary(page, hit, isForward: isForward);

    final movingPos = BookPosition.fromPagePosition(
      snapped,
      chapterIndex: page.chapterIndex,
      pageIndexInChapter: page.pageIndexInChapter,
    );

    setState(() {
      _selectionMoving = movingPos;
      _crossSelection = CrossPageSelection.normalized(
        _selectionAnchor!,
        movingPos,
      );
      _updateSelectionRects();
    });
  }

  void _onHandleDragEnd(DragEndDetails details) {
    // Nothing to cancel — no timers used.
  }

  /// Whether [hit] is at the last text position on [page] and the touch is
  /// past the content (below or to the right of the last element).
  bool _isAtPageEnd(PageLayout page, PagePosition hit, Offset contentOffset) {
    // Find last text element.
    int lastTextIdx = -1;
    for (var i = page.elements.length - 1; i >= 0; i--) {
      if (page.elements[i].hasText) {
        lastTextIdx = i;
        break;
      }
    }
    if (lastTextIdx == -1) return false;
    if (hit.elementIndex != lastTextIdx) return false;

    final lastEl = page.elements[lastTextIdx];
    final lastPainter = lastEl.ensurePainter();
    if (lastPainter == null) return false;
    final textLen = extractPainterTextLength(lastPainter);
    if (hit.charOffset < textLen) return false;

    // Touch must be past the last element's bottom edge.
    return contentOffset.dy > lastEl.rect.bottom;
  }

  /// Whether [hit] is at the first text position on [page] and the touch is
  /// before the content (above or to the left of the first element).
  bool _isAtPageStart(PageLayout page, PagePosition hit, Offset contentOffset) {
    // Find first text element.
    int firstTextIdx = -1;
    for (var i = 0; i < page.elements.length; i++) {
      if (page.elements[i].hasText) {
        firstTextIdx = i;
        break;
      }
    }
    if (firstTextIdx == -1) return false;
    if (hit.elementIndex != firstTextIdx) return false;
    if (hit.charOffset > 0) return false;

    // Touch must be above the first element's top edge.
    return contentOffset.dy < page.elements[firstTextIdx].rect.top;
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
      if (page.elements[i].hasText) {
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
      if (!el.hasText) continue;
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
    final lastPainter = lastEl.ensurePainter();
    if (lastPainter == null) {
      return BookPosition(
        chapterIndex: page.chapterIndex,
        pageIndexInChapter: page.pageIndexInChapter,
        elementIndex: lastOnLine,
        charOffset: 0,
      );
    }
    final textLen = extractPainterTextLength(lastPainter);
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
      if (page.elements[i].hasText) {
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
      if (!el.hasText) continue;
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
    _crossSelection = CrossPageSelection.normalized(
      _selectionAnchor!,
      newMoving,
    );

    // Animate page turn (always single-step for selection).
    // Snapshot adjacent pages so the preview stays stable during animation.
    _snapshotAdjacentPages();

    final screenWidth = MediaQuery.of(context).size.width;
    _isAnimating = true;
    _isSelectionPageTurn = true;

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
      final startPage = (ch == sel.start.chapterIndex)
          ? sel.start.pageIndexInChapter
          : 0;
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

    // Ignore taps while a page-turn animation is in progress to prevent
    // double-advancing (tap fires nextPage() + animation completion fires it
    // again).
    if (_isAnimating) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final x = details.globalPosition.dx;

    if (x < screenWidth * 0.3) {
      _startTapPageTurn(isNext: false);
    } else if (x > screenWidth * 0.7) {
      _startTapPageTurn(isNext: true);
    } else {
      _store.toggleControls();
    }
  }

  void _startTapPageTurn({required bool isNext}) {
    if (_isAnimating) return;
    if (isNext && _store.isLastPageOfBook) return;
    if (!isNext && _store.isFirstPageOfBook) return;

    // Reuse the swipe animation path to avoid one-frame flicker between
    // radically different page types (e.g. image-only ↔ text-only).
    _snapshotAdjacentPages();

    final screenWidth = MediaQuery.of(context).size.width;
    _dragOffset = 0.0;
    _isAnimating = true;
    _isSelectionPageTurn = false;
    _animDirection = isNext ? -1 : 1;
    _pageAnimController.duration = const Duration(milliseconds: 180);

    final tween = Tween<double>(
      begin: 0.0,
      end: isNext ? -screenWidth : screenWidth,
    );
    _curvedDragAnim = tween.animate(
      CurvedAnimation(parent: _pageAnimController, curve: Curves.easeInOut),
    );
    _pageAnimController.forward(from: 0.0);
  }

  // ---------------------------------------------------------------------------
  // Horizontal drag handling
  // ---------------------------------------------------------------------------

  void _onDragStart(DragStartDetails details) {
    // Suppress page swipe during selection.
    if (_crossSelection != null) return;

    if (_isAnimating) {
      _pageAnimController.stop();
      final isSelectionTurn = _isSelectionPageTurn;
      _isSelectionPageTurn = false;
      _isSwapWarmupFrame = false;
      if (_animDirection < 0) {
        isSelectionTurn ? _store.nextSinglePage() : _store.nextPage();
      } else if (_animDirection > 0) {
        isSelectionTurn ? _store.previousSinglePage() : _store.previousPage();
      }
      _isAnimating = false;
      _animDirection = 0;
      _curvedDragAnim = null;
    }
    _dragOffset = 0.0;

    // Snapshot adjacent pages so the preview stays stable throughout the
    // entire drag + animation cycle (prevents flicker from background
    // prefetch completing mid-gesture).
    _snapshotAdjacentPages();

    if (_store.showControls) _store.hideControls();
  }

  /// Capture a snapshot of adjacent page layouts for use during the swipe
  /// gesture. The same snapshots are used for the entire drag + animation
  /// to prevent visual content changes mid-transition.
  void _snapshotAdjacentPages() {
    _snapCurrentLeft = _store.currentPageLayout;
    _snapCurrentRight = _store.secondPageLayout;
    if (_store.isDualPage) {
      _adjNextLeft = _store.nextSpreadLeftPage;
      _adjNextRight = _store.nextSpreadRightPage;
      _adjPrevLeft = _store.prevSpreadLeftPage;
      _adjPrevRight = _store.prevSpreadRightPage;
    } else {
      _adjNextLeft = _store.nextPageLayout;
      _adjNextRight = null;
      _adjPrevLeft = _store.previousPageLayout;
      _adjPrevRight = null;
    }
    // Eagerly create TextPainters for adjacent pages so they are ready before
    // the first paint call. This prevents any lazy-creation delay during
    // animation or page-swap frames.
    _warmUpPainters(_adjNextLeft);
    _warmUpPainters(_adjNextRight);
    _warmUpPainters(_adjPrevLeft);
    _warmUpPainters(_adjPrevRight);
    _warmUpPainters(_snapCurrentLeft);
    _warmUpPainters(_snapCurrentRight);
  }

  /// Pre-create all deferred TextPainters for [page] so paint() doesn't
  /// need to create them lazily.
  void _warmUpPainters(PageLayout? page) {
    if (page == null) return;
    for (final element in page.elements) {
      element.ensurePainter();
    }
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
      if (!_store.isLastPageOfBook) {
        goNext = true;
      }
    } else if (_dragOffset > screenWidth * distanceThreshold ||
        velocity > velocityThreshold) {
      if (!_store.isFirstPageOfBook) {
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
    final durationMs = (remaining / screenWidth * 300).clamp(100, 400).toInt();
    _pageAnimController.duration = Duration(milliseconds: durationMs);

    _curvedDragAnim = tween.animate(
      CurvedAnimation(parent: _pageAnimController, curve: Curves.easeOut),
    );
    _pageAnimController.forward(from: 0.0);
  }

  void _onMorePressed() {
    _store.hideControls();
    Navigator.of(
      context,
    ).pushNamed(RouteNames.bookDetail, arguments: widget.book.id);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  String get _chapterTitle => _store.currentChapterTitle;

  @override
  Widget build(BuildContext context) {
    final prefs = _store.preferences;
    final mq = MediaQuery.of(context);

    // Update coordinate helper with latest screen dimensions and preferences.
    _coordHelper = _store.isDualPage
        ? DualPageCoordinateHelper(
            screenWidth: mq.size.width,
            horizontalPadding: prefs.pageHorizontalPaddingPx,
            verticalPadding: prefs.pageVerticalPaddingPx,
            safeAreaTop: mq.padding.top,
          )
        : SinglePageCoordinateHelper(
            horizontalPadding: prefs.pageHorizontalPaddingPx,
            verticalPadding: prefs.pageVerticalPaddingPx,
            safeAreaTop: mq.padding.top,
          );

    final hasActiveSwipeTransition = _isAnimating || _dragOffset != 0.0;
    final initialLoading =
        _store.book == null || (_store.isLoading && !hasActiveSwipeTransition);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: prefs.theme.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: prefs.theme.backgroundColor,
        body: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _recordInteraction(),
          onPointerMove: (_) => _recordInteraction(),
          onPointerSignal: (_) => _recordInteraction(),
          child: Stack(
            children: [
              if (initialLoading)
                _buildLoading(prefs)
              else if (_store.error != null)
                _buildError(prefs)
              else
                _buildReader(prefs),
              // Controls overlay — rendered above loading/content so it stays
              // visible during chapter transitions triggered from the panel.
              if (_store.showControls && _store.book != null)
                ReaderControlsOverlay(
                  preferences: prefs,
                  chapterTitle: _chapterTitle,
                  currentPage: _store.currentPageIndex,
                  totalPages: _store.totalPagesInChapter,
                  bookPercent: _store.bookPositionPercent,
                  onClose: () => _store.hideControls(),
                  onBack: () => Navigator.of(context).pop(),
                  onPreferencesChanged: (newPrefs) {
                    _store.updatePreferences(newPrefs);
                  },
                  toc: _store.toc,
                  chapters: _store.bookData?.chapters ?? const [],
                  currentChapterIndex: _store.currentChapterIndex,
                  chapterTitleForPercent: _store.chapterTitleAtPositionPercent,
                  onChapterSelected: (index) => _store.goToChapter(index),
                  onPercentChanged: (percent) =>
                      _store.goToBookPercent(percent),
                  onMorePressed: _onMorePressed,
                ),
            ],
          ),
        ),
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

    if (_store.isDualPage) {
      return _buildDualPageReader(prefs, page);
    }
    return _buildSinglePageReader(prefs, page);
  }

  Widget _buildSinglePageReader(ReaderPreferences prefs, PageLayout page) {
    final mediaPadding = MediaQuery.of(context).padding;
    final screenWidth = MediaQuery.of(context).size.width;

    // Use snapshotted adjacent pages to prevent mid-swipe content changes.
    PageLayout? adjacentPage;
    if (_dragOffset < 0) {
      adjacentPage = _adjNextLeft;
    } else if (_dragOffset > 0) {
      adjacentPage = _adjPrevLeft;
    } else {
      adjacentPage = null;
    }
    if (adjacentPage == null && _dragOffset != 0.0) {
      adjacentPage = _snapCurrentLeft ?? page;
    }
    final displayPage = _dragOffset == 0.0
        ? page
        : (_isSwapWarmupFrame ? page : (_snapCurrentLeft ?? page));

    const handleColor = Color(0xFF3B82F6);

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        ColoredBox(
          color: prefs.theme.backgroundColor,
          child: const SizedBox.expand(),
        ),

        // Adjacent page.
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

        // Current page.
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
                    page: displayPage,
                    preferences: prefs,
                    safeAreaTop: mediaPadding.top,
                    safeAreaBottom: mediaPadding.bottom,
                    selectionRects: _selectionRects.isNotEmpty
                        ? _selectionRects
                        : null,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),

        // Selection handles + tooltip.
        if (_crossSelection != null &&
            _selectionRects.isNotEmpty &&
            !_isLongPressing) ...[
          ..._buildSelectionHandles(handleColor),
          _buildSelectionTooltip(),
        ],

        // Chapter title at top.
        Positioned(
          left: prefs.pageHorizontalPaddingPx,
          top: mediaPadding.top + 8,
          child: Text(
            _chapterTitle,
            style: TextStyle(
              color: prefs.theme.textColor.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
        ),

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
                '${(_store.bookPositionPercent * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: prefs.theme.textColor.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDualPageReader(ReaderPreferences prefs, PageLayout leftPage) {
    final mediaPadding = MediaQuery.of(context).padding;
    final screenWidth = MediaQuery.of(context).size.width;
    final rightPage = _store.secondPageLayout;
    final displayLeftPage = _dragOffset == 0.0
        ? leftPage
        : (_isSwapWarmupFrame ? leftPage : (_snapCurrentLeft ?? leftPage));
    final displayRightPage = _dragOffset == 0.0
        ? rightPage
        : (_isSwapWarmupFrame ? rightPage : _snapCurrentRight);

    // Use snapshotted adjacent spread to prevent mid-swipe content changes.
    PageLayout? adjLeft;
    PageLayout? adjRight;
    if (_dragOffset < 0) {
      adjLeft = _adjNextLeft;
      adjRight = _adjNextRight;
    } else if (_dragOffset > 0) {
      adjLeft = _adjPrevLeft;
      adjRight = _adjPrevRight;
    }
    if (_dragOffset != 0.0) {
      adjLeft ??= _snapCurrentLeft ?? leftPage;
      adjRight ??= _snapCurrentRight;
    }

    const handleColor = Color(0xFF3B82F6);

    Widget buildPagePaint(PageLayout? pg, {List<Rect>? selRects}) {
      if (pg == null) {
        return ColoredBox(color: prefs.theme.backgroundColor);
      }
      return RepaintBoundary(
        child: CustomPaint(
          painter: ReaderCanvasPainter(
            page: pg,
            preferences: prefs,
            safeAreaTop: mediaPadding.top,
            safeAreaBottom: mediaPadding.bottom,
            selectionRects: selRects,
          ),
          size: Size.infinite,
        ),
      );
    }

    // Compute selection rects per page for dual mode.
    List<Rect>? leftSelRects;
    List<Rect>? rightSelRects;
    if (_crossSelection != null && _selectionRects.isNotEmpty) {
      if (!_selectionOnRightPage) {
        leftSelRects = _selectionRects;
      } else {
        rightSelRects = _selectionRects;
      }
    }

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // Background.
        ColoredBox(
          color: prefs.theme.backgroundColor,
          child: const SizedBox.expand(),
        ),

        // Adjacent spread (off-screen when idle).
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
            child: (adjLeft != null || adjRight != null)
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: buildPagePaint(adjLeft)),
                      Expanded(child: buildPagePaint(adjRight)),
                    ],
                  )
                : const SizedBox.expand(),
          ),
        ),

        // Current spread (two pages side by side).
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: buildPagePaint(
                      displayLeftPage,
                      selRects: leftSelRects,
                    ),
                  ),
                  Expanded(
                    child: buildPagePaint(
                      displayRightPage,
                      selRects: rightSelRects,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Selection handles + tooltip.
        if (_crossSelection != null &&
            _selectionRects.isNotEmpty &&
            !_isLongPressing) ...[
          ..._buildSelectionHandles(handleColor),
          _buildSelectionTooltip(),
        ],

        // Chapter title at top (left page).
        Positioned(
          left: prefs.pageHorizontalPaddingPx,
          top: mediaPadding.top + 8,
          child: Text(
            _chapterTitle,
            style: TextStyle(
              color: prefs.theme.textColor.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
        ),

        // Left page indicator (bottom-left).
        Positioned(
          left: prefs.pageHorizontalPaddingPx,
          bottom: mediaPadding.bottom + 8,
          child: Text(
            _store.totalBookPages > 0
                ? '${_store.currentBookPage} / ${_store.totalBookPages}'
                : '${_store.currentPageIndex + 1} / ${_store.totalPagesInChapter}',
            style: TextStyle(
              color: prefs.theme.textColor.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
        ),

        // Right page indicator (bottom-right).
        if (rightPage != null)
          Positioned(
            right: prefs.pageHorizontalPaddingPx,
            bottom: mediaPadding.bottom + 8,
            child: Text(
              _store.totalBookPages > 0
                  ? '${_store.secondBookPage} / ${_store.totalBookPages}'
                  : '${_store.currentPageIndex + 2} / ${_store.totalPagesInChapter}',
              style: TextStyle(
                color: prefs.theme.textColor.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
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

    // Determine which page the selection is on.
    final PageLayout? selPage;
    if (_selectionOnRightPage && _store.isDualPage) {
      selPage = _store.secondPageLayout;
    } else {
      selPage = _store.currentPageLayout;
    }
    if (selPage == null) return const [];

    final ch = selPage.chapterIndex;
    final pg = selPage.pageIndexInChapter;

    final startOnPage =
        _crossSelection!.start.chapterIndex == ch &&
        _crossSelection!.start.pageIndexInChapter == pg;
    final endOnPage =
        _crossSelection!.end.chapterIndex == ch &&
        _crossSelection!.end.pageIndexInChapter == pg;

    const hitSize = ReaderSelectionHandle.hitSize;
    final handles = <Widget>[];
    final isRight = _selectionOnRightPage;

    if (startOnPage) {
      final firstRect = _selectionRects.first;
      final startScreen = _toScreenOffset(
        firstRect.bottomLeft,
        isRightPage: isRight,
      );
      handles.add(
        Positioned(
          left: startScreen.dx - hitSize / 2,
          top: startScreen.dy - hitSize / 2,
          child: ReaderSelectionHandle(
            color: color,
            isStart: true,
            onDragUpdate: (d) => _onHandleDrag(d, isStart: true),
            onDragEnd: _onHandleDragEnd,
          ),
        ),
      );
    } else {
      handles.add(_buildEdgeIndicator(isLeft: true, color: color));
    }

    if (endOnPage) {
      final lastRect = _selectionRects.last;
      final endScreen = _toScreenOffset(
        lastRect.bottomRight,
        isRightPage: isRight,
      );
      handles.add(
        Positioned(
          left: endScreen.dx - hitSize / 2,
          top: endScreen.dy - hitSize / 2,
          child: ReaderSelectionHandle(
            color: color,
            isStart: false,
            onDragUpdate: (d) => _onHandleDrag(d, isStart: false),
            onDragEnd: _onHandleDragEnd,
          ),
        ),
      );
    } else {
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
      child: Container(width: 3, color: color.withValues(alpha: 0.5)),
    );
  }

  /// Floating tooltip above the selection with placeholder action buttons.
  Widget _buildSelectionTooltip() {
    if (_selectionRects.isEmpty) return const SizedBox.shrink();

    final firstRect = _selectionRects.first;
    final lastRect = _selectionRects.last;
    final screenWidth = MediaQuery.of(context).size.width;
    final safeTop = MediaQuery.of(context).padding.top;
    final isRight = _selectionOnRightPage;

    // Horizontal center of the selection.
    final selCenterX = (firstRect.left + lastRect.right) / 2;
    final screenCenterX = _toScreenOffset(
      Offset(selCenterX, 0),
      isRightPage: isRight,
    ).dx;

    // Vertical: prefer above the first rect; fall back to below last rect.
    const tooltipHeight = 40.0;
    const gap = 8.0;
    final aboveY =
        _toScreenOffset(firstRect.topLeft, isRightPage: isRight).dy -
        gap -
        tooltipHeight;
    final belowY =
        _toScreenOffset(lastRect.bottomLeft, isRightPage: isRight).dy + gap;
    final tooltipY = aboveY >= safeTop ? aboveY : belowY;

    // Estimate tooltip width to clamp horizontal position.
    const estimatedWidth = 300.0;
    final tooltipLeft = (screenCenterX - estimatedWidth / 2).clamp(
      8.0,
      screenWidth - estimatedWidth - 8.0,
    );

    return Positioned(
      left: tooltipLeft,
      top: tooltipY,
      child: Container(
        height: tooltipHeight,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tooltipButton(
              'Phonetics',
              onPressed: () {
                final selectedText = extractCrossPageText();
                if (selectedText.isEmpty) return;

                final providers = AppProvidersScope.of(context);
                providers.database.incrementPhoneticsCount(widget.book.id);
                ReaderPhoneticsSheet.show(
                  context: context,
                  selectedText: selectedText,
                  phoneticsService: providers.phoneticsService,
                  ttsService: providers.ttsService,
                );
              },
            ),
            Container(width: 1, height: 20, color: Colors.white24),
            _tooltipButton(
              'Explain',
              onPressed: () {
                final selectedText = extractCrossPageText();
                if (selectedText.isEmpty) return;

                final aiSettings = AppProvidersScope.of(
                  context,
                ).aiSettingsService;

                if (!aiSettings.isConfigured) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please configure your AI API key in Settings.',
                      ),
                    ),
                  );
                  return;
                }

                final pageLayout = _store.currentPageLayout;
                final pageContext = pageLayout != null
                    ? extractFullPageText(pageLayout)
                    : '';

                final languageConfig = aiSettings.resolveConfig(
                  widget.book.language,
                );

                final providers = AppProvidersScope.of(context);
                providers.database.incrementExplainCount(widget.book.id);
                ReaderExplainSheet.show(
                  context: context,
                  selectedText: selectedText,
                  pageContext: pageContext,
                  aiSettings: aiSettings,
                  languageConfig: languageConfig,
                  bookTitle: widget.book.title,
                  phoneticsService: providers.phoneticsService,
                  ttsService: providers.ttsService,
                  database: providers.database,
                  bookId: widget.book.id,
                  chapterIndex: _store.currentChapterIndex,
                );
              },
            ),
            Container(width: 1, height: 20, color: Colors.white24),
            _tooltipButton(
              'Read Aloud',
              onPressed: () {
                final selectedText = extractCrossPageText();
                if (selectedText.isEmpty) return;

                final ttsService = AppProvidersScope.of(context).ttsService;

                if (ttsService.isSpeaking) {
                  ttsService.stop();
                } else {
                  final langCode = ttsService.resolveBookLanguage(
                    widget.book.language,
                  );
                  final model = ttsService.modelInfoForLanguage(langCode);
                  if (model == null ||
                      !ttsService.modelManager.isReady(model)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'TTS model not downloaded. Please download it in Settings.',
                        ),
                      ),
                    );
                    return;
                  }
                  ttsService.speakForBookLanguage(
                    selectedText,
                    widget.book.language,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _tooltipButton(String label, {required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
