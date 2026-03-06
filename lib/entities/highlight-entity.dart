class HighlightEntity {
  const HighlightEntity({
    required this.id,
    required this.bookId,
    required this.locatorJson,
    required this.selectedText,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    this.note,
  });

  final String id;
  final String bookId;
  final String locatorJson;
  final String selectedText;
  final String color;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
}
