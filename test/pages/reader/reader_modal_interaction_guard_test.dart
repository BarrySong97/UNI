import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:uni/pages/reader/reader_modal_interaction_guard.dart';

void main() {
  test('blocks immediately and releases after the settle delay', () async {
    final guard = ReaderModalInteractionGuard(
      releaseDelay: const Duration(milliseconds: 20),
    );
    addTearDown(guard.dispose);

    final completer = Completer<void>();
    final future = guard.runWhileBlocked(() => completer.future);

    expect(guard.isBlocking, isTrue);

    completer.complete();
    await future;
    expect(guard.isBlocking, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(guard.isBlocking, isFalse);
  });

  test('keeps blocking until the latest modal settles', () async {
    final guard = ReaderModalInteractionGuard(
      releaseDelay: const Duration(milliseconds: 20),
    );
    addTearDown(guard.dispose);

    await guard.runWhileBlocked(() async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      unawaited(
        guard.runWhileBlocked(
          () async => Future<void>.delayed(const Duration(milliseconds: 5)),
        ),
      );
    });

    expect(guard.isBlocking, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(guard.isBlocking, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(guard.isBlocking, isFalse);
  });
}
