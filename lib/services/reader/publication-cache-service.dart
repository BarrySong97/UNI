import 'dart:async';

import 'package:flureadium/flureadium.dart';

import 'reader-performance-tracker.dart';

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

  final Map<String, Publication> _cachedPubs = <String, Publication>{};
  final Map<String, String> _cachedPaths = <String, String>{};
  final Map<String, Completer<Publication>> _pendingBySession =
      <String, Completer<Publication>>{};

  /// Returns the cached [Publication] if [resolvedPath] matches the currently
  /// open book. Otherwise opens a new publication (the native side
  /// automatically closes the previous one).
  Future<Publication> getOrOpen(
    String resolvedPath, {
    String? sessionId,
  }) async {
    final key = sessionId ?? '__legacy__';
    final watch = ReaderPerf.start(
      'publication.get_or_open',
      extras: <String, Object?>{'path': resolvedPath, 'sessionId': key},
    );
    // Wait for any in-flight open to finish.
    final pending = _pendingBySession[key];
    if (pending != null) {
      ReaderPerf.mark(
        'publication.wait_pending',
        extras: <String, Object?>{'path': resolvedPath, 'sessionId': key},
      );
      await pending.future;
    }

    if (_cachedPaths[key] == resolvedPath && _cachedPubs[key] != null) {
      ReaderPerf.mark(
        'publication.cache_hit',
        extras: <String, Object?>{'path': resolvedPath, 'sessionId': key},
      );
      ReaderPerf.end(
        'publication.get_or_open',
        watch,
        extras: <String, Object?>{'hit': true, 'sessionId': key},
      );
      return _cachedPubs[key]!;
    }

    final completer = Completer<Publication>();
    _pendingBySession[key] = completer;

    try {
      final openWatch = ReaderPerf.start(
        'publication.open_native',
        extras: <String, Object?>{'path': resolvedPath, 'sessionId': key},
      );
      final pub = await _flureadium.openPublication(
        resolvedPath,
        sessionId: sessionId,
      );
      ReaderPerf.end(
        'publication.open_native',
        openWatch,
        extras: <String, Object?>{'path': resolvedPath, 'sessionId': key},
      );
      _cachedPaths[key] = resolvedPath;
      _cachedPubs[key] = pub;
      completer.complete(pub);
      ReaderPerf.end(
        'publication.get_or_open',
        watch,
        extras: <String, Object?>{'hit': false, 'sessionId': key},
      );
      return pub;
    } catch (e) {
      _cachedPaths.remove(key);
      _cachedPubs.remove(key);
      completer.completeError(e);
      ReaderPerf.mark(
        'publication.get_or_open.error',
        extras: <String, Object?>{
          'path': resolvedPath,
          'sessionId': key,
          'error': e.toString(),
        },
      );
      rethrow;
    } finally {
      _pendingBySession.remove(key);
    }
  }

  /// Properly closes the native publication and clears the cache.
  /// Call this on app background / terminate.
  Future<void> evict() async {
    final sessions = _cachedPubs.keys.toList(growable: false);
    for (final sessionKey in sessions) {
      await evictBySession(sessionKey == '__legacy__' ? null : sessionKey);
    }
  }

  Future<void> evictBySession(String? sessionId) async {
    final key = sessionId ?? '__legacy__';
    if (_cachedPubs[key] == null) {
      return;
    }
    await _flureadium.closePublication(sessionId: sessionId);
    _cachedPubs.remove(key);
    _cachedPaths.remove(key);
    _pendingBySession.remove(key);
  }
}
