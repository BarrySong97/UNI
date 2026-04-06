import 'package:flutter/foundation.dart';

import '../../../stores/reader/reader_store.dart';
import '../epub_preparse_service.dart';
import '../models/page_layout.dart';
import '../models/render_node.dart';
import '../selection/cross_page_selection.dart';
import '../selection/page_hit_test.dart';
import 'annotation_models.dart';
import 'annotation_projection.dart';
import 'annotation_text_utils.dart';

class SelectionToAnnotationMapper {
  const SelectionToAnnotationMapper();

  AnnotationAnchorV1? map({
    required ReaderStore store,
    required CrossPageSelection selection,
  }) {
    final bookData = store.bookData;
    if (bookData == null) {
      debugPrint('[Mark] Mapper aborted: bookData is null');
      return null;
    }

    final segmentDrafts = <String, _SegmentDraft>{};
    final debugEvents = <String>[];

    for (
      var chapterIndex = selection.start.chapterIndex;
      chapterIndex <= selection.end.chapterIndex;
      chapterIndex++
    ) {
      final pagination = store.getChapterPagination(chapterIndex);
      if (pagination == null) {
        debugEvents.add('chapter=$chapterIndex skipped: pagination is null');
        continue;
      }
      final projections = buildChapterBlockProjections(pagination);
      debugEvents.add(
        'chapter=$chapterIndex projections=${projections.keys.toList()..sort()}',
      );

      for (final page in pagination.pages) {
        if (!selection.containsPage(chapterIndex, page.pageIndexInChapter)) {
          continue;
        }
        final pageSelection = selection.projectOntoPage(page);
        if (pageSelection == null) {
          continue;
        }
        _collectPageSegments(
          chapterHref: bookData.chapters[chapterIndex].href,
          page: page,
          pageSelection: pageSelection,
          projections: projections,
          segmentDrafts: segmentDrafts,
          debugEvents: debugEvents,
        );
      }
    }

    if (segmentDrafts.isEmpty) {
      debugPrint(
        '[Mark] Mapper produced no segments. '
        'chapters=${selection.start.chapterIndex}-${selection.end.chapterIndex}',
      );
      for (final event in debugEvents) {
        debugPrint('[Mark] Mapper detail: $event');
      }
      return null;
    }

    final segments = segmentDrafts.values
        .map((draft) {
          final normalized = normalizeAnnotationText(draft.projection.rawText);
          final normalizedMapping = NormalizedTextMapping.fromRaw(
            draft.projection.rawText,
          );
          final startNormalized = normalizedMapping.rawToNormalizedBoundary(
            draft.startOffset,
          );
          final endNormalized = normalizedMapping.rawToNormalizedBoundary(
            draft.endOffset,
          );
          final prefixStart = (startNormalized - 48).clamp(
            0,
            normalized.length,
          );
          final suffixEnd = (endNormalized + 48).clamp(0, normalized.length);
          final segmentQuote = draft.projection.rawText.substring(
            draft.startOffset,
            draft.endOffset.clamp(
              draft.startOffset,
              draft.projection.rawText.length,
            ),
          );
          return AnnotationAnchorSegment(
            chapterIndex: draft.chapterIndex,
            chapterHref: draft.chapterHref,
            blockIndex: draft.projection.blockIndex,
            startOffset: draft.startOffset,
            endOffset: draft.endOffset,
            quoteText: segmentQuote,
            prefixText: truncateNormalizedPrefix(
              normalized.substring(prefixStart, startNormalized),
              48,
            ),
            suffixText: truncateNormalizedSuffix(
              normalized.substring(endNormalized, suffixEnd),
              48,
            ),
            blockTextHash: hashNormalizedText(draft.projection.rawText),
          );
        })
        .toList(growable: false);

    final first = segments.first;
    return AnnotationAnchorV1(
      parserVersion: EpubPreparseService.currentParserVersion,
      segments: segments,
      jumpTarget: AnnotationJumpTarget(
        chapterIndex: first.chapterIndex,
        chapterHref: first.chapterHref,
        blockIndex: first.blockIndex,
        offset: first.startOffset,
      ),
    );
  }

