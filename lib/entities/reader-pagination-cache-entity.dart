class ReaderPaginationSliceEntity {
  const ReaderPaginationSliceEntity({
    required this.pageIndex,
    required this.chapterIndex,
    required this.startOffset,
    required this.endOffset,
  });

  final int pageIndex;
  final int chapterIndex;
  final int startOffset;
  final int endOffset;
}

class ReaderPaginationCacheEntity {
  const ReaderPaginationCacheEntity({
    required this.id,
    required this.bookId,
    required this.layoutKey,
    required this.cacheKind,
    required this.chapterStart,
    required this.chapterEnd,
    required this.pageCount,
    required this.updatedAtMillis,
    required this.slices,
  });

  final String id;
  final String bookId;
  final String layoutKey;
  final String cacheKind;
  final int chapterStart;
  final int chapterEnd;
  final int pageCount;
  final int updatedAtMillis;
  final List<ReaderPaginationSliceEntity> slices;
}
