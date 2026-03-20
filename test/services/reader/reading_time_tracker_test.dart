import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/reader/reading_time_tracker.dart';

void main() {
  test('tracks time while foreground and interactive', () async {
    var current = DateTime(2026, 3, 1, 12);
    final flushed = <int>[];
    final tracker = ReadingTimeTracker(
      onFlush: (deltaSeconds) async {
        flushed.add(deltaSeconds);
      },
      flushInterval: const Duration(days: 1),
      now: () => current,
    );

    tracker.onAppForeground();
    tracker.onInteraction();
    current = current.add(const Duration(seconds: 5));

    await tracker.flushNow();

    expect(flushed.fold<int>(0, (sum, value) => sum + value), 5);
    await tracker.dispose();
  });

  test('stops tracking after idle threshold', () async {
    var current = DateTime(2026, 3, 1, 12);
    final flushed = <int>[];
    final tracker = ReadingTimeTracker(
      onFlush: (deltaSeconds) async {
        flushed.add(deltaSeconds);
      },
      flushInterval: const Duration(days: 1),
      now: () => current,
    );

    tracker.onAppForeground();
    tracker.onInteraction();
    current = current.add(const Duration(seconds: 40));

    await tracker.flushNow();

    expect(flushed.fold<int>(0, (sum, value) => sum + value), 30);
    await tracker.dispose();
  });

  test('requires new interaction after returning from background', () async {
    var current = DateTime(2026, 3, 1, 12);
    final flushed = <int>[];
    final tracker = ReadingTimeTracker(
      onFlush: (deltaSeconds) async {
        flushed.add(deltaSeconds);
      },
      flushInterval: const Duration(days: 1),
      now: () => current,
    );

    tracker.onAppForeground();
    tracker.onInteraction();
    current = current.add(const Duration(seconds: 10));

    await tracker.onAppBackground();

    tracker.onAppForeground();
    current = current.add(const Duration(seconds: 10));
    await tracker.flushNow();

    tracker.onInteraction();
    current = current.add(const Duration(seconds: 5));
    await tracker.flushNow();

    expect(flushed.fold<int>(0, (sum, value) => sum + value), 15);
    await tracker.dispose();
  });

  test('flushes pending whole seconds on dispose', () async {
    var current = DateTime(2026, 3, 1, 12);
    final flushed = <int>[];
    final tracker = ReadingTimeTracker(
      onFlush: (deltaSeconds) async {
        flushed.add(deltaSeconds);
      },
      flushInterval: const Duration(days: 1),
      now: () => current,
    );

    tracker.onAppForeground();
    tracker.onInteraction();
    current = current.add(const Duration(seconds: 3));

    await tracker.dispose();

    expect(flushed.fold<int>(0, (sum, value) => sum + value), 3);
  });
}
