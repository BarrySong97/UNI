import '../../entities/annotation-entity.dart';
import '../../shared/constants/reader-constants.dart';

class AnnotationState {
  const AnnotationState({
    this.items = const <AnnotationEntity>[],
    this.isLoading = false,
    this.selectedColor = ReaderConstants.defaultHighlightColor,
  });

  final List<AnnotationEntity> items;
  final bool isLoading;
  final String selectedColor;

  AnnotationState copyWith({
    List<AnnotationEntity>? items,
    bool? isLoading,
    String? selectedColor,
  }) {
    return AnnotationState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      selectedColor: selectedColor ?? this.selectedColor,
    );
  }
}
