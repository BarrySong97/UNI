import 'package:flutter/material.dart';

import '../../entities/book-entity.dart';
import '../../shared/constants/library-design-tokens.dart';
import '../../components/library/book-pop-in-wrapper.dart';
import '../../components/library/library-book-tile.dart';
import '../../components/library/library-empty-state.dart';
import '../../components/library/library-header.dart';
import '../../components/library/library-now-reading-card.dart';
import '../../components/library/library-reading-stats.dart';
import '../../components/library/library-word-of-day-card.dart';
import '../../app/routes/route-names.dart';

class ShelfPageLayout extends StatelessWidget {
  const ShelfPageLayout({
    required this.books,
    required this.isImporting,
    required this.onBookTap,
    required this.onImportTap,
    required this.emptyMessage,
    required this.importingMessage,
    this.progressMap = const <String, double>{},
    this.hasReadingProgress = false,
    this.nowReadingBook,
    this.nowReadingProgress = 0,
    this.gridBooks = const <BookEntity>[],
    this.onContinueReadingTap,
    this.lastImportedBookId,
    super.key,
  });

  final List<BookEntity> books;
  final bool isImporting;
  final ValueChanged<BookEntity> onBookTap;
  final VoidCallback onImportTap;
  final String emptyMessage;
  final String importingMessage;
  final Map<String, double> progressMap;
  final bool hasReadingProgress;
  final BookEntity? nowReadingBook;
  final double nowReadingProgress;
  final List<BookEntity> gridBooks;
  final VoidCallback? onContinueReadingTap;
  final String? lastImportedBookId;

  static const _palette = <Color>[
    LibraryDesignTokens.coverBlue,
    LibraryDesignTokens.coverNeon,
    LibraryDesignTokens.coverBlack,
    LibraryDesignTokens.coverGray,
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Container(
          color: LibraryDesignTokens.pageBackground,
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: 12,
                bottom: 120,
              ),
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
                              onTap: () => Navigator.of(
                                context,
                              ).pushNamed(RouteNames.statistics),
                            )
                          : _buildStatsEmptyState(),
                    ),
                    const SizedBox(height: 24),
                    if (nowReadingBook != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildSectionHeader('Now Reading', showViewAll: true),
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
                              onTap: () => Navigator.of(context)
                                  .pushNamed(RouteNames.wordOfDay),
                            )
                          : _buildReadingPrompt(),
                    ),
                    if (gridBooks.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildSectionHeader('Your Books'),
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
                backgroundColor: LibraryDesignTokens.pageBackground,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  LibraryDesignTokens.textPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHorizontalBookList() {
    final displayBooks = gridBooks.length > LibraryDesignTokens.homeGridMaxItems
        ? gridBooks.sublist(0, LibraryDesignTokens.homeGridMaxItems)
        : gridBooks;

    return SizedBox(
      height: LibraryDesignTokens.homeGridItemWidth /
              LibraryDesignTokens.coverAspectRatio +
          50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: displayBooks.length,
        separatorBuilder: (_, _) => const SizedBox(
          width: LibraryDesignTokens.homeGridItemSpacing,
        ),
        itemBuilder: (context, index) {
          final book = displayBooks[index];
          final progress = progressMap[book.id] ?? 0;
          final percent = (progress * 100).round();

          final isNewBook = book.id == lastImportedBookId;
          final shouldSlide = !isNewBook && lastImportedBookId != null;

          return BookPopInWrapper(
            key: ValueKey<String>(book.id),
            animate: isNewBook,
            slideRight: shouldSlide,
            child: GestureDetector(
              onTap: () => onBookTap(book),
              child: SizedBox(
                width: LibraryDesignTokens.homeGridItemWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        LibraryDesignTokens.homeGridCoverRadius,
                      ),
                      child: Stack(
                        children: <Widget>[
                          LibraryBookTile(
                            book: book,
                            coverColor: _palette[index % _palette.length],
                            coverMark: book.title.isEmpty
                                ? 'B'
                                : book.title.substring(0, 1).toUpperCase(),
                            onTap: () => onBookTap(book),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xAA000000),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$percent%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
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
                        fontSize: LibraryDesignTokens.homeGridTitleSize,
                        fontWeight: FontWeight.w600,
                        color: LibraryDesignTokens.textPrimary,
                      ),
                    ),
                    if (book.author.isNotEmpty && book.author != 'Unknown') ...[
                      const SizedBox(height: 2),
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: LibraryDesignTokens.homeGridAuthorSize,
                          color: LibraryDesignTokens.textSecondary,
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
              color: LibraryDesignTokens.statsCardBg,
              borderRadius: BorderRadius.circular(
                LibraryDesignTokens.statsCardRadius,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'DAILY GOAL',
                  style: TextStyle(
                    fontSize: 12,
                    color: LibraryDesignTokens.statsLabelColor,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Start reading to track your daily progress',
                  style: TextStyle(
                    fontSize: 13,
                    color: LibraryDesignTokens.statsNumberColor.withValues(
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
              color: LibraryDesignTokens.statsBooksReadBg,
              borderRadius: BorderRadius.circular(
                LibraryDesignTokens.statsCardRadius,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'BOOKS READ',
                  style: TextStyle(
                    fontSize: 12,
                    color: LibraryDesignTokens.statsBooksReadText,
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
                          color: LibraryDesignTokens.statsBooksReadText,
                          height: 1.1,
                        ),
                      ),
                      TextSpan(
                        text: '  this year',
                        style: TextStyle(
                          fontSize: 14,
                          color: LibraryDesignTokens.statsBooksReadText,
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
        color: LibraryDesignTokens.wordOfDayCardBg,
        borderRadius: BorderRadius.circular(
          LibraryDesignTokens.wordOfDayCardRadius,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: LibraryDesignTokens.wordOfDayIconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.menu_book_rounded,
              size: 20,
              color: LibraryDesignTokens.wordOfDayIconColor,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Tap a book above to start reading',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: LibraryDesignTokens.textSecondary,
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
            fontSize: LibraryDesignTokens.sectionHeaderSize,
            fontWeight: FontWeight.w600,
            color: LibraryDesignTokens.sectionHeaderColor,
          ),
        ),
      ],
    );
  }
}
