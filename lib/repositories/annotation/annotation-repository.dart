import '../../entities/annotation-entity.dart';

abstract class AnnotationRepository {
  Future<List<AnnotationEntity>> listByBookId(String bookId);

  Future<AnnotationEntity> createAnnotation(AnnotationEntity annotation);

  Future<AnnotationEntity> updateNote({
    required String annotationId,
    required String? note,
  });

  Future<void> deleteAnnotation(String annotationId);
}
