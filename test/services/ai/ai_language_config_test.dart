import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni/services/ai/ai_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('AiLanguageConfig persists vocabularyLevel in json', () {
    const config = AiLanguageConfig(
      detail: ExplanationDetail.brief,
      explanationLanguage: 'English',
      customPrompt: 'Explain {selectedText}',
      customPromptModeEnabled: true,
      vocabularyLevel: 'gre',
    );

    final json = config.toJson();
    final restored = AiLanguageConfig.fromJson(json);

    expect(restored.customPromptModeEnabled, isTrue);
    expect(restored.customPrompt, 'Explain {selectedText}');
    expect(restored.explanationLanguage, 'English');
    expect(restored.vocabularyLevel, 'gre');
  });

  test(
    'AiLanguageConfig legacy json without vocabularyLevel stays compatible',
    () {
      final restored = AiLanguageConfig.fromJson(<String, dynamic>{
        'model': 'gpt-4o-mini',
        'detail': 'balanced',
        'customPrompt': 'Legacy prompt',
      });

      expect(restored.customPromptModeEnabled, isFalse);
      expect(restored.customPrompt, 'Legacy prompt');
      expect(restored.vocabularyLevel, isEmpty);
    },
  );

  test('AiSettingsService persists global model and provider', () async {
    final service = AiSettingsService();
    await service.initialize();

    expect(service.model, AiSettingsService.defaultModel);
    expect(service.provider, AiSettingsService.defaultProvider);

    await service.updateGlobal(
      baseUrl: 'https://example.com/v1',
      apiKey: 'test-key',
      model: 'claude-3-5-sonnet',
      provider: AiProviderKind.anthropicCompatible,
    );

    final reloaded = AiSettingsService();
    await reloaded.initialize();
    expect(reloaded.model, 'claude-3-5-sonnet');
    expect(reloaded.provider, AiProviderKind.anthropicCompatible);
  });

  test('AiSettingsService lifts legacy per-language model into global', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'ai_config_map': '{"en_US":{"model":"gpt-4-turbo","detail":"balanced"}}',
    });
    final service = AiSettingsService();
    await service.initialize();

    expect(service.model, 'gpt-4-turbo');
  });

  test(
    'configForLanguage returns English-aware default vocabulary level',
    () async {
      final service = AiSettingsService();

      await service.initialize();

      expect(service.configForLanguage('en_US').vocabularyLevel, 'cet6');
      expect(service.configForLanguage('en').vocabularyLevel, 'cet6');
      expect(service.configForLanguage('es_ES').vocabularyLevel, isEmpty);
    },
  );

  test('isEnglishLanguageCode recognizes common English variants', () {
    expect(AiSettingsService.isEnglishLanguageCode('en'), isTrue);
    expect(AiSettingsService.isEnglishLanguageCode('en-US'), isTrue);
    expect(AiSettingsService.isEnglishLanguageCode('en_US'), isTrue);
    expect(AiSettingsService.isEnglishLanguageCode('en-GB'), isTrue);
    expect(AiSettingsService.isEnglishLanguageCode('es_ES'), isFalse);
  });

  test('vocabularyOptionsFor returns English presets only', () {
    final englishOptions = AiSettingsService.vocabularyOptionsFor('en_US');

    expect(englishOptions.map((option) => option.id), <String>[
      'cet4',
      'cet6',
      'ielts',
      'toefl',
      'gre',
    ]);
    expect(AiSettingsService.vocabularyOptionsFor('es_ES'), isEmpty);
  });

  test('vocabularyInstruction returns content only for English presets', () {
    for (final levelId in const <String>[
      'cet4',
      'cet6',
      'ielts',
      'toefl',
      'gre',
    ]) {
      expect(
        AiSettingsService.vocabularyInstruction(
          languageCode: 'en_US',
          levelId: levelId,
        ),
        isNotEmpty,
      );
    }

    expect(
      AiSettingsService.vocabularyInstruction(
        languageCode: 'es_ES',
        levelId: 'gre',
      ),
      isEmpty,
    );
  });
}
