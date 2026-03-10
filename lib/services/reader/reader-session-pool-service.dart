import 'dart:async';

import 'reader-performance-tracker.dart';

class ReaderSessionInfo {
  ReaderSessionInfo({
    required this.bookId,
    required this.sessionId,
    required this.resolvedEpubPath,
    this.openCount = 0,
    DateTime? lastOpenedAt,
    DateTime? lastUsedAt,
  }) : lastOpenedAt = lastOpenedAt ?? DateTime.now(),
       lastUsedAt = lastUsedAt ?? DateTime.now();

  final String bookId;
  final String sessionId;
  final String resolvedEpubPath;
  int openCount;
  DateTime lastOpenedAt;
  DateTime lastUsedAt;
}

class ReaderSessionAcquireResult {
  const ReaderSessionAcquireResult({
    required this.session,
    this.evictedBookIds = const <String>[],
  });

  final ReaderSessionInfo session;
  final List<String> evictedBookIds;
}

class ReaderSessionPoolService {
  factory ReaderSessionPoolService() => _instance;
  ReaderSessionPoolService._();
  static final ReaderSessionPoolService _instance =
      ReaderSessionPoolService._();

  static const int maxSize = 3;
  static const Duration ttl = Duration(minutes: 15);

  final Map<String, ReaderSessionInfo> _byBookId =
      <String, ReaderSessionInfo>{};
  Timer? _gcTimer;

  void startPeriodicGc({
    Duration interval = const Duration(seconds: 60),
    required Future<void> Function(List<String> bookIds) onEvict,
  }) {
    // 定时 GC 只负责产出“该淘汰哪些 bookId”，真正资源释放交给上层 controller。
    _gcTimer?.cancel();
    _gcTimer = Timer.periodic(interval, (_) async {
      final evicted = evictExpired();
      if (evicted.isNotEmpty) {
        await onEvict(evicted);
      }
    });
  }

  void stopPeriodicGc() {
    _gcTimer?.cancel();
    _gcTimer = null;
  }

  ReaderSessionAcquireResult acquire(String bookId, String resolvedEpubPath) {
    final now = DateTime.now();
    final existed = _byBookId[bookId];
    if (existed != null) {
      // 命中热池：提升活跃度和打开计数，优先保留常读书。
      existed.lastUsedAt = now;
      existed.lastOpenedAt = now;
      existed.openCount += 1;
      ReaderPerf.mark(
        'pool.hit',
        bookId: bookId,
        extras: <String, Object?>{'sessionId': existed.sessionId},
      );
      ReaderPerf.mark(
        'session.open_count_increment',
        bookId: bookId,
        extras: <String, Object?>{'openCount': existed.openCount},
      );
      return ReaderSessionAcquireResult(session: existed);
    }

    final evicted = evictOneIfNeeded();
    final session = ReaderSessionInfo(
      bookId: bookId,
      sessionId: bookId,
      resolvedEpubPath: resolvedEpubPath,
      openCount: 1,
      lastOpenedAt: now,
      lastUsedAt: now,
    );
    _byBookId[bookId] = session;
    ReaderPerf.mark(
      'pool.miss',
      bookId: bookId,
      extras: <String, Object?>{'sessionId': session.sessionId},
    );
    ReaderPerf.mark(
      'session.open_count_increment',
      bookId: bookId,
      extras: <String, Object?>{'openCount': session.openCount},
    );
    return ReaderSessionAcquireResult(
      session: session,
      evictedBookIds: evicted,
    );
  }

  void markUsed(String bookId) {
    final session = _byBookId[bookId];
    if (session == null) {
      return;
    }
    session.lastUsedAt = DateTime.now();
  }

  void incrementOpenCountIfExists(String bookId) {
    final session = _byBookId[bookId];
    if (session == null) {
      return;
    }
    session.openCount += 1;
    session.lastOpenedAt = DateTime.now();
    session.lastUsedAt = DateTime.now();
    ReaderPerf.mark(
      'session.open_count_increment',
      bookId: bookId,
      extras: <String, Object?>{'openCount': session.openCount},
    );
  }

  List<String> evictExpired() {
    final now = DateTime.now();
    final expired = _byBookId.values
        .where((s) => now.difference(s.lastUsedAt) >= ttl)
        .map((s) => s.bookId)
        .toList(growable: false);
    ReaderPerf.mark(
      'pool.gc.run',
      extras: <String, Object?>{
        'scanned': _byBookId.length,
        'evicted': expired.length,
      },
    );
    for (final bookId in expired) {
      // 这里只维护池元数据；publication/WebView 释放由上层统一执行。
      _byBookId.remove(bookId);
      ReaderPerf.mark(
        'pool.evict',
        bookId: bookId,
        extras: <String, Object?>{'reason': 'ttl'},
      );
    }
    return expired;
  }

  List<String> evictOneIfNeeded() {
    if (_byBookId.length < maxSize) {
      return const <String>[];
    }
    final candidate = _byBookId.values.reduce((a, b) {
      // 先按 LFU（openCount）淘汰，平局再按 LRU（lastUsedAt）淘汰。
      if (a.openCount != b.openCount) {
        return a.openCount < b.openCount ? a : b;
      }
      return a.lastUsedAt.isBefore(b.lastUsedAt) ? a : b;
    });
    _byBookId.remove(candidate.bookId);
    ReaderPerf.mark(
      'pool.evict',
      bookId: candidate.bookId,
      extras: <String, Object?>{'reason': 'capacity'},
    );
    return <String>[candidate.bookId];
  }

  List<ReaderSessionInfo> sessions() =>
      _byBookId.values.toList(growable: false);

  ReaderSessionInfo? getByBookId(String bookId) => _byBookId[bookId];

  void removeBook(String bookId, {String reason = 'lifecycle'}) {
    final removed = _byBookId.remove(bookId);
    if (removed != null) {
      ReaderPerf.mark(
        'pool.evict',
        bookId: bookId,
        extras: <String, Object?>{'reason': reason},
      );
    }
  }

  List<ReaderSessionInfo> rankedByOpenCountThenRecent() {
    final list = _byBookId.values.toList(growable: false);
    list.sort((a, b) {
      final byCount = b.openCount.compareTo(a.openCount);
      if (byCount != 0) {
        return byCount;
      }
      return b.lastUsedAt.compareTo(a.lastUsedAt);
    });
    return list;
  }
}
