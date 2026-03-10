import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flureadium/flureadium.dart';

import 'publication-cache-service.dart';
import 'reader-performance-tracker.dart';
import 'reader-session-pool-service.dart';

enum ReaderOverlayPhase { idle, preloading, ready, visible }

class ReaderOverlaySlot {
  ReaderOverlaySlot({
    required this.bookId,
    required this.sessionId,
    required this.resolvedEpubPath,
    required this.publication,
    required this.initialLocatorJson,
    required this.phase,
    this.isContentReady = false,
  });

  final String bookId;
  final String sessionId;
  final String resolvedEpubPath;
  final Publication publication;
  final String? initialLocatorJson;
  final ReaderOverlayPhase phase;
  final bool isContentReady;

  ReaderOverlaySlot copyWith({
    Publication? publication,
    String? initialLocatorJson,
    ReaderOverlayPhase? phase,
    bool? isContentReady,
  }) {
    return ReaderOverlaySlot(
      bookId: bookId,
      sessionId: sessionId,
      resolvedEpubPath: resolvedEpubPath,
      publication: publication ?? this.publication,
      initialLocatorJson: initialLocatorJson ?? this.initialLocatorJson,
      phase: phase ?? this.phase,
      isContentReady: isContentReady ?? this.isContentReady,
    );
  }
}

class ReaderOverlayController extends ChangeNotifier {
  void startGc() {
    _sessionPool.startPeriodicGc(
      onEvict: (bookIds) async {
        for (final bookId in bookIds) {
          await _evictBook(bookId, reason: 'ttl');
        }
        notifyListeners();
      },
    );
  }

  final ReaderSessionPoolService _sessionPool = ReaderSessionPoolService();
  final PublicationCacheService _publicationCache = PublicationCacheService();

  final Map<String, ReaderOverlaySlot> _slots = <String, ReaderOverlaySlot>{};
  String? _visibleBookId;
  String? _lastPreloadedBookId;

  ReaderOverlayPhase get phase {
    if (_visibleBookId == null) {
      return ReaderOverlayPhase.idle;
    }
    return _slots[_visibleBookId!]?.phase ?? ReaderOverlayPhase.idle;
  }

  String? get preloadedBookId => _lastPreloadedBookId;

  Publication? get publication {
    final visibleBookId = _visibleBookId;
    if (visibleBookId == null) {
      return null;
    }
    return _slots[visibleBookId]?.publication;
  }

  String? get visibleBookId => _visibleBookId;

  List<ReaderOverlaySlot> get slots => _slots.values.toList(growable: false);

  ReaderOverlaySlot? slotForBook(String bookId) => _slots[bookId];

  String? sessionIdForBook(String bookId) => _slots[bookId]?.sessionId;

  String? bookIdForSession(String sessionId) {
    for (final slot in _slots.values) {
      if (slot.sessionId == sessionId) {
        return slot.bookId;
      }
    }
    return null;
  }

  Future<void> preloadForBook(
    String bookId,
    String resolvedEpubPath, {
    String? initialLocatorJson,
  }) async {
    final existing = _slots[bookId];
    if (existing != null && existing.phase != ReaderOverlayPhase.idle) {
      ReaderPerf.mark(
        'overlay.preload.skip_same_book',
        bookId: bookId,
        extras: <String, Object?>{'phase': existing.phase.name},
      );
      return;
    }

    final acquire = _sessionPool.acquire(bookId, resolvedEpubPath);
    for (final evictedBookId in acquire.evictedBookIds) {
      await _evictBook(evictedBookId, reason: 'capacity');
    }

    final watch = ReaderPerf.start(
      'overlay.preload',
      bookId: bookId,
      extras: <String, Object?>{
        'path': resolvedEpubPath,
        'sessionId': acquire.session.sessionId,
      },
    );

    try {
      final pub = await _publicationCache.getOrOpen(
        resolvedEpubPath,
        sessionId: acquire.session.sessionId,
      );
      // 预加载阶段只保证 publication 就绪；是否可秒开要等 overlay widget 自身 ready 信号。
      _slots[bookId] = ReaderOverlaySlot(
        bookId: bookId,
        sessionId: acquire.session.sessionId,
        resolvedEpubPath: resolvedEpubPath,
        publication: pub,
        initialLocatorJson: initialLocatorJson,
        phase: ReaderOverlayPhase.preloading,
        isContentReady: false,
      );
      _lastPreloadedBookId = bookId;
      ReaderPerf.mark('overlay.preload.publication_ready', bookId: bookId);
      ReaderPerf.end('overlay.preload', watch, bookId: bookId);
    } catch (e) {
      debugPrint('[ReaderOverlay] preload failed: $e');
      ReaderPerf.mark(
        'overlay.preload.error',
        bookId: bookId,
        extras: <String, Object?>{'error': e.toString()},
      );
      await _evictBook(bookId, reason: 'preload_error');
    }
    notifyListeners();
  }

