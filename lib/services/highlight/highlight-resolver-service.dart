import '../../entities/highlight-entity.dart';

class HighlightResolverService {
  List<HighlightEntity> sortForRender(List<HighlightEntity> highlights) {
    final sorted = List<HighlightEntity>.from(highlights)
      ..sort((a, b) {
        final startCompare = a.startOffset.compareTo(b.startOffset);
        if (startCompare != 0) {
          return startCompare;
        }
        return a.updatedAt.compareTo(b.updatedAt);
      });
    return sorted;
  }

  ({int start, int end}) relocateByContext({
    required String chapterText,
    required HighlightEntity highlight,
  }) {
    final safeStart = highlight.startOffset;
    final safeEnd = highlight.endOffset;
    if (safeStart >= 0 && safeEnd <= chapterText.length && safeEnd > safeStart) {
      final selected = chapterText.substring(safeStart, safeEnd);
      if (selected == highlight.selectedText) {
        return (start: safeStart, end: safeEnd);
      }
    }

    final candidate = '${highlight.prefixContext}${highlight.selectedText}${highlight.suffixContext}';
    final idx = chapterText.indexOf(candidate);
    if (idx >= 0) {
      final start = idx + highlight.prefixContext.length;
      return (start: start, end: start + highlight.selectedText.length);
    }

    final fallbackIdx = chapterText.indexOf(highlight.selectedText);
    if (fallbackIdx >= 0) {
      return (start: fallbackIdx, end: fallbackIdx + highlight.selectedText.length);
    }

    return (start: highlight.startOffset, end: highlight.endOffset);
  }
}
