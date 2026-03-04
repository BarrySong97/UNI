import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/reader/reader-catalog-metrics-service.dart';
import 'package:uni/services/reader/reader-page-slice.dart';

void main() {
  test('resolve computes chapter start pages from page slices', () {
    final service = ReaderCatalogMetricsService();

    final metrics = service.resolve(
      cacheKey: 'layout-1',
      chapterCount: 3,
      buildAllPages: () => const <ReaderPageSlice>[
        ReaderPageSlice(
          chapterIndex: 0,
          chapterId: 'c0',
          chapterTitle: 'c0',
          startOffset: 0,
          endOffset: 100,
          globalStartOffset: 0,
          globalEndOffset: 100,
          text: 'a',
        ),
        ReaderPageSlice(
          chapterIndex: 0,
          chapterId: 'c0',
          chapterTitle: 'c0',
          startOffset: 100,
          endOffset: 200,
          globalStartOffset: 100,
          globalEndOffset: 200,
          text: 'b',
        ),
        ReaderPageSlice(
          chapterIndex: 1,
          chapterId: 'c1',
          chapterTitle: 'c1',
          startOffset: 0,
          endOffset: 100,
          globalStartOffset: 200,
          globalEndOffset: 300,
          text: 'c',
        ),
      ],
    );

    expect(metrics.chapterStartPages[0], 1);
    expect(metrics.chapterStartPages[1], 3);
    expect(metrics.chapterStartPages[2], 1);
    expect(metrics.totalPages, 3);
  });

  test('resolve reuses cached metrics when cacheKey unchanged', () {
    final service = ReaderCatalogMetricsService();
    var buildCount = 0;

    service.resolve(
      cacheKey: 'layout-2',
      chapterCount: 1,
      buildAllPages: () {
        buildCount++;
        return const <ReaderPageSlice>[];
      },
    );
    service.resolve(
      cacheKey: 'layout-2',
      chapterCount: 1,
      buildAllPages: () {
        buildCount++;
        return const <ReaderPageSlice>[];
      },
    );

    expect(buildCount, 1);
  });
}
