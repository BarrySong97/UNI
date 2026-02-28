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
        crossAxisCount: 2,
        crossAxisSpacing: LibraryDesignTokens.gridSpacing,
        mainAxisSpacing: LibraryDesignTokens.gridSpacing,
        childAspectRatio: 0.62,
      ),
      itemBuilder: (context, index) {
        final book = books[index];
        final palette = <Color>[
          LibraryDesignTokens.coverBlue,
          LibraryDesignTokens.coverNeon,
          LibraryDesignTokens.coverBlack,
          LibraryDesignTokens.coverGray,
        ];
        final marks = <String>['A', 'B', 'C', 'D'];

        return LibraryBookTile(
          book: book,
          coverColor: palette[index % palette.length],
          coverMark: marks[index % marks.length],
          showNewBadge: index == 1,
          onTap: () => onBookTap(book),
        );
      },
    );
  }
}
