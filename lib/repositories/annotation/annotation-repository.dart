import '../../entities/annotation-entity.dart';

abstract class AnnotationRepository {
  Future<List<AnnotationEntity>> listByBookId(String bookId);

  Future<AnnotationEntity> createAnnotation(AnnotationEntity annotation);

  Future<AnnotationEntity> updateNote({
    required String annotationId,
    required String? note,
  });

  Future<AnnotationEntity> updateAppearance({
    required String annotationId,
    required String color,
    required AnnotationStyle style,
  });

  Future<void> deleteAnnotation(String annotationId);
}
