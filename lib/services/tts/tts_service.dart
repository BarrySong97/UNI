import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tts_engine.dart';
import 'tts_model_config.dart';
import 'tts_model_manager.dart';

class TtsService extends ChangeNotifier {
  static const String _keySpeed = 'tts_speed';
  static const String _keyVolume = 'tts_volume';
  static const String _keyUsSpeakerId = 'tts_us_speaker_id';
  static const String _keyUkSpeakerId = 'tts_uk_speaker_id';
  static const String _keyReadAloudAccent = 'tts_read_aloud_accent';

  static const double defaultSpeed = 1.0;
  static const double defaultVolume = 1.0;

  late final TtsModelManager _modelManager;
  late final TtsEngine _engine;

  double _speed = defaultSpeed;
  double _volume = defaultVolume;
  int _usSpeakerId = 0;
  int _ukSpeakerId = 0;
  String _readAloudAccent = 'us';

  double get speed => _speed;
  double get volume => _volume;
  int get usSpeakerId => _usSpeakerId;
  int get ukSpeakerId => _ukSpeakerId;
  String get readAloudAccent => _readAloudAccent;
  bool get isSpeaking => _engine.isSpeaking;

  TtsModelManager get modelManager => _modelManager;

  /// Display name for the currently active read-aloud model.
  String get currentModelDisplayName {
    final model = TtsModels.forAccent(_readAloudAccent);
    if (_modelManager.isReady(model)) {
      return model.displayName;
    }
    return 'Not Downloaded';
  }

  Future<void> initialize() async {
    _modelManager = TtsModelManager();
    await _modelManager.initialize();

    _engine = TtsEngine(modelManager: _modelManager);
    await _engine.initialize();

    _engine.onSpeakingChanged = () {
      notifyListeners();
    };

    final prefs = await SharedPreferences.getInstance();
    _speed = prefs.getDouble(_keySpeed) ?? defaultSpeed;
    _volume = prefs.getDouble(_keyVolume) ?? defaultVolume;
    _usSpeakerId = prefs.getInt(_keyUsSpeakerId) ?? 0;
    _ukSpeakerId = prefs.getInt(_keyUkSpeakerId) ?? 0;
    _readAloudAccent = prefs.getString(_keyReadAloudAccent) ?? 'us';

    notifyListeners();
  }

  /// Speak text using the configured read-aloud accent.
  Future<void> speak(String text) async {
    final model = TtsModels.forAccent(_readAloudAccent);
    final speakerId = _readAloudAccent == 'uk' ? _ukSpeakerId : _usSpeakerId;
    await _engine.speak(
      text: text,
      model: model,
      speakerId: speakerId,
      speed: _speed,
      volume: _volume,
    );
  }

  /// Speak text with a specific accent (for phonetics card).
  Future<void> speakWithAccent(String text, String accent) async {
    await stop();
    final model = TtsModels.forAccent(accent);
    final speakerId = accent == 'uk' ? _ukSpeakerId : _usSpeakerId;
    await _engine.speak(
      text: text,
      model: model,
      speakerId: speakerId,
      speed: _speed,
      volume: _volume,
    );
  }

  Future<void> stop() async {
    await _engine.stop();
  }

  Future<void> update({
    required double speed,
    required double volume,
    int? usSpeakerId,
    int? ukSpeakerId,
    String? readAloudAccent,
  }) async {
    _speed = speed;
    _volume = volume;
    if (usSpeakerId != null) _usSpeakerId = usSpeakerId;
    if (ukSpeakerId != null) _ukSpeakerId = ukSpeakerId;
    if (readAloudAccent != null) _readAloudAccent = readAloudAccent;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySpeed, speed);
    await prefs.setDouble(_keyVolume, volume);
    await prefs.setInt(_keyUsSpeakerId, _usSpeakerId);
    await prefs.setInt(_keyUkSpeakerId, _ukSpeakerId);
    await prefs.setString(_keyReadAloudAccent, _readAloudAccent);

    notifyListeners();
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }
}
