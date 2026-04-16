import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'tts_model_config.dart';
import 'tts_audio_player.dart';
import 'tts_model_manager.dart';

typedef TtsTempDirectoryProvider = Future<String> Function();
typedef TtsBindingsInitializer = void Function();
typedef TtsWaveWriter =
    void Function({
      required String filename,
      required Float32List samples,
      required int sampleRate,
    });
typedef TtsSynthesizerFactory =
    TtsSynthesizer Function(TtsModelInfo model, TtsModelManager modelManager);

abstract class TtsSynthesizer {
  sherpa_onnx.GeneratedAudio generate({
    required String text,
    required int sid,
    required double speed,
  });

  void free();
}

class _SherpaTtsSynthesizer implements TtsSynthesizer {
  _SherpaTtsSynthesizer(this._tts);

  final sherpa_onnx.OfflineTts _tts;

  @override
  sherpa_onnx.GeneratedAudio generate({
    required String text,
    required int sid,
    required double speed,
  }) {
    return _tts.generate(text: text, sid: sid, speed: speed);
  }

  @override
  void free() {
    _tts.free();
  }
}

class TtsEngine {
  final TtsModelManager _modelManager;
  final TtsAudioPlayer _audioPlayer;
  final TtsTempDirectoryProvider _tempDirectoryProvider;
  final TtsBindingsInitializer _bindingsInitializer;
  final TtsWaveWriter _waveWriter;
  final TtsSynthesizerFactory _synthesizerFactory;
  final Map<String, TtsSynthesizer> _engines = {};
  final Set<String> _ownedPlaybackPaths = <String>{};

  bool _initialized = false;
  bool _isSpeaking = false;
  late String _tempDir;
  String? _activePlaybackPath;
  int _playRequestId = 0;

  VoidCallback? onSpeakingChanged;

  bool get isSpeaking => _isSpeaking;

  TtsEngine({
    required TtsModelManager modelManager,
    TtsAudioPlayer? audioPlayer,
    TtsTempDirectoryProvider? tempDirectoryProvider,
    TtsBindingsInitializer? bindingsInitializer,
    TtsWaveWriter? waveWriter,
    TtsSynthesizerFactory? synthesizerFactory,
  }) : _modelManager = modelManager,
       _audioPlayer = audioPlayer ?? DefaultTtsAudioPlayer(),
       _tempDirectoryProvider =
           tempDirectoryProvider ?? _defaultTempDirectoryProvider,
       _bindingsInitializer = bindingsInitializer ?? sherpa_onnx.initBindings,
       _waveWriter = waveWriter ?? sherpa_onnx.writeWave,
       _synthesizerFactory = synthesizerFactory ?? _defaultSynthesizerFactory;

  Future<void> initialize() async {
    if (_initialized) return;

    _bindingsInitializer();
    _tempDir = await _tempDirectoryProvider();
    _audioPlayer.setOnComplete(() {
      unawaited(_handlePlaybackComplete());
    });

    _initialized = true;
  }

  TtsSynthesizer _getOrCreateEngine(TtsModelInfo model) {
    if (_engines.containsKey(model.id)) {
      return _engines[model.id]!;
    }
    final engine = _synthesizerFactory(model, _modelManager);
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
      final audio = engine.generate(
        text: text,
        sid: speakerId,
        speed: speed,
      );

      final wavPath = _nextPlaybackPath(model.id);
      _waveWriter(
        filename: wavPath,
        samples: audio.samples,
        sampleRate: audio.sampleRate,
      );
      _activePlaybackPath = wavPath;
      _ownedPlaybackPaths.add(wavPath);

      await _audioPlayer.playFile(wavPath, volume: volume);
    } catch (e) {
      debugPrint('[TtsEngine] speak error: $e');
      await _deletePlaybackPath(_activePlaybackPath);
      _activePlaybackPath = null;
      _isSpeaking = false;
      onSpeakingChanged?.call();
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    await _deletePlaybackPath(_activePlaybackPath);
    _activePlaybackPath = null;
    _isSpeaking = false;
    onSpeakingChanged?.call();
  }

  void dispose() {
    _deleteAllPlaybackPathsSync();
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

  Future<void> _handlePlaybackComplete() async {
    await _deletePlaybackPath(_activePlaybackPath);
    _activePlaybackPath = null;
    _isSpeaking = false;
    onSpeakingChanged?.call();
  }

  String _nextPlaybackPath(String modelId) {
    _playRequestId += 1;
    final safeModelId = _sanitizeFileComponent(modelId);
    return p.join(_tempDir, 'tts_output_${safeModelId}_$_playRequestId.wav');
  }

  void _deleteAllPlaybackPathsSync() {
    final paths = _ownedPlaybackPaths.toList(growable: false);
    for (final path in paths) {
      _deletePlaybackPathSync(path);
    }
    _activePlaybackPath = null;
  }

  Future<void> _deletePlaybackPath(String? path) async {
    if (path == null) {
      return;
    }
    _ownedPlaybackPaths.remove(path);
    final file = File(path);
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup only.
    }
  }

  void _deletePlaybackPathSync(String? path) {
    if (path == null) {
      return;
    }
    _ownedPlaybackPaths.remove(path);
    final file = File(path);
    try {
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {
      // Best-effort cleanup only.
    }
  }

  static Future<String> _defaultTempDirectoryProvider() async {
    final tmpDir = await getTemporaryDirectory();
    return tmpDir.path;
  }

  static TtsSynthesizer _defaultSynthesizerFactory(
    TtsModelInfo model,
    TtsModelManager modelManager,
  ) {
    final kokoro = sherpa_onnx.OfflineTtsKokoroModelConfig(
      model: modelManager.getModelPath(model),
      voices: modelManager.getVoicesPath(model) ?? '',
      tokens: modelManager.getTokensPath(model),
      dataDir: modelManager.getDataDir(model),
      lengthScale: 1.0,
      lexicon: modelManager.getLexiconPaths(model).join(','),
    );
    final modelConfig = sherpa_onnx.OfflineTtsModelConfig(
      kokoro: kokoro,
      numThreads: 2,
      debug: false,
    );

    final config = sherpa_onnx.OfflineTtsConfig(
      model: modelConfig,
      maxNumSenetences: 2,
    );

    return _SherpaTtsSynthesizer(sherpa_onnx.OfflineTts(config));
  }

  static String _sanitizeFileComponent(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return sanitized.isEmpty ? 'tts' : sanitized;
  }
}
