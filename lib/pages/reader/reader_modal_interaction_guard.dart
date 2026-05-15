import 'dart:async';

import 'package:flutter/foundation.dart';

class ReaderModalInteractionGuard extends ChangeNotifier {
  ReaderModalInteractionGuard({
    this.releaseDelay = const Duration(milliseconds: 220),
  });

  final Duration releaseDelay;

  Timer? _releaseTimer;
  int _generation = 0;
  bool _isBlocking = false;

  bool get isBlocking => _isBlocking;

  Future<T> runWhileBlocked<T>(Future<T> Function() action) async {
    final generation = ++_generation;
    _setBlocking(true);
    try {
      return await action();
    } finally {
      _releaseTimer?.cancel();
      _releaseTimer = Timer(releaseDelay, () {
        if (_generation != generation) {
          return;
        }
        _setBlocking(false);
      });
    }
  }

  void _setBlocking(bool value) {
    if (_isBlocking == value) {
      return;
    }
    _isBlocking = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    super.dispose();
  }
}
