import 'package:flutter/foundation.dart';

import '../../entities/annotation-entity.dart';
import '../../repositories/annotation/annotation-repository.dart';
import '../../services/reader/annotation/annotation_models.dart';
import 'annotation-state.dart';

class AnnotationStore extends ChangeNotifier {
  AnnotationStore({required AnnotationRepository annotationRepository})
    : _annotationRepository = annotationRepository;

  final AnnotationRepository _annotationRepository;

  AnnotationState _state = const AnnotationState();

  AnnotationState get state => _state;

  Future<void> loadAnnotations(String bookId) async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();
    final items = await _annotationRepository.listByBookId(bookId);
    _state = _state.copyWith(items: items, isLoading: false);
    notifyListeners();
  }

  Future<AnnotationEntity> createMark({
    required String bookId,
    required String quoteText,
    required AnnotationAnchorV1 anchor,
    String? color,
    String? note,
  }) async {
    final now = DateTime.now();
    final annotation = AnnotationEntity(
      id: '${bookId}_ann_${now.microsecondsSinceEpoch}',
      bookId: bookId,
      kind: AnnotationKind.mark,
      quoteText: quoteText,
      anchorJson: anchor.encode(),
      color: color ?? _state.selectedColor,
      note: note,
      createdAt: now,
      updatedAt: now,
    );

    final created = await _annotationRepository.createAnnotation(annotation);
    final next = List<AnnotationEntity>.from(_state.items)..add(created);
    _state = _state.copyWith(items: next);
    notifyListeners();
    return created;
  }

  Future<void> deleteAnnotation(String annotationId) async {
    await _annotationRepository.deleteAnnotation(annotationId);
    _state = _state.copyWith(
      items: _state.items
          .where((item) => item.id != annotationId)
          .toList(growable: false),
    );
    notifyListeners();
  }
}
