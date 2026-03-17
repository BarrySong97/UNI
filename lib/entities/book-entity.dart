class BookEntity {
  const BookEntity({
    required this.id,
    required this.title,
    required this.author,
    required this.sourceType,
    required this.createdAt,
    required this.updatedAt,
    this.coverUrl,
    this.profileBgColor,
    this.estimatedTotalPages,
    this.sourcePath,
    this.epubFilePath,
    this.language,
  });

  final String id;
  final String title;
  final String author;
  final String? coverUrl;
  final String? profileBgColor;
  final int? estimatedTotalPages;
  final String sourceType;
  final String? sourcePath;
  final String? epubFilePath;
  final String? language;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Create a copy with an updated language.
  BookEntity copyWithLanguage(String? language) {
    return BookEntity(
      id: id,
      title: title,
      author: author,
      coverUrl: coverUrl,
      profileBgColor: profileBgColor,
      estimatedTotalPages: estimatedTotalPages,
      sourceType: sourceType,
      sourcePath: sourcePath,
      epubFilePath: epubFilePath,
      language: language,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
