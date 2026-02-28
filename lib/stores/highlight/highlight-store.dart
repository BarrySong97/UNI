import 'package:flutter/foundation.dart';

import '../../entities/highlight-entity.dart';
import '../../repositories/highlight/highlight-repository.dart';
import '../../services/highlight/highlight-anchor-service.dart';
import '../../services/highlight/highlight-resolver-service.dart';
import '../../shared/utils/text-range-utils.dart';
import 'highlight-state.dart';

class HighlightStore extends ChangeNotifier {
  HighlightStore({
    required HighlightRepository highlightRepository,
    HighlightAnchorService? anchorService,
    HighlightResolverService? resolverService,
  })  : _highlightRepository = highlightRepository,
        _anchorService = anchorService ?? HighlightAnchorService(),
        _resolverService = resolverService ?? HighlightResolverService();

  final HighlightRepository _highlightRepository;
  final HighlightAnchorService _anchorService;
  final HighlightResolverService _resolverService;

  HighlightState _state = const HighlightState();

  HighlightState get state => _state;

  Future<void> loadHighlights(String bookId, {String? chapterId}) async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();
    final items = await _highlightRepository.getHighlights(bookId, chapterId: chapterId);
    _state = _state.copyWith(items: _resolverService.sortForRender(items), isLoading: false);
    notifyListeners();
  }

  Future<HighlightEntity> createHighlight({
    required String bookId,
    required String chapterId,
    required String chapterText,
    required int startOffset,
    required int endOffset,
    String? color,
    String? note,
  }) async {
    final normalized = TextRangeUtils.normalize(start: startOffset, end: endOffset, max: chapterText.length);
    final anchor = _anchorService.createAnchor(
      chapterText: chapterText,
      start: normalized.start,
      end: normalized.end,
    );
    final now = DateTime.now();
    final highlight = HighlightEntity(
      id: '${chapterId}_${now.microsecondsSinceEpoch}',
      bookId: bookId,
      chapterId: chapterId,
      startOffset: normalized.start,
      endOffset: normalized.end,
      selectedText: anchor.selectedText,
      prefixContext: anchor.prefixContext,
      suffixContext: anchor.suffixContext,
      color: color ?? _state.selectedColor,
      note: note,
      createdAt: now,
      updatedAt: now,
    );

    final created = await _highlightRepository.createHighlight(highlight);
    final next = List<HighlightEntity>.from(_state.items)..add(created);
    _state = _state.copyWith(items: _resolverService.sortForRender(next));
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
