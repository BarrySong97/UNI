import 'package:flutter/foundation.dart';

import 'tts_voice_types.dart';

/// A single voice entry in the built-in offline TTS catalog.
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
    required this.defaultSpeakerId,
    required this.estimatedSizeMB,
    required this.downloadUrl,
    required this.dirName,
    required this.modelFileName,
    this.voicesFileName,
    this.lexiconFileNames = const <String>[],
    required this.gender,
  });

  /// Unique voice key, e.g. `en_US-kokoro-bella`.
  final String key;

  /// Display name, e.g. `Bella`.
  final String name;

  /// Full locale code, e.g. `en_US`.
  final String languageCode;

  /// Language family, e.g. `en`.
  final String languageFamily;

  /// English name of the language, e.g. `English`.
  final String languageName;

  /// English name of the country, e.g. `United States`.
  final String countryName;

  /// Catalog variant label, e.g. `kokoro`.
  final String quality;

  /// Number of selectable speakers for this entry.
  final int numSpeakers;

  /// Named speaker -> ID mapping.
  final Map<String, int> speakerIdMap;

  /// Default speaker ID used for playback.
  final int defaultSpeakerId;

  /// Estimated download size in MB.
  final int estimatedSizeMB;

  final String downloadUrl;
  final String dirName;
  final String modelFileName;
  final String? voicesFileName;
  final List<String> lexiconFileNames;
  final VoiceGender gender;

  String get displayName => name;
}

/// Language group for display in settings.
class TtsLanguageGroup {
  const TtsLanguageGroup({
    required this.languageCode,
    required this.languageName,
    required this.countryName,
    required this.voices,
  });

  final String languageCode;
  final String languageName;
  final String countryName;
  final List<TtsVoiceInfo> voices;

  String get displayLabel => '$languageName ($countryName)';
}

/// Built-in Kokoro English voice catalog.
class TtsVoiceCatalog extends ChangeNotifier {
  static final List<TtsVoiceInfo> _kokoroVoices = <TtsVoiceInfo>[
    _KokoroCatalog.alloy,
    _KokoroCatalog.aoede,
    _KokoroCatalog.bella,
    _KokoroCatalog.heart,
    _KokoroCatalog.jessica,
    _KokoroCatalog.nicole,
    _KokoroCatalog.nova,
    _KokoroCatalog.sky,
    _KokoroCatalog.adam,
    _KokoroCatalog.echo,
    _KokoroCatalog.eric,
    _KokoroCatalog.fenrir,
    _KokoroCatalog.liam,
    _KokoroCatalog.michael,
    _KokoroCatalog.onyx,
    _KokoroCatalog.puck,
    _KokoroCatalog.alice,
    _KokoroCatalog.emma,
    _KokoroCatalog.isabella,
    _KokoroCatalog.lily,
    _KokoroCatalog.daniel,
    _KokoroCatalog.fable,
    _KokoroCatalog.george,
    _KokoroCatalog.lewis,
  ];

  List<TtsVoiceInfo> _voices = const <TtsVoiceInfo>[];
  Map<String, TtsLanguageGroup> _languageGroups = const <String, TtsLanguageGroup>{};
  bool _isLoading = false;
  String? _error;

  List<TtsVoiceInfo> get voices => _voices;
  Map<String, TtsLanguageGroup> get languageGroups => _languageGroups;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _voices = List<TtsVoiceInfo>.unmodifiable(_kokoroVoices);
      _buildLanguageGroups();
      debugPrint(
        '[TtsVoiceCatalog] Loaded built-in Kokoro catalog '
        '(${_voices.length} voices)',
      );
    } catch (e) {
      _voices = const <TtsVoiceInfo>[];
      _languageGroups = const <String, TtsLanguageGroup>{};
      _error = e.toString();
      debugPrint('[TtsVoiceCatalog] Catalog load error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await initialize();
  }

  List<TtsVoiceInfo> voicesForLanguage(String languageCode) {
    return _languageGroups[languageCode]?.voices ?? const <TtsVoiceInfo>[];
  }

  TtsVoiceInfo? findVoice(String voiceKey) {
    for (final voice in _voices) {
      if (voice.key == voiceKey) {
        return voice;
      }
    }
    return null;
  }

  void _buildLanguageGroups() {
    final grouped = <String, List<TtsVoiceInfo>>{};
    for (final voice in _voices) {
      grouped.putIfAbsent(voice.languageCode, () => <TtsVoiceInfo>[]).add(voice);
    }

    final built = <String, TtsLanguageGroup>{};
    for (final entry in grouped.entries) {
      final sortedVoices = List<TtsVoiceInfo>.from(entry.value)
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      final first = sortedVoices.first;
      built[entry.key] = TtsLanguageGroup(
        languageCode: entry.key,
        languageName: first.languageName,
        countryName: first.countryName,
        voices: List<TtsVoiceInfo>.unmodifiable(sortedVoices),
      );
    }

    _languageGroups = Map<String, TtsLanguageGroup>.unmodifiable(built);
  }
}

abstract final class _KokoroCatalog {
  static const String _downloadUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/'
      'kokoro-multi-lang-v1_0.tar.bz2';
  static const String _dirName = 'kokoro-multi-lang-v1_0';
  static const String _modelFileName = 'model.onnx';
  static const String _voicesFileName = 'voices.bin';
  static const int _estimatedSizeMB = 350;

