import '../../entities/annotation-entity.dart';
import '../../entities/annotation-note-entity.dart';
import 'models/annotation-note-write-result.dart';

abstract class AnnotationRepository {
  Future<List<AnnotationEntity>> listByBookId(String bookId);

  Future<List<AnnotationNoteEntity>> listNotesByBookId(String bookId);

  Future<List<AnnotationNoteEntity>> listNotesByAnnotationId(
    String annotationId,
  );

  Future<AnnotationEntity> createAnnotation(AnnotationEntity annotation);

  Future<AnnotationEntity> updateNote({
    required String annotationId,
    required String? note,
  });

  Future<AnnotationNoteWriteResult> createNote({
    required String annotationId,
    required String bookId,
    required String text,
  });

  Future<AnnotationEntity> updateAppearance({
    required String annotationId,
    required String color,
    required AnnotationStyle style,
  });

  Future<void> deleteAnnotation(String annotationId);
}
