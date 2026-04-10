import 'package:flutter/material.dart';

import '../../entities/explain-history-entity.dart';
import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/shelf-design-tokens.dart';

class LibraryWordsCard extends StatelessWidget {
  const LibraryWordsCard({this.preview, super.key});

  final ExplainHistoryEntity? preview;

  @override
  Widget build(BuildContext context) {
    final hasPreview = preview != null;
    final previewText = _previewText(preview);
    final showSelectedTextHeader =
        hasPreview &&
        preview!.selectedText.trim().isNotEmpty &&
        preview!.selectedText.trim() != previewText;

    return Container(
      key: const ValueKey<String>('words-section-card'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ShelfDesignTokens.wordOfDayCardBg,
        borderRadius: BorderRadius.circular(
          ShelfDesignTokens.wordOfDayCardRadius,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ShelfDesignTokens.wordOfDayIconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              hasPreview ? Icons.auto_awesome : Icons.menu_book_rounded,
              size: 20,
              color: ShelfDesignTokens.wordOfDayIconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (hasPreview && showSelectedTextHeader)
                  Text(
                    preview!.selectedText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: CommonDesignTokens.textPrimary,
                    ),
                  )
                else if (!hasPreview)
                  const Text(
                    'Start building your words list',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CommonDesignTokens.textPrimary,
                    ),
                  ),
                if (hasPreview && showSelectedTextHeader)
                  const SizedBox(height: 4),
                if (hasPreview)
                  RichText(
                    key: const ValueKey<String>('words-preview-rich-text'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: CommonDesignTokens.textPrimary,
                      ),
                      children: _buildPreviewSpans(preview!, previewText),
                    ),
                  )
                else
                  const Text(
                    'Select a word in Reader and tap Explain.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: CommonDesignTokens.textSecondary,
                    ),
                  ),
                if (hasPreview) ...[
                  const SizedBox(height: 8),
                  Text(
                    preview!.bookTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: CommonDesignTokens.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _buildPreviewSpans(
    ExplainHistoryEntity preview,
    String previewText,
  ) {
    final selectedText = preview.selectedText.trim();
    if (selectedText.isEmpty) {
      return <InlineSpan>[TextSpan(text: previewText)];
    }

    final lowerText = previewText.toLowerCase();
    final lowerSelected = selectedText.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerSelected);

    if (matchIndex < 0) {
      return <InlineSpan>[TextSpan(text: previewText)];
    }

    final endIndex = matchIndex + selectedText.length;
    return <InlineSpan>[
      if (matchIndex > 0) TextSpan(text: previewText.substring(0, matchIndex)),
      TextSpan(
        text: previewText.substring(matchIndex, endIndex),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: ShelfDesignTokens.wordOfDayIconColor,
        ),
      ),
      if (endIndex < previewText.length)
        TextSpan(text: previewText.substring(endIndex)),
    ];
  }

  String _previewText(ExplainHistoryEntity? preview) {
    if (preview == null) {
      return 'Select a word in Reader and tap Explain.';
    }

    final contextSentence = preview.contextSentence.trim();
    if (contextSentence.isNotEmpty) {
      return contextSentence;
    }
    return preview.selectedText.trim();
  }
}