  static final TtsVoiceInfo alloy = _usFemale('alloy', 'Alloy', 0);
  static final TtsVoiceInfo aoede = _usFemale('aoede', 'Aoede', 1);
  static final TtsVoiceInfo bella = _usFemale('bella', 'Bella', 2);
  static final TtsVoiceInfo heart = _usFemale('heart', 'Heart', 3);
  static final TtsVoiceInfo jessica = _usFemale('jessica', 'Jessica', 4);
  static final TtsVoiceInfo nicole = _usFemale('nicole', 'Nicole', 6);
  static final TtsVoiceInfo nova = _usFemale('nova', 'Nova', 7);
  static final TtsVoiceInfo sky = _usFemale('sky', 'Sky', 10);
  static final TtsVoiceInfo adam = _usMale('adam', 'Adam', 11);
  static final TtsVoiceInfo echo = _usMale('echo', 'Echo', 12);
  static final TtsVoiceInfo eric = _usMale('eric', 'Eric', 13);
  static final TtsVoiceInfo fenrir = _usMale('fenrir', 'Fenrir', 14);
  static final TtsVoiceInfo liam = _usMale('liam', 'Liam', 15);
  static final TtsVoiceInfo michael = _usMale('michael', 'Michael', 16);
  static final TtsVoiceInfo onyx = _usMale('onyx', 'Onyx', 17);
  static final TtsVoiceInfo puck = _usMale('puck', 'Puck', 18);

  static final TtsVoiceInfo alice = _gbFemale('alice', 'Alice', 20);
  static final TtsVoiceInfo emma = _gbFemale('emma', 'Emma', 21);
  static final TtsVoiceInfo isabella = _gbFemale('isabella', 'Isabella', 22);
  static final TtsVoiceInfo lily = _gbFemale('lily', 'Lily', 23);
  static final TtsVoiceInfo daniel = _gbMale('daniel', 'Daniel', 24);
  static final TtsVoiceInfo fable = _gbMale('fable', 'Fable', 25);
  static final TtsVoiceInfo george = _gbMale('george', 'George', 26);
  static final TtsVoiceInfo lewis = _gbMale('lewis', 'Lewis', 27);

  static TtsVoiceInfo _usFemale(String slug, String name, int speakerId) =>
      TtsVoiceInfo(
        key: 'en_US-kokoro-$slug',
        name: name,
        languageCode: 'en_US',
        languageFamily: 'en',
        languageName: 'English',
        countryName: 'United States',
        quality: 'kokoro',
        numSpeakers: 1,
        speakerIdMap: <String, int>{},
        defaultSpeakerId: speakerId,
        estimatedSizeMB: _estimatedSizeMB,
        downloadUrl: _downloadUrl,
        dirName: _dirName,
        modelFileName: _modelFileName,
        voicesFileName: _voicesFileName,
        lexiconFileNames: <String>['lexicon-us-en.txt', 'lexicon-zh.txt'],
        gender: VoiceGender.female,
      );

  static TtsVoiceInfo _usMale(String slug, String name, int speakerId) =>
      TtsVoiceInfo(
        key: 'en_US-kokoro-$slug',
        name: name,
        languageCode: 'en_US',
        languageFamily: 'en',
        languageName: 'English',
        countryName: 'United States',
        quality: 'kokoro',
        numSpeakers: 1,
        speakerIdMap: <String, int>{},
        defaultSpeakerId: speakerId,
        estimatedSizeMB: _estimatedSizeMB,
        downloadUrl: _downloadUrl,
        dirName: _dirName,
        modelFileName: _modelFileName,
        voicesFileName: _voicesFileName,
        lexiconFileNames: <String>['lexicon-us-en.txt', 'lexicon-zh.txt'],
        gender: VoiceGender.male,
      );

  static TtsVoiceInfo _gbFemale(String slug, String name, int speakerId) =>
      TtsVoiceInfo(
        key: 'en_GB-kokoro-$slug',
        name: name,
        languageCode: 'en_GB',
        languageFamily: 'en',
        languageName: 'English',
        countryName: 'United Kingdom',
        quality: 'kokoro',
        numSpeakers: 1,
        speakerIdMap: <String, int>{},
        defaultSpeakerId: speakerId,
        estimatedSizeMB: _estimatedSizeMB,
        downloadUrl: _downloadUrl,
        dirName: _dirName,
        modelFileName: _modelFileName,
        voicesFileName: _voicesFileName,
        lexiconFileNames: <String>['lexicon-us-en.txt', 'lexicon-zh.txt'],
        gender: VoiceGender.female,
      );

  static TtsVoiceInfo _gbMale(String slug, String name, int speakerId) =>
      TtsVoiceInfo(
        key: 'en_GB-kokoro-$slug',
        name: name,
        languageCode: 'en_GB',
        languageFamily: 'en',
        languageName: 'English',
        countryName: 'United Kingdom',
        quality: 'kokoro',
        numSpeakers: 1,
        speakerIdMap: <String, int>{},
        defaultSpeakerId: speakerId,
        estimatedSizeMB: _estimatedSizeMB,
        downloadUrl: _downloadUrl,
        dirName: _dirName,
        modelFileName: _modelFileName,
        voicesFileName: _voicesFileName,
        lexiconFileNames: <String>['lexicon-us-en.txt', 'lexicon-zh.txt'],
        gender: VoiceGender.male,
      );
}
