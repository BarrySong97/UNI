import '../../../entities/annotation-entity.dart';
import 'annotation_models.dart';

enum AnnotationOverlapDecision { none, duplicate, overlap }

AnnotationOverlapDecision detectAnnotationOverlap({
  required AnnotationAnchorV1 candidate,
  required Iterable<AnnotationEntity> existingAnnotations,
}) {
  for (final match in findOverlappingAnnotations(
    candidate: candidate,
    existingAnnotations: existingAnnotations,
  )) {
    final existing = AnnotationAnchorV1.tryParse(match.anchorJson);
    if (existing == null) {
      continue;
    }
    if (_anchorsEqual(existing, candidate)) {
      return AnnotationOverlapDecision.duplicate;
    }
    return AnnotationOverlapDecision.overlap;
  }
  return AnnotationOverlapDecision.none;
}

List<AnnotationEntity> findExactMatchingAnnotations({
  required AnnotationAnchorV1 candidate,
  required Iterable<AnnotationEntity> existingAnnotations,
}) {
  final matches = <AnnotationEntity>[];
  for (final annotation in existingAnnotations) {
    final existing = AnnotationAnchorV1.tryParse(annotation.anchorJson);
    if (existing == null) {
      continue;
    }
    if (_anchorsEqual(existing, candidate)) {
      matches.add(annotation);
    }
  }
  return matches;
}

List<AnnotationEntity> findOverlappingAnnotations({
  required AnnotationAnchorV1 candidate,
  required Iterable<AnnotationEntity> existingAnnotations,
}) {
  final matches = <AnnotationEntity>[];
  for (final annotation in existingAnnotations) {
    final existing = AnnotationAnchorV1.tryParse(annotation.anchorJson);
    if (existing == null) {
      continue;
    }
    if (_anchorsEqual(existing, candidate) ||
        _anchorsOverlap(existing, candidate)) {
      matches.add(annotation);
    }
  }
  return matches;
}

bool _anchorsEqual(AnnotationAnchorV1 left, AnnotationAnchorV1 right) {
  if (left.segments.length != right.segments.length) {
    return false;
  }
  for (var i = 0; i < left.segments.length; i++) {
    final a = left.segments[i];
    final b = right.segments[i];
    if (a.chapterIndex != b.chapterIndex ||
        a.blockIndex != b.blockIndex ||
        a.startOffset != b.startOffset ||
        a.endOffset != b.endOffset) {
      return false;
    }
  }
  return true;
}

bool _anchorsOverlap(AnnotationAnchorV1 left, AnnotationAnchorV1 right) {
  for (final a in left.segments) {
    for (final b in right.segments) {
      if (a.chapterIndex != b.chapterIndex || a.blockIndex != b.blockIndex) {
        continue;
      }
      final overlapStart = a.startOffset > b.startOffset
          ? a.startOffset
          : b.startOffset;
      final overlapEnd = a.endOffset < b.endOffset ? a.endOffset : b.endOffset;
      if (overlapStart < overlapEnd) {
        return true;
      }
    }
  }
  return false;
}
