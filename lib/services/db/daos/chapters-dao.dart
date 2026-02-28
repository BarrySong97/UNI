import '../../../dtos/db/chapter-dto.dart';
import '../app-database.dart';

class ChaptersDao {
  ChaptersDao({required AppDatabase database}) : _database = database;

  final AppDatabase _database;

  Future<List<ChapterDto>> listByBookId(String bookId) => _database.listChaptersByBook(bookId);

  Future<ChapterDto?> getById(String chapterId) => _database.getChapter(chapterId);

  Future<void> upsertChapter(ChapterDto dto) => _database.upsertChapter(dto);
}
