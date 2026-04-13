import 'package:flutter/material.dart';

import '../../entities/explain-history-entity.dart';
import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/shelf-design-tokens.dart';

class LibraryWordsCard extends StatelessWidget {
  const LibraryWordsCard({
    this.preview,
    this.expanded = false,
    this.onTap,
    super.key,
  });

  final ExplainHistoryEntity? preview;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (expanded) return _buildExpandedLayout();
    return _buildCompactLayout();
  }

  // ── Compact (phone) ──────────────────────────────────────────────

  Widget _buildCompactLayout() {
    final hasPreview = preview != null;
    final previewText = _previewText(preview);
    final showSelectedTextHeader =
        hasPreview &&
        preview!.selectedText.trim().isNotEmpty &&
        preview!.selectedText.trim() != previewText;

    final card = Container(
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

    if (preview == null || onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey<String>('words-section-card-tap-target'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          ShelfDesignTokens.wordOfDayCardRadius,
        ),
        child: card,
      ),
    );
  }

  // ── Expanded (tablet) ────────────────────────────────────────────

  Widget _buildExpandedLayout() {
    final hasPreview = preview != null;
    final previewText = _previewText(preview);

    final card = Container(
      key: const ValueKey<String>('words-section-card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ShelfDesignTokens.wordOfDayCardBg,
        borderRadius: BorderRadius.circular(
          ShelfDesignTokens.wordOfDayCardRadius,
        ),
      ),
      child: hasPreview
          ? _buildExpandedContent(preview!, previewText)
          : _buildExpandedEmpty(),
    );

    if (!hasPreview || onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey<String>('words-section-card-tap-target'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          ShelfDesignTokens.wordOfDayCardRadius,
        ),
        child: card,
      ),
    );
  }

  Widget _buildExpandedEmpty() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.menu_book_rounded,
              size: 18,
              color: ShelfDesignTokens.wordOfDayIconColor,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Start building your words list',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: CommonDesignTokens.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Select a word in Reader and tap Explain.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: CommonDesignTokens.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedContent(
    ExplainHistoryEntity preview,
    String previewText,
  ) {
    final structured = preview.structuredData;
    final meaning = structured?.meaningExplain ?? preview.previewMeaning;
    final details = structured?.detailExplain ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Word title with icon
        Row(
          children: <Widget>[
            Icon(
              Icons.auto_awesome,
              size: 18,
              color: ShelfDesignTokens.wordOfDayIconColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                preview.selectedText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: CommonDesignTokens.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Context sentence
        RichText(
          key: const ValueKey<String>('words-preview-rich-text'),
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: CommonDesignTokens.textPrimary,
            ),
            children: _buildPreviewSpans(preview, previewText),
          ),
        ),
        // Divider
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Container(height: 1, color: ShelfDesignTokens.wordOfDayIconBg),
        ),
        // Meaning
        Text(
          meaning,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: CommonDesignTokens.textPrimary,
          ),
        ),
        // Detail points
        if (details.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final detail in details.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '·  ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ShelfDesignTokens.wordOfDayIconColor,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: CommonDesignTokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        // Divider + book source
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Container(height: 1, color: ShelfDesignTokens.wordOfDayIconBg),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Icon(
              Icons.book_outlined,
              size: 13,
              color: CommonDesignTokens.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                preview.bookTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CommonDesignTokens.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Shared helpers ───────────────────────────────────────────────

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
