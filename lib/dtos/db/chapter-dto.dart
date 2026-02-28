import '../../entities/chapter-entity.dart';

class ChapterDto {
  const ChapterDto({
    required this.id,
    required this.bookId,
    required this.idx,
    required this.title,
    required this.content,
    required this.wordCount,
  });

  final String id;
  final String bookId;
  final int idx;
  final String title;
  final String content;
  final int wordCount;

  ChapterEntity toEntity() {
    return ChapterEntity(
      id: id,
      bookId: bookId,
      idx: idx,
      title: title,
      content: content,
      wordCount: wordCount,
    );
  }

  factory ChapterDto.fromEntity(ChapterEntity entity) {
    return ChapterDto(
      id: entity.id,
      bookId: entity.bookId,
      idx: entity.idx,
      title: entity.title,
      content: entity.content,
      wordCount: entity.wordCount,
    );
  }
}
