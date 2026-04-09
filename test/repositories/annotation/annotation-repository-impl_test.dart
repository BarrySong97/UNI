import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/annotation-entity.dart';
import 'package:uni/repositories/annotation/annotation-repository-impl.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/daos/annotation-notes-dao.dart';
import 'package:uni/services/db/daos/annotations-dao.dart';

void main() {
  test('create and list annotation maps dto/entity correctly', () async {
    final database = AppDatabase();
    final repository = AnnotationRepositoryImpl(
      annotationsDao: AnnotationsDao(database: database),
      annotationNotesDao: AnnotationNotesDao(database: database),
    );

    final now = DateTime.now();
    final entity = AnnotationEntity(
      id: 'a1',
      bookId: 'b1',
      kind: AnnotationKind.mark,
      style: AnnotationStyle.underline,
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
    expect(list.first.style, AnnotationStyle.underline);
    expect(list.first.anchorJson, contains('"parserVersion":3'));
  });

  test('updateAppearance updates color and style', () async {
    final database = AppDatabase();
    final repository = AnnotationRepositoryImpl(
      annotationsDao: AnnotationsDao(database: database),
      annotationNotesDao: AnnotationNotesDao(database: database),
    );

    final now = DateTime.now();
    await repository.createAnnotation(
      AnnotationEntity(
        id: 'a1',
        bookId: 'b1',
        kind: AnnotationKind.mark,
        style: AnnotationStyle.highlight,
        quoteText: 'selected text',
        anchorJson:
            '{"version":1,"parserVersion":3,"segments":[],"jumpTarget":{"chapterIndex":0,"chapterHref":"Text/ch0.xhtml","blockIndex":1,"offset":0}}',
        color: '#FFE082',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final updated = await repository.updateAppearance(
      annotationId: 'a1',
      color: '#90CAF9',
      style: AnnotationStyle.underline,
    );

    expect(updated.color, '#90CAF9');
    expect(updated.style, AnnotationStyle.underline);
    expect(
      updated.updatedAt.millisecondsSinceEpoch >= now.millisecondsSinceEpoch,
      isTrue,
    );
  });

  test('createNote updates latest note and lists note timeline', () async {
    final database = AppDatabase();
    final repository = AnnotationRepositoryImpl(
      annotationsDao: AnnotationsDao(database: database),
      annotationNotesDao: AnnotationNotesDao(database: database),
    );

    final now = DateTime.now();
    await repository.createAnnotation(
      AnnotationEntity(
        id: 'a1',
        bookId: 'b1',
        kind: AnnotationKind.mark,
        style: AnnotationStyle.highlight,
        quoteText: 'selected text',
        anchorJson:
            '{"version":1,"parserVersion":3,"segments":[],"jumpTarget":{"chapterIndex":0,"chapterHref":"Text/ch0.xhtml","blockIndex":1,"offset":0}}',
        color: '#FFE082',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final result = await repository.createNote(
      annotationId: 'a1',
      bookId: 'b1',
      text: 'first note',
    );

    final notes = await repository.listNotesByAnnotationId('a1');
    final annotations = await repository.listByBookId('b1');

    expect(result.note.text, 'first note');
    expect(notes, hasLength(1));
    expect(notes.single.text, 'first note');
    expect(annotations.single.note, 'first note');
    expect(
      annotations.single.updatedAt.millisecondsSinceEpoch >=
          now.millisecondsSinceEpoch,
      isTrue,
    );
  });
}
