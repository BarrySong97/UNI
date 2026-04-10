import 'package:flutter_test/flutter_test.dart';
import 'package:uni/dtos/db/book-dto.dart';
import 'package:uni/services/db/app-database.dart';

void main() {
  test('listExplainHistory returns latest items with joined book titles', () async {
    final database = AppDatabase();
    final nowMillis = DateTime(2026, 3, 1).millisecondsSinceEpoch;

    await database.upsertBook(
      BookDto(
        id: 'book-1',
        title: 'First Book',
        author: 'Author',
        sourceType: 'local_epub',
        createdAtMillis: nowMillis,
        updatedAtMillis: nowMillis,
      ),
    );
    await database.upsertBook(
      BookDto(
        id: 'book-2',
        title: 'Second Book',
        author: 'Author',
        sourceType: 'local_epub',
        createdAtMillis: nowMillis,
        updatedAtMillis: nowMillis,
      ),
    );

    await database.upsertExplainCache(
      bookId: 'book-1',
      chapterIndex: 0,
      selectedText: 'serene',
      contextSentence: 'The sea felt serene.',
      response:
          '{"meaningExplain":"calm and peaceful","detailExplain":["Used to describe a quiet feeling."]}',
    );
    await Future<void>.delayed(const Duration(milliseconds: 1));
    await database.upsertExplainCache(
      bookId: 'book-2',
      chapterIndex: 1,
      selectedText: 'vivid',
      contextSentence: 'The image stayed vivid in memory.',
      response:
          '{"meaningExplain":"very clear and bright","detailExplain":["Often used for strong memories or colors."]}',
    );

    final history = await database.listExplainHistory();

    expect(history, hasLength(2));
    expect(history.first.selectedText, 'vivid');
    expect(history.first.bookTitle, 'Second Book');
    expect(history.last.selectedText, 'serene');
    expect(history.last.bookTitle, 'First Book');
  });
}