  void _collectPageSegments({
    required String chapterHref,
    required PageLayout page,
    required PageSelection pageSelection,
    required Map<int, BlockTextProjection> projections,
    required Map<String, _SegmentDraft> segmentDrafts,
    required List<String> debugEvents,
  }) {
    final startIdx = pageSelection.start.elementIndex;
    final endIdx = pageSelection.end.elementIndex;
    debugEvents.add(
      'page=${page.chapterIndex}:${page.pageIndexInChapter} selectionElements=$startIdx-$endIdx',
    );

    for (var elementIndex = startIdx; elementIndex <= endIdx; elementIndex++) {
      if (elementIndex < 0 || elementIndex >= page.elements.length) {
        debugEvents.add(
          'page=${page.chapterIndex}:${page.pageIndexInChapter} element=$elementIndex skipped: out of bounds',
        );
        continue;
      }

      final element = page.elements[elementIndex];
      final blockIndex = renderNodeBlockIndex(element.sourceNode);
      final sourceType = element.sourceNode.runtimeType;
      if (blockIndex == null) {
        debugEvents.add(
          'page=${page.chapterIndex}:${page.pageIndexInChapter} element=$elementIndex source=$sourceType skipped: blockIndex is null',
        );
        continue;
      }

      final projection = projections[blockIndex];
      if (projection == null) {
        debugEvents.add(
          'page=${page.chapterIndex}:${page.pageIndexInChapter} element=$elementIndex source=$sourceType block=$blockIndex skipped: projection missing',
        );
        continue;
      }

      final elementText = layoutElementPlainText(element);
      if (elementText.isEmpty) {
        debugEvents.add(
          'page=${page.chapterIndex}:${page.pageIndexInChapter} element=$elementIndex source=$sourceType block=$blockIndex skipped: elementText empty',
        );
        continue;
      }

      final slice = findBlockSlice(
        projection,
        page.pageIndexInChapter,
        elementIndex,
      );
      if (slice == null) {
        debugEvents.add(
          'page=${page.chapterIndex}:${page.pageIndexInChapter} element=$elementIndex source=$sourceType block=$blockIndex text="$elementText" skipped: slice missing in raw="${projection.rawText}"',
        );
        continue;
      }

      var localStart = 0;
      var localEnd = elementText.length;
      if (elementIndex == startIdx) {
        localStart = pageSelection.start.charOffset.clamp(
          0,
          elementText.length,
        );
      }
      if (elementIndex == endIdx) {
        localEnd = pageSelection.end.charOffset.clamp(0, elementText.length);
      }
      if (localStart >= localEnd) {
        debugEvents.add(
          'page=${page.chapterIndex}:${page.pageIndexInChapter} element=$elementIndex source=$sourceType block=$blockIndex text="$elementText" skipped: localStart($localStart) >= localEnd($localEnd)',
        );
        continue;
      }

      final globalStart = slice.startOffset + localStart;
      final globalEnd = slice.startOffset + localEnd;
      final key = '${page.chapterIndex}:$blockIndex';
      final draft = segmentDrafts.putIfAbsent(
        key,
        () => _SegmentDraft(
          chapterIndex: page.chapterIndex,
          chapterHref: chapterHref,
          projection: projection,
          startOffset: globalStart,
          endOffset: globalEnd,
        ),
      );
      if (globalStart < draft.startOffset) {
        draft.startOffset = globalStart;
      }
      if (globalEnd > draft.endOffset) {
        draft.endOffset = globalEnd;
      }
      debugEvents.add(
        'page=${page.chapterIndex}:${page.pageIndexInChapter} element=$elementIndex source=$sourceType block=$blockIndex accepted: text="$elementText" local=$localStart-$localEnd global=$globalStart-$globalEnd',
      );
    }
  }
}

class _SegmentDraft {
  _SegmentDraft({
    required this.chapterIndex,
    required this.chapterHref,
    required this.projection,
    required this.startOffset,
    required this.endOffset,
  });

  final int chapterIndex;
  final String chapterHref;
  final BlockTextProjection projection;
  int startOffset;
  int endOffset;
}
