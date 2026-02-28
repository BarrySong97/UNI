import 'package:flutter/material.dart';

import '../../entities/book-entity.dart';
import '../../shared/constants/library-design-tokens.dart';
import 'library-book-tile.dart';

class LibraryBookGrid extends StatelessWidget {
  const LibraryBookGrid({
    required this.books,
    required this.onBookTap,
    super.key,
  });

  final List<BookEntity> books;
  final ValueChanged<BookEntity> onBookTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: books.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 14,
        childAspectRatio: 0.5,
      ),
      itemBuilder: (context, index) {
        final book = books[index];
        final palette = <Color>[
          LibraryDesignTokens.coverBlue,
          LibraryDesignTokens.coverNeon,
          LibraryDesignTokens.coverBlack,
          LibraryDesignTokens.coverGray,
        ];

        return LibraryBookTile(
          book: book,
          coverColor: palette[index % palette.length],
          coverMark: _coverMarkForBook(book),
          showNewBadge: index == 1,
          onTap: () => onBookTap(book),
        );
      },
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
