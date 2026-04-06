import '../../../entities/annotation-entity.dart';
import '../models/page_layout.dart';
import '../selection/page_hit_test.dart';
import 'annotation_models.dart';
import 'annotation_projection.dart';
import 'annotation_text_utils.dart';

class ReaderAnnotationResolver {
  const ReaderAnnotationResolver();

  List<ResolvedAnnotationSegment> resolveChapterAnnotations({
    required ChapterPagination pagination,
    required Iterable<AnnotationEntity> annotations,
  }) {
    final projections = buildChapterBlockProjections(pagination);
    final resolved = <ResolvedAnnotationSegment>[];

    for (final annotation in annotations) {
      final anchor = AnnotationAnchorV1.tryParse(annotation.anchorJson);
      if (anchor == null) {
        continue;
      }

      for (final segment in anchor.segments) {
        if (segment.chapterIndex != pagination.chapterIndex) {
          continue;
        }

        final resolution = _resolveSegment(
          segment: segment,
          projections: projections,
        );
        if (resolution == null) {
          continue;
        }

        resolved.addAll(
          _projectToPages(
            annotationId: annotation.id,
            color: annotation.color,
            pagination: pagination,
            projection: resolution.projection,
            rawStart: resolution.startOffset,
            rawEnd: resolution.endOffset,
          ),
        );
      }
    }

    return resolved;
  }

  _ResolvedRawRange? _resolveSegment({
    required AnnotationAnchorSegment segment,
    required Map<int, BlockTextProjection> projections,
  }) {
    final exactProjection = projections[segment.blockIndex];
    if (exactProjection != null) {
      final exact = _tryExactResolve(exactProjection, segment);
      if (exact != null) {
        return exact;
      }

      final sameBlock = _findBestOccurrence(
        segment: segment,
        candidates: <BlockTextProjection>[exactProjection],
      );
      if (sameBlock != null) {
        return sameBlock;
      }
    }

    return _findBestOccurrence(
      segment: segment,
      candidates: projections.values,
    );
  }

  _ResolvedRawRange? _tryExactResolve(
    BlockTextProjection projection,
    AnnotationAnchorSegment segment,
  ) {
    if (projection.rawText.isEmpty) {
      return null;
    }
    if (hashNormalizedText(projection.rawText) != segment.blockTextHash) {
      return null;
    }
    if (segment.startOffset < 0 ||
        segment.endOffset > projection.rawText.length) {
      return null;
    }
    if (segment.startOffset >= segment.endOffset) {
      return null;
    }

    final selected = projection.rawText.substring(
      segment.startOffset,
      segment.endOffset,
    );
    if (normalizeAnnotationText(selected) !=
        normalizeAnnotationText(segment.quoteText)) {
      return null;
    }
    return _ResolvedRawRange(
      projection: projection,
      startOffset: segment.startOffset,
      endOffset: segment.endOffset,
    );
  }

  _ResolvedRawRange? _findBestOccurrence({
    required AnnotationAnchorSegment segment,
    required Iterable<BlockTextProjection> candidates,
  }) {
    final needle = normalizeAnnotationText(segment.quoteText);
    if (needle.isEmpty) {
      return null;
    }

    _ScoredOccurrence? best;
    for (final candidate in candidates) {
      final normalized = NormalizedTextMapping.fromRaw(candidate.rawText);
      final haystack = normalized.normalizedText;
      if (haystack.isEmpty) {
        continue;
      }

      var searchStart = 0;
      while (searchStart <= haystack.length - needle.length) {
        final matchStart = haystack.indexOf(needle, searchStart);
        if (matchStart < 0) {
          break;
        }
        final matchEnd = matchStart + needle.length;
        final prefix = haystack.substring(0, matchStart);
        final suffix = haystack.substring(matchEnd);
        final score = _scoreCandidate(
          candidate: candidate,
          segment: segment,
          prefix: prefix,
          suffix: suffix,
        );
        if (best == null || score > best.score) {
          best = _ScoredOccurrence(
            projection: candidate,
            score: score,
            startOffset: normalized.normalizedToRawBoundary(matchStart),
            endOffset: normalized.normalizedToRawBoundary(matchEnd),
          );
        }
        searchStart = matchStart + 1;
      }
    }

    if (best == null) {
      return null;
    }
    return _ResolvedRawRange(
      projection: best.projection,
      startOffset: best.startOffset,
      endOffset: best.endOffset,
    );
  }

