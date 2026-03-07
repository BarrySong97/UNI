import 'dart:math';

import 'package:flutter/material.dart';

import '../../entities/book-entity.dart';
import '../../shared/constants/library-design-tokens.dart';
import 'library-book-tile.dart';

class LibraryBookGrid extends StatelessWidget {
  const LibraryBookGrid({
    required this.books,
    required this.onBookTap,
    this.progressMap = const <String, double>{},
    this.maxItems = LibraryDesignTokens.homeGridMaxItems,
    super.key,
  });

  final List<BookEntity> books;
  final ValueChanged<BookEntity> onBookTap;
  final Map<String, double> progressMap;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final displayCount = min(books.length, maxItems);

    return SizedBox(
      height: _estimateHeight(),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: displayCount,
        separatorBuilder: (_, _) =>
            const SizedBox(width: LibraryDesignTokens.homeGridItemSpacing),
        itemBuilder: (_, index) => SizedBox(
          width: LibraryDesignTokens.homeGridItemWidth,
          child: _buildItem(books[index], index),
        ),
      ),
    );
  }

  double _estimateHeight() {
    // cover height + gap + title + author + gap + progress row
    final coverHeight = LibraryDesignTokens.homeGridItemWidth /
        LibraryDesignTokens.coverAspectRatio;
    return coverHeight + 8 + 18 + 16 + 6 + 20;
  }

  Widget _buildItem(BookEntity book, int index) {
    final palette = <Color>[
      LibraryDesignTokens.coverBlue,
      LibraryDesignTokens.coverNeon,
      LibraryDesignTokens.coverBlack,
      LibraryDesignTokens.coverGray,
    ];
    final progress = progressMap[book.id] ?? 0;

    return GestureDetector(
      onTap: () => onBookTap(book),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LibraryBookTile(
            book: book,
            coverColor: palette[index % palette.length],
            coverMark: _coverMarkForBook(book),
            showNewBadge: false,
            onTap: () => onBookTap(book),
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
              height: 1.2,
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
          const SizedBox(height: 6),
          _buildProgressRow(progress),
        ],
      ),
    );
  }

  Widget _buildProgressRow(double progress) {
    final percent = (progress * 100).round();

    return Row(
      children: <Widget>[
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: LibraryDesignTokens.homeGridProgressHeight,
              backgroundColor: LibraryDesignTokens.homeGridProgressBg,
              valueColor: const AlwaysStoppedAnimation<Color>(
                LibraryDesignTokens.homeGridProgressFill,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$percent%',
          style: const TextStyle(
            fontSize: 11,
            color: LibraryDesignTokens.textSecondary,
          ),
        ),
      ],
    );
  }

  String _coverMarkForBook(BookEntity book) {
    final trimmed = book.title.trim();
    if (trimmed.isEmpty) {
      return 'B';
    }
    return trimmed.substring(0, 1).toUpperCase();
  }
}
