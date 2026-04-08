import '../../../dtos/db/annotation-note-dto.dart';
import '../app-database.dart';

class AnnotationNotesDao {
  AnnotationNotesDao({required AppDatabase database}) : _database = database;

  final AppDatabase _database;

  Future<List<AnnotationNoteDto>> listByBookId(String bookId) {
    return _database.listAnnotationNotesByBookId(bookId);
  }

  Future<List<AnnotationNoteDto>> listByAnnotationId(String annotationId) {
    return _database.listAnnotationNotesByAnnotationId(annotationId);
  }

  Future<void> upsertNote(AnnotationNoteDto dto) =>
      _database.upsertAnnotationNote(dto);

  Future<void> deleteByAnnotationId(String annotationId) =>
      _database.deleteAnnotationNotesByAnnotationId(annotationId);
}