  int _scoreCandidate({
    required BlockTextProjection candidate,
    required AnnotationAnchorSegment segment,
    required String prefix,
    required String suffix,
  }) {
    var score = 0;
    if (candidate.blockIndex == segment.blockIndex) {
      score += 1000;
    }
    score -= (candidate.blockIndex - segment.blockIndex).abs() * 5;
    score += _sharedSuffixLength(prefix, segment.prefixText) * 4;
    score += _sharedPrefixLength(suffix, segment.suffixText) * 4;
    return score;
  }

  int _sharedSuffixLength(String a, String b) {
    final left = truncateNormalizedPrefix(a, 48);
    final right = truncateNormalizedPrefix(b, 48);
    var matched = 0;
    while (matched < left.length &&
        matched < right.length &&
        left[left.length - matched - 1] == right[right.length - matched - 1]) {
      matched += 1;
    }
    return matched;
  }

  int _sharedPrefixLength(String a, String b) {
    final left = truncateNormalizedSuffix(a, 48);
    final right = truncateNormalizedSuffix(b, 48);
    var matched = 0;
    while (matched < left.length &&
        matched < right.length &&
        left[matched] == right[matched]) {
      matched += 1;
    }
    return matched;
  }

  List<ResolvedAnnotationSegment> _projectToPages({
    required String annotationId,
    required String color,
    required ChapterPagination pagination,
    required BlockTextProjection projection,
    required int rawStart,
    required int rawEnd,
  }) {
    final pageStart = <int, PagePosition>{};
    final pageEnd = <int, PagePosition>{};

    for (final slice in projection.slices) {
      if (slice.endOffset <= rawStart || slice.startOffset >= rawEnd) {
        continue;
      }

      final localStart = (rawStart - slice.startOffset).clamp(
        0,
        slice.endOffset - slice.startOffset,
      );
      final localEnd = (rawEnd - slice.startOffset).clamp(
        0,
        slice.endOffset - slice.startOffset,
      );
      if (localStart >= localEnd) {
        continue;
      }

      final pageIndex = slice.pageIndexInChapter;
      pageStart.putIfAbsent(
        pageIndex,
        () => PagePosition(
          elementIndex: slice.elementIndex,
          charOffset: localStart,
        ),
      );
      pageEnd[pageIndex] = PagePosition(
        elementIndex: slice.elementIndex,
        charOffset: localEnd,
      );
    }

    final pageIndexes = pageStart.keys.toList()..sort();
    return pageIndexes
        .map((pageIndex) {
          return ResolvedAnnotationSegment(
            annotationId: annotationId,
            chapterIndex: pagination.chapterIndex,
            pageIndexInChapter: pageIndex,
            pageSelection: PageSelection(
              start: pageStart[pageIndex]!,
              end: pageEnd[pageIndex]!,
            ),
            color: color,
          );
        })
        .toList(growable: false);
  }
}

class _ResolvedRawRange {
  const _ResolvedRawRange({
    required this.projection,
    required this.startOffset,
    required this.endOffset,
  });

  final BlockTextProjection projection;
  final int startOffset;
  final int endOffset;
}

class _ScoredOccurrence {
  const _ScoredOccurrence({
    required this.projection,
    required this.score,
    required this.startOffset,
    required this.endOffset,
  });

  final BlockTextProjection projection;
  final int score;
  final int startOffset;
  final int endOffset;
}
