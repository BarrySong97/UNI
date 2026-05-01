import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tts_engine.dart';
import 'tts_model_config.dart';
import 'tts_model_manager.dart';
import 'tts_voice_catalog.dart';

/// Per-language voice selection stored in SharedPreferences.
class VoiceSelection {
  const VoiceSelection({required this.voiceKey, this.speakerId = 0});

  final String voiceKey;
  final int speakerId;

  Map<String, dynamic> toJson() => {
    'voiceKey': voiceKey,
    'speakerId': speakerId,
  };

  factory VoiceSelection.fromJson(Map<String, dynamic> json) {
    return VoiceSelection(
      voiceKey: json['voiceKey'] as String,
      speakerId: (json['speakerId'] as num?)?.toInt() ?? 0,
    );
  }
}

class TtsService extends ChangeNotifier {
  // New keys.
  static const String _keySpeed = 'tts_speed';
  static const String _keyVolume = 'tts_volume';
  static const String _keyVoiceMap = 'tts_voice_map';
  static const String _keyDefaultEnglishAccent = 'tts_default_english_accent';

  // Legacy keys (for migration).
  static const String _keyLegacyUsSpeakerId = 'tts_us_speaker_id';
  static const String _keyLegacyUkSpeakerId = 'tts_uk_speaker_id';
  static const String _keyLegacyReadAloudAccent = 'tts_read_aloud_accent';

  static const double defaultSpeed = 1.0;
  static const double defaultVolume = 1.0;
  static const String defaultLanguage = 'en_US';

  late final TtsModelManager _modelManager;
  late final TtsEngine _engine;
  late final TtsVoiceCatalog _catalog;

  double _speed = defaultSpeed;
  double _volume = defaultVolume;
  String _defaultEnglishAccent = defaultLanguage;

  /// Per-language voice selections: languageCode -> VoiceSelection.
  final Map<String, VoiceSelection> _voiceMap = {};

  double get speed => _speed;
  double get volume => _volume;
  String get defaultEnglishAccent => _defaultEnglishAccent;
  Map<String, VoiceSelection> get voiceMap => Map.unmodifiable(_voiceMap);
  bool get isSpeaking => _engine.isSpeaking;

  TtsModelManager get modelManager => _modelManager;
  TtsVoiceCatalog get catalog => _catalog;

  /// Display name for a language's configured voice.
  String voiceDisplayName(String languageCode) {
    final selection = _voiceMap[languageCode];
    if (selection == null) return 'Not configured';
    final voice = _catalog.findVoice(selection.voiceKey);
    if (voice != null) return voice.displayName;
    return selection.voiceKey;
  }

  /// Get the configured voice model info for a language.
  TtsModelInfo? modelInfoForLanguage(String languageCode) {
    final selection = _voiceMap[languageCode];
    if (selection == null) return null;

    final voice = _catalog.findVoice(selection.voiceKey);
    if (voice != null) return TtsModelInfo.fromVoiceInfo(voice);

    // Fallback to built-in if catalog not loaded.
    for (final m in TtsBuiltinModels.all) {
      if (m.id == selection.voiceKey) return m;
    }
    return null;
  }

  /// List of language codes that have a voice configured.
  List<String> get configuredLanguages => _voiceMap.keys.toList();

  Future<void> initialize() async {
    _modelManager = TtsModelManager();
    await _modelManager.initialize();

    _engine = TtsEngine(modelManager: _modelManager);
    await _engine.initialize();

    _catalog = TtsVoiceCatalog();
    await _catalog.initialize();

    _engine.onSpeakingChanged = () {
      notifyListeners();
    };

    final prefs = await SharedPreferences.getInstance();
    _speed = prefs.getDouble(_keySpeed) ?? defaultSpeed;
    _volume = prefs.getDouble(_keyVolume) ?? defaultVolume;
    _defaultEnglishAccent =
        prefs.getString(_keyDefaultEnglishAccent) ?? defaultLanguage;

    // Load voice map or migrate from legacy settings.
    final voiceMapJson = prefs.getString(_keyVoiceMap);
    if (voiceMapJson != null) {
      _loadVoiceMap(voiceMapJson);
    } else {
      await _migrateLegacySettings(prefs);
    }

    await _normalizeVoiceMap(prefs);

    notifyListeners();
  }

