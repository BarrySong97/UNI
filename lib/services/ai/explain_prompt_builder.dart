import 'ai_settings_service.dart';

String buildExplainSystemPrompt({
  required String bookTitle,
  required String selectedText,
  required String context,
  required String languageCode,
  required AiLanguageConfig config,
  required bool includePartOfSpeech,
}) {
  final detailLine = AiSettingsService.detailInstruction(config.detail);
  final languageLine = AiSettingsService.languageInstruction(
    config.explanationLanguage,
  );

  if (config.customPromptModeEnabled) {
    final promptTemplate = config.customPrompt.isNotEmpty
        ? config.customPrompt
        : AiSettingsService.defaultPrompt;
    final basePrompt = promptTemplate
        .replaceAll('{bookTitle}', bookTitle)
        .replaceAll('{selectedText}', selectedText)
        .replaceAll('{context}', context);
    return '$basePrompt\n\n$detailLine'
        '${languageLine.isNotEmpty ? '\n$languageLine' : ''}';
  }

  final vocabularyLine = AiSettingsService.vocabularyInstruction(
    languageCode: languageCode,
    levelId: config.vocabularyLevel,
  );
  final languageInstruction = languageLine.isNotEmpty
      ? '\n- $languageLine'
      : '';
  final vocabularyInstruction = vocabularyLine.isNotEmpty
      ? '\n- $vocabularyLine'
      : '';
  final partOfSpeechInstruction = includePartOfSpeech
      ? '\n- Because the selection is a single word, set partOfSpeech to the '
            'most likely part of speech in this exact context '
            '(for example: noun, verb, adjective).'
      : '\n- Because the selection is not a single word, return an empty '
            'string for partOfSpeech.';

  return 'You are a reading assistant for "$bookTitle".\n'
      'The user selected text: "$selectedText"\n'
      'Context:\n---\n$context\n---\n\n'
      'Goal: help the reader quickly understand the selected text in context.\n'
      'Return ONLY a JSON object (no markdown, no code fence, no extra text) '
      'with this exact schema:\n'
      '{\n'
      '  "partOfSpeech": "string",\n'
      '  "meaningExplain": "string",\n'
      '  "detailExplain": ["string", "string"]\n'
      '}\n\n'
      'Constraints:\n'
      '- Keep each string concise and practical.\n'
      '- Focus on this exact context, not generic dictionary entries.\n'
      '- Keep detailExplain to 2-3 short bullets.\n'
      '$partOfSpeechInstruction\n'
      '- $detailLine'
      '$languageInstruction'
      '$vocabularyInstruction';
}
