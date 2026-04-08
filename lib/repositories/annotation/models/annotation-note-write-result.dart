import '../../../entities/annotation-entity.dart';
import '../../../entities/annotation-note-entity.dart';

class AnnotationNoteWriteResult {
  const AnnotationNoteWriteResult({
    required this.annotation,
    required this.note,
  });

  final AnnotationEntity annotation;
  final AnnotationNoteEntity note;
}