  void _loadVoiceMap(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      _voiceMap.clear();
      for (final entry in map.entries) {
        _voiceMap[entry.key] = VoiceSelection.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('[TtsService] Error loading voice map: $e');
    }
  }

  Future<void> _migrateLegacySettings(SharedPreferences prefs) async {
    _voiceMap['en_US'] = VoiceSelection(
      voiceKey: TtsBuiltinModels.usModel.id,
      speakerId: TtsBuiltinModels.usModel.defaultSpeakerId,
    );

    _voiceMap['en_GB'] = VoiceSelection(
      voiceKey: TtsBuiltinModels.ukModel.id,
      speakerId: TtsBuiltinModels.ukModel.defaultSpeakerId,
    );

    // Save migrated settings.
    await _saveVoiceMap(prefs);

    // Clean up legacy keys.
    await prefs.remove(_keyLegacyUsSpeakerId);
    await prefs.remove(_keyLegacyUkSpeakerId);
    await prefs.remove(_keyLegacyReadAloudAccent);
  }

  Future<void> _normalizeVoiceMap(SharedPreferences prefs) async {
    var changed = false;

    final normalized = <String, VoiceSelection>{};
    for (final entry in _voiceMap.entries) {
      final languageCode = entry.key;
      final current = entry.value;
      final fallback = _defaultSelectionForLanguage(languageCode);
      final catalogVoice = _catalog.findVoice(current.voiceKey);

      late final VoiceSelection selection;
      if (catalogVoice == null && fallback != null) {
        selection = fallback;
      } else if (catalogVoice != null &&
          current.speakerId == 0 &&
          catalogVoice.defaultSpeakerId != 0) {
        selection = VoiceSelection(
          voiceKey: current.voiceKey,
          speakerId: catalogVoice.defaultSpeakerId,
        );
      } else {
        selection = current;
      }

      normalized[languageCode] = selection;
      if (selection.voiceKey != current.voiceKey ||
          selection.speakerId != current.speakerId) {
        changed = true;
      }
    }

    if (!normalized.containsKey('en_US')) {
      normalized['en_US'] = _defaultSelectionForLanguage('en_US')!;
      changed = true;
    }

    if (!normalized.containsKey('en_GB')) {
      normalized['en_GB'] = _defaultSelectionForLanguage('en_GB')!;
      changed = true;
    }

    _voiceMap
      ..clear()
      ..addAll(normalized);

    if (changed) {
      await _saveVoiceMap(prefs);
    }
  }

  /// Set voice for a language.
  Future<void> setVoiceForLanguage(
    String languageCode,
    String voiceKey, {
    int? speakerId,
  }) async {
    final previous = _voiceMap[languageCode];
    final resolvedSpeakerId = speakerId ?? _defaultSpeakerIdForVoice(voiceKey);
    _voiceMap[languageCode] = VoiceSelection(
      voiceKey: voiceKey,
      speakerId: resolvedSpeakerId,
    );

    if (previous != null && previous.voiceKey != voiceKey) {
      _engine.invalidateEngine(previous.voiceKey);
    }

    final prefs = await SharedPreferences.getInstance();
    await _saveVoiceMap(prefs);
    notifyListeners();
  }

  /// Remove a language configuration.
  Future<void> removeLanguage(String languageCode) async {
    final previous = _voiceMap.remove(languageCode);
    if (previous != null) {
      _engine.invalidateEngine(previous.voiceKey);
    }

    final prefs = await SharedPreferences.getInstance();
    await _saveVoiceMap(prefs);
    notifyListeners();
  }

  int _defaultSpeakerIdForVoice(String voiceKey) {
    final voice = _catalog.findVoice(voiceKey);
    if (voice != null) {
      return voice.defaultSpeakerId;
    }
    for (final model in TtsBuiltinModels.all) {
      if (model.id == voiceKey) {
        return model.defaultSpeakerId;
      }
    }
    return 0;
  }

  VoiceSelection? _defaultSelectionForLanguage(String languageCode) {
    if (languageCode == 'en_US') {
      return VoiceSelection(
        voiceKey: TtsBuiltinModels.usModel.id,
        speakerId: TtsBuiltinModels.usModel.defaultSpeakerId,
      );
    }
    if (languageCode == 'en_GB') {
      return VoiceSelection(
        voiceKey: TtsBuiltinModels.ukModel.id,
        speakerId: TtsBuiltinModels.ukModel.defaultSpeakerId,
      );
    }
    return null;
  }

