import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/providers/app-providers.dart';
import '../../app/routes/route-names.dart';
import '../../entities/annotation-entity.dart';
import 'models/reader_annotation_card_item.dart';
import 'models/reader_tooltip_action_spec.dart';
import '../../entities/book-entity.dart';
import '../../services/db/app-database.dart';
import '../../services/reader/annotation/annotation_models.dart';
import '../../services/reader/annotation/annotation_overlap_detector.dart';
import '../../services/reader/annotation/annotation_text_utils.dart';
import '../../services/reader/annotation/reader_annotation_resolver.dart';
import '../../services/reader/annotation/selection_to_annotation_mapper.dart';
import '../../services/reader/data/chapter_data_source.dart';
import '../../services/reader/models/page_layout.dart';
import '../../services/reader/models/reader_preferences.dart';
import '../../services/reader/reading_time_tracker.dart';
import '../../services/reader/selection/cross_page_selection.dart';
import '../../services/reader/selection/page_hit_test.dart';
import '../../shared/constants/reader-constants.dart';
import '../../shared/layout/responsive_layout.dart';
import 'quote_card/models/reader_quote_card_payload.dart';
import 'quote_card/reader_quote_card_page.dart';
import '../../stores/annotation/annotation-store.dart';
import '../../stores/reader/reader_store.dart';
import '../../stores/reader/reader_store_manager.dart';
import 'reader_coordinate_helper.dart';
import 'widgets/reader_canvas_painter.dart';
import 'widgets/reader_annotation_note_composer.dart';
import 'widgets/reader_annotation_sheet.dart';
import 'widgets/reader_controls_overlay.dart';
import 'widgets/reader_explain_sheet.dart';
import 'widgets/reader_mark_style_editor.dart';
import 'widgets/reader_tooltip_actions_bar.dart';
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
  late final AnnotationStore _annotationStore;
  late final ReadingTimeTracker _readingTimeTracker;
  final SelectionToAnnotationMapper _annotationMapper =
      const SelectionToAnnotationMapper();
  final ReaderAnnotationResolver _annotationResolver =
      const ReaderAnnotationResolver();
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
  Map<String, List<AnnotationPaintBucket>> _annotationPaintBucketsByPageKey =
      const <String, List<AnnotationPaintBucket>>{};
  Map<String, List<_AnnotationTapTarget>> _annotationTapTargetsByPageKey =
      const <String, List<_AnnotationTapTarget>>{};
  _PreviewReturnLocation? _previewReturnLocation;
  _FocusedAnnotationOverlay? _focusedAnnotationOverlay;
  _MarkEditorMode _markEditorMode = _MarkEditorMode.hidden;
  String _markEditorColor = ReaderConstants.defaultHighlightColor;
  AnnotationStyle _markEditorStyle = AnnotationStyle.highlight;
  String? _editingAnnotationId;

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
    _annotationStore = AppProvidersScope.of(context).annotationStore;
    _annotationStore.addListener(_onAnnotationStoreChanged);
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
    _syncMarkAppearanceDefaultsFromPreferences();
    await _annotationStore.loadAnnotations(widget.book.id);
    if (!mounted) return;
    setState(() {
      _annotationPaintBucketsByPageKey =
          _buildAnnotationPaintBucketsByPageKey();
    });
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

  void _syncMarkAppearanceDefaultsFromPreferences() {
    final prefs = _store.preferences;
    _markEditorColor = prefs.defaultMarkColor;
    _markEditorStyle = prefs.defaultMarkStyle;
    _annotationStore.setSelectedAppearance(
      color: prefs.defaultMarkColor,
      style: prefs.defaultMarkStyle,
    );
  }

  Future<void> _persistMarkAppearancePreference({
    required String color,
    required AnnotationStyle style,
  }) async {
    _annotationStore.setSelectedAppearance(color: color, style: style);
    await _store.updatePreferences(
      _store.preferences.copyWith(
        defaultMarkColor: color,
        defaultMarkStyle: style,
      ),
    );
  }

  void _hideMarkEditor() {
    _markEditorMode = _MarkEditorMode.hidden;
    _editingAnnotationId = null;
  }

  void _setMarkEditorAppearance({
    required String color,
    required AnnotationStyle style,
  }) {
    _markEditorColor = color;
    _markEditorStyle = style;
  }

  void _openSelectionEditEditor(AnnotationEntity annotation) {
    _markEditorMode = _MarkEditorMode.editSelection;
    _editingAnnotationId = annotation.id;
    _setMarkEditorAppearance(color: annotation.color, style: annotation.style);
  }

  void _openFocusedMarkEditor(AnnotationEntity annotation) {
    _markEditorMode = _MarkEditorMode.editFocused;
    _editingAnnotationId = annotation.id;
    _setMarkEditorAppearance(color: annotation.color, style: annotation.style);
  }

  AnnotationEntity? _activeEditingAnnotation() {
    final annotationId = _editingAnnotationId;
    if (annotationId == null) {
      return null;
    }
    for (final annotation in _annotationStore.state.items) {
      if (annotation.id == annotationId) {
        return annotation;
      }
    }
    return null;
  }

  _SelectionAnnotationDraft? _prepareSelectionAnnotationDraft() {
    final selection = _crossSelection;
    if (selection == null) {
      debugPrint('[Mark] Failed: selection is null');
      return null;
    }

    final selectedText = extractCrossPageText();
    if (selectedText.isEmpty) {
      debugPrint('[Mark] Failed: selectedText is empty');
      return null;
    }

    final anchor = _annotationMapper.map(store: _store, selection: selection);
    if (anchor == null || anchor.segments.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to create mark.')));
      return null;
    }

    final overlapDecision = detectAnnotationOverlap(
      candidate: anchor,
      existingAnnotations: _annotationStore.state.items,
    );
    if (overlapDecision != AnnotationOverlapDecision.none) {
      final message = overlapDecision == AnnotationOverlapDecision.duplicate
          ? 'Already marked.'
          : 'Overlaps an existing mark.';
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return null;
    }

    final focusPage = (_selectionOnRightPage && _store.isDualPage)
        ? _store.secondPageLayout
        : _store.currentPageLayout;
    return _SelectionAnnotationDraft(
      selectedText: selectedText,
      anchor: anchor,
      focusPage: focusPage,
      focusedRects: List<Rect>.from(_selectionRects),
      focusIsRight: _selectionOnRightPage,
    );
  }

  void _applyAnnotationMutationResult({
    AnnotationEntity? focusedAnnotation,
    PageLayout? focusPage,
    List<Rect>? focusedRects,
    bool focusIsRight = false,
  }) {
    _clearSelection();
    _annotationPaintBucketsByPageKey = _buildAnnotationPaintBucketsByPageKey();
    _annotationTapTargetsByPageKey = _buildAnnotationTapTargetsByPageKey();
    if (focusedAnnotation != null &&
        focusPage != null &&
        focusedRects != null &&
        focusedRects.isNotEmpty) {
      _focusedAnnotationOverlay = _FocusedAnnotationOverlay(
        chapterIndex: focusPage.chapterIndex,
        pageIndexInChapter: focusPage.pageIndexInChapter,
        isRightPage: focusIsRight,
        annotations: <AnnotationEntity>[focusedAnnotation],
        rects: List<Rect>.unmodifiable(focusedRects),
      );
      _markEditorMode = _MarkEditorMode.editFocused;
      _editingAnnotationId = focusedAnnotation.id;
      _markEditorColor = focusedAnnotation.color;
      _markEditorStyle = focusedAnnotation.style;
    }
  }

  Future<void> _openNoteComposerForSelection({
    AnnotationEntity? annotation,
  }) async {
    if (_selectionRects.isEmpty && annotation == null) {
      return;
    }
    final quoteText = annotation?.quoteText ?? extractCrossPageText();
    if (quoteText.trim().isEmpty) {
      return;
    }
    final noteText = await ReaderAnnotationNoteComposer.show(
      context: context,
      quoteText: quoteText,
      isTablet: _store.isDualPage,
    );
    if (noteText == null || noteText.trim().isEmpty) {
      return;
    }
    if (annotation != null) {
      await _handleAppendNote(annotation, noteText: noteText);
      return;
    }
    await _handleCreateMarkWithNote(noteText: noteText, focusCreated: true);
  }

  Future<void> _openNoteComposerForAnnotation(
    AnnotationEntity annotation,
  ) async {
    final noteText = await ReaderAnnotationNoteComposer.show(
      context: context,
      quoteText: annotation.quoteText,
      isTablet: _store.isDualPage,
    );
    if (noteText == null || noteText.trim().isEmpty) {
      return;
    }
    await _handleAppendNote(annotation, noteText: noteText);
  }

  Future<void> _handleCreateMarkWithNote({
    required String noteText,
    bool focusCreated = false,
  }) async {
    final draft = _prepareSelectionAnnotationDraft();
    if (draft == null) {
      return;
    }

    try {
      final result = await _annotationStore.createMarkWithNote(
        bookId: widget.book.id,
        quoteText: draft.selectedText,
        anchor: draft.anchor,
        noteText: noteText,
        color: _markEditorColor,
        style: _markEditorStyle,
      );
      await _persistMarkAppearancePreference(
        color: _markEditorColor,
        style: _markEditorStyle,
      );
      if (!mounted) return;
      setState(() {
        _applyAnnotationMutationResult(
          focusedAnnotation: focusCreated ? result.annotation : null,
          focusPage: draft.focusPage,
          focusedRects: draft.focusedRects,
          focusIsRight: draft.focusIsRight,
        );
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save note.')));
    }
  }

  Future<void> _handleAppendNote(
    AnnotationEntity annotation, {
    required String noteText,
  }) async {
    try {
      final result = await _annotationStore.createNote(
        annotationId: annotation.id,
        bookId: widget.book.id,
        text: noteText,
      );
      if (!mounted) return;
      setState(() {
        _annotationPaintBucketsByPageKey =
            _buildAnnotationPaintBucketsByPageKey();
        _annotationTapTargetsByPageKey = _buildAnnotationTapTargetsByPageKey();
        if (_focusedAnnotationOverlay != null &&
            _focusedAnnotationOverlay!.annotations.any(
              (item) => item.id == annotation.id,
            )) {
          _focusedAnnotationOverlay = _FocusedAnnotationOverlay(
            chapterIndex: _focusedAnnotationOverlay!.chapterIndex,
            pageIndexInChapter: _focusedAnnotationOverlay!.pageIndexInChapter,
            isRightPage: _focusedAnnotationOverlay!.isRightPage,
            annotations: <AnnotationEntity>[result.annotation],
            rects: _focusedAnnotationOverlay!.rects,
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save note.')));
    }
  }

  List<ReaderAnnotationCardItem> _buildAnnotationCardItems() {
    return _annotationStore.state.items
        .map((annotation) {
          final notes =
              _annotationStore.state.notesByAnnotationId[annotation.id] ??
              const [];
          final anchor = AnnotationAnchorV1.tryParse(annotation.anchorJson);
          final chapterTitle = anchor == null
              ? 'Unknown chapter'
              : _store.chapterTitleAt(anchor.jumpTarget.chapterIndex);
          final latestNote = notes.isEmpty ? null : notes.last.text;
          return ReaderAnnotationCardItem(
            annotation: annotation,
            notes: notes,
            chapterTitle: chapterTitle,
            latestNoteText: latestNote,
            noteCount: notes.length,
            activityTime: annotation.updatedAt,
          );
        })
        .toList(growable: false);
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
      _clearFocusedAnnotationOverlay();
    }

    _annotationPaintBucketsByPageKey = _buildAnnotationPaintBucketsByPageKey();
    _annotationTapTargetsByPageKey = _buildAnnotationTapTargetsByPageKey();
    setState(() {});
  }

  void _onAnnotationStoreChanged() {
    if (!mounted) return;
    setState(() {
      _annotationPaintBucketsByPageKey =
          _buildAnnotationPaintBucketsByPageKey();
      _annotationTapTargetsByPageKey = _buildAnnotationTapTargetsByPageKey();
      if (_focusedAnnotationOverlay != null) {
        final pageKey = _annotationPageKey(
          _focusedAnnotationOverlay!.chapterIndex,
          _focusedAnnotationOverlay!.pageIndexInChapter,
        );
        final refreshed = _annotationTapTargetsByPageKey[pageKey];
        final replacement = refreshed
            ?.where((target) {
              final focusedIds = _focusedAnnotationOverlay!.annotations
                  .map((item) => item.id)
                  .toSet();
              return target.annotations.any(
                (item) => focusedIds.contains(item.id),
              );
            })
            .toList(growable: false);
        _focusedAnnotationOverlay = replacement == null || replacement.isEmpty
            ? null
            : _FocusedAnnotationOverlay(
                chapterIndex: _focusedAnnotationOverlay!.chapterIndex,
                pageIndexInChapter:
                    _focusedAnnotationOverlay!.pageIndexInChapter,
                isRightPage: _focusedAnnotationOverlay!.isRightPage,
                annotations: replacement.first.annotations,
                rects: replacement.first.rects,
              );
      }
    });
  }

  @override
  void dispose() {
    _pageAnimController.dispose();
    _store.removeListener(_onStoreChanged);
    WidgetsBinding.instance.removeObserver(this);
    if (_didInitDependencies) {
      _annotationStore.removeListener(_onAnnotationStoreChanged);
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
      _goNextPage(isSelectionTurn: isSelectionTurn);
    } else if (direction > 0) {
      _goPreviousPage(isSelectionTurn: isSelectionTurn);
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
    _hideMarkEditor();
  }

  void _clearFocusedAnnotationOverlay() {
    _focusedAnnotationOverlay = null;
    _hideMarkEditor();
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
    _clearFocusedAnnotationOverlay();
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

        final text = extractSelectedText(pageLayout, pageSel);
        if (text.isNotEmpty) {
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(text);
        }
      }
    }

    return buffer.toString();
  }

  Future<void> _openQuoteCard({required String selectedText}) async {
    final trimmedText = selectedText.trim();
    if (trimmedText.isEmpty) {
      return;
    }

    await ReaderQuoteCardPage.show(
      context: context,
      payload: ReaderQuoteCardPayload(
        bookId: widget.book.id,
        bookTitle: widget.book.title,
        bookAuthor: widget.book.author,
        selectedText: trimmedText,
        readerFontFamily: _store.preferences.fontFamily,
        readerThemeName: _store.preferences.theme.name,
        coverDataUrl: widget.book.coverUrl,
        chapterTitle: _store.currentChapterTitle,
        pageLabel: _store.totalBookPages > 0
            ? 'Page ${_store.currentBookPage}'
            : 'Page ${_store.currentPageIndex + 1}',
        collectionLabel: null,
      ),
    );
  }

  void _openPhoneticsSheet(String selectedText) {
    final text = selectedText.trim();
    if (text.isEmpty) return;

    final providers = AppProvidersScope.of(context);
    providers.database.incrementPhoneticsCount(widget.book.id);
    ReaderPhoneticsSheet.show(
      context: context,
      selectedText: text,
      phoneticsService: providers.phoneticsService,
      ttsService: providers.ttsService,
    );
  }

  void _openExplainSheet({
    required String selectedText,
    required bool selectionOnRightPage,
    PageLayout? pageLayout,
    String paragraphContext = '',
  }) {
    final text = selectedText.trim();
    if (text.isEmpty) return;

    final aiSettings = AppProvidersScope.of(context).aiSettingsService;
    if (!aiSettings.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please configure your AI API key in Settings.'),
        ),
      );
      return;
    }

    final languageConfig = aiSettings.resolveConfig(widget.book.language);
    final providers = AppProvidersScope.of(context);
    providers.database.incrementExplainCount(widget.book.id);
    ReaderExplainSheet.show(
      context: context,
      selectedText: text,
      pageContext: pageLayout != null ? extractFullPageText(pageLayout) : '',
      paragraphContext: paragraphContext,
      aiSettings: aiSettings,
      languageConfig: languageConfig,
      bookTitle: widget.book.title,
      phoneticsService: providers.phoneticsService,
      ttsService: providers.ttsService,
      database: providers.database,
      bookId: widget.book.id,
      chapterIndex: _store.currentChapterIndex,
      bookLanguage: widget.book.language,
      isTablet: _store.isDualPage,
      selectionOnRightPage: selectionOnRightPage,
    );
  }

  void _toggleReadAloud(String selectedText) {
    final text = selectedText.trim();
    if (text.isEmpty) return;

    final ttsService = AppProvidersScope.of(context).ttsService;
    if (ttsService.isSpeaking) {
      ttsService.stop();
      return;
    }

    final langCode = ttsService.resolveBookLanguage(widget.book.language);
    final model = ttsService.modelInfoForLanguage(langCode);
    if (model == null || !ttsService.modelManager.isReady(model)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'TTS model not downloaded. Please download it in Settings.',
          ),
        ),
      );
      return;
    }
    ttsService.speakForBookLanguage(text, widget.book.language);
  }

  Map<String, List<AnnotationPaintBucket>>
  _buildAnnotationPaintBucketsByPageKey() {
    final pagination = _store.currentChapterPagination;
    if (pagination == null) {
      return const <String, List<AnnotationPaintBucket>>{};
    }

    final resolved = _annotationResolver.resolveChapterAnnotations(
      pagination: pagination,
      annotations: _annotationStore.state.items,
    );
    final bucketBuildersByPageKey =
        <String, Map<String, _AnnotationPaintBucketBuilder>>{};

    for (final segment in resolved) {
      final page = _store.getPageLayout(
        segment.chapterIndex,
        segment.pageIndexInChapter,
      );
      if (page == null) {
        continue;
      }

      final rects = getSelectionRects(page, segment.pageSelection);
      if (rects.isEmpty) {
        continue;
      }

      final pageKey = _annotationPageKey(
        segment.chapterIndex,
        segment.pageIndexInChapter,
      );
      final pageBuckets = bucketBuildersByPageKey.putIfAbsent(
        pageKey,
        () => <String, _AnnotationPaintBucketBuilder>{},
      );
      final bucketKey = '${segment.style.name}:${segment.color}';
      final bucket = pageBuckets.putIfAbsent(
        bucketKey,
        () => _AnnotationPaintBucketBuilder(
          style: segment.style,
          color: segment.style == AnnotationStyle.underline
              ? annotationColorFromHex(segment.color, alpha: 1)
              : annotationColorFromHex(segment.color),
        ),
      );
      bucket.rects.addAll(rects);
    }

    return bucketBuildersByPageKey.map(
      (pageKey, buckets) => MapEntry(
        pageKey,
        buckets.values
            .map(
              (bucket) => AnnotationPaintBucket(
                style: bucket.style,
                color: bucket.color,
                rects: List<Rect>.unmodifiable(bucket.rects),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  String _annotationPageKey(int chapterIndex, int pageIndexInChapter) {
    return '$chapterIndex:$pageIndexInChapter';
  }

  List<AnnotationPaintBucket>? _annotationPaintBucketsForPage(
    PageLayout? page,
  ) {
    if (page == null) {
      return null;
    }
    return _annotationPaintBucketsByPageKey[_annotationPageKey(
      page.chapterIndex,
      page.pageIndexInChapter,
    )];
  }

  List<_AnnotationTapTarget> _annotationTapTargetsForPage(PageLayout? page) {
    if (page == null) {
      return const <_AnnotationTapTarget>[];
    }
    return _annotationTapTargetsByPageKey[_annotationPageKey(
          page.chapterIndex,
          page.pageIndexInChapter,
        )] ??
        const <_AnnotationTapTarget>[];
  }

  AnnotationAnchorV1? _currentSelectionAnchor() {
    final selection = _crossSelection;
    if (selection == null) {
      return null;
    }
    return _annotationMapper.map(store: _store, selection: selection);
  }

  List<AnnotationEntity> _annotationsForCurrentSelection() {
    final anchor = _currentSelectionAnchor();
    if (anchor == null || anchor.segments.isEmpty) {
      return const <AnnotationEntity>[];
    }
    return findOverlappingAnnotations(
      candidate: anchor,
      existingAnnotations: _annotationStore.state.items,
    );
  }

  List<AnnotationEntity> _exactAnnotationsForCurrentSelection() {
    final anchor = _currentSelectionAnchor();
    if (anchor == null || anchor.segments.isEmpty) {
      return const <AnnotationEntity>[];
    }
    return findExactMatchingAnnotations(
      candidate: anchor,
      existingAnnotations: _annotationStore.state.items,
    );
  }

  Map<String, List<_AnnotationTapTarget>>
  _buildAnnotationTapTargetsByPageKey() {
    final pagination = _store.currentChapterPagination;
    if (pagination == null) {
      return const <String, List<_AnnotationTapTarget>>{};
    }

    final resolved = _annotationResolver.resolveChapterAnnotations(
      pagination: pagination,
      annotations: _annotationStore.state.items,
    );
    final targetsByPageAndAnnotation = <String, _AnnotationTapTargetBuilder>{};
    final annotationById = <String, AnnotationEntity>{
      for (final annotation in _annotationStore.state.items)
        annotation.id: annotation,
    };

    for (final segment in resolved) {
      final page = _store.getPageLayout(
        segment.chapterIndex,
        segment.pageIndexInChapter,
      );
      if (page == null) {
        continue;
      }
      final rects = getSelectionRects(page, segment.pageSelection);
      if (rects.isEmpty) {
        continue;
      }
      final annotation = annotationById[segment.annotationId];
      if (annotation == null) {
        continue;
      }
      final key =
          '${_annotationPageKey(segment.chapterIndex, segment.pageIndexInChapter)}:${segment.annotationId}';
      final builder = targetsByPageAndAnnotation.putIfAbsent(
        key,
        () => _AnnotationTapTargetBuilder(
          chapterIndex: segment.chapterIndex,
          pageIndexInChapter: segment.pageIndexInChapter,
          annotations: <AnnotationEntity>[annotation],
        ),
      );
      builder.rects.addAll(rects);
    }

    final byPageKey = <String, List<_AnnotationTapTarget>>{};
    for (final builder in targetsByPageAndAnnotation.values) {
      final pageKey = _annotationPageKey(
        builder.chapterIndex,
        builder.pageIndexInChapter,
      );
      final targets = byPageKey.putIfAbsent(
        pageKey,
        () => <_AnnotationTapTarget>[],
      );
      targets.add(
        _AnnotationTapTarget(
          chapterIndex: builder.chapterIndex,
          pageIndexInChapter: builder.pageIndexInChapter,
          annotations: builder.annotations,
          rects: List<Rect>.unmodifiable(builder.rects),
        ),
      );
    }
    return byPageKey;
  }

  Future<void> _handleCreateMark({
    String? color,
    AnnotationStyle? style,
    bool focusCreated = false,
  }) async {
    final draft = _prepareSelectionAnnotationDraft();
    if (draft == null) {
      return;
    }

    try {
      final created = await _annotationStore.createMark(
        bookId: widget.book.id,
        quoteText: draft.selectedText,
        anchor: draft.anchor,
        color: color,
        style: style,
      );
      await _persistMarkAppearancePreference(
        color: color ?? _markEditorColor,
        style: style ?? _markEditorStyle,
      );

      if (!mounted) return;
      setState(() {
        _applyAnnotationMutationResult(
          focusedAnnotation: focusCreated ? created : null,
          focusPage: draft.focusPage,
          focusedRects: draft.focusedRects,
          focusIsRight: draft.focusIsRight,
        );
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Marked.')));
    } catch (error, stackTrace) {
      debugPrint('[Mark] Failed to persist mark. error=$error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to create mark.')));
    }
  }

  Future<void> _handleStyleChange(
    AnnotationEntity annotation, {
    String? color,
    AnnotationStyle? style,
    required _MarkEditorMode mode,
  }) async {
    final nextColor = color ?? _markEditorColor;
    final nextStyle = style ?? _markEditorStyle;
    final updated = await _annotationStore.updateAnnotationAppearance(
      annotationId: annotation.id,
      color: nextColor,
      style: nextStyle,
    );
    await _persistMarkAppearancePreference(color: nextColor, style: nextStyle);

    if (!mounted) return;
    setState(() {
      _markEditorColor = nextColor;
      _markEditorStyle = nextStyle;
      _editingAnnotationId = updated.id;
      _markEditorMode = mode;
      _annotationPaintBucketsByPageKey =
          _buildAnnotationPaintBucketsByPageKey();
      _annotationTapTargetsByPageKey = _buildAnnotationTapTargetsByPageKey();
      if (mode == _MarkEditorMode.editFocused &&
          _focusedAnnotationOverlay != null) {
        _focusedAnnotationOverlay = _FocusedAnnotationOverlay(
          chapterIndex: _focusedAnnotationOverlay!.chapterIndex,
          pageIndexInChapter: _focusedAnnotationOverlay!.pageIndexInChapter,
          isRightPage: _focusedAnnotationOverlay!.isRightPage,
          annotations: <AnnotationEntity>[updated],
          rects: _focusedAnnotationOverlay!.rects,
        );
      }
    });
  }

  Future<void> _handleRemoveMarks(List<AnnotationEntity> annotations) async {
    if (annotations.isEmpty) {
      return;
    }

    for (final annotation in annotations) {
      await _annotationStore.deleteAnnotation(annotation.id);
    }

    if (!mounted) return;
    setState(() {
      _clearSelection();
      _clearFocusedAnnotationOverlay();
      _annotationPaintBucketsByPageKey =
          _buildAnnotationPaintBucketsByPageKey();
      _annotationTapTargetsByPageKey = _buildAnnotationTapTargetsByPageKey();
    });
    final message = annotations.length == 1
        ? 'Mark removed.'
        : '${annotations.length} marks removed.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

    final (page, isRight) = _hitPageForTouch(details.globalPosition);
    final contentOffset = page == null
        ? null
        : _toContentOffset(details.globalPosition, isRightPage: isRight);

    if (page != null && contentOffset != null) {
      final tappedAnnotation = _annotationTapTargetsForPage(page)
          .where((target) => target.contains(contentOffset))
          .toList(growable: false);
      if (tappedAnnotation.isNotEmpty) {
        setState(() {
          _clearSelection();
          _focusedAnnotationOverlay = _FocusedAnnotationOverlay(
            chapterIndex: page.chapterIndex,
            pageIndexInChapter: page.pageIndexInChapter,
            isRightPage: isRight,
            annotations: tappedAnnotation.first.annotations,
            rects: tappedAnnotation.first.rects,
          );
          if (tappedAnnotation.first.annotations.length == 1) {
            _openFocusedMarkEditor(tappedAnnotation.first.annotations.first);
          }
        });
        return;
      }
    }

    if (_focusedAnnotationOverlay != null) {
      setState(() => _clearFocusedAnnotationOverlay());
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
        _goNextPage(isSelectionTurn: isSelectionTurn);
      } else if (_animDirection > 0) {
        _goPreviousPage(isSelectionTurn: isSelectionTurn);
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

  void _acceptPreviewJump() {
    if (_previewReturnLocation == null || !mounted) {
      return;
    }
    setState(() {
      _previewReturnLocation = null;
    });
  }

  Future<void> _returnToPreviewLocation() async {
    final target = _previewReturnLocation;
    if (target == null) {
      return;
    }
    await _store.goToLocation(
      chapterIndex: target.chapterIndex,
      pageIndexInChapter: target.pageIndexInChapter,
      persistProgress: false,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _previewReturnLocation = null;
    });
  }

  Future<void> _openAnnotationsPanel() async {
    _store.hideControls();
    final selected = await ReaderAnnotationSheet.show(
      context: context,
      items: _buildAnnotationCardItems(),
      isTablet: _store.isDualPage,
      showOnLeft: _store.isDualPage,
    );
    if (selected == null || !mounted) {
      return;
    }
    if (selected.type == ReaderAnnotationSheetActionType.addNote) {
      await _openNoteComposerForAnnotation(selected.annotation);
      return;
    }
    await _jumpToAnnotationPreview(selected.annotation);
  }

  Future<void> _jumpToAnnotationPreview(AnnotationEntity annotation) async {
    final anchor = AnnotationAnchorV1.tryParse(annotation.anchorJson);
    if (anchor == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to open mark.')));
      return;
    }

    final pagination = await _store.ensureChapterPagination(
      anchor.jumpTarget.chapterIndex,
    );
    if (pagination == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to open mark.')));
      return;
    }

    final resolved = _annotationResolver.resolveChapterAnnotations(
      pagination: pagination,
      annotations: <AnnotationEntity>[annotation],
    );
    final targetPage = resolved.isNotEmpty
        ? resolved.first.pageIndexInChapter
        : 0;
    final isSamePage =
        _store.currentChapterIndex == pagination.chapterIndex &&
        _store.currentPageIndex == targetPage;

    if (isSamePage) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Already on this mark.')));
      return;
    }

    if (_previewReturnLocation == null) {
      await _store.flushProgress();
      if (!mounted) return;
      setState(() {
        _previewReturnLocation = _PreviewReturnLocation(
          chapterIndex: _store.currentChapterIndex,
          pageIndexInChapter: _store.currentPageIndex,
        );
      });
    }

    await _store.goToLocation(
      chapterIndex: pagination.chapterIndex,
      pageIndexInChapter: targetPage,
      persistProgress: false,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Jumped to mark.')));
  }

  void _goNextPage({bool isSelectionTurn = false}) {
    _acceptPreviewJump();
    isSelectionTurn ? _store.nextSinglePage() : _store.nextPage();
  }

  void _goPreviousPage({bool isSelectionTurn = false}) {
    _acceptPreviewJump();
    isSelectionTurn ? _store.previousSinglePage() : _store.previousPage();
  }

  Future<void> _goToChapterFromControls(int index) async {
    _acceptPreviewJump();
    await _store.goToChapter(index);
  }

  Future<void> _goToBookPercentFromControls(double percent) async {
    _acceptPreviewJump();
    await _store.goToBookPercent(percent);
  }

  bool get _shouldShowPreviewReturnButton {
    final target = _previewReturnLocation;
    if (target == null) {
      return false;
    }
    return !(_store.currentChapterIndex == target.chapterIndex &&
        _store.currentPageIndex == target.pageIndexInChapter);
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
              if (_shouldShowPreviewReturnButton)
                _buildPreviewReturnButton(prefs, mq.padding.top),
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
                  currentChapterIndex: _store.currentDisplayChapterIndex,
                  chapterTitleForPercent: _store.chapterTitleAtPositionPercent,
                  onChapterSelected: _goToChapterFromControls,
                  onPercentChanged: _goToBookPercentFromControls,
                  onAnnotationsPressed: _openAnnotationsPanel,
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

  Widget _buildPreviewReturnButton(ReaderPreferences prefs, double safeTop) {
    final topOffset = safeTop + (_store.showControls ? 72 : 18);
    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: false,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: _returnToPreviewLocation,
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: prefs.theme.isDark
                      ? const Color(0xFF111827)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.reply_rounded,
                      size: 18,
                      color: prefs.theme.textColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Back to previous location',
                      style: TextStyle(
                        color: prefs.theme.textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
                        annotationPaintBuckets: _annotationPaintBucketsForPage(
                          adjacentPage,
                        ),
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
                    annotationPaintBuckets: _annotationPaintBucketsForPage(
                      displayPage,
                    ),
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
        if (_focusedAnnotationOverlay != null &&
            !_isLongPressing &&
            _crossSelection == null)
          _buildFocusedAnnotationTooltip(),

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
      // adjRight intentionally NOT fallback-filled: null means the adjacent
      // spread has no right page (e.g. last spread of an odd-page chapter).
      // buildPagePaint(null) renders the theme background color, which is
      // the correct visual for an empty right page.
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
            annotationPaintBuckets: _annotationPaintBucketsForPage(pg),
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

    // Helper: build a spread widget. When the spread has only one page and
    // it is image-only, center it across the full screen width for a nicer
    // visual instead of leaving an empty right half.
    final halfWidth = screenWidth / 2;
    Widget buildSpread(
      PageLayout? left,
      PageLayout? right, {
      List<Rect>? leftSel,
      List<Rect>? rightSel,
    }) {
      if (right == null && left != null && left.isImageOnly) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: halfWidth,
              child: buildPagePaint(left, selRects: leftSel),
            ),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: buildPagePaint(left, selRects: leftSel)),
          Expanded(child: buildPagePaint(right, selRects: rightSel)),
        ],
      );
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
                ? buildSpread(adjLeft, adjRight)
                : const SizedBox.expand(),
          ),
        ),

        // Current spread (two pages side by side, or centered if image-only).
        Positioned.fill(
          child: GestureDetector(
            // Opaque so gestures are captured on the empty space flanking a
            // centered image-only page (the Row only has a half-width child).
            behavior: HitTestBehavior.opaque,
            onTapUp: _onTapUp,
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            onLongPressStart: _onLongPressStart,
            onLongPressMoveUpdate: _onLongPressMoveUpdate,
            onLongPressEnd: _onLongPressEnd,
            child: Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: buildSpread(
                displayLeftPage,
                displayRightPage,
                leftSel: leftSelRects,
                rightSel: rightSelRects,
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
        if (_focusedAnnotationOverlay != null &&
            !_isLongPressing &&
            _crossSelection == null)
          _buildFocusedAnnotationTooltip(),

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

        // Page indicator(s).
        // When the spread is a centered image-only page, show a single
        // centered indicator; otherwise show left/right indicators.
        if (rightPage == null && leftPage.isImageOnly) ...[
          Positioned(
            left: 0,
            right: 0,
            bottom: mediaPadding.bottom + 8,
            child: Text(
              _store.totalBookPages > 0
                  ? '${_store.currentBookPage} / ${_store.totalBookPages}'
                  : '${_store.currentPageIndex + 1} / ${_store.totalPagesInChapter}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: prefs.theme.textColor.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
          ),
        ] else ...[
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
    final matchedAnnotations = _annotationsForCurrentSelection();
    final exactMatches = _exactAnnotationsForCurrentSelection();
    final canEditSingle =
        matchedAnnotations.length == 1 && exactMatches.length == 1;
    final canOnlyUnmark = matchedAnnotations.isNotEmpty && !canEditSingle;
    final actionSpec = ReaderTooltipActionSpec.forSelection(
      canEditSingle: canEditSingle,
      canOnlyUnmark: canOnlyUnmark,
    );
    final showsEditor = _markEditorMode == _MarkEditorMode.editSelection;
    final editingAnnotation = _activeEditingAnnotation();
    final toolbarWidth = math.min(
      MediaQuery.of(context).size.width - 16,
      520.0,
    );

    return _buildTooltipCluster(
      rects: _selectionRects,
      isRightPage: _selectionOnRightPage,
      toolbarWidth: toolbarWidth,
      toolbarChild: ReaderTooltipActionsBar(
        actionSpec: actionSpec,
        onPhoneticsPressed: () {
          final selectedText = extractCrossPageText();
          _openPhoneticsSheet(selectedText);
        },
        onExplainPressed: () {
          final selectedText = extractCrossPageText();
          final pageLayout = (_selectionOnRightPage && _store.isDualPage)
              ? _store.secondPageLayout
              : _store.currentPageLayout;

          var paragraphContext = '';
          if (pageLayout != null && _crossSelection != null) {
            final pageSel = _crossSelection!.projectOntoPage(pageLayout);
            if (pageSel != null) {
              paragraphContext = extractSelectionParagraphText(
                pageLayout,
                pageSel,
              );
            }
          }

          _openExplainSheet(
            selectedText: selectedText,
            selectionOnRightPage: _selectionOnRightPage,
            pageLayout: pageLayout,
            paragraphContext: paragraphContext,
          );
        },
        onPrimaryPressed: () async {
          if (canOnlyUnmark) {
            await _handleRemoveMarks(matchedAnnotations);
            return;
          }
          if (canEditSingle) {
            setState(() {
              _openSelectionEditEditor(exactMatches.first);
            });
            return;
          }
          await _handleCreateMark(
            color: _markEditorColor,
            style: _markEditorStyle,
            focusCreated: true,
          );
        },
        onNotePressed: () async {
          await _openNoteComposerForSelection(
            annotation: canEditSingle ? exactMatches.first : null,
          );
        },
        onQuoteCardPressed: () async {
          await _openQuoteCard(selectedText: extractCrossPageText());
        },
        onReadAloudPressed: () {
          final selectedText = extractCrossPageText();
          _toggleReadAloud(selectedText);
        },
      ),
      editorWidth: ReaderMarkStyleEditor.compactWidth,
      editorHeight: ReaderMarkStyleEditor.compactHeight,
      editorChild: showsEditor
          ? ReaderMarkStyleEditor(
              selectedColor: _markEditorColor,
              selectedStyle: _markEditorStyle,
              onColorChanged: (color) {
                setState(() => _markEditorColor = color);
                if (editingAnnotation != null) {
                  unawaited(
                    _handleStyleChange(
                      editingAnnotation,
                      color: color,
                      mode: _MarkEditorMode.editSelection,
                    ),
                  );
                }
              },
              onStyleChanged: (style) {
                setState(() => _markEditorStyle = style);
                if (editingAnnotation != null) {
                  unawaited(
                    _handleStyleChange(
                      editingAnnotation,
                      style: style,
                      mode: _MarkEditorMode.editSelection,
                    ),
                  );
                }
              },
            )
          : null,
    );
  }

  Widget _buildFocusedAnnotationTooltip() {
    final overlay = _focusedAnnotationOverlay;
    if (overlay == null || overlay.rects.isEmpty) {
      return const SizedBox.shrink();
    }
    final actionSpec = ReaderTooltipActionSpec.forFocused(
      annotationCount: overlay.annotations.length,
    );
    if (overlay.annotations.length != 1) {
      return _buildTooltipCluster(
        rects: overlay.rects,
        isRightPage: overlay.isRightPage,
        toolbarWidth: 140,
        toolbarChild: ReaderTooltipActionsBar(
          actionSpec: actionSpec,
          onPrimaryPressed: () async {
            await _handleRemoveMarks(overlay.annotations);
          },
        ),
      );
    }

    final annotation = overlay.annotations.first;
    final showsEditor =
        _markEditorMode == _MarkEditorMode.editFocused &&
        _editingAnnotationId == annotation.id;

    final selectedColor = showsEditor ? _markEditorColor : annotation.color;
    final selectedStyle = showsEditor ? _markEditorStyle : annotation.style;
    final toolbarWidth = math.min(
      MediaQuery.of(context).size.width - 16,
      520.0,
    );

    return _buildTooltipCluster(
      rects: overlay.rects,
      isRightPage: overlay.isRightPage,
      toolbarWidth: toolbarWidth,
      toolbarChild: ReaderTooltipActionsBar(
        actionSpec: actionSpec,
        onPhoneticsPressed: () {
          _openPhoneticsSheet(annotation.quoteText);
        },
        onExplainPressed: () {
          final pageLayout = _store.getPageLayout(
            overlay.chapterIndex,
            overlay.pageIndexInChapter,
          );
          _openExplainSheet(
            selectedText: annotation.quoteText,
            selectionOnRightPage: overlay.isRightPage,
            pageLayout: pageLayout,
            paragraphContext: annotation.quoteText.trim(),
          );
        },
        onNotePressed: () async {
          await _openNoteComposerForAnnotation(annotation);
        },
        onQuoteCardPressed: () async {
          await _openQuoteCard(selectedText: annotation.quoteText);
        },
        onUnmarkPressed: () async {
          await _handleRemoveMarks(<AnnotationEntity>[annotation]);
        },
        onReadAloudPressed: () {
          _toggleReadAloud(annotation.quoteText);
        },
      ),
      editorWidth: ReaderMarkStyleEditor.compactWidth,
      editorHeight: ReaderMarkStyleEditor.compactHeight,
      editorChild: showsEditor
          ? ReaderMarkStyleEditor(
              selectedColor: selectedColor,
              selectedStyle: selectedStyle,
              onColorChanged: (color) {
                setState(() {
                  _editingAnnotationId = annotation.id;
                  _markEditorMode = _MarkEditorMode.editFocused;
                  _markEditorColor = color;
                });
                unawaited(
                  _handleStyleChange(
                    annotation,
                    color: color,
                    mode: _MarkEditorMode.editFocused,
                  ),
                );
              },
              onStyleChanged: (style) {
                setState(() {
                  _editingAnnotationId = annotation.id;
                  _markEditorMode = _MarkEditorMode.editFocused;
                  _markEditorStyle = style;
                });
                unawaited(
                  _handleStyleChange(
                    annotation,
                    style: style,
                    mode: _MarkEditorMode.editFocused,
                  ),
                );
              },
            )
          : null,
    );
  }

  Widget _buildTooltipCluster({
    required List<Rect> rects,
    required bool isRightPage,
    required double toolbarWidth,
    required Widget toolbarChild,
    Widget? editorChild,
    double? editorWidth,
    double? editorHeight,
  }) {
    final placement = _buildTooltipPlacement(
      rects: rects,
      isRightPage: isRightPage,
      toolbarWidth: toolbarWidth,
      editorWidth: editorChild == null ? null : editorWidth,
      editorHeight: editorChild == null ? null : editorHeight,
    );

    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (editorChild != null)
            Positioned(
              left: placement.editorLeft,
              top: placement.editorTop,
              child: editorChild,
            ),
          Positioned(
            left: placement.toolbarLeft,
            top: placement.toolbarTop,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: toolbarWidth),
              child: toolbarChild,
            ),
          ),
        ],
      ),
    );
  }

  _TooltipPlacement _buildTooltipPlacement({
    required List<Rect> rects,
    required bool isRightPage,
    required double toolbarWidth,
    double? editorWidth,
    double? editorHeight,
  }) {
    final firstRect = rects.first;
    final lastRect = rects.last;
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final safeTop = mediaQuery.padding.top;
    final safeBottom = mediaQuery.padding.bottom;

    const gap = 8.0;
    const interGap = 10.0;
    const toolbarHeight = 40.0;

    final selCenterX = (firstRect.left + lastRect.right) / 2;
    final screenCenterX = _toScreenOffset(
      Offset(selCenterX, 0),
      isRightPage: isRightPage,
    ).dx;
    final toolbarTopAbove =
        _toScreenOffset(firstRect.topLeft, isRightPage: isRightPage).dy -
        gap -
        toolbarHeight;
    final toolbarTopBelow =
        _toScreenOffset(lastRect.bottomLeft, isRightPage: isRightPage).dy + gap;

    final requiredEditorSpace = editorHeight == null
        ? 0.0
        : editorHeight + interGap;
    final showAbove = toolbarTopAbove - requiredEditorSpace >= safeTop;
    final toolbarTop = showAbove
        ? toolbarTopAbove
        : toolbarTopBelow.clamp(
            safeTop,
            screenHeight - safeBottom - toolbarHeight,
          );
    final toolbarLeft = (screenCenterX - toolbarWidth / 2).clamp(
      8.0,
      screenWidth - toolbarWidth - 8.0,
    );

    var resolvedEditorLeft = toolbarLeft;
    var resolvedEditorTop = toolbarTop;
    if (editorWidth != null && editorHeight != null) {
      final maxEditorLeft = screenWidth - editorWidth - 8.0;
      resolvedEditorLeft = toolbarLeft.clamp(8.0, maxEditorLeft);
      resolvedEditorTop = showAbove
          ? (toolbarTop - interGap - editorHeight).clamp(safeTop, toolbarTop)
          : (toolbarTop + toolbarHeight + interGap).clamp(
              safeTop,
              screenHeight - safeBottom - editorHeight,
            );
    }

    return _TooltipPlacement(
      toolbarLeft: toolbarLeft,
      toolbarTop: toolbarTop,
      editorLeft: resolvedEditorLeft,
      editorTop: resolvedEditorTop,
    );
  }
}

class _TooltipPlacement {
  const _TooltipPlacement({
    required this.toolbarLeft,
    required this.toolbarTop,
    required this.editorLeft,
    required this.editorTop,
  });

  final double toolbarLeft;
  final double toolbarTop;
  final double editorLeft;
  final double editorTop;
}

class _SelectionAnnotationDraft {
  const _SelectionAnnotationDraft({
    required this.selectedText,
    required this.anchor,
    required this.focusPage,
    required this.focusedRects,
    required this.focusIsRight,
  });

  final String selectedText;
  final AnnotationAnchorV1 anchor;
  final PageLayout? focusPage;
  final List<Rect> focusedRects;
  final bool focusIsRight;
}

class _PreviewReturnLocation {
  const _PreviewReturnLocation({
    required this.chapterIndex,
    required this.pageIndexInChapter,
  });

  final int chapterIndex;
  final int pageIndexInChapter;
}

class _AnnotationPaintBucketBuilder {
  _AnnotationPaintBucketBuilder({required this.style, required this.color});

  final AnnotationStyle style;
  final Color color;
  final List<Rect> rects = <Rect>[];
}

enum _MarkEditorMode { hidden, editSelection, editFocused }

class _AnnotationTapTargetBuilder {
  _AnnotationTapTargetBuilder({
    required this.chapterIndex,
    required this.pageIndexInChapter,
    required this.annotations,
  });

  final int chapterIndex;
  final int pageIndexInChapter;
  final List<AnnotationEntity> annotations;
  final List<Rect> rects = <Rect>[];
}

class _AnnotationTapTarget {
  const _AnnotationTapTarget({
    required this.chapterIndex,
    required this.pageIndexInChapter,
    required this.annotations,
    required this.rects,
  });

  final int chapterIndex;
  final int pageIndexInChapter;
  final List<AnnotationEntity> annotations;
  final List<Rect> rects;

  bool contains(Offset point) {
    for (final rect in rects) {
      if (rect.contains(point)) {
        return true;
      }
    }
    return false;
  }
}

class _FocusedAnnotationOverlay {
  const _FocusedAnnotationOverlay({
    required this.chapterIndex,
    required this.pageIndexInChapter,
    required this.isRightPage,
    required this.annotations,
    required this.rects,
  });

  final int chapterIndex;
  final int pageIndexInChapter;
  final bool isRightPage;
  final List<AnnotationEntity> annotations;
  final List<Rect> rects;
}
