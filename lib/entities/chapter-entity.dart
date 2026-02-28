class ChapterEntity {
  const ChapterEntity({
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
}
