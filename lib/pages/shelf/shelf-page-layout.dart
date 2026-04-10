import 'package:flutter/material.dart';

import '../../entities/book-entity.dart';
import '../../entities/explain-history-entity.dart';
import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/shelf-design-tokens.dart';
import '../../shared/layout/responsive_layout.dart';
import '../../components/library/book-pop-in-wrapper.dart';
import '../../components/library/library-book-tile.dart';
import '../../components/library/library-empty-state.dart';
import '../../components/library/library-header.dart';
import '../../components/library/library-now-reading-card.dart';
import '../../components/library/library-reading-stats.dart';
import '../../components/library/library-word-of-day-card.dart';
import '../../shared/utils/cover-image-cache.dart';
import '../../app/routes/route-names.dart';
import '../../entities/reading-time-entity.dart';
import '../statistics/statistics-types.dart';

class ShelfPageLayout extends StatelessWidget {
  const ShelfPageLayout({
    required this.books,
    required this.isImporting,
    required this.onBookTap,
    required this.onImportTap,
    required this.emptyMessage,
    required this.importingMessage,
    this.progressMap = const <String, double>{},
    this.progressBookIds = const <String>{},
    this.hasReadingProgress = false,
    this.readingTime,
    this.booksReadThisYear = 0,
    this.nowReadingBook,
    this.nowReadingProgress = 0,
    this.gridBooks = const <BookEntity>[],
    this.onContinueReadingTap,
    this.wordsPreview,
    this.onWordsMoreTap,
    this.lastImportedBookId,
    super.key,
  });

  final List<BookEntity> books;
  final bool isImporting;
  final void Function(BookEntity book, bool hasProgress) onBookTap;
  final VoidCallback onImportTap;
  final String emptyMessage;
  final String importingMessage;
  final Map<String, double> progressMap;
  final Set<String> progressBookIds;
  final bool hasReadingProgress;
  final ReadingTimeEntity? readingTime;
  final int booksReadThisYear;
  final BookEntity? nowReadingBook;
  final double nowReadingProgress;
  final List<BookEntity> gridBooks;
  final VoidCallback? onContinueReadingTap;
  final ExplainHistoryEntity? wordsPreview;
  final VoidCallback? onWordsMoreTap;
  final String? lastImportedBookId;

