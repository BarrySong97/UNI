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
    super.key,
  });

  final BookEntity book;
  final Color coverColor;
  final String coverMark;
  final VoidCallback onTap;
  final bool showNewBadge;

  @override
  Widget build(BuildContext context) {
    final coverBytes = _decodeCoverDataUrl(book.coverUrl);

    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AspectRatio(
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
                if (showNewBadge)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: LibraryNewBadge(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF666666),
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackCover() {
    return Container(
      color: coverColor,
      padding: const EdgeInsets.all(14),
      child: Stack(
        children: <Widget>[
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
    if (cover == LibraryDesignTokens.coverNeon || cover == LibraryDesignTokens.coverGray) {
      return const Color(0xFF111111);
    }
    return const Color(0xFFF4F4F4);
  }
}
