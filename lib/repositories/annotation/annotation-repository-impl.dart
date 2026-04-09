import '../../dtos/db/annotation-dto.dart';
import '../../dtos/db/annotation-note-dto.dart';
import '../../entities/annotation-entity.dart';
import '../../entities/annotation-note-entity.dart';
import '../../services/db/daos/annotation-notes-dao.dart';
import '../../services/db/daos/annotations-dao.dart';
import 'annotation-repository.dart';
import 'models/annotation-note-write-result.dart';

class AnnotationRepositoryImpl implements AnnotationRepository {
  AnnotationRepositoryImpl({
    required AnnotationsDao annotationsDao,
    required AnnotationNotesDao annotationNotesDao,
  }) : _annotationsDao = annotationsDao,
       _annotationNotesDao = annotationNotesDao;

  final AnnotationsDao _annotationsDao;
  final AnnotationNotesDao _annotationNotesDao;

  @override
  Future<List<AnnotationEntity>> listByBookId(String bookId) async {
    final list = await _annotationsDao.listByBookId(bookId);
    return list.map((dto) => dto.toEntity()).toList(growable: false);
  }

  @override
  Future<List<AnnotationNoteEntity>> listNotesByBookId(String bookId) async {
    final list = await _annotationNotesDao.listByBookId(bookId);
    return list.map((dto) => dto.toEntity()).toList(growable: false);
  }

  @override
  Future<List<AnnotationNoteEntity>> listNotesByAnnotationId(
    String annotationId,
  ) async {
    final list = await _annotationNotesDao.listByAnnotationId(annotationId);
    return list.map((dto) => dto.toEntity()).toList(growable: false);
  }

  @override
  Future<AnnotationEntity> createAnnotation(AnnotationEntity annotation) async {
    await _annotationsDao.upsertAnnotation(
      AnnotationDto.fromEntity(annotation),
    );
    return annotation;
  }

  @override
  Future<AnnotationEntity> updateNote({
    required String annotationId,
    required String? note,
  }) async {
    final current = await _annotationsDao.getById(annotationId);
    if (current == null) {
      throw StateError('Annotation not found: $annotationId');
    }

    final updated = AnnotationDto(
      id: current.id,
      bookId: current.bookId,
      kind: current.kind,
      style: current.style,
      quoteText: current.quoteText,
      anchorJson: current.anchorJson,
      color: current.color,
      note: note,
      createdAtMillis: current.createdAtMillis,
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    await _annotationsDao.upsertAnnotation(updated);
    return updated.toEntity();
  }

  @override
  Future<AnnotationNoteWriteResult> createNote({
    required String annotationId,
    required String bookId,
    required String text,
  }) async {
    final current = await _annotationsDao.getById(annotationId);
    if (current == null) {
      throw StateError('Annotation not found: $annotationId');
    }

    final now = DateTime.now();
    final note = AnnotationNoteEntity(
      id: '${annotationId}_note_${now.microsecondsSinceEpoch}',
      annotationId: annotationId,
      bookId: bookId,
      text: text,
      createdAt: now,
    );
    await _annotationNotesDao.upsertNote(AnnotationNoteDto.fromEntity(note));

    final updated = AnnotationDto(
      id: current.id,
      bookId: current.bookId,
      kind: current.kind,
      style: current.style,
      quoteText: current.quoteText,
      anchorJson: current.anchorJson,
      color: current.color,
      note: text,
      createdAtMillis: current.createdAtMillis,
      updatedAtMillis: now.millisecondsSinceEpoch,
    );
    await _annotationsDao.upsertAnnotation(updated);
    return AnnotationNoteWriteResult(
      annotation: updated.toEntity(),
      note: note,
    );
  }

  @override
  Future<AnnotationEntity> updateAppearance({
    required String annotationId,
    required String color,
    required AnnotationStyle style,
  }) async {
    final current = await _annotationsDao.getById(annotationId);
    if (current == null) {
      throw StateError('Annotation not found: $annotationId');
    }

    final updated = AnnotationDto(
      id: current.id,
      bookId: current.bookId,
      kind: current.kind,
      style: style.name,
      quoteText: current.quoteText,
      anchorJson: current.anchorJson,
      color: color,
      note: current.note,
      createdAtMillis: current.createdAtMillis,
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    await _annotationsDao.upsertAnnotation(updated);
    return updated.toEntity();
  }

  @override
  Future<void> deleteAnnotation(String annotationId) {
    return _annotationsDao.deleteAnnotation(annotationId);
  }
}
