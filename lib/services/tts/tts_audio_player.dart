import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

abstract class TtsAudioPlayer {
  Future<void> playFile(String path, {required double volume});

  Future<void> stop();

  void setOnComplete(VoidCallback callback);

  void dispose();
}

class DefaultTtsAudioPlayer implements TtsAudioPlayer {
  DefaultTtsAudioPlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _completeSubscription = _player.onPlayerComplete.listen((_) {
      _onComplete?.call();
    });
  }

  final AudioPlayer _player;
  late final StreamSubscription<void> _completeSubscription;
  VoidCallback? _onComplete;

  @override
  Future<void> playFile(String path, {required double volume}) async {
    await _player.setVolume(volume);
    await _player.play(DeviceFileSource(path));
  }

  @override
  Future<void> stop() {
    return _player.stop();
  }

  @override
  void setOnComplete(VoidCallback callback) {
    _onComplete = callback;
  }

  @override
  void dispose() {
    unawaited(_completeSubscription.cancel());
    _player.dispose();
  }
}
