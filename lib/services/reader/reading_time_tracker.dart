import 'dart:async';

class ReadingTimeTracker {
  ReadingTimeTracker({
    required Future<void> Function(int deltaSeconds) onFlush,
    Duration idleThreshold = const Duration(seconds: 30),
    Duration flushInterval = const Duration(seconds: 5),
    DateTime Function()? now,
  }) : _onFlush = onFlush,
       _idleThreshold = idleThreshold,
       _flushInterval = flushInterval,
       _now = now ?? DateTime.now {
    _timer = Timer.periodic(_flushInterval, (_) {
      unawaited(_flushIfNeeded());
    });
  }

  final Future<void> Function(int deltaSeconds) _onFlush;
  final Duration _idleThreshold;
  final Duration _flushInterval;
  final DateTime Function() _now;

  late final Timer _timer;
  DateTime? _lastAccountingAt;
  DateTime? _lastInteractionAt;
  int _pendingMilliseconds = 0;
  bool _isForeground = false;

  void onAppForeground() {
    final now = _now();
    _captureElapsed(now);
    _isForeground = true;
    _lastAccountingAt = now;
  }

  Future<void> onAppBackground() async {
    final now = _now();
    _captureElapsed(now);
    _isForeground = false;
    _lastAccountingAt = now;
    _lastInteractionAt = null;
    await _flushIfNeeded();
  }

  void onInteraction() {
    final now = _now();
    _captureElapsed(now);
    _lastInteractionAt = now;
    _lastAccountingAt = now;
  }

  Future<void> flushNow() async {
    await _flushIfNeeded();
  }

  Future<void> dispose() async {
    final now = _now();
    _captureElapsed(now);
    _timer.cancel();
    await _flushIfNeeded();
  }

  void _captureElapsed(DateTime now) {
    final lastAccountingAt = _lastAccountingAt;
    if (lastAccountingAt == null) {
      _lastAccountingAt = now;
      return;
    }

    if (!_isForeground || _lastInteractionAt == null) {
      _lastAccountingAt = now;
      return;
    }

    final activeUntil = _lastInteractionAt!.add(_idleThreshold);
    final effectiveEnd = now.isBefore(activeUntil) ? now : activeUntil;
    if (effectiveEnd.isAfter(lastAccountingAt)) {
      _pendingMilliseconds += effectiveEnd
          .difference(lastAccountingAt)
          .inMilliseconds;
    }
    _lastAccountingAt = now;
  }

  Future<void> _flushIfNeeded() async {
    _captureElapsed(_now());
    final deltaSeconds = _pendingMilliseconds ~/ 1000;
    if (deltaSeconds <= 0) {
      return;
    }

    _pendingMilliseconds -= deltaSeconds * 1000;
    await _onFlush(deltaSeconds);
  }
}
