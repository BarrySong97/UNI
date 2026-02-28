class HighlightAnchor {
  const HighlightAnchor({
    required this.selectedText,
    required this.prefixContext,
    required this.suffixContext,
  });

  final String selectedText;
  final String prefixContext;
  final String suffixContext;
}

class HighlightAnchorService {
  HighlightAnchor createAnchor({
    required String chapterText,
    required int start,
    required int end,
    int contextWindow = 24,
  }) {
    final safeStart = start.clamp(0, chapterText.length).toInt();
    final safeEnd = end.clamp(safeStart, chapterText.length).toInt();
    final prefixStart = (safeStart - contextWindow).clamp(0, safeStart).toInt();
    final suffixEnd = (safeEnd + contextWindow).clamp(safeEnd, chapterText.length).toInt();

    return HighlightAnchor(
      selectedText: chapterText.substring(safeStart, safeEnd),
      prefixContext: chapterText.substring(prefixStart, safeStart),
      suffixContext: chapterText.substring(safeEnd, suffixEnd),
    );
  }
}
