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
    this.sourcePath,
  });

  final String id;
  final String title;
  final String author;
  final String? coverUrl;
  final String? profileBgColor;
  final String sourceType;
  final String? sourcePath;
  final DateTime createdAt;
  final DateTime updatedAt;
}
