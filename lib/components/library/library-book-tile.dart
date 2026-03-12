import 'package:flutter/material.dart';

import '../../entities/book-entity.dart';
import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/shelf-design-tokens.dart';
import '../../shared/utils/cover-image-cache.dart';
import 'library-new-badge.dart';

class LibraryBookTile extends StatelessWidget {
  const LibraryBookTile({
    required this.book,
    required this.coverColor,
    required this.coverMark,
    required this.onTap,
    this.showNewBadge = false,
    this.progress,
    super.key,
  });

  final BookEntity book;
  final Color coverColor;
  final String coverMark;
  final VoidCallback onTap;
  final bool showNewBadge;
  final double? progress;

  static const double _coverRadius = ShelfDesignTokens.homeGridCoverRadius;

  @override
  Widget build(BuildContext context) {
    final coverBytes = CoverImageCache.decode(book.coverUrl);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_coverRadius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_coverRadius),
        child: AspectRatio(
          aspectRatio: CommonDesignTokens.coverAspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (coverBytes != null)
                Image.memory(
                  coverBytes,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _buildFallbackCover(),
                )
              else
                _buildFallbackCover(),
              if (showNewBadge)
                const Positioned(top: 8, right: 8, child: LibraryNewBadge()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackCover() {
    final textColor = _coverTextColor(coverColor);

    return Container(
      color: coverColor,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            book.title,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
              height: 1.2,
            ),
          ),
          if (book.author.isNotEmpty && book.author != 'Unknown') ...[
            const SizedBox(height: 6),
            Text(
              book.author,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textColor.withValues(alpha: 0.7),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _coverTextColor(Color cover) {
    if (cover == CommonDesignTokens.coverNeon ||
        cover == CommonDesignTokens.coverGray) {
      return CommonDesignTokens.coverTextDark;
    }
    return CommonDesignTokens.coverTextLight;
  }
}