  /// Set the default English accent (e.g. 'en_US' or 'en_GB').
  Future<void> setDefaultEnglishAccent(String languageCode) async {
    _defaultEnglishAccent = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultEnglishAccent, languageCode);
    notifyListeners();
  }

  /// Update playback settings.
  Future<void> updatePlayback({
    required double speed,
    required double volume,
  }) async {
    _speed = speed;
    _volume = volume;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySpeed, speed);
    await prefs.setDouble(_keyVolume, volume);
    _engine.clearShortAudioCache();
    notifyListeners();
  }

  Future<void> warmUpLanguage(String languageCode) async {
    final modelInfo = modelInfoForLanguage(languageCode);
    if (modelInfo == null || !_modelManager.isReady(modelInfo)) {
      return;
    }
    await _engine.warmUp(modelInfo);
  }

  Future<void> warmUpDefaultEnglishAccent() async {
    await warmUpLanguage(_defaultEnglishAccent);
  }

  Future<void> releaseIdleResources() async {
    await _engine.releaseIdleResources();
  }

  void handleMemoryPressure() {
    unawaited(_engine.releaseIdleResources());
  }

  Future<void> _saveVoiceMap(SharedPreferences prefs) async {
    final map = <String, dynamic>{};
    for (final entry in _voiceMap.entries) {
      map[entry.key] = entry.value.toJson();
    }
    await prefs.setString(_keyVoiceMap, jsonEncode(map));
  }

  /// Speak text using the voice configured for the given language.
  Future<void> speakWithLanguage(String text, String languageCode) async {
    await speakWithLanguageOptions(
      text,
      languageCode,
      speed: _speed,
      volume: _volume,
    );
  }

  Future<void> speakWithLanguageOptions(
    String text,
    String languageCode, {
    required double speed,
    required double volume,
  }) async {
    await stop();

    final modelInfo = modelInfoForLanguage(languageCode);
    if (modelInfo == null) {
      debugPrint('[TtsService] No voice configured for $languageCode');
      return;
    }

    final selection = _voiceMap[languageCode]!;
    await _engine.speak(
      text: text,
      model: modelInfo,
      speakerId: selection.speakerId,
      speed: speed,
      volume: volume,
    );
  }

  /// Preview a specific model without changing saved config.
  Future<void> previewVoice({
    required String text,
    required TtsModelInfo model,
    int speakerId = 0,
  }) async {
    await stop();
    await _engine.speak(
      text: text,
      model: model,
      speakerId: speakerId,
      speed: _speed,
      volume: _volume,
    );
  }

  /// Speak text using the default language (en_US fallback).
  Future<void> speak(String text) async {
    await speakWithLanguage(text, defaultLanguage);
  }

  /// Speak text using the best matching language for a book's language tag.
  /// Maps language family codes (e.g. "en") to specific locales (e.g. "en_US").
  Future<void> speakForBookLanguage(String text, String? bookLanguage) async {
    final languageCode = resolveBookLanguage(bookLanguage);
    await speakWithLanguage(text, languageCode);
  }

  /// Resolve a book's dc:language tag to a configured TTS language code.
  String resolveBookLanguage(String? bookLanguage) {
    if (bookLanguage == null || bookLanguage.isEmpty) {
      return _defaultEnglishAccent;
    }

    // Normalize: "en-US" -> "en_US", "en" -> "en"
    final normalized = bookLanguage.replaceAll('-', '_');

    // Exact match.
    if (_voiceMap.containsKey(normalized)) return normalized;

    // Family match: use default accent preference for English.
    final family = normalized.split('_').first;
    if (family == 'en') return _defaultEnglishAccent;

    for (final lang in _voiceMap.keys) {
      if (lang.startsWith('${family}_')) return lang;
    }

    return _defaultEnglishAccent;
  }

  Future<void> stop() async {
    await _engine.stop();
  }

  @override
  void dispose() {
    _engine.dispose();
    _catalog.dispose();
    super.dispose();
  }
}
