import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/ai/ai_settings_service.dart';

void main() {
  test('AiLanguageConfig persists customPromptModeEnabled in json', () {
    const config = AiLanguageConfig(
      model: 'gpt-4o-mini',
      detail: ExplanationDetail.brief,
      explanationLanguage: 'English',
      customPrompt: 'Explain {selectedText}',
      customPromptModeEnabled: true,
    );

    final json = config.toJson();
    final restored = AiLanguageConfig.fromJson(json);

    expect(restored.customPromptModeEnabled, isTrue);
    expect(restored.customPrompt, 'Explain {selectedText}');
    expect(restored.explanationLanguage, 'English');
  });

  test(
    'AiLanguageConfig defaults customPromptModeEnabled to false for legacy json',
    () {
      final restored = AiLanguageConfig.fromJson(<String, dynamic>{
        'model': 'gpt-4o-mini',
        'detail': 'balanced',
        'customPrompt': 'Legacy prompt',
      });

      expect(restored.customPromptModeEnabled, isFalse);
      expect(restored.customPrompt, 'Legacy prompt');
    },
  );
}
