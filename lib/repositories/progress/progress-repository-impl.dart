import '../../dtos/db/reading-progress-dto.dart';
import '../../entities/reading-progress-entity.dart';
import '../../services/db/daos/progress-dao.dart';
import 'progress-repository.dart';

class ProgressRepositoryImpl implements ProgressRepository {
  ProgressRepositoryImpl({required ProgressDao progressDao}) : _progressDao = progressDao;

  final ProgressDao _progressDao;

  @override
  Future<ReadingProgressEntity?> getProgress(String bookId) async {
    final dto = await _progressDao.getByBookId(bookId);
    return dto?.toEntity();
  }

  @override
  Future<List<ReadingProgressEntity>> getAllProgress() async {
    final dtos = await _progressDao.getAll();
    return dtos.map((dto) => dto.toEntity()).toList(growable: false);
  }

  @override
  Future<void> saveProgress(ReadingProgressEntity progress) {
    return _progressDao.upsertProgress(ReadingProgressDto.fromEntity(progress));
  }
}
