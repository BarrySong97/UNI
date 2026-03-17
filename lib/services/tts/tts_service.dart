import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsService extends ChangeNotifier {
  static const String _keySpeechRate = 'tts_speech_rate';
  static const String _keyPitch = 'tts_pitch';
  static const String _keyVolume = 'tts_volume';
  static const String _keyVoiceName = 'tts_voice_name';
  static const String _keyVoiceLocale = 'tts_voice_locale';

  static const double defaultSpeechRate = 0.5;
  static const double defaultPitch = 1.0;
  static const double defaultVolume = 1.0;

  final FlutterTts _tts = FlutterTts();

  double _speechRate = defaultSpeechRate;
  double _pitch = defaultPitch;
  double _volume = defaultVolume;
  String? _voiceName;
  String? _voiceLocale;
  bool _isSpeaking = false;

  double get speechRate => _speechRate;
  double get pitch => _pitch;
  double get volume => _volume;
  String? get voiceName => _voiceName;
  String? get voiceLocale => _voiceLocale;
  bool get isSpeaking => _isSpeaking;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _speechRate = prefs.getDouble(_keySpeechRate) ?? defaultSpeechRate;
    _pitch = prefs.getDouble(_keyPitch) ?? defaultPitch;
    _volume = prefs.getDouble(_keyVolume) ?? defaultVolume;
    _voiceName = prefs.getString(_keyVoiceName);
    _voiceLocale = prefs.getString(_keyVoiceLocale);

    // iOS requires explicit audio category for playback.
    if (Platform.isIOS) {
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        ],
        IosTextToSpeechAudioMode.defaultMode,
      );
    }

    await _applySettings();

    // Set default language if no voice is configured.
    if (_voiceName == null) {
      await _tts.setLanguage('en-US');
    }

    _tts.setStartHandler(() {
      debugPrint('[TtsService] started speaking');
      _isSpeaking = true;
      notifyListeners();
    });
    _tts.setCompletionHandler(() {
      debugPrint('[TtsService] completed');
      _isSpeaking = false;
      notifyListeners();
    });
    _tts.setCancelHandler(() {
      debugPrint('[TtsService] cancelled');
      _isSpeaking = false;
      notifyListeners();
    });
    _tts.setErrorHandler((msg) {
      debugPrint('[TtsService] error: $msg');
      _isSpeaking = false;
      notifyListeners();
    });

    notifyListeners();
  }

  Future<void> _applySettings() async {
    await _tts.setSpeechRate(_speechRate);
    await _tts.setPitch(_pitch);
    await _tts.setVolume(_volume);
    if (_voiceName != null && _voiceLocale != null) {
      await _tts.setVoice({'name': _voiceName!, 'locale': _voiceLocale!});
    }
  }

  Future<List<Map<String, String>>> getVoices() async {
    final voices = await _tts.getVoices as List<dynamic>;
    final parsed = voices
        .cast<Map<dynamic, dynamic>>()
        .map((v) {
          final name = v['name']?.toString() ?? '';
          final locale = v['locale']?.toString() ?? '';
          final quality = _parseVoiceQuality(name);
          final displayName = parseDisplayName(name);
          return {
            'name': name,
            'locale': locale,
            'quality': quality,
            'displayName': displayName,
          };
        })
        .where((v) => v['name']!.isNotEmpty)
        .toList();

    // Build a set of voices that have an enhanced variant so we can
    // hide their compact counterparts.
    final enhancedKeys = <String>{};
    for (final v in parsed) {
      if (v['quality'] == 'enhanced' || v['quality'] == 'premium') {
        enhancedKeys.add('${v['locale']}|${v['displayName']}');
      }
    }

    // Filter out compact voices when a higher-quality version exists.
    final filtered = parsed.where((v) {
      if (v['quality'] == 'compact') {
        return !enhancedKeys.contains('${v['locale']}|${v['displayName']}');
      }
      return true;
    }).toList();

    // Sort: enhanced/premium first, then default, then compact.
    // Within the same quality tier, sort by displayName.
    const qualityOrder = {'premium': 0, 'enhanced': 1, 'default': 2, 'compact': 3};
    filtered.sort((a, b) {
      final qa = qualityOrder[a['quality']] ?? 2;
      final qb = qualityOrder[b['quality']] ?? 2;
      if (qa != qb) return qa.compareTo(qb);
      return a['displayName']!.compareTo(b['displayName']!);
    });

    return filtered;
  }

  /// Parse quality tier from Apple voice identifier.
  static String _parseVoiceQuality(String voiceName) {
    final lower = voiceName.toLowerCase();
    if (lower.contains('.premium.')) return 'premium';
    if (lower.contains('.enhanced.')) return 'enhanced';
    if (lower.contains('.compact.')) return 'compact';
    return 'default';
  }

  /// Extract a human-readable display name from the system voice identifier.
  static String parseDisplayName(String voiceName) {
    // Apple format: "com.apple.voice.compact.en-US.Samantha"
    // or "com.apple.speech.synthesis.voice.Samantha"
    final parts = voiceName.split('.');
    if (parts.length >= 2) {
      return parts.last;
    }
    return voiceName;
  }

  Future<void> speak(String text) async {
    final result = await _tts.speak(text);
    debugPrint('[TtsService] speak result=$result, text="${text.substring(0, text.length.clamp(0, 50))}"');
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<void> update({
    required double speechRate,
    required double pitch,
    required double volume,
    String? voiceName,
    String? voiceLocale,
  }) async {
    _speechRate = speechRate;
    _pitch = pitch;
    _volume = volume;
    _voiceName = voiceName;
    _voiceLocale = voiceLocale;

    await _applySettings();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySpeechRate, speechRate);
    await prefs.setDouble(_keyPitch, pitch);
    await prefs.setDouble(_keyVolume, volume);
    if (voiceName != null) {
      await prefs.setString(_keyVoiceName, voiceName);
    } else {
      await prefs.remove(_keyVoiceName);
    }
    if (voiceLocale != null) {
      await prefs.setString(_keyVoiceLocale, voiceLocale);
    } else {
      await prefs.remove(_keyVoiceLocale);
    }

    notifyListeners();
  }
}
