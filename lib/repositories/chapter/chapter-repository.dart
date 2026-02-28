import '../../entities/chapter-entity.dart';

abstract class ChapterRepository {
  Future<List<ChapterEntity>> getChapters(String bookId);

  Future<ChapterEntity?> getChapter(String chapterId);

  Future<void> upsertChapter(ChapterEntity chapter);
}
