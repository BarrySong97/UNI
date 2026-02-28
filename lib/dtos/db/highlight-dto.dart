import '../../entities/highlight-entity.dart';

class HighlightDto {
  const HighlightDto({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.startOffset,
    required this.endOffset,
    required this.selectedText,
    required this.prefixContext,
    required this.suffixContext,
    required this.color,
    required this.createdAtMillis,
    required this.updatedAtMillis,
    this.note,
  });

  final String id;
  final String bookId;
  final String chapterId;
  final int startOffset;
  final int endOffset;
  final String selectedText;
  final String prefixContext;
  final String suffixContext;
  final String color;
  final String? note;
  final int createdAtMillis;
  final int updatedAtMillis;

  HighlightEntity toEntity() {
    return HighlightEntity(
      id: id,
      bookId: bookId,
      chapterId: chapterId,
      startOffset: startOffset,
      endOffset: endOffset,
      selectedText: selectedText,
      prefixContext: prefixContext,
      suffixContext: suffixContext,
      color: color,
      note: note,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMillis),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMillis),
    );
  }

  factory HighlightDto.fromEntity(HighlightEntity entity) {
    return HighlightDto(
      id: entity.id,
      bookId: entity.bookId,
      chapterId: entity.chapterId,
      startOffset: entity.startOffset,
      endOffset: entity.endOffset,
      selectedText: entity.selectedText,
      prefixContext: entity.prefixContext,
      suffixContext: entity.suffixContext,
      color: entity.color,
      note: entity.note,
      createdAtMillis: entity.createdAt.millisecondsSinceEpoch,
      updatedAtMillis: entity.updatedAt.millisecondsSinceEpoch,
    );
  }
}
