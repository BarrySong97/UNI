import 'package:flutter/material.dart';

import '../../entities/book-entity.dart';
import '../../shared/constants/library-design-tokens.dart';
import 'library-new-badge.dart';

class LibraryBookTile extends StatelessWidget {
  const LibraryBookTile({
    required this.book,
    required this.coverColor,
    required this.coverMark,
    required this.onTap,
    this.showNewBadge = false,
    super.key,
  });

  final BookEntity book;
  final Color coverColor;
  final String coverMark;
  final VoidCallback onTap;
  final bool showNewBadge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AspectRatio(
            aspectRatio: LibraryDesignTokens.coverAspectRatio,
            child: Container(
              color: coverColor,
              padding: const EdgeInsets.all(14),
              child: Stack(
                children: <Widget>[
                  if (showNewBadge)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: LibraryNewBadge(),
                    ),
                  Positioned(
                    left: 8,
                    bottom: 2,
                    child: Text(
                      coverMark,
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        color: _coverTextColor(coverColor),
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: LibraryDesignTokens.bookTitleSize,
              fontWeight: FontWeight.w700,
              color: LibraryDesignTokens.textPrimary,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Color _coverTextColor(Color cover) {
    if (cover == LibraryDesignTokens.coverNeon || cover == LibraryDesignTokens.coverGray) {
      return const Color(0xFF111111);
    }
    return const Color(0xFFF4F4F4);
  }
}
