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
typedef TtsWaveBytesWriter =
    Uint8List Function({required Float32List samples, required int sampleRate});
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
  static const int defaultNumThreads = 4;
  static const int shortTextCharacterLimit = 80;
  static const int _maxCachedShortAudios = 30;
  static const int _maxCachedShortAudioBytes = 8 * 1024 * 1024;
  static const Duration engineIdleTtl = Duration(seconds: 90);

  final TtsModelManager _modelManager;
  final TtsAudioPlayer _audioPlayer;
  final TtsTempDirectoryProvider _tempDirectoryProvider;
  final TtsBindingsInitializer _bindingsInitializer;
  final TtsWaveWriter _waveWriter;
  final TtsWaveBytesWriter _waveBytesWriter;
  final TtsSynthesizerFactory _synthesizerFactory;
  final Map<String, _EngineEntry> _engines = {};
  final Map<String, Future<TtsSynthesizer>> _engineCreations = {};
  final _ShortAudioLruCache _shortAudioCache = _ShortAudioLruCache(
    maxEntries: _maxCachedShortAudios,
    maxBytes: _maxCachedShortAudioBytes,
  );
  final Set<String> _ownedPlaybackPaths = <String>{};

  bool _initialized = false;
  bool _isSpeaking = false;
  late String _tempDir;
  String? _activePlaybackPath;
  int _playRequestId = 0;
  int _speakRequestId = 0;
  Timer? _engineIdleTimer;

  VoidCallback? onSpeakingChanged;

  bool get isSpeaking => _isSpeaking;

  TtsEngine({
    required TtsModelManager modelManager,
    TtsAudioPlayer? audioPlayer,
    TtsTempDirectoryProvider? tempDirectoryProvider,
    TtsBindingsInitializer? bindingsInitializer,
    TtsWaveWriter? waveWriter,
    TtsWaveBytesWriter? waveBytesWriter,
    TtsSynthesizerFactory? synthesizerFactory,
  }) : _modelManager = modelManager,
       _audioPlayer = audioPlayer ?? DefaultTtsAudioPlayer(),
       _tempDirectoryProvider =
           tempDirectoryProvider ?? _defaultTempDirectoryProvider,
       _bindingsInitializer = bindingsInitializer ?? sherpa_onnx.initBindings,
       _waveWriter = waveWriter ?? sherpa_onnx.writeWave,
       _waveBytesWriter = waveBytesWriter ?? _defaultWaveBytesWriter,
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

  Future<TtsSynthesizer> _getOrCreateEngine(TtsModelInfo model) async {
    final cached = _engines[model.id];
    if (cached != null) {
      return cached.synthesizer;
    }

    final inFlight = _engineCreations[model.id];
    if (inFlight != null) {
      return inFlight;
    }

    _releaseEnginesExcept(model.id);
    final stopwatch = Stopwatch()..start();
    final creation = Future<TtsSynthesizer>.sync(() {
      final engine = _synthesizerFactory(model, _modelManager);
      _engines[model.id] = _EngineEntry(engine);
      _logTiming('engine create', stopwatch.elapsed, modelId: model.id);
      return engine;
    });
    _engineCreations[model.id] = creation;
    try {
      return await creation;
    } finally {
      _engineCreations.remove(model.id);
    }
  }

  Future<void> warmUp(TtsModelInfo model) async {
    if (!_modelManager.isReady(model)) {
      return;
    }
    await _getOrCreateEngine(model);
    _scheduleEngineRelease();
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

    final operationWatch = Stopwatch()..start();
    final requestId = _nextSpeakRequestId();
    _logTiming(
      'speak start',
      Duration.zero,
      modelId: model.id,
      requestId: requestId,
      textLength: text.trim().runes.length,
    );
    final engine = await _getOrCreateEngine(model);
    final shortText = _isShortText(text);
    final cacheKey = shortText
        ? _ShortAudioCacheKey(
            modelId: model.id,
            speakerId: speakerId,
            speed: speed,
            volume: volume,
            text: _normalizeShortText(text),
          )
        : null;

    _isSpeaking = true;
    onSpeakingChanged?.call();

    try {
      if (cacheKey != null) {
        final cached = _shortAudioCache.get(cacheKey);
        if (cached != null) {
          _logTiming(
            'short cache hit',
            operationWatch.elapsed,
            modelId: model.id,
            requestId: requestId,
            totalElapsed: operationWatch.elapsed,
          );
          await _playBytes(
            cached,
            volume: volume,
            modelId: model.id,
            requestId: requestId,
            totalWatch: operationWatch,
          );
          _scheduleEngineRelease();
          return;
        }
      }

      final generateWatch = Stopwatch()..start();
      final audio = engine.generate(text: text, sid: speakerId, speed: speed);
      _logTiming(
        'generate',
        generateWatch.elapsed,
        modelId: model.id,
        requestId: requestId,
        totalElapsed: operationWatch.elapsed,
      );

      if (cacheKey != null) {
        final encodeWatch = Stopwatch()..start();
        final wavBytes = _waveBytesWriter(
          samples: audio.samples,
          sampleRate: audio.sampleRate,
        );
        _logTiming(
          'encode bytes',
          encodeWatch.elapsed,
          modelId: model.id,
          requestId: requestId,
          totalElapsed: operationWatch.elapsed,
        );
        _shortAudioCache.put(cacheKey, wavBytes);
        await _playBytes(
          wavBytes,
          volume: volume,
          modelId: model.id,
          requestId: requestId,
          totalWatch: operationWatch,
        );
        _scheduleEngineRelease();
        return;
      }

      final writeWatch = Stopwatch()..start();
      final wavPath = _nextPlaybackPath(model.id);
      _waveWriter(
        filename: wavPath,
        samples: audio.samples,
        sampleRate: audio.sampleRate,
      );
      _logTiming(
        'write wav',
        writeWatch.elapsed,
        modelId: model.id,
        requestId: requestId,
        totalElapsed: operationWatch.elapsed,
      );
      _activePlaybackPath = wavPath;
      _ownedPlaybackPaths.add(wavPath);

      await _playFile(
        wavPath,
        volume: volume,
        modelId: model.id,
        requestId: requestId,
        totalWatch: operationWatch,
      );
      _scheduleEngineRelease();
    } catch (e) {
      debugPrint('[TtsEngine] speak error: $e');
      await _deletePlaybackPath(_activePlaybackPath);
      _activePlaybackPath = null;
      _isSpeaking = false;
      onSpeakingChanged?.call();
    }
  }

  Future<void> stop() async {
    final stopwatch = Stopwatch()..start();
    await _audioPlayer.stop();
    await _deletePlaybackPath(_activePlaybackPath);
    _activePlaybackPath = null;
    _isSpeaking = false;
    onSpeakingChanged?.call();
    _logTiming('stop', stopwatch.elapsed);
    _scheduleEngineRelease();
  }

  Future<void> releaseIdleResources() async {
    if (_isSpeaking) {
      await stop();
    }
    _releaseEngines();
    _shortAudioCache.clear();
  }

  void clearShortAudioCache() {
    _shortAudioCache.clear();
  }

  void dispose() {
    _engineIdleTimer?.cancel();
    _deleteAllPlaybackPathsSync();
    _audioPlayer.dispose();
    _releaseEngines();
  }

  /// Remove cached engine for a model (e.g. after model deletion).
  void invalidateEngine(String modelId) {
    final engine = _engines.remove(modelId);
    engine?.synthesizer.free();
    _engineCreations.remove(modelId);
    _shortAudioCache.clear();
  }

  Future<void> _handlePlaybackComplete() async {
    await _deletePlaybackPath(_activePlaybackPath);
    _activePlaybackPath = null;
    _isSpeaking = false;
    onSpeakingChanged?.call();
    _scheduleEngineRelease();
  }

  Future<void> _playBytes(
    Uint8List bytes, {
    required double volume,
    required String modelId,
    int? requestId,
    Stopwatch? totalWatch,
  }) async {
    final playWatch = Stopwatch()..start();
    try {
      await _audioPlayer.playBytes(bytes, volume: volume);
      _logTiming(
        'play bytes start',
        playWatch.elapsed,
        modelId: modelId,
        requestId: requestId,
        totalElapsed: totalWatch?.elapsed,
      );
    } catch (e) {
      debugPrint('[TtsEngine] play bytes failed, falling back to file: $e');
      final wavPath = _nextPlaybackPath(modelId);
      final file = File(wavPath)..createSync(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      _activePlaybackPath = wavPath;
      _ownedPlaybackPaths.add(wavPath);
      await _playFile(
        wavPath,
        volume: volume,
        modelId: modelId,
        requestId: requestId,
        totalWatch: totalWatch,
      );
    }
  }

  Future<void> _playFile(
    String path, {
    required double volume,
    required String modelId,
    int? requestId,
    Stopwatch? totalWatch,
  }) async {
    final playWatch = Stopwatch()..start();
    await _audioPlayer.playFile(path, volume: volume);
    _logTiming(
      'play file start',
      playWatch.elapsed,
      modelId: modelId,
      requestId: requestId,
      totalElapsed: totalWatch?.elapsed,
    );
  }

  void _scheduleEngineRelease() {
    _engineIdleTimer?.cancel();
    _engineIdleTimer = Timer(engineIdleTtl, () {
      if (_isSpeaking) {
        _scheduleEngineRelease();
        return;
      }
      _releaseEngines();
    });
  }

  void _releaseEngines() {
    _engineIdleTimer?.cancel();
    _engineIdleTimer = null;
    for (final engine in _engines.values) {
      engine.synthesizer.free();
    }
    _engines.clear();
    _engineCreations.clear();
  }

  void _releaseEnginesExcept(String modelId) {
    final staleModelIds = _engines.keys
        .where((cachedModelId) => cachedModelId != modelId)
        .toList(growable: false);
    for (final staleModelId in staleModelIds) {
      final engine = _engines.remove(staleModelId);
      engine?.synthesizer.free();
    }
  }

  String _nextPlaybackPath(String modelId) {
    _playRequestId += 1;
    final safeModelId = _sanitizeFileComponent(modelId);
    return p.join(_tempDir, 'tts_output_${safeModelId}_$_playRequestId.wav');
  }

  int _nextSpeakRequestId() {
    _speakRequestId += 1;
    return _speakRequestId;
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

  static Uint8List _defaultWaveBytesWriter({
    required Float32List samples,
    required int sampleRate,
  }) {
    final byteData = ByteData(44 + samples.length * 2);
    void writeAscii(int offset, String value) {
      for (var i = 0; i < value.length; i += 1) {
        byteData.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    const channels = 1;
    const bitsPerSample = 16;
    final dataBytes = samples.length * 2;
    writeAscii(0, 'RIFF');
    byteData.setUint32(4, 36 + dataBytes, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little);
    byteData.setUint16(22, channels, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(
      28,
      sampleRate * channels * bitsPerSample ~/ 8,
      Endian.little,
    );
    byteData.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
    byteData.setUint16(34, bitsPerSample, Endian.little);
    writeAscii(36, 'data');
    byteData.setUint32(40, dataBytes, Endian.little);

    var offset = 44;
    for (final sample in samples) {
      final clamped = sample.clamp(-1.0, 1.0);
      final value = clamped < 0
          ? (clamped * 32768).round()
          : (clamped * 32767).round();
      byteData.setInt16(offset, value, Endian.little);
      offset += 2;
    }
    return byteData.buffer.asUint8List();
  }

  static TtsSynthesizer _defaultSynthesizerFactory(
    TtsModelInfo model,
    TtsModelManager modelManager,
  ) {
    return _SherpaTtsSynthesizer(
      sherpa_onnx.OfflineTts(buildSherpaConfig(model, modelManager)),
    );
  }

  @visibleForTesting
  static sherpa_onnx.OfflineTtsConfig buildSherpaConfig(
    TtsModelInfo model,
    TtsModelManager modelManager, {
    int numThreads = defaultNumThreads,
  }) {
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
      numThreads: numThreads,
      debug: false,
    );

    return sherpa_onnx.OfflineTtsConfig(
      model: modelConfig,
      maxNumSenetences: 2,
    );
  }

  static String _sanitizeFileComponent(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return sanitized.isEmpty ? 'tts' : sanitized;
  }

  static bool _isShortText(String text) {
    return text.trim().runes.length <= shortTextCharacterLimit;
  }

  static String _normalizeShortText(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  static void _logTiming(
    String label,
    Duration elapsed, {
    String? modelId,
    int? requestId,
    int? textLength,
    Duration? totalElapsed,
  }) {
    debugPrint(
      '[TtsEngine] ts=${_formatTimestamp(DateTime.now())}'
      '${requestId == null ? '' : ' req=$requestId'}'
      ' $label=${elapsed.inMilliseconds}ms'
      '${totalElapsed == null ? '' : ' total=${totalElapsed.inMilliseconds}ms'}'
      '${textLength == null ? '' : ' len=$textLength'}'
      '${modelId == null ? '' : ' model=$modelId'}',
    );
  }

  static String _formatTimestamp(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    String three(int value) => value.toString().padLeft(3, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}.${three(time.millisecond)}';
  }
}

class _EngineEntry {
  const _EngineEntry(this.synthesizer);

  final TtsSynthesizer synthesizer;
}

class _ShortAudioCacheKey {
  const _ShortAudioCacheKey({
    required this.modelId,
    required this.speakerId,
    required this.speed,
    required this.volume,
    required this.text,
  });

  final String modelId;
  final int speakerId;
  final double speed;
  final double volume;
  final String text;

  @override
  bool operator ==(Object other) {
    return other is _ShortAudioCacheKey &&
        other.modelId == modelId &&
        other.speakerId == speakerId &&
        other.speed == speed &&
        other.volume == volume &&
        other.text == text;
  }

  @override
  int get hashCode => Object.hash(modelId, speakerId, speed, volume, text);
}

class _ShortAudioLruCache {
  _ShortAudioLruCache({required this.maxEntries, required this.maxBytes});

  final int maxEntries;
  final int maxBytes;
  final Map<_ShortAudioCacheKey, Uint8List> _entries = {};
  int _totalBytes = 0;

  Uint8List? get(_ShortAudioCacheKey key) {
    final value = _entries.remove(key);
    if (value == null) {
      return null;
    }
    _entries[key] = value;
    return value;
  }

  void put(_ShortAudioCacheKey key, Uint8List value) {
    final oldValue = _entries.remove(key);
    if (oldValue != null) {
      _totalBytes -= oldValue.lengthInBytes;
    }
    _entries[key] = value;
    _totalBytes += value.lengthInBytes;
    _evictOverflow();
  }

  void clear() {
    _entries.clear();
    _totalBytes = 0;
  }

  void _evictOverflow() {
    while (_entries.length > maxEntries || _totalBytes > maxBytes) {
      final oldestKey = _entries.keys.first;
      final oldestValue = _entries.remove(oldestKey)!;
      _totalBytes -= oldestValue.lengthInBytes;
    }
  }
}
