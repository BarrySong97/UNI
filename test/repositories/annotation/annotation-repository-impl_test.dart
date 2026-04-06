import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/annotation-entity.dart';
import 'package:uni/repositories/annotation/annotation-repository-impl.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/daos/annotations-dao.dart';

void main() {
  test('create and list annotation maps dto/entity correctly', () async {
    final repository = AnnotationRepositoryImpl(
      annotationsDao: AnnotationsDao(database: AppDatabase()),
    );

    final now = DateTime.now();
    final entity = AnnotationEntity(
      id: 'a1',
      bookId: 'b1',
      kind: AnnotationKind.mark,
      quoteText: 'selected text',
      anchorJson:
          '{"version":1,"parserVersion":3,"segments":[],"jumpTarget":{"chapterIndex":0,"chapterHref":"Text/ch0.xhtml","blockIndex":1,"offset":0}}',
      color: '#FFE082',
      createdAt: now,
      updatedAt: now,
    );

    await repository.createAnnotation(entity);
    final list = await repository.listByBookId('b1');

    expect(list, hasLength(1));
    expect(list.first.id, 'a1');
    expect(list.first.kind, AnnotationKind.mark);
    expect(list.first.anchorJson, contains('"parserVersion":3'));
  });
}