  void show([String? bookId]) {
    final targetBookId = bookId ?? _lastPreloadedBookId;
    if (targetBookId == null) {
      return;
    }
    final slot = _slots[targetBookId];
    // 只有 content_ready 的槽位才允许展示，避免“看起来打开了但正文还没稳定”。
    if (slot == null || !slot.isContentReady) {
      return;
    }
    _sessionPool.markUsed(targetBookId);
    _visibleBookId = targetBookId;
    _slots[targetBookId] = slot.copyWith(phase: ReaderOverlayPhase.visible);
    ReaderPerf.mark('overlay.show', bookId: targetBookId);
    notifyListeners();
  }

  void hide() {
    final visibleBookId = _visibleBookId;
    if (visibleBookId == null) {
      return;
    }
    final slot = _slots[visibleBookId];
    if (slot == null) {
      _visibleBookId = null;
      notifyListeners();
      return;
    }
    _slots[visibleBookId] = slot.copyWith(phase: ReaderOverlayPhase.ready);
    _visibleBookId = null;
    ReaderPerf.mark('overlay.hide', bookId: visibleBookId);
    notifyListeners();
  }

  Future<void> markLifecycleEvictAll() async {
    final books = _slots.keys.toList(growable: false);
    for (final bookId in books) {
      await _evictBook(bookId, reason: 'lifecycle');
    }
    _visibleBookId = null;
    _lastPreloadedBookId = null;
    notifyListeners();
  }

  void invalidate() {
    unawaited(markLifecycleEvictAll());
  }

  @override
  void dispose() {
    stopGc();
    super.dispose();
  }

  void stopGc() {
    _sessionPool.stopPeriodicGc();
  }

  Future<void> runGc() async {
    final expiredBooks = _sessionPool.evictExpired();
    if (expiredBooks.isEmpty) {
      return;
    }
    for (final bookId in expiredBooks) {
      await _evictBook(bookId, reason: 'ttl');
    }
    notifyListeners();
  }

  Future<void> _evictBook(String bookId, {required String reason}) async {
    final slot = _slots.remove(bookId);
    if (slot == null) {
      _sessionPool.removeBook(bookId, reason: reason);
      return;
    }
    // 回收顺序：先关 native publication，再删会话元数据，避免悬挂引用。
    await _publicationCache.evictBySession(slot.sessionId);
    _sessionPool.removeBook(bookId, reason: reason);
    if (_visibleBookId == bookId) {
      _visibleBookId = null;
    }
    if (_lastPreloadedBookId == bookId) {
      _lastPreloadedBookId = null;
    }
  }

  /// Marks that the preloaded reader has emitted its first meaningful signal
  /// (status/locator), which indicates it's stable enough for instant show.
  void markContentReady(String bookId) {
    final slot = _slots[bookId];
    if (slot == null) {
      return;
    }
    if (slot.isContentReady) {
      return;
    }
    // 由 overlay 层在收到首个有效 reader 信号后调用，标记该书进入秒开可用态。
    _slots[bookId] = slot.copyWith(
      phase: ReaderOverlayPhase.ready,
      isContentReady: true,
    );
    ReaderPerf.mark('overlay.content_ready', bookId: bookId);
    notifyListeners();
  }

  bool canShowInstantly(String bookId) {
    final slot = _slots[bookId];
    return slot != null &&
        slot.phase == ReaderOverlayPhase.ready &&
        slot.isContentReady;
  }
}
