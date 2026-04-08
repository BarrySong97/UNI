import '../../entities/annotation-entity.dart';
import '../../entities/annotation-note-entity.dart';
import '../../shared/constants/reader-constants.dart';

class AnnotationState {
  const AnnotationState({
    this.items = const <AnnotationEntity>[],
    this.isLoading = false,
    this.notesByAnnotationId = const <String, List<AnnotationNoteEntity>>{},
    this.selectedColor = ReaderConstants.defaultHighlightColor,
    this.selectedStyle = AnnotationStyle.highlight,
  });

  final List<AnnotationEntity> items;
  final bool isLoading;
  final Map<String, List<AnnotationNoteEntity>> notesByAnnotationId;
  final String selectedColor;
  final AnnotationStyle selectedStyle;

  AnnotationState copyWith({
    List<AnnotationEntity>? items,
    bool? isLoading,
    Map<String, List<AnnotationNoteEntity>>? notesByAnnotationId,
    String? selectedColor,
    AnnotationStyle? selectedStyle,
  }) {
    return AnnotationState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      notesByAnnotationId: notesByAnnotationId ?? this.notesByAnnotationId,
      selectedColor: selectedColor ?? this.selectedColor,
      selectedStyle: selectedStyle ?? this.selectedStyle,
    );
  }
}
