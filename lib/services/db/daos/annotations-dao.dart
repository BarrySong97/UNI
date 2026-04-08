import '../../../dtos/db/annotation-dto.dart';
import '../../../dtos/db/annotation-note-dto.dart';
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

  Future<List<AnnotationNoteDto>> listNotesByBookId(String bookId) {
    return _database.listAnnotationNotesByBookId(bookId);
  }

  Future<List<AnnotationNoteDto>> listNotesByAnnotationId(String annotationId) {
    return _database.listAnnotationNotesByAnnotationId(annotationId);
  }

  Future<void> upsertNote(AnnotationNoteDto dto) =>
      _database.upsertAnnotationNote(dto);

  Future<void> deleteNotesByAnnotationId(String annotationId) =>
      _database.deleteAnnotationNotesByAnnotationId(annotationId);
}
