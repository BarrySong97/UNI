import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../entities/book-entity.dart';
import '../../repositories/progress/progress-repository.dart';
import '../../services/reader/data/chapter_data_source.dart';
import '../../services/reader/models/reader_preferences.dart';
import '../../stores/reader/reader_store.dart';
import 'widgets/reader_canvas_painter.dart';
import 'widgets/reader_controls_overlay.dart';
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

class _ReaderPageState extends State<ReaderPage> {
  late final ReaderStore _store;

  @override
  void initState() {
    super.initState();
    _store = ReaderStore(progressRepository: widget.progressRepository);
    _store.addListener(_onStoreChanged);
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
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _store.dispose();
    super.dispose();
  }

  void _onTapUp(TapUpDetails details) {
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

  @override
  Widget build(BuildContext context) {
    final prefs = _store.preferences;

    // Show loading until openBook() completes (book is null before that).
    final showLoading = _store.isLoading || _store.book == null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: prefs.theme == ReaderTheme.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: prefs.theme.backgroundColor,
        body: showLoading
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
    final chapterTitle = _store.bookData?.chapters.isNotEmpty == true
        ? (_store
                  .bookData!
                  .chapters[_store.currentChapterIndex]
                  .title
                  .isNotEmpty
              ? _store.bookData!.chapters[_store.currentChapterIndex].title
              : 'Chapter ${_store.currentChapterIndex + 1}')
        : widget.book.title;

    return Stack(
      children: [
        // Canvas layer.
        GestureDetector(
          onTapUp: _onTapUp,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: ReaderCanvasPainter(
                page: page,
                preferences: prefs,
                safeAreaTop: mediaPadding.top,
                safeAreaBottom: mediaPadding.bottom,
              ),
              size: Size.infinite,
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
}
