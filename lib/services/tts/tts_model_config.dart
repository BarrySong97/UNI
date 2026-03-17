import 'tts_voice_catalog.dart';

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
    this.gender = VoiceGender.unknown,
  });

  final String id;
  final String displayName;

  /// Language locale code, e.g. "en_US", "fr_FR".
  final String languageCode;

  final String downloadUrl;

  /// Directory name after extraction (e.g. "vits-piper-en_US-libritts_r-medium").
  final String dirName;

  /// ONNX model file relative to [dirName].
  final String modelFileName;

  final int speakerCount;
  final int estimatedSizeMB;
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
      gender: voice.gender,
    );
  }
}

/// Built-in fallback models when the catalog is not yet loaded.
abstract final class TtsBuiltinModels {
  static const usModel = TtsModelInfo(
    id: 'en_US-libritts_r-medium',
    displayName: 'LibriTTS-R Medium',
    languageCode: 'en_US',
    downloadUrl:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-libritts_r-medium.tar.bz2',
    dirName: 'vits-piper-en_US-libritts_r-medium',
    modelFileName: 'en_US-libritts_r-medium.onnx',
    speakerCount: 904,
    estimatedSizeMB: 75,
  );

  static const ukModel = TtsModelInfo(
    id: 'en_GB-alba-medium',
    displayName: 'Alba Medium',
    languageCode: 'en_GB',
    downloadUrl:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_GB-alba-medium.tar.bz2',
    dirName: 'vits-piper-en_GB-alba-medium',
    modelFileName: 'en_GB-alba-medium.onnx',
    speakerCount: 1,
    estimatedSizeMB: 64,
  );

  static const List<TtsModelInfo> all = [usModel, ukModel];
}
