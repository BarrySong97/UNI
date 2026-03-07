import 'package:flutter/material.dart';

import '../../entities/book-entity.dart';
import '../../shared/constants/library-design-tokens.dart';
import '../../components/library/library-book-grid.dart';
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
                  ),
                  const SizedBox(height: 20),
                  if (books.isEmpty)
                    _buildEmptyState()
                  else ...[
                    LibraryReadingStats(
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed(RouteNames.statistics),
                    ),
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
                    WordOfDayCard(
                      onTap: () =>
                          Navigator.of(context).pushNamed(RouteNames.wordOfDay),
                    ),
                    const SizedBox(height: 24),
                    if (gridBooks.isNotEmpty)
                      LibraryBookGrid(books: gridBooks, onBookTap: onBookTap),
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

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.menu_book_rounded,
              size: 64,
              color: LibraryDesignTokens.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Start your reading journey',
              style: TextStyle(
                fontSize: 16,
                color: LibraryDesignTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onImportTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: LibraryDesignTokens.continueButtonBg,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Add Your First Book',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
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
