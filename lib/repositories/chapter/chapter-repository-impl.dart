import '../../dtos/db/chapter-dto.dart';
import '../../entities/chapter-entity.dart';
import '../../services/db/daos/chapters-dao.dart';
import 'chapter-repository.dart';

class ChapterRepositoryImpl implements ChapterRepository {
  ChapterRepositoryImpl({required ChaptersDao chaptersDao})
    : _chaptersDao = chaptersDao;

  final ChaptersDao _chaptersDao;

  @override
  Future<List<ChapterEntity>> getChapters(String bookId) async {
    final list = await _chaptersDao.listByBookId(bookId);
    return list.map((dto) => dto.toEntity()).toList(growable: false);
  }

  @override
  Future<ChapterEntity?> getChapter(String chapterId) async {
    final dto = await _chaptersDao.getById(chapterId);
    return dto?.toEntity();
  }

  @override
  Future<void> upsertChapter(ChapterEntity chapter) {
    return _chaptersDao.upsertChapter(ChapterDto.fromEntity(chapter));
  }

  Future<void> upsertSeedChapter({
    required String id,
    required String bookId,
    required int idx,
    required String title,
    required String content,
  }) {
    return _chaptersDao.upsertChapter(
      ChapterDto(
        id: id,
        bookId: bookId,
        idx: idx,
        title: title,
        content: content,
        wordCount: content.length,
      ),
    );
  }
}
