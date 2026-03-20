import 'dart:collection';

import '../../repositories/progress/progress-repository.dart';
import 'reader_store.dart';

/// LRU cache of [ReaderStore] instances keyed by book ID.
///
/// Keeps the in-memory pagination cache (TextPainters, decoded images, page
/// layouts) alive across reader entries so that re-opening the same book is
/// instant.
class ReaderStoreManager {
  ReaderStoreManager({
    required this.progressRepository,
    this.maxStores = 2,
  });

  final ProgressRepository progressRepository;
  final int maxStores;

  // ignore: prefer_collection_literals
  final _stores = LinkedHashMap<String, ReaderStore>();

  /// Get or create a [ReaderStore] for [bookId].
  ///
  /// If a store already exists it is moved to the MRU end of the LRU map.
  /// If the cache is at capacity the oldest store is evicted and disposed.
  ReaderStore getStore(String bookId) {
    final existing = _stores.remove(bookId);
    if (existing != null) {
      _stores[bookId] = existing;
      return existing;
    }

    // Evict oldest entries until we have room.
    while (_stores.length >= maxStores) {
      final oldest = _stores.keys.first;
      _stores.remove(oldest)?.dispose();
    }

    final store = ReaderStore(progressRepository: progressRepository);
    _stores[bookId] = store;
    return store;
  }

  void dispose() {
    for (final store in _stores.values) {
      store.dispose();
    }
    _stores.clear();
  }
}
