import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Gender of a TTS voice.
enum VoiceGender { male, female, unknown }

/// A single voice entry parsed from the piper voices.json catalog.
class TtsVoiceInfo {
  const TtsVoiceInfo({
    required this.key,
    required this.name,
    required this.languageCode,
    required this.languageFamily,
    required this.languageName,
    required this.countryName,
    required this.quality,
    required this.numSpeakers,
    required this.speakerIdMap,
    required this.estimatedSizeMB,
    required this.onnxRelativePath,
    required this.gender,
  });

  /// Unique voice key, e.g. "en_US-amy-medium".
  final String key;

  /// Speaker/voice name, e.g. "amy".
  final String name;

  /// Full locale code, e.g. "en_US".
  final String languageCode;

  /// Language family, e.g. "en".
  final String languageFamily;

  /// English name of the language, e.g. "English".
  final String languageName;

  /// English name of the country, e.g. "United States".
  final String countryName;

  /// Quality level: "x_low", "low", "medium", "high".
  final String quality;

  /// Number of speakers in this model.
  final int numSpeakers;

  /// Named speaker -> ID mapping (empty for single-speaker models).
  final Map<String, int> speakerIdMap;

  /// Estimated download size in MB.
  final int estimatedSizeMB;

  /// Relative path to the .onnx file within the HuggingFace repo.
  final String onnxRelativePath;

  /// Inferred gender of the voice.
  final VoiceGender gender;

  /// Display name combining speaker name and quality.
  String get displayName {
    final capitalized = name
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
    final q = quality[0].toUpperCase() + quality.substring(1);
    return '$capitalized ($q)';
  }

  /// sherpa-onnx download URL for this voice.
  String get downloadUrl =>
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-$key.tar.bz2';

  /// Expected directory name after extraction.
  String get dirName => 'vits-piper-$key';

  /// ONNX model file name.
  String get modelFileName => '$key.onnx';
}

/// Language group for display in settings.
class TtsLanguageGroup {
  const TtsLanguageGroup({
    required this.languageCode,
    required this.languageName,
    required this.countryName,
    required this.voices,
  });

  /// e.g. "en_US"
  final String languageCode;

  /// e.g. "English"
  final String languageName;

  /// e.g. "United States"
  final String countryName;

  /// All voices for this language+region.
  final List<TtsVoiceInfo> voices;

  /// Display label, e.g. "English (United States)".
  String get displayLabel => '$languageName ($countryName)';
}

/// Fetches, parses, and caches the piper voice catalog.
class TtsVoiceCatalog extends ChangeNotifier {
  static const String _cacheFileName = 'voices_cache.json';
  static const Duration _cacheMaxAge = Duration(days: 7);

  List<TtsVoiceInfo> _voices = [];
  Map<String, TtsLanguageGroup> _languageGroups = {};
  bool _isLoading = false;
  String? _error;

  List<TtsVoiceInfo> get voices => _voices;
  Map<String, TtsLanguageGroup> get languageGroups => _languageGroups;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize the catalog: load from cache first, then refresh if stale.
  Future<void> initialize() async {
    final cacheFile = await _cacheFile();

    // Try loading from cache.
    if (cacheFile.existsSync()) {
      try {
        final cacheContent = await cacheFile.readAsString();
        final cacheData = jsonDecode(cacheContent) as Map<String, dynamic>;
        final cachedAt = DateTime.fromMillisecondsSinceEpoch(
          cacheData['cached_at'] as int,
        );
        final isStale = DateTime.now().difference(cachedAt) > _cacheMaxAge;

        _parseVoicesJson(cacheData['data'] as Map<String, dynamic>);
        notifyListeners();

        if (isStale) {
          // Refresh in background.
          _fetchAndCache();
        }
        return;
      } catch (e) {
        debugPrint('[TtsVoiceCatalog] Cache read error: $e');
      }
    }

    // No valid cache, fetch from network.
    await _fetchAndCache();
  }

  /// Force refresh the catalog from network.
  Future<void> refresh() async {
    await _fetchAndCache();
  }

  /// Get voices for a specific language code.
  List<TtsVoiceInfo> voicesForLanguage(String languageCode) {
    return _languageGroups[languageCode]?.voices ?? [];
  }

  /// Find a voice by its key.
  TtsVoiceInfo? findVoice(String voiceKey) {
    for (final v in _voices) {
      if (v.key == voiceKey) return v;
    }
    return null;
  }

