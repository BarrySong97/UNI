import 'dart:async';

class Throttler {
  Throttler({required this.duration});

  final Duration duration;
  bool _isLocked = false;

  void run(void Function() action) {
    if (_isLocked) {
      return;
    }
    _isLocked = true;
    action();
    Timer(duration, () {
      _isLocked = false;
    });
  }
}
