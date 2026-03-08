import 'dart:async';

import 'package:flureadium/flureadium.dart';

/// Caches the most recently opened [Publication] so that reopening the same
/// book skips the expensive native EPUB parsing step.
///
/// The native side keeps `currentPublication` alive as long as
/// [closePublication] is not called. When the user returns to the same book
/// we reuse both the Dart object and the native state.
class PublicationCacheService {
  factory PublicationCacheService() => _instance;
  PublicationCacheService._();
  static final PublicationCacheService _instance = PublicationCacheService._();

  final Flureadium _flureadium = Flureadium();

  String? _cachedPath;
  Publication? _cachedPub;
  Completer<Publication>? _pending;

  /// Returns the cached [Publication] if [resolvedPath] matches the currently
  /// open book. Otherwise opens a new publication (the native side
  /// automatically closes the previous one).
  Future<Publication> getOrOpen(String resolvedPath) async {
    // Wait for any in-flight open to finish.
    if (_pending != null) {
      await _pending!.future;
    }

    if (_cachedPath == resolvedPath && _cachedPub != null) {
      return _cachedPub!;
    }

    final completer = Completer<Publication>();
    _pending = completer;

    try {
      final pub = await _flureadium.openPublication(resolvedPath);
      _cachedPath = resolvedPath;
      _cachedPub = pub;
      completer.complete(pub);
      return pub;
    } catch (e) {
      _cachedPath = null;
      _cachedPub = null;
      completer.completeError(e);
      rethrow;
    } finally {
      _pending = null;
    }
  }

  /// Properly closes the native publication and clears the cache.
  /// Call this on app background / terminate.
  Future<void> evict() async {
    if (_cachedPub != null) {
      await _flureadium.closePublication();
      _cachedPub = null;
      _cachedPath = null;
    }
  }
}