  Future<void> _fetchAndCache() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse(
          'https://huggingface.co/rhasspy/piper-voices/raw/main/voices.json',
        ),
      );
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        _parseVoicesJson(data);

        // Save cache.
        final cacheFile = await _cacheFile();
        final cacheData = jsonEncode({
          'cached_at': DateTime.now().millisecondsSinceEpoch,
          'data': data,
        });
        await cacheFile.writeAsString(cacheData);
      } else {
        _error = 'HTTP ${response.statusCode}';
      }
      client.close();
    } catch (e) {
      _error = e.toString();
      debugPrint('[TtsVoiceCatalog] Fetch error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void _parseVoicesJson(Map<String, dynamic> json) {
    final voices = <TtsVoiceInfo>[];

    for (final entry in json.entries) {
      try {
        final key = entry.key;
        final data = entry.value as Map<String, dynamic>;
        final language = data['language'] as Map<String, dynamic>;
        final files = data['files'] as Map<String, dynamic>;

        // Find the .onnx file path and size.
        String? onnxPath;
        int sizeBytes = 0;
        for (final fileEntry in files.entries) {
          if (fileEntry.key.endsWith('.onnx')) {
            onnxPath = fileEntry.key;
            final fileInfo = fileEntry.value as Map<String, dynamic>;
            sizeBytes = (fileInfo['size_bytes'] as num?)?.toInt() ?? 0;
            break;
          }
        }
        if (onnxPath == null) continue;

        final numSpeakers = (data['num_speakers'] as num?)?.toInt() ?? 1;
        final speakerIdMap = <String, int>{};
        final rawSpeakerMap = data['speaker_id_map'] as Map<String, dynamic>?;
        if (rawSpeakerMap != null) {
          for (final se in rawSpeakerMap.entries) {
            speakerIdMap[se.key] = (se.value as num).toInt();
          }
        }

        final voiceName = (data['name'] as String?) ?? key;
        final quality = (data['quality'] as String?) ?? 'medium';

        voices.add(TtsVoiceInfo(
          key: key,
          name: voiceName,
          languageCode: (language['code'] as String?) ?? '',
          languageFamily: (language['family'] as String?) ?? '',
          languageName: (language['name_english'] as String?) ?? '',
          countryName: (language['country_english'] as String?) ?? '',
          quality: quality,
          numSpeakers: numSpeakers,
          speakerIdMap: speakerIdMap,
          estimatedSizeMB: (sizeBytes / (1024 * 1024)).ceil(),
          onnxRelativePath: onnxPath,
          gender: _inferGender(key, voiceName, numSpeakers),
        ));
      } catch (e) {
        debugPrint('[TtsVoiceCatalog] Parse error for ${entry.key}: $e');
      }
    }

    _voices = voices;
    _buildLanguageGroups();
  }

  void _buildLanguageGroups() {
    final groups = <String, List<TtsVoiceInfo>>{};
    for (final voice in _voices) {
      groups.putIfAbsent(voice.languageCode, () => []).add(voice);
    }

    _languageGroups = {};
    for (final entry in groups.entries) {
      final first = entry.value.first;
      _languageGroups[entry.key] = TtsLanguageGroup(
        languageCode: entry.key,
        languageName: first.languageName,
        countryName: first.countryName,
        voices: entry.value,
      );
    }
  }

  Future<File> _cacheFile() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final modelsDir = p.join(docsDir.path, 'tts-models');
    await Directory(modelsDir).create(recursive: true);
    return File(p.join(modelsDir, _cacheFileName));
  }

  // ---------------------------------------------------------------------------
  // Gender inference
  // ---------------------------------------------------------------------------

  static VoiceGender _inferGender(
    String key,
    String name,
    int numSpeakers,
  ) {
    // Multi-speaker models -> unknown.
    if (numSpeakers > 1) return VoiceGender.unknown;

    final lower = '${key.toLowerCase()} ${name.toLowerCase()}';

    // Explicit keywords.
    if (lower.contains('female')) return VoiceGender.female;
    if (lower.contains('male')) return VoiceGender.male;

    // Check known gender map.
    final nameOnly = name.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (_knownFemaleNames.contains(nameOnly)) return VoiceGender.female;
    if (_knownMaleNames.contains(nameOnly)) return VoiceGender.male;

    return VoiceGender.unknown;
  }

  static const Set<String> _knownFemaleNames = {
    'amy',
    'alba',
    'cori',
    'kathleen',
    'kristin',
    'lessac',
    'eva',
    'kerstin',
    'ramona',
    'rapunzelina',
    'jenny',
    'jennydioco',
    'ljspeech',
    'salka',
    'ugla',
    'anna',
    'berta',
    'natia',
    'raya',
    'meera',
    'nathalie',
    'gosia',
    'lili',
    'lada',
    'lisa',
    'paola',
    'daniela',
    'siwis',
    'priyamvada',
    'irina',
  };

  static const Set<String> _knownMaleNames = {
    'alan',
    'bryce',
    'danny',
    'joe',
    'john',
    'ryan',
    'sam',
    'norman',
    'kareem',
    'thorsten',
    'karlsson',
    'pavoque',
    'dimitar',
    'amir',
    'harri',
    'gilles',
    'tom',
    'riccardo',
    'imre',
    'bui',
    'steinn',
    'aivars',
    'arjun',
    'pim',
    'ronnie',
    'mihai',
    'denis',
    'dmitri',
    'ruslan',
    'artur',
    'faber',
    'cadu',
    'pratham',
    'kusal',
    'fahrettin',
    'fettah',
  };
}
