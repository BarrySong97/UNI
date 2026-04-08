import 'package:flutter_test/flutter_test.dart';
import 'package:uni/dtos/db/annotation-dto.dart';
import 'package:uni/dtos/db/annotation-note-dto.dart';
import 'package:uni/services/db/app-database.dart';

void main() {
  test('deleteAnnotation removes child notes', () async {
    final database = AppDatabase();
    final nowMillis = DateTime.now().millisecondsSinceEpoch;

    await database.upsertAnnotation(
      AnnotationDto(
        id: 'a1',
        bookId: 'b1',
        kind: 'mark',
        style: 'highlight',
        quoteText: 'selected',
        anchorJson: '{}',
        color: '#FFE082',
        note: 'latest',
        createdAtMillis: nowMillis,
        updatedAtMillis: nowMillis,
      ),
    );
    await database.upsertAnnotationNote(
      AnnotationNoteDto(
        id: 'n1',
        annotationId: 'a1',
        bookId: 'b1',
        text: 'note body',
        createdAtMillis: nowMillis,
      ),
    );

    await database.deleteAnnotation('a1');

    expect(await database.getAnnotation('a1'), isNull);
    expect(await database.listAnnotationNotesByAnnotationId('a1'), isEmpty);
  });

  test('deleteBookCascade removes annotation notes for that book', () async {
    final database = AppDatabase();
    final nowMillis = DateTime.now().millisecondsSinceEpoch;

    await database.upsertAnnotation(
      AnnotationDto(
        id: 'a1',
        bookId: 'book-1',
        kind: 'mark',
        style: 'highlight',
        quoteText: 'selected',
        anchorJson: '{}',
        color: '#FFE082',
        note: 'latest',
        createdAtMillis: nowMillis,
        updatedAtMillis: nowMillis,
      ),
    );
    await database.upsertAnnotation(
      AnnotationDto(
        id: 'a2',
        bookId: 'book-2',
        kind: 'mark',
        style: 'highlight',
        quoteText: 'selected',
        anchorJson: '{}',
        color: '#FFE082',
        note: 'latest',
        createdAtMillis: nowMillis,
        updatedAtMillis: nowMillis,
      ),
    );
    await database.upsertAnnotationNote(
      AnnotationNoteDto(
        id: 'n1',
        annotationId: 'a1',
        bookId: 'book-1',
        text: 'book 1 note',
        createdAtMillis: nowMillis,
      ),
    );
    await database.upsertAnnotationNote(
      AnnotationNoteDto(
        id: 'n2',
        annotationId: 'a2',
        bookId: 'book-2',
        text: 'book 2 note',
        createdAtMillis: nowMillis,
      ),
    );

    await database.deleteBookCascade('book-1');

    expect(await database.listAnnotationNotesByBookId('book-1'), isEmpty);
    expect(await database.listAnnotationNotesByBookId('book-2'), hasLength(1));
  });
}
