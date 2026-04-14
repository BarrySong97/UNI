import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';

import '../ai/ai_settings_service.dart';
import 'phonetics_models.dart';

typedef AiPhoneticsRequester =
    Future<String> Function({
      required String baseUrl,
      required String apiKey,
      required String model,
      required String systemPrompt,
      required String userPrompt,
    });

class AiPhoneticsService {
  AiPhoneticsService({
    required AiSettingsService settings,
    AiPhoneticsRequester? requester,
  }) : _settings = settings,
       _requester = requester ?? _defaultRequester;

  final AiSettingsService _settings;
  final AiPhoneticsRequester _requester;

  bool get isConfigured => _settings.isConfigured;

  Future<PhoneticsResult> lookupIpa(String text) async {
    if (!isConfigured) {
      throw const PhoneticsAiNotConfiguredException();
    }

    final rawResponse = await _requester(
      baseUrl: _settings.baseUrl,
      apiKey: _settings.apiKey,
      model: _settings.resolveConfig(null).model,
      systemPrompt: _systemPrompt,
      userPrompt: text,
    );

    final parsed = _parseResult(rawResponse);
    if (!parsed.hasAny) {
      throw const PhoneticsAiLookupException('AI did not return IPA.');
    }
    return parsed;
  }

  PhoneticsResult _parseResult(String rawResponse) {
    final trimmed = rawResponse.trim();
    if (trimmed.contains('```')) {
      throw const PhoneticsAiLookupException(
        'AI returned markdown instead of JSON.',
      );
    }

    final jsonStart = trimmed.indexOf('{');
    final jsonEnd = trimmed.lastIndexOf('}');
    if (jsonStart < 0 || jsonEnd <= jsonStart) {
      throw const PhoneticsAiLookupException('AI returned invalid JSON.');
    }

    final payload = trimmed.substring(jsonStart, jsonEnd + 1);
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) {
      throw const PhoneticsAiLookupException('AI returned invalid JSON.');
    }

    final us = _cleanIpa(decoded['us']);
    final uk = _cleanIpa(decoded['uk']);
    return PhoneticsResult(us: us, uk: uk);
  }

  String _cleanIpa(Object? value) {
    if (value is! String) {
      return '';
    }
    return value.trim().replaceAll('/', '');
  }

  static Future<String> _defaultRequester({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final ai = Genkit(
      plugins: [openAI(apiKey: apiKey, baseUrl: baseUrl)],
    );

    final response = StringBuffer();
    final stream = ai.generateStream(
      model: openAI.model(model),
      messages: <Message>[
        Message(
          role: Role.system,
          content: [TextPart(text: systemPrompt)],
        ),
        Message(
          role: Role.user,
          content: [TextPart(text: userPrompt)],
        ),
      ],
    );

    await for (final chunk in stream) {
      if (chunk.text.isNotEmpty) {
        response.write(chunk.text);
      }
    }

    return response.toString();
  }

  static const String _systemPrompt =
      'You are an English pronunciation assistant.\n'
      'Return only strict JSON with keys "us" and "uk".\n'
      'The values must be IPA strings without slashes.\n'
      'If you are unsure for one accent, return an empty string for that field.\n'
      'Do not include markdown, prose, or code fences.';
}
