import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../entities/book-entity.dart';
import '../../shared/constants/library-design-tokens.dart';

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
        color: LibraryDesignTokens.nowReadingCardBg,
        borderRadius: BorderRadius.circular(LibraryDesignTokens.nowReadingCardRadius),
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
    final coverBytes = _decodeCoverDataUrl(book.coverUrl);

    return Container(
      width: LibraryDesignTokens.nowReadingCoverWidth,
      height: LibraryDesignTokens.nowReadingCoverHeight,
      decoration: BoxDecoration(
        color: LibraryDesignTokens.nowReadingCoverPlaceholderBg,
        borderRadius: BorderRadius.circular(LibraryDesignTokens.nowReadingCoverRadius),
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
      color: LibraryDesignTokens.coverBlack,
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
    final progressPercent = (progress * 100).round();

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
            color: LibraryDesignTokens.textPrimary,
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
              color: LibraryDesignTokens.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Text(
              'Chapter',
              style: TextStyle(
                fontSize: 13,
                color: LibraryDesignTokens.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '$progressPercent%',
              style: TextStyle(
                fontSize: 13,
                color: LibraryDesignTokens.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: LibraryDesignTokens.nowReadingProgressBg,
            valueColor: const AlwaysStoppedAnimation<Color>(
              LibraryDesignTokens.nowReadingProgressFill,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: onContinueTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: LibraryDesignTokens.continueButtonBg,
                borderRadius: BorderRadius.circular(LibraryDesignTokens.continueButtonRadius),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const <Widget>[
                  Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: LibraryDesignTokens.continueButtonText,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: LibraryDesignTokens.continueButtonText,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Uint8List? _decodeCoverDataUrl(String? dataUrl) {
    if (dataUrl == null || !dataUrl.startsWith('data:image/')) {
      return null;
    }
    const marker = ';base64,';
    final markerIndex = dataUrl.indexOf(marker);
    if (markerIndex <= 0 || markerIndex + marker.length >= dataUrl.length) {
      return null;
    }
    final payload = dataUrl.substring(markerIndex + marker.length);
    try {
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }
}
