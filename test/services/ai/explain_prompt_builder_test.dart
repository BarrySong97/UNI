import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/ai/ai_settings_service.dart';
import 'package:uni/services/ai/explain_prompt_builder.dart';

void main() {
  String buildPrompt({
    required String languageCode,
    required AiLanguageConfig config,
  }) {
    return buildExplainSystemPrompt(
      bookTitle: 'The Great Gatsby',
      selectedText: 'ephemeral',
      context:
          'Yet the sight made him feel that the moment was ephemeral, destined to dissolve like morning mist under the indifferent sun.',
      languageCode: languageCode,
      config: config,
      includePartOfSpeech: true,
    );
  }

  test('structured English prompt includes vocabulary instruction', () {
    final prompt = buildPrompt(
      languageCode: 'en_US',
      config: const AiLanguageConfig(vocabularyLevel: 'cet6'),
    );

    expect(prompt, contains('CET-6 level English comprehension'));
  });

  test(
    'different English levels produce different vocabulary instructions',
    () {
      final cet6Prompt = buildPrompt(
        languageCode: 'en_US',
        config: const AiLanguageConfig(vocabularyLevel: 'cet6'),
      );
      final grePrompt = buildPrompt(
        languageCode: 'en_US',
        config: const AiLanguageConfig(vocabularyLevel: 'gre'),
      );

      expect(cet6Prompt, isNot(equals(grePrompt)));
      expect(grePrompt, contains('GRE-level English comprehension'));
    },
  );

  test('structured non-English prompt omits vocabulary instruction', () {
    final prompt = buildPrompt(
      languageCode: 'es_ES',
      config: const AiLanguageConfig(vocabularyLevel: 'gre'),
    );

    expect(prompt, isNot(contains('GRE-level English comprehension')));
    expect(prompt, isNot(contains('CET-6 level English comprehension')));
  });

  test('custom prompt mode omits vocabulary instruction', () {
    final prompt = buildPrompt(
      languageCode: 'en_US',
      config: const AiLanguageConfig(
        customPrompt: 'Explain {selectedText} in this context: {context}',
        customPromptModeEnabled: true,
        vocabularyLevel: 'gre',
      ),
    );

    expect(prompt, contains('Explain ephemeral in this context:'));
    expect(prompt, isNot(contains('GRE-level English comprehension')));
  });

  test(
    'structured prompt keeps explanation language alongside vocabulary level',
    () {
      final prompt = buildPrompt(
        languageCode: 'en_US',
        config: const AiLanguageConfig(
          explanationLanguage: 'Chinese',
          vocabularyLevel: 'cet6',
        ),
      );

      expect(prompt, contains('Respond in Chinese.'));
      expect(prompt, contains('Even if you respond in another language'));
    },
  );
}
