import 'reader-page-slice.dart';

class ReaderCatalogMetrics {
  const ReaderCatalogMetrics({
    required this.chapterStartPages,
    required this.totalPages,
  });

  final Map<int, int> chapterStartPages;
  final int totalPages;
}

class ReaderCatalogMetricsService {
  String _cacheKey = '';
  ReaderCatalogMetrics? _lastMetrics;

  ReaderCatalogMetrics resolve({
    required String cacheKey,
    required int chapterCount,
    required List<ReaderPageSlice> Function() buildAllPages,
  }) {
    if (_cacheKey == cacheKey && _lastMetrics != null) {
      return _lastMetrics!;
    }

    final pages = buildAllPages();
    final fallback = <int, int>{for (var i = 0; i < chapterCount; i++) i: 1};
    if (pages.isEmpty) {
      final metrics = ReaderCatalogMetrics(
        chapterStartPages: fallback,
        totalPages: 1,
      );
      _cacheKey = cacheKey;
      _lastMetrics = metrics;
      return metrics;
    }

    final chapterStartPages = <int, int>{};
    for (var i = 0; i < pages.length; i++) {
      chapterStartPages.putIfAbsent(pages[i].chapterIndex, () => i + 1);
    }
    for (var i = 0; i < chapterCount; i++) {
      chapterStartPages.putIfAbsent(i, () => 1);
    }

    final metrics = ReaderCatalogMetrics(
      chapterStartPages: chapterStartPages,
      totalPages: pages.length,
    );
    _cacheKey = cacheKey;
    _lastMetrics = metrics;
    return metrics;
  }
}
