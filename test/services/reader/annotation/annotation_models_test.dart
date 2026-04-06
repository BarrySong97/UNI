import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/reader/annotation/annotation_models.dart';

void main() {
  test('annotation anchor v1 encodes and decodes', () {
    const anchor = AnnotationAnchorV1(
      parserVersion: 3,
      segments: <AnnotationAnchorSegment>[
        AnnotationAnchorSegment(
          chapterIndex: 2,
          chapterHref: 'Text/ch2.xhtml',
          blockIndex: 17,
          startOffset: 4,
          endOffset: 9,
          quoteText: 'world',
          prefixText: 'hello ',
          suffixText: ' again',
          blockTextHash: 'abc123',
        ),
      ],
      jumpTarget: AnnotationJumpTarget(
        chapterIndex: 2,
        chapterHref: 'Text/ch2.xhtml',
        blockIndex: 17,
        offset: 4,
      ),
    );

    final decoded = AnnotationAnchorV1.tryParse(anchor.encode());

    expect(decoded, isNotNull);
    expect(decoded!.parserVersion, 3);
    expect(decoded.segments, hasLength(1));
    expect(decoded.segments.first.blockIndex, 17);
    expect(decoded.segments.first.quoteText, 'world');
    expect(decoded.jumpTarget.offset, 4);
  });
}
