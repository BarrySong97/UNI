import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/highlight-entity.dart';
import 'package:uni/repositories/highlight/highlight-repository-impl.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/daos/highlights-dao.dart';

void main() {
  test('create and list highlight maps dto/entity correctly', () async {
    final repository = HighlightRepositoryImpl(
      highlightsDao: HighlightsDao(database: AppDatabase()),
    );

    final now = DateTime.now();
    final entity = HighlightEntity(
      id: 'h1',
      bookId: 'b1',
      chapterId: 'c1',
      startOffset: 1,
      endOffset: 2,
      selectedText: 'x',
      prefixContext: 'a',
      suffixContext: 'b',
      color: '#FF0000',
      createdAt: now,
      updatedAt: now,
    );

    await repository.createHighlight(entity);
    final list = await repository.getHighlights('b1', chapterId: 'c1');

    expect(list.length, 1);
    expect(list.first.id, 'h1');
    expect(list.first.color, '#FF0000');
  });
}
