import 'package:flutter/material.dart';

import '../../../pages/reader/models/reader_annotation_card_item.dart';
import '../../../services/reader/annotation/annotation_text_utils.dart';

class ReaderAnnotationCard extends StatelessWidget {
  const ReaderAnnotationCard({
    super.key,
    required this.item,
    required this.timestampText,
    required this.onTap,
    required this.onGoToLocation,
  });

  final ReaderAnnotationCardItem item;
  final String timestampText;
  final VoidCallback onTap;
  final VoidCallback onGoToLocation;

  @override
  Widget build(BuildContext context) {
    final accent = annotationColorFromHex(item.annotation.color, alpha: 1);
    final quoteBg = annotationColorFromHex(item.annotation.color, alpha: 0.18);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.chapterTitle.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                color: quoteBg,
                borderRadius: BorderRadius.circular(16),
                border: Border(left: BorderSide(color: accent, width: 4)),
              ),
              child: Text(
                item.annotation.quoteText,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 17,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: quoteBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.edit_outlined, color: accent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.latestNoteText ?? 'No notes yet',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: item.latestNoteText == null
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF4B5563),
                          fontSize: 15,
                          height: 1.45,
                          fontWeight: item.latestNoteText == null
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.noteCount == 1
                            ? '1 note'
                            : '${item.noteCount} notes',
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  timestampText,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onGoToLocation,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFEFF6FF),
                    foregroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Go to location →'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
