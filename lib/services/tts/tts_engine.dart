import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'tts_model_config.dart';
import 'tts_model_manager.dart';

class TtsEngine {
  final TtsModelManager _modelManager;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, sherpa_onnx.OfflineTts> _engines = {};

  bool _initialized = false;
  bool _isSpeaking = false;
  late String _tempDir;

  VoidCallback? onSpeakingChanged;

  bool get isSpeaking => _isSpeaking;

  TtsEngine({required TtsModelManager modelManager})
      : _modelManager = modelManager;

  Future<void> initialize() async {
    if (_initialized) return;

    sherpa_onnx.initBindings();

    final tmpDir = await getTemporaryDirectory();
    _tempDir = tmpDir.path;

    _audioPlayer.onPlayerComplete.listen((_) {
      _isSpeaking = false;
      onSpeakingChanged?.call();
    });

    _initialized = true;
  }

  sherpa_onnx.OfflineTts _getOrCreateEngine(TtsModelInfo model) {
    if (_engines.containsKey(model.id)) {
      return _engines[model.id]!;
    }

    final modelPath = _modelManager.getModelPath(model);
    final tokensPath = _modelManager.getTokensPath(model);
    final dataDir = _modelManager.getDataDir(model);

    final vits = sherpa_onnx.OfflineTtsVitsModelConfig(
      model: modelPath,
      tokens: tokensPath,
      dataDir: dataDir,
      lengthScale: 1.0,
    );

    final modelConfig = sherpa_onnx.OfflineTtsModelConfig(
      vits: vits,
      numThreads: 2,
      debug: false,
    );

    final config = sherpa_onnx.OfflineTtsConfig(
      model: modelConfig,
      maxNumSenetences: 2,
    );

    final engine = sherpa_onnx.OfflineTts(config);
    _engines[model.id] = engine;
    return engine;
  }

  Future<void> speak({
    required String text,
    required TtsModelInfo model,
    int speakerId = 0,
    double speed = 1.0,
    double volume = 1.0,
  }) async {
    if (!_modelManager.isReady(model)) {
      debugPrint('[TtsEngine] Model ${model.id} not ready');
      return;
    }

    final engine = _getOrCreateEngine(model);

    _isSpeaking = true;
    onSpeakingChanged?.call();

    try {
      final audio = engine.generate(text: text, sid: speakerId, speed: speed);

      final wavPath = p.join(_tempDir, 'tts_output_${model.id}.wav');
      sherpa_onnx.writeWave(
        filename: wavPath,
        samples: audio.samples,
        sampleRate: audio.sampleRate,
      );

      await _audioPlayer.setVolume(volume);
      await _audioPlayer.play(DeviceFileSource(wavPath));
    } catch (e) {
      debugPrint('[TtsEngine] speak error: $e');
      _isSpeaking = false;
      onSpeakingChanged?.call();
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _isSpeaking = false;
    onSpeakingChanged?.call();
  }

  void dispose() {
    _audioPlayer.dispose();
    for (final engine in _engines.values) {
      engine.free();
    }
    _engines.clear();
  }

  /// Remove cached engine for a model (e.g. after model deletion).
  void invalidateEngine(String modelId) {
    final engine = _engines.remove(modelId);
    engine?.free();
  }
}
