enum AnnotationKind { mark }

enum AnnotationStyle { highlight, underline }

class AnnotationEntity {
  const AnnotationEntity({
    required this.id,
    required this.bookId,
    required this.kind,
    required this.style,
    required this.quoteText,
    required this.anchorJson,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    this.note,
  });

  final String id;
  final String bookId;
  final AnnotationKind kind;
  final AnnotationStyle style;
  final String quoteText;
  final String anchorJson;
  final String color;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
}
