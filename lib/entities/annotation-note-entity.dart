class AnnotationNoteEntity {
  const AnnotationNoteEntity({
    required this.id,
    required this.annotationId,
    required this.bookId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String annotationId;
  final String bookId;
  final String text;
  final DateTime createdAt;
}
