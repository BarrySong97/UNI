import 'package:flutter/material.dart';

import '../../entities/book-entity.dart';
import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/shelf-design-tokens.dart';
import '../../shared/utils/cover-image-cache.dart';

class NowReadingCard extends StatelessWidget {
  const NowReadingCard({
    required this.book,
    required this.progress,
    required this.onContinueTap,
    super.key,
  });

  final BookEntity book;
  final double progress;
  final VoidCallback onContinueTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CommonDesignTokens.cardBg,
        borderRadius: BorderRadius.circular(CommonDesignTokens.cardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildCover(),
          const SizedBox(width: 16),
          Expanded(child: _buildInfo()),
        ],
      ),
    );
  }

  Widget _buildCover() {
    final coverBytes = CoverImageCache.decode(book.coverUrl);

    return Container(
      width: ShelfDesignTokens.nowReadingCoverWidth,
      height: ShelfDesignTokens.nowReadingCoverHeight,
      decoration: BoxDecoration(
        color: ShelfDesignTokens.nowReadingCoverPlaceholderBg,
        borderRadius: BorderRadius.circular(
          ShelfDesignTokens.nowReadingCoverRadius,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: coverBytes != null
          ? Image.memory(
              coverBytes,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildFallbackCover(),
            )
          : _buildFallbackCover(),
    );
  }

  Widget _buildFallbackCover() {
    return Container(
      color: CommonDesignTokens.coverBlack,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            book.title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          if (book.author.isNotEmpty && book.author != 'Unknown')
            Text(
              book.author.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w500,
                color: Color(0xFFAAAAAA),
                letterSpacing: 0.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: CommonDesignTokens.textPrimary,
            height: 1.2,
          ),
        ),
        if (book.author.isNotEmpty && book.author != 'Unknown') ...[
          const SizedBox(height: 4),
          Text(
            'by ${book.author}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: CommonDesignTokens.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: onContinueTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: ShelfDesignTokens.continueButtonBg,
                borderRadius: BorderRadius.circular(
                  ShelfDesignTokens.continueButtonRadius,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const <Widget>[
                  Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ShelfDesignTokens.continueButtonText,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: ShelfDesignTokens.continueButtonText,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
