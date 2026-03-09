import 'package:flutter/foundation.dart';

/// Lightweight debug-only performance logger for reader critical path.
class ReaderPerf {
  static bool get _enabled => kDebugMode;
  static final Map<String, DateTime> _routeFallbackAtByBook =
      <String, DateTime>{};

  static Stopwatch start(
    String stage, {
    String? bookId,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    mark('$stage.start', bookId: bookId, extras: extras);
    return Stopwatch()..start();
  }

  static void end(
    String stage,
    Stopwatch stopwatch, {
    String? bookId,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    stopwatch.stop();
    mark(
      '$stage.end',
      bookId: bookId,
      elapsedMs: stopwatch.elapsedMilliseconds,
      extras: extras,
    );
  }

  static void mark(
    String stage, {
    String? bookId,
    int? elapsedMs,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    if (!_enabled) {
      return;
    }
    final parts = <String>[
      '[PERF][Reader]',
      stage,
      if (bookId != null && bookId.isNotEmpty) 'book=$bookId',
      if (elapsedMs != null) 'elapsed=${elapsedMs}ms',
      ...extras.entries
          .where((entry) => entry.value != null)
          .map((entry) => '${entry.key}=${entry.value}'),
    ];
    debugPrint(parts.join(' '));
  }

  static void markRouteFallback(String bookId) {
    _routeFallbackAtByBook[bookId] = DateTime.now();
  }

  static int? consumeRouteFallbackElapsedMs(String bookId) {
    final at = _routeFallbackAtByBook.remove(bookId);
    if (at == null) {
      return null;
    }
    return DateTime.now().difference(at).inMilliseconds;
  }
}
