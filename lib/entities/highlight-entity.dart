class HighlightEntity {
  const HighlightEntity({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.startOffset,
    required this.endOffset,
    required this.selectedText,
    required this.prefixContext,
    required this.suffixContext,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    this.note,
  });

  final String id;
  final String bookId;
  final String chapterId;
  final int startOffset;
  final int endOffset;
  final String selectedText;
  final String prefixContext;
  final String suffixContext;
  final String color;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
}
