import '../../../entities/annotation-entity.dart';
import '../../../entities/annotation-note-entity.dart';

class ReaderAnnotationCardItem {
  const ReaderAnnotationCardItem({
    required this.annotation,
    required this.notes,
    required this.chapterTitle,
    required this.latestNoteText,
    required this.noteCount,
    required this.activityTime,
  });

  final AnnotationEntity annotation;
  final List<AnnotationNoteEntity> notes;
  final String chapterTitle;
  final String? latestNoteText;
  final int noteCount;
  final DateTime activityTime;
}
