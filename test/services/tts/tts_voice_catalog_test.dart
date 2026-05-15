import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/tts/tts_model_config.dart';
import 'package:uni/services/tts/tts_voice_catalog.dart';

void main() {
  test('loads built-in Kokoro English voices', () async {
    final catalog = TtsVoiceCatalog();

    await catalog.initialize();

    expect(catalog.error, isNull);
    expect(catalog.languageGroups.keys, containsAll(<String>['en_US', 'en_GB']));
    expect(catalog.voicesForLanguage('en_US'), isNotEmpty);
    expect(catalog.voicesForLanguage('en_GB'), isNotEmpty);

    final usDefault = catalog.findVoice(TtsBuiltinModels.usModel.id);
    final ukDefault = catalog.findVoice(TtsBuiltinModels.ukModel.id);

    expect(usDefault?.displayName, 'Bella');
    expect(usDefault?.defaultSpeakerId, 2);
    expect(
      usDefault?.lexiconFileNames,
      <String>['lexicon-us-en.txt', 'lexicon-zh.txt'],
    );
    expect(ukDefault?.displayName, 'Emma');
    expect(ukDefault?.defaultSpeakerId, 21);
    expect(
      ukDefault?.lexiconFileNames,
      <String>['lexicon-us-en.txt', 'lexicon-zh.txt'],
    );
  });
}
