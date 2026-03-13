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
      locatorJson:
          '{"href":"/chapter1.xhtml","locations":{"cssSelector":"p.intro"}}',
      selectedText: 'highlighted text',
    );

    expect(store.state.items.length, 1);
    expect(store.state.items.first.selectedText, 'highlighted text');
    expect(store.state.items.first.locatorJson, contains('chapter1.xhtml'));

    await store.deleteHighlight(created.id);

    expect(store.state.items, isEmpty);
  });

  test('loadHighlights loads highlights for a book', () async {
    final repository = HighlightRepositoryImpl(
      highlightsDao: HighlightsDao(database: AppDatabase()),
    );
    final store = HighlightStore(highlightRepository: repository);

    await store.createHighlight(
      bookId: 'book-2',
      locatorJson: '{"href":"/chapter2.xhtml"}',
      selectedText: 'first highlight',
    );
    await store.createHighlight(
      bookId: 'book-2',
      locatorJson: '{"href":"/chapter3.xhtml"}',
      selectedText: 'second highlight',
    );

    final newStore = HighlightStore(highlightRepository: repository);
    await newStore.loadHighlights('book-2');

    expect(newStore.state.items.length, 2);
  });
}
