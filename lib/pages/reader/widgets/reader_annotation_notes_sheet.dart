import 'package:flutter/material.dart';

import '../../../pages/reader/models/reader_annotation_card_item.dart';
import '../../../services/reader/annotation/annotation_text_utils.dart';
import '../../../shared/constants/common-design-tokens.dart';
import '../../../shared/constants/shelf-design-tokens.dart';

class ReaderAnnotationNotesSheet extends StatelessWidget {
  const ReaderAnnotationNotesSheet({
    super.key,
    required this.item,
    required this.onBack,
    required this.onAddNote,
    required this.onGoToLocation,
    required this.formatTimestamp,
  });

  final ReaderAnnotationCardItem item;
  final VoidCallback onBack;
  final VoidCallback onAddNote;
  final VoidCallback onGoToLocation;
  final String Function(DateTime value) formatTimestamp;

  @override
  Widget build(BuildContext context) {
    final accent = annotationColorFromHex(item.annotation.color, alpha: 1);
    final quoteBg = annotationColorFromHex(item.annotation.color, alpha: 0.18);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: CommonDesignTokens.textPrimary,
              ),
              Expanded(
                child: Text(
                  item.chapterTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: CommonDesignTokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: quoteBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border(left: BorderSide(color: accent, width: 4)),
                ),
                child: Text(
                  item.annotation.quoteText,
                  style: const TextStyle(
                    color: CommonDesignTokens.textPrimary,
                    fontSize: 16,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (item.notes.isEmpty)
                const Text(
                  'No notes yet.',
                  style: TextStyle(
                    color: CommonDesignTokens.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else
                for (final note in item.notes) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ShelfDesignTokens.statsCardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: CommonDesignTokens.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.text,
                          style: const TextStyle(
                            color: CommonDesignTokens.textPrimary,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          formatTimestamp(note.createdAt),
                          style: const TextStyle(
                            color: CommonDesignTokens.headerLabelColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onAddNote,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CommonDesignTokens.textPrimary,
                    side: const BorderSide(color: CommonDesignTokens.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Add Note'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: onGoToLocation,
                  style: TextButton.styleFrom(
                    backgroundColor: ShelfDesignTokens.statsCardBg,
                    foregroundColor: ShelfDesignTokens.statsNumberColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Go to location →'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
