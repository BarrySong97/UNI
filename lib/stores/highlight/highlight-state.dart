import '../../entities/highlight-entity.dart';
import '../../shared/constants/reader-constants.dart';

class HighlightState {
  const HighlightState({
    this.items = const <HighlightEntity>[],
    this.isLoading = false,
    this.selectedColor = ReaderConstants.defaultHighlightColor,
  });

  final List<HighlightEntity> items;
  final bool isLoading;
  final String selectedColor;

  HighlightState copyWith({
    List<HighlightEntity>? items,
    bool? isLoading,
    String? selectedColor,
  }) {
    return HighlightState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      selectedColor: selectedColor ?? this.selectedColor,
    );
  }
}
