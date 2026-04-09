import '../../entities/annotation-entity.dart';

class AnnotationDto {
  const AnnotationDto({
    required this.id,
    required this.bookId,
    required this.kind,
    required this.style,
    required this.quoteText,
    required this.anchorJson,
    required this.color,
    required this.createdAtMillis,
    required this.updatedAtMillis,
    this.note,
  });

  final String id;
  final String bookId;
  final String kind;
  final String style;
  final String quoteText;
  final String anchorJson;
  final String color;
  final String? note;
  final int createdAtMillis;
  final int updatedAtMillis;

  AnnotationEntity toEntity() {
    return AnnotationEntity(
      id: id,
      bookId: bookId,
      kind: _annotationKindFromString(kind),
      style: _annotationStyleFromString(style),
      quoteText: quoteText,
      anchorJson: anchorJson,
      color: color,
      note: note,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMillis),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMillis),
    );
  }

  factory AnnotationDto.fromEntity(AnnotationEntity entity) {
    return AnnotationDto(
      id: entity.id,
      bookId: entity.bookId,
      kind: entity.kind.name,
      style: entity.style.name,
      quoteText: entity.quoteText,
      anchorJson: entity.anchorJson,
      color: entity.color,
      note: entity.note,
      createdAtMillis: entity.createdAt.millisecondsSinceEpoch,
      updatedAtMillis: entity.updatedAt.millisecondsSinceEpoch,
    );
  }
}

AnnotationKind _annotationKindFromString(String raw) {
  return switch (raw) {
    'mark' => AnnotationKind.mark,
    _ => AnnotationKind.mark,
  };
}

AnnotationStyle _annotationStyleFromString(String raw) {
  return switch (raw) {
    'underline' => AnnotationStyle.underline,
    'highlight' => AnnotationStyle.highlight,
    _ => AnnotationStyle.highlight,
  };
}
