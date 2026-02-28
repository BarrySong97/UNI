import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/highlight-entity.dart';
import 'package:uni/services/highlight/highlight-resolver-service.dart';

void main() {
  test('sortForRender sorts by start then updatedAt', () {
    final service = HighlightResolverService();
    final t1 = DateTime(2026, 1, 1);
    final t2 = DateTime(2026, 1, 2);

    final list = service.sortForRender(<HighlightEntity>[
      HighlightEntity(
        id: 'b',
        bookId: 'book',
        chapterId: 'chapter',
        startOffset: 2,
        endOffset: 4,
        selectedText: 'cd',
        prefixContext: 'b',
        suffixContext: 'e',
        color: '#EEE',
        createdAt: t2,
        updatedAt: t2,
      ),
      HighlightEntity(
        id: 'a',
        bookId: 'book',
        chapterId: 'chapter',
        startOffset: 2,
        endOffset: 3,
        selectedText: 'c',
        prefixContext: 'b',
        suffixContext: 'd',
        color: '#EEE',
        createdAt: t1,
        updatedAt: t1,
      ),
    ]);

    expect(list.first.id, 'a');
  });

  test('relocateByContext recovers range when offset is stale', () {
    final service = HighlightResolverService();
    final now = DateTime.now();
    final highlight = HighlightEntity(
      id: 'h',
      bookId: 'book',
      chapterId: 'chapter',
      startOffset: 30,
      endOffset: 34,
      selectedText: 'text',
      prefixContext: 'demo ',
      suffixContext: ' body',
      color: '#EEE',
      createdAt: now,
      updatedAt: now,
    );

    final result = service.relocateByContext(
      chapterText: 'prefix demo text body suffix',
      highlight: highlight,
    );

    expect(result.start, 12);
    expect(result.end, 16);
  });
}
