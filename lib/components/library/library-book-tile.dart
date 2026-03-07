import 'dart:convert';
import 'dart:typed_data';

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
    this.progress,
    super.key,
  });

  final BookEntity book;
  final Color coverColor;
  final String coverMark;
  final VoidCallback onTap;
  final bool showNewBadge;
  final double? progress;

  static const double _coverRadius = LibraryDesignTokens.homeGridCoverRadius;

  @override
  Widget build(BuildContext context) {
    final coverBytes = _decodeCoverDataUrl(book.coverUrl);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_coverRadius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_coverRadius),
        child: AspectRatio(
          aspectRatio: LibraryDesignTokens.coverAspectRatio,
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
              if (progress != null && progress! > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xCC000000),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${(progress! * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              else if (showNewBadge)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: LibraryNewBadge(),
                ),
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

  Uint8List? _decodeCoverDataUrl(String? dataUrl) {
    if (dataUrl == null || !dataUrl.startsWith('data:image/')) {
      return null;
    }
    final marker = ';base64,';
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

  Color _coverTextColor(Color cover) {
    if (cover == LibraryDesignTokens.coverNeon ||
        cover == LibraryDesignTokens.coverGray) {
      return LibraryDesignTokens.coverTextDark;
    }
    return LibraryDesignTokens.coverTextLight;
  }
}
