import '../../entities/reader-pagination-cache-entity.dart';

class ReaderPaginationSliceDto {
  const ReaderPaginationSliceDto({
    required this.pageIndex,
    required this.chapterIndex,
    required this.startOffset,
    required this.endOffset,
  });

  final int pageIndex;
  final int chapterIndex;
  final int startOffset;
  final int endOffset;

  ReaderPaginationSliceEntity toEntity() {
    return ReaderPaginationSliceEntity(
      pageIndex: pageIndex,
      chapterIndex: chapterIndex,
      startOffset: startOffset,
      endOffset: endOffset,
    );
  }

  factory ReaderPaginationSliceDto.fromEntity(
    ReaderPaginationSliceEntity entity,
  ) {
    return ReaderPaginationSliceDto(
      pageIndex: entity.pageIndex,
      chapterIndex: entity.chapterIndex,
      startOffset: entity.startOffset,
      endOffset: entity.endOffset,
    );
  }
}

class ReaderPaginationCacheDto {
  const ReaderPaginationCacheDto({
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
  final List<ReaderPaginationSliceDto> slices;

  ReaderPaginationCacheEntity toEntity() {
    return ReaderPaginationCacheEntity(
      id: id,
      bookId: bookId,
      layoutKey: layoutKey,
      cacheKind: cacheKind,
      chapterStart: chapterStart,
      chapterEnd: chapterEnd,
      pageCount: pageCount,
      updatedAtMillis: updatedAtMillis,
      slices: slices.map((item) => item.toEntity()).toList(growable: false),
    );
  }

  factory ReaderPaginationCacheDto.fromEntity(ReaderPaginationCacheEntity e) {
    return ReaderPaginationCacheDto(
      id: e.id,
      bookId: e.bookId,
      layoutKey: e.layoutKey,
      cacheKind: e.cacheKind,
      chapterStart: e.chapterStart,
      chapterEnd: e.chapterEnd,
      pageCount: e.pageCount,
      updatedAtMillis: e.updatedAtMillis,
      slices: e.slices
          .map((item) => ReaderPaginationSliceDto.fromEntity(item))
          .toList(growable: false),
    );
  }
}
