import 'package:flutter/foundation.dart';

import '../../entities/highlight-entity.dart';
import '../../repositories/highlight/highlight-repository.dart';
import 'highlight-state.dart';

class HighlightStore extends ChangeNotifier {
  HighlightStore({
    required HighlightRepository highlightRepository,
  }) : _highlightRepository = highlightRepository;

  final HighlightRepository _highlightRepository;

  HighlightState _state = const HighlightState();

  HighlightState get state => _state;

  Future<void> loadHighlights(String bookId) async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();
    final items = await _highlightRepository.getHighlights(bookId);
    _state = _state.copyWith(items: items, isLoading: false);
    notifyListeners();
  }

  Future<HighlightEntity> createHighlight({
    required String bookId,
    required String locatorJson,
    required String selectedText,
    String? color,
    String? note,
  }) async {
    final now = DateTime.now();
    final highlight = HighlightEntity(
      id: '${bookId}_hl_${now.microsecondsSinceEpoch}',
      bookId: bookId,
      locatorJson: locatorJson,
      selectedText: selectedText,
      color: color ?? _state.selectedColor,
      note: note,
      createdAt: now,
      updatedAt: now,
    );

    final created = await _highlightRepository.createHighlight(highlight);
    final next = List<HighlightEntity>.from(_state.items)..add(created);
    _state = _state.copyWith(items: next);
    notifyListeners();
    return created;
  }

  Future<void> deleteHighlight(String highlightId) async {
    await _highlightRepository.deleteHighlight(highlightId);
    _state = _state.copyWith(
      items: _state.items.where((item) => item.id != highlightId).toList(growable: false),
    );
    notifyListeners();
  }
}
