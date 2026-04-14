import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/phonetics/phonetics_candidate_builder.dart';

void main() {
  test('builds conservative ordered fallbacks', () {
    expect(buildPhoneticsFallbackCandidates(' co-operate '), <String>[
      'co-operate',
      'co operate',
      'cooperate',
    ]);
    expect(buildPhoneticsFallbackCandidates('bookmarked'), <String>[
      'bookmarked',
      'bookmark',
      'bookmarke',
    ]);
    expect(buildPhoneticsFallbackCandidates('OpenAI'), <String>[
      'OpenAI',
      'openai',
      'Open AI',
    ]);
    expect(buildPhoneticsFallbackCandidates('3rd'), <String>['3rd', 'third']);
  });

  test('normalizes cache keys across case and punctuation', () {
    expect(normalizePhoneticsCacheKey(' OpenAI '), 'openai');
    expect(normalizePhoneticsCacheKey('"Open AI"'), 'open ai');
  });
}