  static const _palette = <Color>[
    CommonDesignTokens.coverBlue,
    CommonDesignTokens.coverNeon,
    CommonDesignTokens.coverBlack,
    CommonDesignTokens.coverGray,
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Container(
            color: CommonDesignTokens.pageBackground,
            child: SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= kTabletBreakpoint;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 12, bottom: 120),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isWide ? 1200 : kContentMaxWidth,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWide ? 32 : 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              LibraryHeader(
                                onImportTap: onImportTap,
                                isImporting: isImporting,
                                showImportButton: books.isNotEmpty,
                              ),
                              const SizedBox(height: 20),
                              if (books.isEmpty)
                                LibraryEmptyState(onImportTap: onImportTap)
                              else if (isWide)
                                _buildWideContent(context)
                              else
                                _buildNarrowContent(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (isImporting)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: CommonDesignTokens.pageBackground,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  CommonDesignTokens.textPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNarrowContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        hasReadingProgress
            ? LibraryReadingStats(
                readingTime:
                    readingTime ??
                    ReadingTimeEntity.empty(
                      year: DateTime.now().year,
                      month: DateTime.now().month,
                    ),
                booksReadThisYear: booksReadThisYear,
                onReadingTimeTap: () => Navigator.of(context).pushNamed(
                  RouteNames.statistics,
                  arguments: const StatisticsPageArguments(
                    initialTab: StatisticsTab.readingTime,
                    initialPeriodPreset: StatisticsPeriodPreset.thisMonth,
                  ),
                ),
                onBooksReadTap: () => Navigator.of(context).pushNamed(
                  RouteNames.statistics,
                  arguments: const StatisticsPageArguments(
                    initialTab: StatisticsTab.booksRead,
                    initialPeriodPreset: StatisticsPeriodPreset.thisMonth,
                  ),
                ),
              )
            : _buildStatsEmptyState(),
        const SizedBox(height: 24),
        if (nowReadingBook != null) ...[
          _buildSectionHeader('Now Reading'),
          const SizedBox(height: 12),
          BookPopInWrapper(
            animate: nowReadingBook!.id == lastImportedBookId,
            child: NowReadingCard(
              book: nowReadingBook!,
              progress: nowReadingProgress,
              onContinueTap: onContinueReadingTap ?? () {},
            ),
          ),
          const SizedBox(height: 24),
        ],
        _buildSectionHeader(
          'Words',
          actionLabel: 'More',
          onActionTap: onWordsMoreTap,
        ),
        const SizedBox(height: 12),
        _buildWordsCard(),
        if (gridBooks.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionHeader('Recent Books'),
          const SizedBox(height: 12),
          _buildHorizontalBookList(),
        ],
      ],
    );
  }

  Widget _buildWideContent(BuildContext context) {
    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        hasReadingProgress
            ? LibraryReadingStats(
                readingTime:
                    readingTime ??
                    ReadingTimeEntity.empty(
                      year: DateTime.now().year,
                      month: DateTime.now().month,
                    ),
                booksReadThisYear: booksReadThisYear,
                onReadingTimeTap: () => Navigator.of(context).pushNamed(
                  RouteNames.statistics,
                  arguments: const StatisticsPageArguments(
                    initialTab: StatisticsTab.readingTime,
                    initialPeriodPreset: StatisticsPeriodPreset.thisMonth,
                  ),
                ),
                onBooksReadTap: () => Navigator.of(context).pushNamed(
                  RouteNames.statistics,
                  arguments: const StatisticsPageArguments(
                    initialTab: StatisticsTab.booksRead,
                    initialPeriodPreset: StatisticsPeriodPreset.thisMonth,
                  ),
                ),
              )
            : _buildStatsEmptyState(),
        if (gridBooks.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionHeader('Recent Books'),
          const SizedBox(height: 12),
          _buildBookGrid(columns: 3),
        ],
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Left column: Now Reading
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (nowReadingBook != null)
                BookPopInWrapper(
                  animate: nowReadingBook!.id == lastImportedBookId,
                  child: _buildWideNowReadingCard(),
                )
              else
                _buildReadingPrompt(),
              const SizedBox(height: 24),
              _buildSectionHeader(
                'Words',
                actionLabel: 'More',
                onActionTap: onWordsMoreTap,
              ),
              const SizedBox(height: 12),
              _buildWordsCard(),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Right column: Stats + Recent Books grid
        Expanded(flex: 6, child: rightColumn),
      ],
    );
  }

  Widget _buildWideNowReadingCard() {
    final book = nowReadingBook!;
    final coverBytes = CoverImageCache.decode(book.coverUrl);
    final progressPercent = (nowReadingProgress * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CommonDesignTokens.cardBg,
        borderRadius: BorderRadius.circular(CommonDesignTokens.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Section label inside card
          Text(
            'Now Reading',
            style: TextStyle(
              fontSize: ShelfDesignTokens.sectionHeaderSize,
              fontWeight: FontWeight.w600,
              color: ShelfDesignTokens.sectionHeaderColor,
            ),
          ),
          const SizedBox(height: 16),
          // Cover - centered
          Center(
            child: Container(
              width: 180,
              height: 257,
              decoration: BoxDecoration(
                color: ShelfDesignTokens.nowReadingCoverPlaceholderBg,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x20000000),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: coverBytes != null
                  ? Image.memory(
                      coverBytes,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildWideFallbackCover(book),
                    )
                  : _buildWideFallbackCover(book),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: CommonDesignTokens.textPrimary,
              height: 1.2,
            ),
          ),
          if (book.author.isNotEmpty && book.author != 'Unknown') ...[
            const SizedBox(height: 4),
            Text(
              'by ${book.author}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: CommonDesignTokens.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Progress bar + percentage
          Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: nowReadingProgress,
                    minHeight: 4,
                    backgroundColor: ShelfDesignTokens.nowReadingProgressBg,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      ShelfDesignTokens.nowReadingProgressFill,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$progressPercent%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CommonDesignTokens.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Continue button - full width
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: onContinueReadingTap ?? () {},
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: ShelfDesignTokens.continueButtonBg,
                  borderRadius: BorderRadius.circular(
                    ShelfDesignTokens.continueButtonRadius,
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const <Widget>[
                    Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ShelfDesignTokens.continueButtonText,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: ShelfDesignTokens.continueButtonText,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideFallbackCover(BookEntity book) {
    return Container(
      color: CommonDesignTokens.coverBlack,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            book.title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          if (book.author.isNotEmpty && book.author != 'Unknown')
            Text(
              book.author.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: Color(0xFFAAAAAA),
                letterSpacing: 0.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHorizontalBookList() {
    final displayBooks = gridBooks.length > ShelfDesignTokens.homeGridMaxItems
        ? gridBooks.sublist(0, ShelfDesignTokens.homeGridMaxItems)
        : gridBooks;

    return SizedBox(
      height:
          ShelfDesignTokens.homeGridItemWidth /
              CommonDesignTokens.coverAspectRatio +
          50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: displayBooks.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: ShelfDesignTokens.homeGridItemSpacing),
        itemBuilder: (context, index) {
          final book = displayBooks[index];
          final progress = progressMap[book.id] ?? 0;
          final hasProgress = progress > 0 || progressBookIds.contains(book.id);

          final isNewBook = book.id == lastImportedBookId;
          final shouldSlide = !isNewBook && lastImportedBookId != null;

          return BookPopInWrapper(
            key: ValueKey<String>(book.id),
            animate: isNewBook,
            slideRight: shouldSlide,
            child: GestureDetector(
              onTap: () => onBookTap(book, hasProgress),
              child: SizedBox(
                width: ShelfDesignTokens.homeGridItemWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        ShelfDesignTokens.homeGridCoverRadius,
                      ),
                      child: Stack(
                        children: <Widget>[
                          LibraryBookTile(
                            book: book,
                            coverColor: _palette[index % _palette.length],
                            coverMark: book.title.isEmpty
                                ? 'B'
                                : book.title.substring(0, 1).toUpperCase(),
                            onTap: () => onBookTap(book, hasProgress),
                            progress: progress,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: ShelfDesignTokens.homeGridTitleSize,
                        fontWeight: FontWeight.w600,
                        color: CommonDesignTokens.textPrimary,
                      ),
                    ),
                    if (book.author.isNotEmpty && book.author != 'Unknown') ...[
                      const SizedBox(height: 2),
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: ShelfDesignTokens.homeGridAuthorSize,
                          color: CommonDesignTokens.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookGrid({int? columns}) {
    final displayBooks = gridBooks.length > ShelfDesignTokens.homeGridMaxItems
        ? gridBooks.sublist(0, ShelfDesignTokens.homeGridMaxItems)
        : gridBooks;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns0 = columns ?? responsiveGridColumns(constraints.maxWidth);
        final rows = <Widget>[];
        for (var i = 0; i < displayBooks.length; i += columns0) {
          final rowChildren = <Widget>[];
          for (var col = 0; col < columns0; col++) {
            if (col > 0) {
              rowChildren.add(
                const SizedBox(width: ShelfDesignTokens.homeGridItemSpacing),
              );
            }
            final index = i + col;
            rowChildren.add(
              Expanded(
                child: index < displayBooks.length
                    ? _buildGridItem(displayBooks[index], index)
                    : const SizedBox.shrink(),
              ),
            );
          }
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rowChildren,
            ),
          );
          if (i + columns0 < displayBooks.length) {
            rows.add(const SizedBox(height: CommonDesignTokens.gridRowSpacing));
          }
        }
        return Column(children: rows);
      },
    );
  }

  Widget _buildGridItem(BookEntity book, int index) {
    final progress = progressMap[book.id] ?? 0;
    final hasProgress = progress > 0 || progressBookIds.contains(book.id);
    final isNewBook = book.id == lastImportedBookId;
    final shouldSlide = !isNewBook && lastImportedBookId != null;

    return BookPopInWrapper(
      key: ValueKey<String>(book.id),
      animate: isNewBook,
      slideRight: shouldSlide,
      child: GestureDetector(
        onTap: () => onBookTap(book, hasProgress),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(
                ShelfDesignTokens.homeGridCoverRadius,
              ),
              child: Stack(
                children: <Widget>[
                  LibraryBookTile(
                    book: book,
                    coverColor: _palette[index % _palette.length],
                    coverMark: book.title.isEmpty
                        ? 'B'
                        : book.title.substring(0, 1).toUpperCase(),
                    onTap: () => onBookTap(book, hasProgress),
                    progress: progress,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: ShelfDesignTokens.homeGridTitleSize,
                fontWeight: FontWeight.w600,
                color: CommonDesignTokens.textPrimary,
              ),
            ),
            if (book.author.isNotEmpty && book.author != 'Unknown') ...[
              const SizedBox(height: 2),
              Text(
                book.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: ShelfDesignTokens.homeGridAuthorSize,
                  color: CommonDesignTokens.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsEmptyState() {
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CommonDesignTokens.cardBg,
              borderRadius: BorderRadius.circular(
                CommonDesignTokens.cardRadius,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'DAILY GOAL',
                  style: TextStyle(
                    fontSize: 12,
                    color: ShelfDesignTokens.statsLabelColor,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Start reading to track your daily progress',
                  style: TextStyle(
                    fontSize: 13,
                    color: ShelfDesignTokens.statsNumberColor.withValues(
                      alpha: 0.6,
                    ),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ShelfDesignTokens.statsBooksReadBg,
              borderRadius: BorderRadius.circular(
                CommonDesignTokens.cardRadius,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'BOOKS READ',
                  style: TextStyle(
                    fontSize: 12,
                    color: ShelfDesignTokens.statsBooksReadText,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 12),
                RichText(
                  text: const TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: '0',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: ShelfDesignTokens.statsBooksReadText,
                          height: 1.1,
                        ),
                      ),
                      TextSpan(
                        text: '  this year',
                        style: TextStyle(
                          fontSize: 14,
                          color: ShelfDesignTokens.statsBooksReadText,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadingPrompt() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ShelfDesignTokens.wordOfDayCardBg,
        borderRadius: BorderRadius.circular(
          ShelfDesignTokens.wordOfDayCardRadius,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ShelfDesignTokens.wordOfDayIconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.menu_book_rounded,
              size: 20,
              color: ShelfDesignTokens.wordOfDayIconColor,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Tap a book above to start reading',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: CommonDesignTokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordsCard() {
    return LibraryWordsCard(preview: wordsPreview);
  }

  Widget _buildSectionHeader(
    String title, {
    String? actionLabel,
    VoidCallback? onActionTap,
  }) {
    return Row(
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: ShelfDesignTokens.sectionHeaderSize,
            fontWeight: FontWeight.w600,
            color: ShelfDesignTokens.sectionHeaderColor,
          ),
        ),
        const Spacer(),
        if (actionLabel != null)
          TextButton(
            onPressed: onActionTap,
            style: TextButton.styleFrom(
              foregroundColor: CommonDesignTokens.textSecondary,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CommonDesignTokens.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
