class TtsModelInfo {
  const TtsModelInfo({
    required this.id,
    required this.displayName,
    required this.accent,
    required this.downloadUrl,
    required this.dirName,
    required this.modelFileName,
    required this.speakerCount,
    required this.estimatedSizeMB,
  });

  final String id;
  final String displayName;

  /// 'us' or 'uk'.
  final String accent;

  final String downloadUrl;

  /// Directory name after extraction (e.g. "vits-piper-en_US-libritts_r-medium").
  final String dirName;

  /// ONNX model file relative to [dirName].
  final String modelFileName;

  final int speakerCount;
  final int estimatedSizeMB;

  String get tokensRelative => 'tokens.txt';
  String get dataDirRelative => 'espeak-ng-data';
}

abstract final class TtsModels {
  static const usModel = TtsModelInfo(
    id: 'en_US-libritts_r-medium',
    displayName: 'LibriTTS-R Medium',
    accent: 'us',
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
    accent: 'uk',
    downloadUrl:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_GB-alba-medium.tar.bz2',
    dirName: 'vits-piper-en_GB-alba-medium',
    modelFileName: 'en_GB-alba-medium.onnx',
    speakerCount: 1,
    estimatedSizeMB: 64,
  );

  static const List<TtsModelInfo> all = [usModel, ukModel];

  static TtsModelInfo forAccent(String accent) {
    return accent == 'uk' ? ukModel : usModel;
  }
}
