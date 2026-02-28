import '../../dtos/db/book-dto.dart';
import '../../dtos/db/chapter-dto.dart';
import '../../dtos/db/highlight-dto.dart';
import '../../dtos/db/reading-progress-dto.dart';

class AppDatabase {
  final Map<String, BookDto> _books = <String, BookDto>{};
  final Map<String, ChapterDto> _chapters = <String, ChapterDto>{};
  final Map<String, ReadingProgressDto> _progress = <String, ReadingProgressDto>{};
  final Map<String, HighlightDto> _highlights = <String, HighlightDto>{};

  Future<List<BookDto>> listBooks() async => _books.values.toList(growable: false);

  Future<BookDto?> getBook(String bookId) async => _books[bookId];

  Future<void> upsertBook(BookDto book) async {
    _books[book.id] = book;
  }

  Future<void> upsertChapter(ChapterDto chapter) async {
    _chapters[chapter.id] = chapter;
  }

  Future<ChapterDto?> getChapter(String chapterId) async => _chapters[chapterId];

  Future<List<ChapterDto>> listChaptersByBook(String bookId) async {
    final list = _chapters.values.where((chapter) => chapter.bookId == bookId).toList(growable: false);
    list.sort((a, b) => a.idx.compareTo(b.idx));
    return list;
  }

  Future<ReadingProgressDto?> getProgress(String bookId) async => _progress[bookId];

  Future<void> upsertProgress(ReadingProgressDto progress) async {
    _progress[progress.bookId] = progress;
  }

  Future<List<HighlightDto>> listHighlights(String bookId, {String? chapterId}) async {
    final filtered = _highlights.values.where(
      (item) => item.bookId == bookId && (chapterId == null || item.chapterId == chapterId),
    );
    final list = filtered.toList(growable: false)
      ..sort((a, b) {
        final start = a.startOffset.compareTo(b.startOffset);
        if (start != 0) {
          return start;
        }
        return a.updatedAtMillis.compareTo(b.updatedAtMillis);
      });
    return list;
  }

  Future<void> upsertHighlight(HighlightDto highlight) async {
    _highlights[highlight.id] = highlight;
  }

  Future<void> deleteHighlight(String highlightId) async {
    _highlights.remove(highlightId);
  }
}
