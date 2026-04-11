import 'package:flutter/material.dart';

import '../../../pages/reader/models/reader_annotation_card_item.dart';
import '../../../shared/constants/common-design-tokens.dart';

class ReaderAnnotationCard extends StatelessWidget {
  const ReaderAnnotationCard({
    super.key,
    required this.item,
    required this.timestampText,
    required this.onTap,
  });

  static const _cardBg = Color(0xFFF8F6F2);
  static const _cardBorder = Color(0xFFE8E4DF);

  final ReaderAnnotationCardItem item;
  final String timestampText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cardBorder),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.annotation.quoteText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: CommonDesignTokens.textPrimary,
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (item.latestNoteText != null) ...[
              const SizedBox(height: 8),
              Text(
                item.latestNoteText!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: CommonDesignTokens.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (item.noteCount > 0) ...[
                  Icon(
                    Icons.sticky_note_2_outlined,
                    size: 13,
                    color: CommonDesignTokens.headerLabelColor,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${item.noteCount}',
                    style: const TextStyle(
                      color: CommonDesignTokens.headerLabelColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '·',
                    style: TextStyle(
                      color: CommonDesignTokens.headerLabelColor,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  timestampText,
                  style: const TextStyle(
                    color: CommonDesignTokens.headerLabelColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
