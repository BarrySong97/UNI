import 'package:flutter/material.dart';

import '../../entities/book-entity.dart';
import '../../shared/constants/library-design-tokens.dart';
import '../../components/library/library-book-grid.dart';
import '../../components/library/library-empty-state.dart';
import '../../components/library/library-header.dart';
import '../../components/library/library-now-reading-card.dart';
import '../../components/library/library-reading-stats.dart';
import '../../components/library/library-word-of-day-card.dart';
import '../../app/routes/route-names.dart';
import '../../shared/ui/loading-view.dart';

class LibraryPageLayout extends StatelessWidget {
  const LibraryPageLayout({
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
                left: 16,
                right: 16,
                top: 12,
                bottom: 120,
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
                  else ...[
                    if (hasReadingProgress)
                      LibraryReadingStats(
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(RouteNames.statistics),
                      )
                    else
                      _buildStatsEmptyState(),
                    const SizedBox(height: 24),
                    if (nowReadingBook != null) ...[
                      _buildSectionHeader('Now Reading', showViewAll: true),
                      const SizedBox(height: 12),
                      NowReadingCard(
                        book: nowReadingBook!,
                        progress: nowReadingProgress,
                        onContinueTap: onContinueReadingTap ?? () {},
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (hasReadingProgress) ...[
                      WordOfDayCard(
                        onTap: () =>
                            Navigator.of(context).pushNamed(RouteNames.wordOfDay),
                      ),
                    ] else ...[
                      _buildReadingPrompt(),
                    ],
                    const SizedBox(height: 24),
                    LibraryBookGrid(
                      books: gridBooks,
                      onBookTap: onBookTap,
                      progressMap: progressMap,
                      categories: const <String>[],
                      activeCategory: '',
                      onCategoryTap: (_) {},
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (isImporting)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0x99000000),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const LoadingView(),
                  const SizedBox(height: 12),
                  Text(
                    importingMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
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
