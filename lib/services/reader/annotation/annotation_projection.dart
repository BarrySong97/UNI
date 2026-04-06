import '../models/page_layout.dart';
import '../models/render_node.dart';

class BlockElementSlice {
  const BlockElementSlice({
    required this.pageIndexInChapter,
    required this.elementIndex,
    required this.startOffset,
    required this.endOffset,
  });

  final int pageIndexInChapter;
  final int elementIndex;
  final int startOffset;
  final int endOffset;
}

class BlockTextProjection {
  BlockTextProjection({
    required this.chapterIndex,
    required this.sourceNode,
    required this.blockIndex,
    required this.rawText,
  });

  final int chapterIndex;
  final RenderNode sourceNode;
  final int blockIndex;
  final String rawText;
  final List<BlockElementSlice> slices = [];
}

Map<int, BlockTextProjection> buildChapterBlockProjections(
  ChapterPagination pagination,
) {
  final projections = <int, BlockTextProjection>{};
  final searchCursorByBlock = <int, int>{};

  for (final page in pagination.pages) {
    for (
      var elementIndex = 0;
      elementIndex < page.elements.length;
      elementIndex++
    ) {
      final element = page.elements[elementIndex];
      if (!element.hasText) {
        continue;
      }

      final blockIndex = renderNodeBlockIndex(element.sourceNode);
      if (blockIndex == null) {
        continue;
      }

      final text = _layoutElementText(element);
      if (text.isEmpty) {
        continue;
      }

      final projection = projections.putIfAbsent(
        blockIndex,
        () => BlockTextProjection(
          chapterIndex: pagination.chapterIndex,
          sourceNode: element.sourceNode,
          blockIndex: blockIndex,
          rawText: renderNodePlainText(element.sourceNode),
        ),
      );
      if (projection.rawText.isEmpty) {
        continue;
      }

      final cursor = searchCursorByBlock[blockIndex] ?? 0;
      final matchStart = _findFragmentStart(
        rawText: projection.rawText,
        fragmentText: text,
        searchStart: cursor,
      );
      if (matchStart == null) {
        continue;
      }

      final matchEnd = matchStart + text.length;
      searchCursorByBlock[blockIndex] = matchEnd;
      projection.slices.add(
        BlockElementSlice(
          pageIndexInChapter: page.pageIndexInChapter,
          elementIndex: elementIndex,
          startOffset: matchStart,
          endOffset: matchEnd,
        ),
      );
    }
  }

  return projections;
}

String layoutElementPlainText(LayoutElement element) =>
    _layoutElementText(element);

BlockElementSlice? findBlockSlice(
  BlockTextProjection projection,
  int pageIndexInChapter,
  int elementIndex,
) {
  for (final slice in projection.slices) {
    if (slice.pageIndexInChapter == pageIndexInChapter &&
        slice.elementIndex == elementIndex) {
      return slice;
    }
  }
  return null;
}

String _layoutElementText(LayoutElement element) {
  final painter = element.ensurePainter();
  final text = painter?.text?.toPlainText() ?? '';
  return text;
}

int? _findFragmentStart({
  required String rawText,
  required String fragmentText,
  required int searchStart,
}) {
  final direct = rawText.indexOf(fragmentText, searchStart);
  if (direct >= 0) {
    return direct;
  }
  final fallback = rawText.indexOf(fragmentText);
  if (fallback >= 0) {
    return fallback;
  }
  return null;
}
