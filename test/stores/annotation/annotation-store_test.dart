import 'package:flutter_test/flutter_test.dart';
import 'package:uni/repositories/annotation/annotation-repository-impl.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/daos/annotations-dao.dart';
import 'package:uni/services/reader/annotation/annotation_models.dart';
import 'package:uni/stores/annotation/annotation-store.dart';

void main() {
  test('createMark appends and deleteAnnotation removes', () async {
    final repository = AnnotationRepositoryImpl(
      annotationsDao: AnnotationsDao(database: AppDatabase()),
    );
    final store = AnnotationStore(annotationRepository: repository);

    final created = await store.createMark(
      bookId: 'book-1',
      quoteText: 'hello world',
      anchor: const AnnotationAnchorV1(
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
      ),
    );

    expect(store.state.items, hasLength(1));

    await store.deleteAnnotation(created.id);

    expect(store.state.items, isEmpty);
  });
}
