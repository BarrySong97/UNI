import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/annotation-entity.dart';
import 'package:uni/services/reader/annotation/annotation_models.dart';
import 'package:uni/services/reader/annotation/annotation_text_utils.dart';
import 'package:uni/services/reader/annotation/reader_annotation_resolver.dart';
import 'package:uni/services/reader/models/page_layout.dart';
import 'package:uni/services/reader/models/render_node.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final resolver = const ReaderAnnotationResolver();

  test('resolver restores exact block offsets', () {
    final pagination = _singlePagePagination(
      chapterIndex: 0,
      blockIndex: 7,
      text: 'hello world again',
    );
    final annotation = _buildAnnotation(
      blockIndex: 7,
      startOffset: 6,
      endOffset: 11,
      quoteText: 'world',
      prefixText: 'hello ',
      suffixText: ' again',
      blockText: 'hello world again',
    );

    final resolved = resolver.resolveChapterAnnotations(
      pagination: pagination,
      annotations: <AnnotationEntity>[annotation],
    );

    expect(resolved, hasLength(1));
    expect(resolved.first.pageIndexInChapter, 0);
    expect(resolved.first.pageSelection.start.charOffset, 6);
    expect(resolved.first.pageSelection.end.charOffset, 11);
  });

  test(
    'resolver falls back to same chapter search when block index drifts',
    () {
      final pagination = _singlePagePagination(
        chapterIndex: 0,
        blockIndex: 3,
        text: 'alpha beta gamma',
      );
      final annotation = _buildAnnotation(
        blockIndex: 99,
        startOffset: 0,
        endOffset: 1,
        quoteText: 'beta',
        prefixText: 'alpha ',
        suffixText: ' gamma',
        blockText: 'alpha beta gamma',
      );

      final resolved = resolver.resolveChapterAnnotations(
        pagination: pagination,
        annotations: <AnnotationEntity>[annotation],
      );

      expect(resolved, hasLength(1));
      expect(resolved.first.pageSelection.start.charOffset, 6);
      expect(resolved.first.pageSelection.end.charOffset, 10);
    },
  );
}

AnnotationEntity _buildAnnotation({
  required int blockIndex,
  required int startOffset,
  required int endOffset,
  required String quoteText,
  required String prefixText,
  required String suffixText,
  required String blockText,
}) {
  final anchor = AnnotationAnchorV1(
    parserVersion: 3,
    segments: <AnnotationAnchorSegment>[
      AnnotationAnchorSegment(
        chapterIndex: 0,
        chapterHref: 'Text/ch0.xhtml',
        blockIndex: blockIndex,
        startOffset: startOffset,
        endOffset: endOffset,
        quoteText: quoteText,
        prefixText: prefixText,
        suffixText: suffixText,
        blockTextHash: hashNormalizedText(blockText),
      ),
    ],
    jumpTarget: AnnotationJumpTarget(
      chapterIndex: 0,
      chapterHref: 'Text/ch0.xhtml',
      blockIndex: blockIndex,
      offset: startOffset,
    ),
  );

  final now = DateTime.now();
  return AnnotationEntity(
    id: 'ann-1',
    bookId: 'book-1',
    kind: AnnotationKind.mark,
    quoteText: quoteText,
    anchorJson: anchor.encode(),
    color: '#FFE082',
    createdAt: now,
    updatedAt: now,
  );
}

ChapterPagination _singlePagePagination({
  required int chapterIndex,
  required int blockIndex,
  required String text,
}) {
  final sourceNode = ParagraphNode(
    blockIndex: blockIndex,
    children: <RenderNode>[TextNode(content: text)],
  );
  final painter = TextPainter(
    text: TextSpan(text: text),
    textDirection: TextDirection.ltr,
  )..layout();
  final page = PageLayout(
    chapterIndex: chapterIndex,
    pageIndexInChapter: 0,
    elements: <LayoutElement>[
      LayoutElement(
        rect: const Rect.fromLTWH(0, 0, 100, 20),
        sourceNode: sourceNode,
        textPainter: painter,
      ),
    ],
  );
  return ChapterPagination(
    chapterIndex: chapterIndex,
    pages: <PageLayout>[page],
    viewportSize: const Size(320, 480),
    preferencesHash: 1,
  );
}
