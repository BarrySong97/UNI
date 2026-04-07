import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/annotation-entity.dart';
import 'package:uni/services/reader/annotation/annotation_models.dart';
import 'package:uni/services/reader/annotation/annotation_overlap_detector.dart';

void main() {
  AnnotationAnchorV1 anchor({
    required int start,
    required int end,
    int chapterIndex = 0,
    int blockIndex = 1,
  }) {
    return AnnotationAnchorV1(
      parserVersion: 4,
      segments: <AnnotationAnchorSegment>[
        AnnotationAnchorSegment(
          chapterIndex: chapterIndex,
          chapterHref: 'Text/ch$chapterIndex.xhtml',
          blockIndex: blockIndex,
          startOffset: start,
          endOffset: end,
          quoteText: 'quote',
          prefixText: '',
          suffixText: '',
          blockTextHash: 'hash',
        ),
      ],
      jumpTarget: AnnotationJumpTarget(
        chapterIndex: chapterIndex,
        chapterHref: 'Text/ch$chapterIndex.xhtml',
        blockIndex: blockIndex,
        offset: start,
      ),
    );
  }

  AnnotationEntity entity(String id, AnnotationAnchorV1 anchor) {
    final now = DateTime(2024, 1, 1);
    return AnnotationEntity(
      id: id,
      bookId: 'book-1',
      kind: AnnotationKind.mark,
      style: AnnotationStyle.highlight,
      quoteText: 'quote',
      anchorJson: anchor.encode(),
      color: '#FFE08A',
      createdAt: now,
      updatedAt: now,
    );
  }

  test('detects duplicate marks', () {
    final existing = entity('a1', anchor(start: 10, end: 20));
    final decision = detectAnnotationOverlap(
      candidate: anchor(start: 10, end: 20),
      existingAnnotations: <AnnotationEntity>[existing],
    );

    expect(decision, AnnotationOverlapDecision.duplicate);
  });

  test('detects partial overlap', () {
    final existing = entity('a1', anchor(start: 10, end: 20));
    final decision = detectAnnotationOverlap(
      candidate: anchor(start: 18, end: 24),
      existingAnnotations: <AnnotationEntity>[existing],
    );

    expect(decision, AnnotationOverlapDecision.overlap);
  });

  test('allows disjoint marks', () {
    final existing = entity('a1', anchor(start: 10, end: 20));
    final decision = detectAnnotationOverlap(
      candidate: anchor(start: 21, end: 30),
      existingAnnotations: <AnnotationEntity>[existing],
    );

    expect(decision, AnnotationOverlapDecision.none);
  });

  test('findOverlappingAnnotations returns all matched marks', () {
    final existing = <AnnotationEntity>[
      entity('a1', anchor(start: 10, end: 20)),
      entity('a2', anchor(start: 30, end: 40)),
    ];

    final matches = findOverlappingAnnotations(
      candidate: anchor(start: 15, end: 35),
      existingAnnotations: existing,
    );

    expect(matches.map((item) => item.id), <String>['a1', 'a2']);
  });
}
