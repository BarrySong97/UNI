import '../../entities/book-entity.dart';

class BookDto {
  const BookDto({
    required this.id,
    required this.title,
    required this.author,
    required this.sourceType,
    required this.createdAtMillis,
    required this.updatedAtMillis,
    this.coverUrl,
    this.profileBgColor,
    this.sourcePath,
  });

  final String id;
  final String title;
  final String author;
  final String? coverUrl;
  final String? profileBgColor;
  final String sourceType;
  final String? sourcePath;
  final int createdAtMillis;
  final int updatedAtMillis;

  BookEntity toEntity() {
    return BookEntity(
      id: id,
      title: title,
      author: author,
      coverUrl: coverUrl,
      profileBgColor: profileBgColor,
      sourceType: sourceType,
      sourcePath: sourcePath,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMillis),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMillis),
    );
  }

  factory BookDto.fromEntity(BookEntity entity) {
    return BookDto(
      id: entity.id,
      title: entity.title,
      author: entity.author,
      coverUrl: entity.coverUrl,
      profileBgColor: entity.profileBgColor,
      sourceType: entity.sourceType,
      sourcePath: entity.sourcePath,
      createdAtMillis: entity.createdAt.millisecondsSinceEpoch,
      updatedAtMillis: entity.updatedAt.millisecondsSinceEpoch,
    );
  }
}
