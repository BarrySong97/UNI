import 'package:flutter/material.dart';

import '../../entities/book-entity.dart';
import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/shelf-design-tokens.dart';
import '../../components/library/book-pop-in-wrapper.dart';
import '../../components/library/library-book-tile.dart';
import '../../components/library/library-empty-state.dart';
import '../../components/library/library-header.dart';
import '../../components/library/library-now-reading-card.dart';
import '../../components/library/library-reading-stats.dart';
import '../../components/library/library-word-of-day-card.dart';
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
        Container(
          color: CommonDesignTokens.pageBackground,
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 12, bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: LibraryHeader(
                      onImportTap: onImportTap,
                      isImporting: isImporting,
                      showImportButton: books.isNotEmpty,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (books.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: LibraryEmptyState(onImportTap: onImportTap),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: hasReadingProgress
                          ? LibraryReadingStats(
                              readingTime:
                                  readingTime ??
                                  ReadingTimeEntity.empty(
                                    year: DateTime.now().year,
                                    month: DateTime.now().month,
                                  ),
                              booksReadThisYear: booksReadThisYear,
                              onReadingTimeTap: () =>
                                  Navigator.of(context).pushNamed(
                                    RouteNames.statistics,
                                    arguments: const StatisticsPageArguments(
                                      initialTab: StatisticsTab.readingTime,
                                      initialPeriodPreset:
                                          StatisticsPeriodPreset.thisMonth,
                                    ),
                                  ),
                              onBooksReadTap: () =>
                                  Navigator.of(context).pushNamed(
                                    RouteNames.statistics,
                                    arguments: const StatisticsPageArguments(
                                      initialTab: StatisticsTab.booksRead,
                                      initialPeriodPreset:
                                          StatisticsPeriodPreset.thisMonth,
                                    ),
                                  ),
                            )
                          : _buildStatsEmptyState(),
                    ),
                    const SizedBox(height: 24),
                    if (nowReadingBook != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildSectionHeader(
                          'Now Reading',
                          showViewAll: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: BookPopInWrapper(
                          animate: nowReadingBook!.id == lastImportedBookId,
                          child: NowReadingCard(
                            book: nowReadingBook!,
                            progress: nowReadingProgress,
                            onContinueTap: onContinueReadingTap ?? () {},
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: hasReadingProgress
                          ? WordOfDayCard(
                              onTap: () => Navigator.of(
                                context,
                              ).pushNamed(RouteNames.wordOfDay),
                            )
                          : _buildReadingPrompt(),
                    ),
                    if (gridBooks.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildSectionHeader('Recent Books'),
                      ),
                      const SizedBox(height: 12),
                      _buildHorizontalBookList(),
                    ],
                  ],
                ],
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
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

  Widget _buildSectionHeader(String title, {bool showViewAll = false}) {
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
      ],
    );
  }
}
