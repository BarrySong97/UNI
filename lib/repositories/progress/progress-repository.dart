import '../../entities/reading-progress-entity.dart';

abstract class ProgressRepository {
  Future<ReadingProgressEntity?> getProgress(String bookId);

  Future<List<ReadingProgressEntity>> getAllProgress();

  Future<void> saveProgress(ReadingProgressEntity progress);
}
