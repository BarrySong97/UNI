import 'package:flutter_test/flutter_test.dart';
import 'package:uni/repositories/highlight/highlight-repository-impl.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/daos/highlights-dao.dart';
import 'package:uni/stores/highlight/highlight-store.dart';

void main() {
  test('createHighlight appends and deleteHighlight removes', () async {
    final repository = HighlightRepositoryImpl(
      highlightsDao: HighlightsDao(database: AppDatabase()),
    );
    final store = HighlightStore(highlightRepository: repository);

    final created = await store.createHighlight(
      bookId: 'book-1',
      chapterId: 'chapter-1',
      chapterText: 'abcdefghijklmnopqrstuvwxyz',
      startOffset: 1,
      endOffset: 3,
    );

    expect(store.state.items.length, 1);
    expect(store.state.items.first.selectedText, 'bc');

    await store.deleteHighlight(created.id);

    expect(store.state.items, isEmpty);
  });
}
