import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/annotation-entity.dart';
import 'package:uni/repositories/annotation/annotation-repository-impl.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/daos/annotations-dao.dart';
import 'package:uni/services/reader/annotation/annotation_models.dart';
import 'package:uni/stores/annotation/annotation-store.dart';

void main() {
  test(
    'createMark defaults to highlight and deleteAnnotation removes',
    () async {
      final repository = AnnotationRepositoryImpl(
        annotationsDao: AnnotationsDao(database: AppDatabase()),
      );
      final store = AnnotationStore(annotationRepository: repository);

      final created = await store.createMark(
        bookId: 'book-1',
        quoteText: 'hello world',
        anchor: _anchor,
      );

      expect(store.state.items, hasLength(1));
      expect(created.style, AnnotationStyle.highlight);

      await store.deleteAnnotation(created.id);

      expect(store.state.items, isEmpty);
    },
  );

  test(
    'createMark accepts underline and updateAnnotationAppearance persists it',
    () async {
      final repository = AnnotationRepositoryImpl(
        annotationsDao: AnnotationsDao(database: AppDatabase()),
      );
      final store = AnnotationStore(annotationRepository: repository);

      final created = await store.createMark(
        bookId: 'book-1',
        quoteText: 'hello world',
        anchor: _anchor,
        style: AnnotationStyle.underline,
        color: '#90CAF9',
      );

      expect(created.style, AnnotationStyle.underline);
      expect(created.color, '#90CAF9');

      final updated = await store.updateAnnotationAppearance(
        annotationId: created.id,
        color: '#A5D6A7',
        style: AnnotationStyle.highlight,
      );

      expect(updated.style, AnnotationStyle.highlight);
      expect(updated.color, '#A5D6A7');
      expect(store.state.items.single.style, AnnotationStyle.highlight);
    },
  );

  test('setSelectedAppearance updates store defaults', () {
    final repository = AnnotationRepositoryImpl(
      annotationsDao: AnnotationsDao(database: AppDatabase()),
    );
    final store = AnnotationStore(annotationRepository: repository);

    store.setSelectedAppearance(
      color: '#CE93D8',
      style: AnnotationStyle.underline,
    );

    expect(store.state.selectedColor, '#CE93D8');
    expect(store.state.selectedStyle, AnnotationStyle.underline);
  });
}

const _anchor = AnnotationAnchorV1(
  parserVersion: 3,
  segments: <AnnotationAnchorSegment>[
    AnnotationAnchorSegment(
      chapterIndex: 0,
      chapterHref: 'Text/ch0.xhtml',
      blockIndex: 1,
      startOffset: 0,
      endOffset: 5,
      quoteText: 'hello',
      prefixText: '',
      suffixText: ' world',
      blockTextHash: 'hash',
    ),
  ],
  jumpTarget: AnnotationJumpTarget(
    chapterIndex: 0,
    chapterHref: 'Text/ch0.xhtml',
    blockIndex: 1,
    offset: 0,
  ),
);
