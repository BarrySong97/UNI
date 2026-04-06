import '../../../dtos/db/annotation-dto.dart';
import '../app-database.dart';

class AnnotationsDao {
  AnnotationsDao({required AppDatabase database}) : _database = database;

  final AppDatabase _database;

  Future<List<AnnotationDto>> listByBookId(String bookId) {
    return _database.listAnnotations(bookId);
  }

  Future<AnnotationDto?> getById(String annotationId) {
    return _database.getAnnotation(annotationId);
  }

  Future<void> upsertAnnotation(AnnotationDto dto) =>
      _database.upsertAnnotation(dto);

  Future<void> deleteAnnotation(String annotationId) =>
      _database.deleteAnnotation(annotationId);
}
