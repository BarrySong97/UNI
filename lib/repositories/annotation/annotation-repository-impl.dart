import '../../dtos/db/annotation-dto.dart';
import '../../entities/annotation-entity.dart';
import '../../services/db/daos/annotations-dao.dart';
import 'annotation-repository.dart';

class AnnotationRepositoryImpl implements AnnotationRepository {
  AnnotationRepositoryImpl({required AnnotationsDao annotationsDao})
    : _annotationsDao = annotationsDao;

  final AnnotationsDao _annotationsDao;

  @override
  Future<List<AnnotationEntity>> listByBookId(String bookId) async {
    final list = await _annotationsDao.listByBookId(bookId);
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
