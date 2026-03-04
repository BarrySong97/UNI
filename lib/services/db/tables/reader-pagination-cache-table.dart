abstract final class ReaderPaginationCacheTable {
  static const String tableName = 'reader_pagination_cache';
  static const String id = 'id';
  static const String bookId = 'book_id';
  static const String layoutKey = 'layout_key';
  static const String cacheKind = 'cache_kind';
  static const String chapterStart = 'chapter_start';
  static const String chapterEnd = 'chapter_end';
  static const String pageCount = 'page_count';
  static const String updatedAt = 'updated_at';
}

abstract final class ReaderPaginationSliceTable {
  static const String tableName = 'reader_pagination_slice';
  static const String cacheId = 'cache_id';
  static const String pageIndex = 'page_index';
  static const String chapterIndex = 'chapter_index';
  static const String startOffset = 'start_offset';
  static const String endOffset = 'end_offset';
}
