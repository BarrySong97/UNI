import '../../entities/annotation-entity.dart';
import '../../shared/constants/reader-constants.dart';

class AnnotationState {
  const AnnotationState({
    this.items = const <AnnotationEntity>[],
    this.isLoading = false,
    this.selectedColor = ReaderConstants.defaultHighlightColor,
    this.selectedStyle = AnnotationStyle.highlight,
  });

  final List<AnnotationEntity> items;
  final bool isLoading;
  final String selectedColor;
  final AnnotationStyle selectedStyle;

  AnnotationState copyWith({
    List<AnnotationEntity>? items,
    bool? isLoading,
    String? selectedColor,
    AnnotationStyle? selectedStyle,
  }) {
    return AnnotationState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      selectedColor: selectedColor ?? this.selectedColor,
      selectedStyle: selectedStyle ?? this.selectedStyle,
    );
  }
}
