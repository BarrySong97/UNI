import 'package:flutter/foundation.dart';

import '../../entities/annotation-entity.dart';
import '../../entities/annotation-note-entity.dart';
import '../../repositories/annotation/annotation-repository.dart';
import '../../services/reader/annotation/annotation_models.dart';
import '../../repositories/annotation/models/annotation-note-write-result.dart';
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
    final notes = await _annotationRepository.listNotesByBookId(bookId);
    _state = _state.copyWith(
      items: items,
      notesByAnnotationId: _groupNotes(notes),
      isLoading: false,
    );
    notifyListeners();
  }

  Future<AnnotationEntity> createMark({
    required String bookId,
    required String quoteText,
    required AnnotationAnchorV1 anchor,
    String? color,
    AnnotationStyle? style,
    String? note,
  }) async {
    final now = DateTime.now();
    final annotation = AnnotationEntity(
      id: '${bookId}_ann_${now.microsecondsSinceEpoch}',
      bookId: bookId,
      kind: AnnotationKind.mark,
      style: style ?? _state.selectedStyle,
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

  Future<AnnotationNoteWriteResult> createNote({
    required String annotationId,
    required String bookId,
    required String text,
  }) async {
    final result = await _annotationRepository.createNote(
      annotationId: annotationId,
      bookId: bookId,
      text: text,
    );
    final nextItems = _state.items
        .map((item) => item.id == annotationId ? result.annotation : item)
        .toList(growable: false);
    final nextNotes = Map<String, List<AnnotationNoteEntity>>.from(
      _state.notesByAnnotationId,
    );
    final currentNotes = List<AnnotationNoteEntity>.from(
      nextNotes[annotationId] ?? const <AnnotationNoteEntity>[],
    )..add(result.note);
    currentNotes.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    nextNotes[annotationId] = List<AnnotationNoteEntity>.unmodifiable(
      currentNotes,
    );
    _state = _state.copyWith(items: nextItems, notesByAnnotationId: nextNotes);
    notifyListeners();
    return result;
  }

  Future<AnnotationNoteWriteResult> createMarkWithNote({
    required String bookId,
    required String quoteText,
    required AnnotationAnchorV1 anchor,
    required String noteText,
    String? color,
    AnnotationStyle? style,
  }) async {
    final created = await createMark(
      bookId: bookId,
      quoteText: quoteText,
      anchor: anchor,
      color: color,
      style: style,
    );
    try {
      return await createNote(
        annotationId: created.id,
        bookId: bookId,
        text: noteText,
      );
    } catch (_) {
      await deleteAnnotation(created.id);
      rethrow;
    }
  }

  void setSelectedAppearance({String? color, AnnotationStyle? style}) {
    _state = _state.copyWith(selectedColor: color, selectedStyle: style);
    notifyListeners();
  }

  Future<AnnotationEntity> updateAnnotationAppearance({
    required String annotationId,
    required String color,
    required AnnotationStyle style,
  }) async {
    final updated = await _annotationRepository.updateAppearance(
      annotationId: annotationId,
      color: color,
      style: style,
    );
    final next = _state.items
        .map((item) => item.id == annotationId ? updated : item)
        .toList(growable: false);
    _state = _state.copyWith(
      items: next,
      selectedColor: color,
      selectedStyle: style,
    );
    notifyListeners();
    return updated;
  }

  Future<void> deleteAnnotation(String annotationId) async {
    await _annotationRepository.deleteAnnotation(annotationId);
    final nextNotes = Map<String, List<AnnotationNoteEntity>>.from(
      _state.notesByAnnotationId,
    )..remove(annotationId);
    _state = _state.copyWith(
      items: _state.items
          .where((item) => item.id != annotationId)
          .toList(growable: false),
      notesByAnnotationId: nextNotes,
    );
    notifyListeners();
  }
}

Map<String, List<AnnotationNoteEntity>> _groupNotes(
  List<AnnotationNoteEntity> notes,
) {
  final grouped = <String, List<AnnotationNoteEntity>>{};
  for (final note in notes) {
    final list = grouped.putIfAbsent(
      note.annotationId,
      () => <AnnotationNoteEntity>[],
    );
    list.add(note);
  }
  for (final entry in grouped.entries) {
    entry.value.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }
  return grouped.map(
    (key, value) =>
        MapEntry(key, List<AnnotationNoteEntity>.unmodifiable(value)),
  );
}
