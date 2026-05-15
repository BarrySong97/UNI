import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni/services/ai/ai_settings_service.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/phonetics/ai_phonetics_service.dart';
import 'package:uni/services/phonetics/phonetics_service.dart';

void main() {
  test('stops fallback pipeline after original input hits', () async {
    final visited = <String>[];
    final service = PhoneticsService(
      localLookupOverride: (candidate) async {
        visited.add(candidate);
        if (candidate == 'walked') {
          return const PhoneticsResult(us: 'wˈɔkt', uk: '');
        }
        return PhoneticsResult.empty;
      },
    );

    final outcome = await service.lookupWithOutcome('walked');

    expect(visited, <String>['walked']);
    expect(outcome.foundLocally, isTrue);
    expect(outcome.result.us, 'wˈɔkt');
  });

  test('stops fallback pipeline after lowercase hit', () async {
    final visited = <String>[];
    final service = PhoneticsService(
      localLookupOverride: (candidate) async {
        visited.add(candidate);
        if (candidate == 'openai') {
          return const PhoneticsResult(us: 'ipa', uk: '');
        }
        return PhoneticsResult.empty;
      },
    );

    final outcome = await service.lookupWithOutcome('OpenAI');

    expect(visited, <String>['OpenAI', 'openai']);
    expect(outcome.foundLocally, isTrue);
    expect(outcome.result.us, 'ipa');
  });

  test('uses global normalized AI cache when local lookup misses', () async {
    final database = AppDatabase();
    await database.upsertPhoneticsCache(
      normalizedText: 'openai',
      usIpa: 'ˌoʊpənˈeɪˈaɪ',
      ukIpa: '',
      source: 'ai',
    );

    final service = PhoneticsService(
      database: database,
      localLookupOverride: (_) async => PhoneticsResult.empty,
    );

    final outcome = await service.lookupWithOutcome('OpenAI');

    expect(outcome.foundLocally, isFalse);
    expect(outcome.foundInAiCache, isTrue);
    expect(outcome.result.us, 'ˌoʊpənˈeɪˈaɪ');
  });

  test('fetchWithAiAndCache persists result for later lookups', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = AiSettingsService();
    await settings.initialize();
    await settings.updateGlobal(
      baseUrl: 'https://example.com/v1',
      apiKey: 'token',
    );
    final database = AppDatabase();
    final aiService = AiPhoneticsService(
      settings: settings,
      requester:
          ({
            required String baseUrl,
            required String apiKey,
            required String model,
            required String systemPrompt,
            required String userPrompt,
          }) async => '{"us":"ˌoʊpənˈeɪˈaɪ","uk":"ˌəʊpənˈeɪˈaɪ"}',
    );
    final service = PhoneticsService(
      database: database,
      aiPhoneticsService: aiService,
      aiSettingsService: settings,
      localLookupOverride: (_) async => PhoneticsResult.empty,
    );

    final fetched = await service.fetchWithAiAndCache('OpenAI');
    final cachedOutcome = await service.lookupWithOutcome('openai');

    expect(fetched.us, 'ˌoʊpənˈeɪˈaɪ');
    expect(cachedOutcome.foundInAiCache, isTrue);
    expect(cachedOutcome.result.uk, 'ˌəʊpənˈeɪˈaɪ');
  });
}
