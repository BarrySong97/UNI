import 'dart:async';
import 'dart:collection';

import 'package:flureadium/flureadium.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/pages/reader/reader-channel-mixin.dart';
import 'package:uni/stores/reader/reader-store.dart';

class _ReaderChannelHarness with ReaderChannelMixin {
  _ReaderChannelHarness(this._restoreQueue, {this.publication});

  final Queue<Completer<void>> _restoreQueue;
  final Publication? publication;

  @override
  final Flureadium flureadium = Flureadium();

  int statusSubscribeCount = 0;
  int locatorSubscribeCount = 0;
  int restoreCallCount = 0;

  @override
  ReaderStore? get readerStore => null;

  @override
  Publication? get activePublication => publication;

  @override
  String? get activeSessionId => 'book-1';

  @override
  StreamSubscription<ReaderStatusEvent> subscribeStatusEvents(
    void Function(ReaderStatusEvent event) onData,
  ) {
    statusSubscribeCount += 1;
    return const Stream<ReaderStatusEvent>.empty().listen(onData);
  }

  @override
  StreamSubscription<ReaderLocatorEvent> subscribeLocatorEvents(
    void Function(ReaderLocatorEvent event) onData,
  ) {
    locatorSubscribeCount += 1;
    return const Stream<ReaderLocatorEvent>.empty().listen(onData);
  }

  @override
  Future<void> restoreSavedPosition() async {
    restoreCallCount += 1;
    if (_restoreQueue.isEmpty) {
      return;
    }
    await _restoreQueue.removeFirst().future;
  }
}

void main() {
  Publication buildPublication() {
    final pub = Publication.fromJson(<String, dynamic>{
      'metadata': <String, dynamic>{'title': 'Test Book'},
      'links': <Map<String, dynamic>>[],
      'readingOrder': <Map<String, dynamic>>[
        <String, dynamic>{
          'href': 'chapter1.xhtml',
          'type': 'application/xhtml+xml',
        },
        <String, dynamic>{
          'href': 'chapter2.xhtml',
          'type': 'application/xhtml+xml',
        },
        <String, dynamic>{
          'href': 'chapter3.xhtml',
          'type': 'application/xhtml+xml',
        },
      ],
    });
    expect(pub, isNotNull);
    return pub!;
  }

  test('subscribeToChannels attaches locator listener after restore', () async {
    final restore = Completer<void>();
    final harness = _ReaderChannelHarness(
      Queue<Completer<void>>.of(<Completer<void>>[restore]),
    );

    final subscribeFuture = harness.subscribeToChannels();

    expect(harness.statusSubscribeCount, 1);
    expect(harness.restoreCallCount, 1);
    expect(harness.locatorSubscribeCount, 0);

    restore.complete();
    await subscribeFuture;

    expect(harness.locatorSubscribeCount, 1);
  });

  test(
    'stale subscribe call cannot attach locator after a newer subscribe',
    () async {
      final restore1 = Completer<void>();
      final restore2 = Completer<void>();
      final harness = _ReaderChannelHarness(
        Queue<Completer<void>>.of(<Completer<void>>[restore1, restore2]),
      );

      final firstSubscribe = harness.subscribeToChannels();
      final secondSubscribe = harness.subscribeToChannels();

      expect(harness.statusSubscribeCount, 2);
      expect(harness.restoreCallCount, 2);
      expect(harness.locatorSubscribeCount, 0);

      restore1.complete();
      await firstSubscribe;
      expect(harness.locatorSubscribeCount, 0);

      restore2.complete();
      await secondSubscribe;
      expect(harness.locatorSubscribeCount, 1);
    },
  );

  test('extractPercentFromLocator uses page fragments only', () {
    final harness = _ReaderChannelHarness(Queue<Completer<void>>());
    final locator = Locator.fromJson(<String, dynamic>{
      'href': '/chapter1.xhtml',
      'type': 'text/html',
      'locations': <String, dynamic>{
        'fragments': <String>['page=15', 'totalPages=26'],
      },
    });

    expect(locator, isNotNull);
    expect(
      harness.extractPercentFromLocator(locator!),
      closeTo(0.56, 0.000001),
    );
  });

  test(
    'extractPercentFromLocator returns null when page and total are absent',
    () {
      final harness = _ReaderChannelHarness(Queue<Completer<void>>());
      final locator = Locator.fromJson(<String, dynamic>{
        'href': '/chapter1.xhtml',
        'type': 'text/html',
        'locations': <String, dynamic>{'position': 12},
      });

      expect(locator, isNotNull);
      expect(harness.extractPercentFromLocator(locator!), isNull);
    },
  );

  test('extractPercentFromLocator ignores chapter-level progression only', () {
    final harness = _ReaderChannelHarness(Queue<Completer<void>>());
    final locator = Locator.fromJson(<String, dynamic>{
      'href': '/chapter2.xhtml',
      'type': 'text/html',
      'locations': <String, dynamic>{'progression': 0.85},
    });

    expect(locator, isNotNull);
    expect(harness.extractPercentFromLocator(locator!), isNull);
  });

  test(
    'extractPercentFromEvent computes whole-book percent from publication',
    () {
      final harness = _ReaderChannelHarness(
        Queue<Completer<void>>(),
        publication: buildPublication(),
      );
      final locator = Locator.fromJson(<String, dynamic>{
        'href': '/chapter2.xhtml',
        'type': 'application/xhtml+xml',
        'locations': <String, dynamic>{'progression': 0.25},
      });
      expect(locator, isNotNull);

      final event = ReaderLocatorEvent(locator: locator!);
      expect(
        harness.extractPercentFromEvent(
          event,
          publication: harness.activePublication,
        ),
        closeTo(0.416666, 0.000001),
      );
    },
  );

  test('extractPercentFromEvent returns null without page info', () {
    final harness = _ReaderChannelHarness(Queue<Completer<void>>());
    final locator = Locator.fromJson(<String, dynamic>{
      'href': '/chapter1.xhtml',
      'type': 'text/html',
      'locations': <String, dynamic>{},
    });
    expect(locator, isNotNull);

    final event = ReaderLocatorEvent(locator: locator!);
    expect(harness.extractPercentFromEvent(event), isNull);
  });
}
