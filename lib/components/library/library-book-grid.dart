import 'package:flutter/material.dart';

import '../../entities/book-entity.dart';
import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/shelf-design-tokens.dart';
import 'book-pop-in-wrapper.dart';
import 'library-book-tile.dart';

class LibraryBookGrid extends StatelessWidget {
  const LibraryBookGrid({
    required this.books,
    required this.onBookTap,
    required this.categories,
    required this.activeCategory,
    required this.onCategoryTap,
    this.progressMap = const <String, double>{},
    this.lastImportedBookId,
    super.key,
  });

  final List<BookEntity> books;
  final ValueChanged<BookEntity> onBookTap;
  final Map<String, double> progressMap;
  final List<String> categories;
  final String activeCategory;
  final ValueChanged<String> onCategoryTap;
  final String? lastImportedBookId;

  static const _palette = <Color>[
    CommonDesignTokens.coverBlue,
    CommonDesignTokens.coverNeon,
    CommonDesignTokens.coverBlack,
    CommonDesignTokens.coverGray,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (categories.isNotEmpty) ...[
          _buildCategoryTabs(),
          const SizedBox(height: 20),
        ],
        _buildGrid(),
      ],
    );
  }

  Widget _buildCategoryTabs() {
    return Row(
      children: categories.map((category) {
        final isActive = category == activeCategory;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onCategoryTap(category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? CommonDesignTokens.tabActiveBg
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? CommonDesignTokens.tabActiveText
                      : CommonDesignTokens.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGrid() {
    if (books.isEmpty) {
      return const SizedBox.shrink();
    }

    final rows = <Widget>[];
    for (var i = 0; i < books.length; i += 2) {
      final left = books[i];
      final right = i + 1 < books.length ? books[i + 1] : null;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: _buildItem(left, i)),
            const SizedBox(width: CommonDesignTokens.gridSpacing),
            Expanded(
              child: right != null
                  ? _buildItem(right, i + 1)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
      if (i + 2 < books.length) {
        rows.add(const SizedBox(height: CommonDesignTokens.gridRowSpacing));
      }
    }

    return Column(children: rows);
  }

  Widget _buildItem(BookEntity book, int index) {
    final progress = progressMap[book.id] ?? 0;
    final isNewBook = book.id == lastImportedBookId;
    final shouldSlide = !isNewBook && lastImportedBookId != null;

    return BookPopInWrapper(
      key: ValueKey<String>(book.id),
      animate: isNewBook,
      slideRight: shouldSlide,
      child: GestureDetector(
        onTap: () => onBookTap(book),
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
                    onTap: () => onBookTap(book),
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
                fontSize: 14,
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
                  fontSize: 12,
                  color: CommonDesignTokens.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
