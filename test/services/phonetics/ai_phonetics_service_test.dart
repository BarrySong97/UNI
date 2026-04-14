import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni/services/ai/ai_settings_service.dart';
import 'package:uni/services/phonetics/ai_phonetics_service.dart';
import 'package:uni/services/phonetics/phonetics_models.dart';

void main() {
  late AiSettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    settings = AiSettingsService();
    await settings.initialize();
  });

  test('parses structured US/UK JSON from requester', () async {
    await settings.updateGlobal(
      baseUrl: 'https://example.com/v1',
      apiKey: 'test-key',
    );

    final service = AiPhoneticsService(
      settings: settings,
      requester:
          ({
            required String baseUrl,
            required String apiKey,
            required String model,
            required String systemPrompt,
            required String userPrompt,
          }) async {
            expect(baseUrl, 'https://example.com/v1');
            expect(apiKey, 'test-key');
            expect(model, AiSettingsService.defaultModel);
            expect(userPrompt, 'OpenAI');
            expect(systemPrompt, contains('Return only strict JSON'));
            return '{"us":"ˌoʊpənˈeɪˈaɪ","uk":"ˌəʊpənˈeɪˈaɪ"}';
          },
    );

    final result = await service.lookupIpa('OpenAI');

    expect(
      result,
      const TypeMatcher<PhoneticsResult>()
          .having((value) => value.us, 'us', 'ˌoʊpənˈeɪˈaɪ')
          .having((value) => value.uk, 'uk', 'ˌəʊpənˈeɪˈaɪ'),
    );
  });

  test('rejects markdown or invalid json responses', () async {
    await settings.updateGlobal(
      baseUrl: 'https://example.com/v1',
      apiKey: 'test-key',
    );
    final service = AiPhoneticsService(
      settings: settings,
      requester:
          ({
            required String baseUrl,
            required String apiKey,
            required String model,
            required String systemPrompt,
            required String userPrompt,
          }) async => '```json {"us":"ipa"} ```',
    );

    expect(
      () => service.lookupIpa('OpenAI'),
      throwsA(isA<PhoneticsAiLookupException>()),
    );
  });

  test('throws when AI is not configured', () {
    final service = AiPhoneticsService(
      settings: settings,
      requester:
          ({
            required String baseUrl,
            required String apiKey,
            required String model,
            required String systemPrompt,
            required String userPrompt,
          }) async => '{"us":"","uk":""}',
    );

    expect(
      () => service.lookupIpa('OpenAI'),
      throwsA(isA<PhoneticsAiNotConfiguredException>()),
    );
  });
}
