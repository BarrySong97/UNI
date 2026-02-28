import '../../entities/reading-progress-entity.dart';

class ReadingProgressDto {
  const ReadingProgressDto({
    required this.bookId,
    required this.chapterId,
    required this.charOffset,
    required this.percent,
    required this.updatedAtMillis,
  });

  final String bookId;
  final String chapterId;
  final int charOffset;
  final double percent;
  final int updatedAtMillis;

  ReadingProgressEntity toEntity() {
    return ReadingProgressEntity(
      bookId: bookId,
      chapterId: chapterId,
      charOffset: charOffset,
      percent: percent,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMillis),
    );
  }

  factory ReadingProgressDto.fromEntity(ReadingProgressEntity entity) {
    return ReadingProgressDto(
      bookId: entity.bookId,
      chapterId: entity.chapterId,
      charOffset: entity.charOffset,
      percent: entity.percent,
      updatedAtMillis: entity.updatedAt.millisecondsSinceEpoch,
    );
  }
}
