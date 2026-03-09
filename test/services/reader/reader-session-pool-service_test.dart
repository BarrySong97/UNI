import 'package:flutter_test/flutter_test.dart';

import 'package:uni/services/reader/reader-session-pool-service.dart';

void main() {
  group('ReaderSessionPoolService', () {
    test('evicts LFU then LRU when capacity exceeded', () {
      final pool = ReaderSessionPoolService();
      pool.removeBook('a', reason: 'reset');
      pool.removeBook('b', reason: 'reset');
      pool.removeBook('c', reason: 'reset');
      pool.removeBook('d', reason: 'reset');

      pool.acquire('a', '/a');
      pool.acquire('b', '/b');
      pool.acquire('c', '/c');

      pool.incrementOpenCountIfExists('a'); // a = 2
      pool.incrementOpenCountIfExists('b'); // b = 2
      final b = pool.getByBookId('b')!;
      b.lastUsedAt = DateTime.now().subtract(const Duration(minutes: 5));

      final acquireD = pool.acquire('d', '/d');

      expect(acquireD.evictedBookIds, isNotEmpty);
      expect(pool.getByBookId('c'), isNull); // c had lowest openCount
      expect(pool.getByBookId('d'), isNotNull);
    });

    test('evicts stale sessions by ttl', () {
      final pool = ReaderSessionPoolService();
      pool.removeBook('ttl-book', reason: 'reset');
      pool.acquire('ttl-book', '/ttl');
      final session = pool.getByBookId('ttl-book')!;
      session.lastUsedAt = DateTime.now().subtract(
        ReaderSessionPoolService.ttl + const Duration(seconds: 1),
      );

      final evicted = pool.evictExpired();

      expect(evicted, contains('ttl-book'));
      expect(pool.getByBookId('ttl-book'), isNull);
    });

    test('acquire existing book returns hit and increments openCount', () {
      final pool = ReaderSessionPoolService();
      pool.removeBook('hit-book', reason: 'reset');

      pool.acquire('hit-book', '/hit');
      final second = pool.acquire('hit-book', '/hit');

      expect(second.evictedBookIds, isEmpty);
      expect(second.session.openCount, 2);
    });
  });
}
