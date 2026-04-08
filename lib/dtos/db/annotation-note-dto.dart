import '../../entities/annotation-note-entity.dart';

class AnnotationNoteDto {
  const AnnotationNoteDto({
    required this.id,
    required this.annotationId,
    required this.bookId,
    required this.text,
    required this.createdAtMillis,
  });

  final String id;
  final String annotationId;
  final String bookId;
  final String text;
  final int createdAtMillis;

  AnnotationNoteEntity toEntity() {
    return AnnotationNoteEntity(
      id: id,
      annotationId: annotationId,
      bookId: bookId,
      text: text,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMillis),
    );
  }

  factory AnnotationNoteDto.fromEntity(AnnotationNoteEntity entity) {
    return AnnotationNoteDto(
      id: entity.id,
      annotationId: entity.annotationId,
      bookId: entity.bookId,
      text: entity.text,
      createdAtMillis: entity.createdAt.millisecondsSinceEpoch,
    );
  }
}
