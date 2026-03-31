import 'kp_items.dart';

/// Caches pre-built K-P item sequences for paragraph-like nodes.
///
/// Cache values are immutable item lists that can be reused across repeated
/// pagination calls with identical text/style/layout inputs.
class ParagraphPrepareCache {
  final Map<String, List<KPItem>> _itemsByKey = {};

  List<KPItem>? get(String key) => _itemsByKey[key];

  void put(String key, List<KPItem> items) {
    _itemsByKey[key] = List<KPItem>.unmodifiable(items);
  }

  void clear() => _itemsByKey.clear();

  int get size => _itemsByKey.length;
}
