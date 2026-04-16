import 'tts_voice_catalog.dart';
import 'tts_voice_types.dart';

class TtsModelInfo {
  const TtsModelInfo({
    required this.id,
    required this.displayName,
    required this.languageCode,
    required this.downloadUrl,
    required this.dirName,
    required this.modelFileName,
    required this.speakerCount,
    required this.estimatedSizeMB,
    this.defaultSpeakerId = 0,
    this.voicesFileName,
    this.lexiconFileNames = const <String>[],
    this.gender = VoiceGender.unknown,
  });

  final String id;
  final String displayName;

  /// Language locale code, e.g. "en_US", "fr_FR".
  final String languageCode;
  final String downloadUrl;

  /// Directory name after extraction.
  final String dirName;

  /// ONNX model file relative to [dirName].
  final String modelFileName;

  final int speakerCount;
  final int estimatedSizeMB;
  final int defaultSpeakerId;
  final String? voicesFileName;
  final List<String> lexiconFileNames;
  final VoiceGender gender;

  String get tokensRelative => 'tokens.txt';
  String get dataDirRelative => 'espeak-ng-data';

  /// Construct from a catalog voice entry.
  factory TtsModelInfo.fromVoiceInfo(TtsVoiceInfo voice) {
    return TtsModelInfo(
      id: voice.key,
      displayName: voice.displayName,
      languageCode: voice.languageCode,
      downloadUrl: voice.downloadUrl,
      dirName: voice.dirName,
      modelFileName: voice.modelFileName,
      speakerCount: voice.numSpeakers,
      estimatedSizeMB: voice.estimatedSizeMB,
      defaultSpeakerId: voice.defaultSpeakerId,
      voicesFileName: voice.voicesFileName,
      lexiconFileNames: voice.lexiconFileNames,
      gender: voice.gender,
    );
  }
}

/// Built-in fallback models when the catalog is not yet loaded.
abstract final class TtsBuiltinModels {
  static const usModel = TtsModelInfo(
    id: 'en_US-kokoro-bella',
    displayName: 'Bella',
    languageCode: 'en_US',
    downloadUrl:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-multi-lang-v1_0.tar.bz2',
    dirName: 'kokoro-multi-lang-v1_0',
    modelFileName: 'model.onnx',
    speakerCount: 1,
    estimatedSizeMB: 350,
    defaultSpeakerId: 2,
    voicesFileName: 'voices.bin',
    lexiconFileNames: <String>['lexicon-us-en.txt', 'lexicon-zh.txt'],
    gender: VoiceGender.female,
  );

  static const ukModel = TtsModelInfo(
    id: 'en_GB-kokoro-emma',
    displayName: 'Emma',
    languageCode: 'en_GB',
    downloadUrl:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-multi-lang-v1_0.tar.bz2',
    dirName: 'kokoro-multi-lang-v1_0',
    modelFileName: 'model.onnx',
    speakerCount: 1,
    estimatedSizeMB: 350,
    defaultSpeakerId: 21,
    voicesFileName: 'voices.bin',
    lexiconFileNames: <String>['lexicon-us-en.txt', 'lexicon-zh.txt'],
    gender: VoiceGender.female,
  );

  static const List<TtsModelInfo> all = [usModel, ukModel];
}
