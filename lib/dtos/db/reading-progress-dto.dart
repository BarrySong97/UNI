import '../../entities/reading-progress-entity.dart';

class ReadingProgressDto {
  const ReadingProgressDto({
    required this.bookId,
    required this.locatorJson,
    required this.percent,
    required this.updatedAtMillis,
    this.prefsJson,
    this.pageCountsJson,
  });

  final String bookId;
  final String locatorJson;
  final double percent;
  final int updatedAtMillis;
  final String? prefsJson;
  final String? pageCountsJson;

  ReadingProgressEntity toEntity() {
    return ReadingProgressEntity(
      bookId: bookId,
      locatorJson: locatorJson,
      percent: percent,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMillis),
      prefsJson: prefsJson,
      pageCountsJson: pageCountsJson,
    );
  }

  factory ReadingProgressDto.fromEntity(ReadingProgressEntity entity) {
    return ReadingProgressDto(
      bookId: entity.bookId,
      locatorJson: entity.locatorJson,
      percent: entity.percent,
      updatedAtMillis: entity.updatedAt.millisecondsSinceEpoch,
      prefsJson: entity.prefsJson,
      pageCountsJson: entity.pageCountsJson,
    );
  }
}
